extends MiniGame
## Tic-Tac-Toe — standard 3x3, but a match is best-of-five rounds so it
## resolves in under 60 seconds and a drawn round doesn't feel like nothing
## happened (it just replays). Both players tap the same shared board;
## only the player whose turn it is can register a move.

const ROUNDS_TO_WIN := 3

## Centred on the real visible rect, not a hardcoded box -- see Field.gd. Both
## are set in layout(), because the viewport isn't known at _init().
##
## CELL is derived rather than fixed: a 130px cell was a comfortable third of a
## 1280-wide landscape screen, but on a 720-wide portrait one 3x130 leaves the
## board cramped against the seam HUD, and it drifts further on a 20:9 phone.
var cell := 130.0
var grid_origin := Vector2.ZERO
const WIN_LINES := [
	[0, 1, 2], [3, 4, 5], [6, 7, 8],
	[0, 3, 6], [1, 4, 7], [2, 5, 8],
	[0, 4, 8], [2, 4, 6],
]

var board: Array = []
var piece_scale: Array = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
var current_turn := 1
var p1_rounds := 0
var p2_rounds := 0
var _match_active := false
var _round_locked := false
var _message := ""

func _init() -> void:
	game_id = "tic_tac_toe"
	display_name = "Tic-Tac-Toe"
	rules_text = "Tap a square.\nThree in a row wins the round.\nFirst to 3 rounds wins."
	match_duration = 0.0
	theme_bg = Palette.turn_tint(current_turn)
	view_mode = ViewMode.SHARED
	input_space = InputManager.Space.SCREEN

func layout() -> void:
	var w := Field.right() - Field.left()
	# Leave room for a mirrored turn banner above and below the board.
	cell = minf(w * 0.30, Field.play_height() * 0.26)
	grid_origin = Field.center() - Vector2(cell * 1.5, cell * 1.5)
	queue_redraw()

func setup(_config: Dictionary) -> void:
	layout()
	# One shared board straddling the midline: ownership must follow the turn,
	# not the screen half, or the far half of the board is unreachable for
	# whoever is on the wrong side of it (GAME_AUDIT.md C3).
	InputManager.set_shared_board_turn(current_turn)
	_reset_board()
	InputManager.player_pressed.connect(_on_touch)

func start_match() -> void:
	_match_active = true

func _set_turn(player: int) -> void:
	current_turn = player
	InputManager.set_shared_board_turn(player)
	# Whole-screen tint to whoever is on the clock -- see ConnectFour.
	set_theme_bg(Palette.turn_tint(player))

func _on_touch(player: int, _zone: int, position: Vector2, _screen: Vector2) -> void:
	if not _match_active or _round_locked:
		return
	if player != current_turn:
		return

	var col := int((position.x - grid_origin.x) / cell)
	var row := int((position.y - grid_origin.y) / cell)
	if col < 0 or col > 2 or row < 0 or row > 2:
		return

	var idx := row * 3 + col
	if board[idx] != 0:
		return

	board[idx] = player
	AudioManager.play_sfx("place", player)
	_pop_piece(idx)

	var winner := _check_winner()
	if winner != 0:
		_round_won(winner)
	elif _board_full():
		_round_draw()
	else:
		_set_turn(2 if current_turn == 1 else 1)

	queue_redraw()

func _check_winner() -> int:
	for line in WIN_LINES:
		var a: int = board[line[0]]
		if a != 0 and a == board[line[1]] and a == board[line[2]]:
			return a
	return 0

func _board_full() -> bool:
	return not board.has(0)

func _round_won(winner: int) -> void:
	_round_locked = true
	if winner == 1:
		p1_rounds += 1
	else:
		p2_rounds += 1
	score_updated.emit(p1_rounds, p2_rounds)
	AudioManager.play_sfx("round_win", winner)

	if p1_rounds >= ROUNDS_TO_WIN or p2_rounds >= ROUNDS_TO_WIN:
		var match_winner := 1 if p1_rounds > p2_rounds else 2
		await get_tree().create_timer(1.0).timeout
		end_match(match_winner, p1_rounds, p2_rounds)
	else:
		await get_tree().create_timer(1.0).timeout
		_reset_board()
		_set_turn(1 if winner == 2 else 2) # loser of the round opens the next one
		_round_locked = false

func _round_draw() -> void:
	_round_locked = true
	# Say so on screen -- the board used to just silently clear, which reads as
	# the game eating your move (GAME_AUDIT.md L1).
	_message = "DRAW - REPLAY"
	queue_redraw()
	await get_tree().create_timer(1.1).timeout
	_message = ""
	_reset_board()
	# Whoever placed the last piece doesn't also get to open the replay.
	_set_turn(2 if current_turn == 1 else 1)
	_round_locked = false

func _reset_board() -> void:
	board = [0, 0, 0, 0, 0, 0, 0, 0, 0]
	piece_scale = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
	queue_redraw()

## Pop-in scale animation (overshoot) on the just-placed piece for feedback.
func _pop_piece(idx: int) -> void:
	piece_scale[idx] = 0.0
	var t := create_tween()
	t.tween_method(func(v: float): piece_scale[idx] = v; queue_redraw(), 0.0, 1.0, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	# Board as a single cream slab with the grid scored into it, rather than
	# four bare lines floating on the ground colour.
	var board_rect := Rect2(grid_origin, Vector2(3 * cell, 3 * cell))
	Juice.sticker_rect(self, board_rect.grow(14.0), Palette.SURFACE, 24.0, 8.0)
	for i in range(1, 3):
		draw_line(grid_origin + Vector2(i * cell, 6.0), grid_origin + Vector2(i * cell, 3 * cell - 6.0), Palette.OUTLINE, 7.0)
		draw_line(grid_origin + Vector2(6.0, i * cell), grid_origin + Vector2(3 * cell - 6.0, i * cell), Palette.OUTLINE, 7.0)

	for idx in range(9):
		var v: int = board[idx]
		if v == 0:
			continue
		var row := idx / 3
		var col := idx % 3
		var center: Vector2 = grid_origin + Vector2(col * cell + cell * 0.5, row * cell + cell * 0.5)
		var color := Palette.for_player(v)
		var s: float = piece_scale[idx]
		# Mark size follows the cell, so a derived board keeps its proportions.
		var thick := cell * 0.17
		if v == 1:
			var d: float = cell * 0.29 * s
			# Outline pass then colour pass, so the mark carries the same hard
			# black edge as every other piece in the app.
			draw_line(center + Vector2(-d, -d), center + Vector2(d, d), Palette.OUTLINE, thick)
			draw_line(center + Vector2(-d, d), center + Vector2(d, -d), Palette.OUTLINE, thick)
			draw_line(center + Vector2(-d, -d), center + Vector2(d, d), color, thick * 0.59)
			draw_line(center + Vector2(-d, d), center + Vector2(d, -d), color, thick * 0.59)
		else:
			var r := cell * 0.32 * s
			draw_arc(center, r, 0, TAU, 40, Palette.OUTLINE, thick * 1.09)
			draw_arc(center, r, 0, TAU, 40, color, thick * 0.64)

	# One communal board, two players facing opposite ways: whose-turn-it-is has
	# to be legible from both ends, so the banner is drawn twice -- upright below
	# the board for Player 1, rotated PI above it for Player 2.
	var cx := grid_origin.x + 1.5 * cell
	_draw_banner(Vector2(cx, grid_origin.y + 3.0 * cell + 46.0), false)
	_draw_banner(Vector2(cx, grid_origin.y - 46.0), true)

func _draw_banner(center: Vector2, rotated: bool) -> void:
	if rotated:
		draw_set_transform(center, PI, Vector2.ONE)
		_draw_banner_content(Vector2.ZERO)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_draw_banner_content(center)

func _draw_banner_content(center: Vector2) -> void:
	if _message != "":
		var font := ThemeDB.fallback_font
		var size := font.get_string_size(_message, HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
		draw_string(
			font, center + Vector2(-size.x * 0.5, size.y * 0.34),
			_message, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Palette.ACCENT,
		)
	else:
		TurnBanner.draw_turn(self, center, current_turn)
