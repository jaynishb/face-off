extends MiniGame
## Connect Four — standard 7x6 drop-token grid, tap a column to drop.
## Turn-based like Tic-Tac-Toe, but a single decisive match (no rounds):
## four in a row, any direction, wins outright.

const COLS := 7
const ROWS := 6
const DIRECTIONS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]

## Centred on the real visible rect rather than a hardcoded design box, so the
## board sits in the middle of the actual screen -- see Field.gd.
##
## cell is derived, not fixed. 7x78 fits inside a 720-wide portrait screen, so a
## fixed value would not crash or obviously misdraw -- it would just sit cramped
## and drift on a 20:9 phone, which is exactly the kind of wrongness that
## survives review and ships.
var cell := 78.0
var origin := Vector2.ZERO

## board[col] is a bottom-to-top stack of player ints for that column.
var board: Array = []
var current_turn := 1
var p1_pieces := 0
var p2_pieces := 0
var _match_active := false
var _turn_locked := false

## "col_row" -> { y, vel, target, player }. A cell being animated here is
## skipped by the static grid draw and drawn separately mid-drop, per the
## PRD's "animate the token drop with a bounce" note (deferred at Day 3).
var _falling: Dictionary = {}
const GRAVITY := 2600.0
const BOUNCE_DAMPING := 0.35
const SETTLE_VELOCITY := 40.0

func _init() -> void:
	game_id = "connect_four"
	display_name = "Connect Four"
	rules_text = "Tap a column to drop your piece.\nFour in a row — any direction — wins."
	match_duration = 0.0
	theme_bg = Palette.turn_tint(current_turn)
	view_mode = ViewMode.SHARED
	input_space = InputManager.Space.SCREEN

## Board geometry is derived from the live viewport every time it changes --
## a resize mid-match must move the board, not leave it where the first frame
## happened to put it (see MiniGame.layout).
func layout() -> void:
	# Leave headroom above and below for the mirrored turn banners.
	cell = minf((Field.right() - Field.left()) / (COLS + 0.6), Field.play_height() * 0.62 / ROWS)
	origin = Field.center() - Vector2(COLS * cell * 0.5, ROWS * cell * 0.5)
	# In-flight tokens target an absolute y, so retarget them onto the new
	# board position rather than letting them fall to a stale row.
	for key in _falling.keys():
		var f: Dictionary = _falling[key]
		var landed_row: int = int(key.split("_")[1])
		f.target = origin.y + landed_row * cell + cell * 0.5
		_falling[key] = f
	queue_redraw()

func setup(_config: Dictionary) -> void:
	layout()
	# Shared board straddling the midline -- ownership follows the turn, not
	# the screen half, or each player can only reach the columns on their own
	# side (GAME_AUDIT.md C3).
	InputManager.set_shared_board_turn(current_turn)
	set_process(true)
	_reset_board()
	InputManager.player_pressed.connect(_on_touch)

func _set_turn(player: int) -> void:
	current_turn = player
	InputManager.set_shared_board_turn(player)
	# The whole screen becomes the active player's colour -- on a shared phone
	# that is the fastest possible "it's you" signal, far quicker to read than
	# any badge.
	set_theme_bg(Palette.turn_tint(player))

func _process(delta: float) -> void:
	if _falling.is_empty():
		return
	var settled_keys := []
	for key in _falling.keys():
		var f: Dictionary = _falling[key]
		f.vel += GRAVITY * delta
		f.y += f.vel * delta
		if f.y >= f.target:
			f.y = f.target
			if absf(f.vel) < SETTLE_VELOCITY:
				settled_keys.append(key)
			else:
				f.vel = -f.vel * BOUNCE_DAMPING
		_falling[key] = f
	for key in settled_keys:
		_falling.erase(key)
	queue_redraw()

func start_match() -> void:
	_match_active = true

func _on_touch(player: int, _zone: int, position: Vector2, _screen: Vector2) -> void:
	if not _match_active or _turn_locked:
		return
	if player != current_turn:
		return

	var col := int((position.x - origin.x) / cell)
	if col < 0 or col >= COLS:
		return
	if board[col].size() >= ROWS:
		return # column full

	board[col].append(player)
	var landed_row: int = ROWS - board[col].size()
	var key := "%d_%d" % [col, landed_row]
	_falling[key] = {
		"y": origin.y - cell * 0.5,
		"vel": 0.0,
		"target": origin.y + landed_row * cell + cell * 0.5,
		"player": player,
		"col": col,
	}
	if player == 1:
		p1_pieces += 1
	else:
		p2_pieces += 1
	AudioManager.play_sfx("drop", player)
	queue_redraw() # redraw immediately -- the branches below may await before resolving

	var winner := _check_winner()
	if winner != 0:
		_turn_locked = true
		AudioManager.play_sfx("win", winner)
		_finish_after_delay(winner, 0.8)
	elif _board_full():
		_turn_locked = true
		_finish_after_delay(0, 0.8)
	else:
		_set_turn(2 if current_turn == 1 else 1)

func _finish_after_delay(winner: int, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	end_match(winner, p1_pieces, p2_pieces)

func _get_cell(row: int, col: int) -> int:
	var index_from_bottom := ROWS - 1 - row
	if index_from_bottom < 0 or index_from_bottom >= board[col].size():
		return 0
	return board[col][index_from_bottom]

func _check_winner() -> int:
	for row in range(ROWS):
		for col in range(COLS):
			var v := _get_cell(row, col)
			if v == 0:
				continue
			for d in DIRECTIONS:
				var count := 1
				var r := row
				var c := col
				for _step in range(3):
					r += d.y
					c += d.x
					if r < 0 or r >= ROWS or c < 0 or c >= COLS or _get_cell(r, c) != v:
						break
					count += 1
				if count >= 4:
					return v
	return 0

func _board_full() -> bool:
	for column in board:
		if column.size() < ROWS:
			return false
	return true

func _reset_board() -> void:
	board = []
	for _c in range(COLS):
		board.append([])
	queue_redraw()

func _draw() -> void:
	var board_rect := Rect2(origin, Vector2(COLS * cell, ROWS * cell))

	# The queued-token indicator that used to sit at each flank is gone: in
	# portrait the board spans nearly the full width, so both copies were drawn
	# past the screen edge and rendered as clipped half-circles. The mirrored
	# turn banners below already say whose turn it is, and they do it the
	# accessible way -- colour AND shape AND text.

	# A charcoal slab with holes punched through it -- the shape Connect Four
	# is actually recognised by. The board had no fill at all before, so cream
	# holes sat on a cream ground at near-zero contrast (GAME_AUDIT.md M3).
	Juice.sticker_rect(self, board_rect.grow(14.0), Palette.BOARD_CHARCOAL, 26.0, 8.0)

	for row in range(ROWS):
		for col in range(COLS):
			var center: Vector2 = origin + Vector2(col * cell + cell * 0.5, row * cell + cell * 0.5)
			var v := _get_cell(row, col)
			if v == 0 or _falling.has("%d_%d" % [col, row]):
				# Empty socket: a darker recess with a hard rim, so the board
				# reads as drilled rather than printed.
				draw_circle(center, cell * 0.40, Palette.OUTLINE)
				draw_circle(center, cell * 0.35, Palette.BOARD_HOLE)
			else:
				Juice.cartoon_circle(self, center, cell * 0.35, Palette.for_player(v), Vector2.ONE, false)

	for key in _falling.keys():
		var f: Dictionary = _falling[key]
		# f.y is already an absolute viewport coordinate (it is compared against
		# f.target, which is absolute), so only x is offset by origin. Adding
		# origin.y here as well double-counted it and drew a token drifting
		# below the board -- visible as a stray disc off the bottom edge.
		var center := Vector2(origin.x + f.col * cell + cell * 0.5, f.y)
		Juice.cartoon_circle(self, center, cell * 0.35, Palette.for_player(f.player), Vector2.ONE, false)

	# One communal board, two players facing opposite ways: draw the turn banner
	# twice -- upright below the board for Player 1, rotated PI above it for
	# Player 2 -- so neither has to read it upside down.
	var cx := origin.x + COLS * cell * 0.5
	TurnBanner.draw_turn(self, Vector2(cx, origin.y + ROWS * cell + 50.0), current_turn)
	draw_set_transform(Vector2(cx, origin.y - 50.0), PI, Vector2.ONE)
	TurnBanner.draw_turn(self, Vector2.ZERO, current_turn)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
