extends MiniGame
## Connect Four — standard 7x6 drop-token grid, tap a column to drop.
## Turn-based like Tic-Tac-Toe, but a single decisive match (no rounds):
## four in a row, any direction, wins outright.

const COLS := 7
const ROWS := 6
const CELL := 78.0
const ORIGIN := Vector2(367, 220)
const DIRECTIONS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]

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

func setup(_config: Dictionary) -> void:
	set_process(true)
	_reset_board()
	InputManager.player_pressed.connect(_on_touch)

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

func _on_touch(player: int, _zone: int, position: Vector2) -> void:
	if not _match_active or _turn_locked:
		return
	if player != current_turn:
		return

	var col := int((position.x - ORIGIN.x) / CELL)
	if col < 0 or col >= COLS:
		return
	if board[col].size() >= ROWS:
		return # column full

	board[col].append(player)
	var landed_row: int = ROWS - board[col].size()
	var key := "%d_%d" % [col, landed_row]
	_falling[key] = {
		"y": ORIGIN.y - CELL * 0.5,
		"vel": 0.0,
		"target": ORIGIN.y + landed_row * CELL + CELL * 0.5,
		"player": player,
		"col": col,
	}
	if player == 1:
		p1_pieces += 1
	else:
		p2_pieces += 1
	AudioManager.play_sfx("drop", player)
	score_updated.emit(p1_pieces, p2_pieces)
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
		current_turn = 2 if current_turn == 1 else 1

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
	draw_rect(Rect2(ORIGIN, Vector2(COLS * CELL, ROWS * CELL)), Palette.PLAYER_2.lerp(Palette.INK, 0.7), false, 4)
	for row in range(ROWS):
		for col in range(COLS):
			if _falling.has("%d_%d" % [col, row]):
				continue # drawn separately below, mid-drop
			var center: Vector2 = ORIGIN + Vector2(col * CELL + CELL * 0.5, row * CELL + CELL * 0.5)
			var v := _get_cell(row, col)
			if v == 0:
				draw_circle(center, CELL * 0.4, Palette.SURFACE)
			else:
				Juice.cartoon_circle(self, center, CELL * 0.36, Palette.for_player(v))

	for key in _falling.keys():
		var f: Dictionary = _falling[key]
		var center: Vector2 = ORIGIN + Vector2(f.col * CELL + CELL * 0.5, f.y)
		Juice.cartoon_circle(self, center, CELL * 0.36, Palette.for_player(f.player))

	var turn_color := Palette.for_player(current_turn)
	draw_rect(Rect2(ORIGIN.x, ORIGIN.y - 30, COLS * CELL, 12), turn_color)
