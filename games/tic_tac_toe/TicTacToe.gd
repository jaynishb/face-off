extends MiniGame
## Tic-Tac-Toe — standard 3x3, but a match is best-of-five rounds so it
## resolves in under 60 seconds and a drawn round doesn't feel like nothing
## happened (it just replays). Both players tap the same shared board;
## only the player whose turn it is can register a move.

const CELL := 130.0
const GRID_ORIGIN := Vector2(640 - 195, 393 - 195)
const ROUNDS_TO_WIN := 3
const WIN_LINES := [
	[0, 1, 2], [3, 4, 5], [6, 7, 8],
	[0, 3, 6], [1, 4, 7], [2, 5, 8],
	[0, 4, 8], [2, 4, 6],
]

var board: Array = []
var current_turn := 1
var p1_rounds := 0
var p2_rounds := 0
var _match_active := false
var _round_locked := false

func _init() -> void:
	game_id = "tic_tac_toe"
	display_name = "Tic-Tac-Toe"
	rules_text = "Tap a square.\nThree in a row wins the round.\nFirst to 3 rounds wins."
	match_duration = 0.0

func setup(_config: Dictionary) -> void:
	_reset_board()
	InputManager.player_pressed.connect(_on_touch)

func start_match() -> void:
	_match_active = true

func _on_touch(player: int, _zone: int, position: Vector2) -> void:
	if not _match_active or _round_locked:
		return
	if player != current_turn:
		return

	var col := int((position.x - GRID_ORIGIN.x) / CELL)
	var row := int((position.y - GRID_ORIGIN.y) / CELL)
	if col < 0 or col > 2 or row < 0 or row > 2:
		return

	var idx := row * 3 + col
	if board[idx] != 0:
		return

	board[idx] = player
	AudioManager.play_sfx("place", player)

	var winner := _check_winner()
	if winner != 0:
		_round_won(winner)
	elif _board_full():
		_round_draw()
	else:
		current_turn = 2 if current_turn == 1 else 1

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
		current_turn = 1 if winner == 2 else 2 # loser of the round opens the next one
		_round_locked = false

func _round_draw() -> void:
	_round_locked = true
	await get_tree().create_timer(0.8).timeout
	_reset_board()
	_round_locked = false

func _reset_board() -> void:
	board = [0, 0, 0, 0, 0, 0, 0, 0, 0]
	queue_redraw()

func _draw() -> void:
	for i in range(1, 3):
		draw_line(GRID_ORIGIN + Vector2(i * CELL, 0), GRID_ORIGIN + Vector2(i * CELL, 3 * CELL), Palette.INK, 4)
		draw_line(GRID_ORIGIN + Vector2(0, i * CELL), GRID_ORIGIN + Vector2(3 * CELL, i * CELL), Palette.INK, 4)
	draw_rect(Rect2(GRID_ORIGIN, Vector2(3 * CELL, 3 * CELL)), Palette.INK, false, 4)

	for idx in range(9):
		var v: int = board[idx]
		if v == 0:
			continue
		var row := idx / 3
		var col := idx % 3
		var center: Vector2 = GRID_ORIGIN + Vector2(col * CELL + CELL * 0.5, row * CELL + CELL * 0.5)
		var color := Palette.for_player(v)
		if v == 1:
			draw_line(center + Vector2(-40, -40), center + Vector2(40, 40), color, 10)
			draw_line(center + Vector2(-40, 40), center + Vector2(40, -40), color, 10)
		else:
			draw_arc(center, 45, 0, TAU, 32, color, 10)

	var turn_color := Palette.for_player(current_turn)
	draw_rect(Rect2(GRID_ORIGIN.x, GRID_ORIGIN.y - 30, 3 * CELL, 12), turn_color)
