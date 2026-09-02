extends MiniGame
## Ping Pong — horizontal bats, drag left/right. Ball speeds up each rally hit,
## capped so it never becomes unreadable. First to 7.
##
## FIELD mode: one ball, one table, no rotation. In portrait the table is tall,
## the net lies across the seam, and each player defends their own near end —
## Player 2 the top, Player 1 the bottom.

const PADDLE_THICKNESS := 26.0
const PADDLE_MARGIN := 46.0
## Inset of the table from the screen edge, so the game's ground colour reads as
## a surround the table sits on rather than a thin border.
const TABLE_INSET := 26.0
const BALL_RADIUS := 14.0
const WIN_SCORE := 7
const BASE_BALL_SPEED := 420.0
const SPEED_INCREMENT := 35.0
const MAX_BALL_SPEED := 950.0

# Geometry from the real visible rect -- see Field.gd. Both bats sit the same
# distance from their own screen edge; P1's was once flush to its edge while
# P2's floated ~170px inside the other (GAME_AUDIT.md C4).
var table_top := 0.0
var table_bottom := 0.0
var field_left := 0.0
var field_right := 0.0
var p1_y := 0.0
var p2_y := 0.0
## The blade's length along x, derived — a fixed 140 was a third of a 1280-wide
## landscape table and would be a fifth of a 720-wide portrait one.
var paddle_length := 140.0

var p1_x := 0.0
var p2_x := 0.0
var ball_pos := Vector2.ZERO
var ball_vel := Vector2.ZERO
var ball_squash := Vector2.ONE
var p1_score := 0
var p2_score := 0
var _match_active := false
var _rally_speed := BASE_BALL_SPEED

func _init() -> void:
	game_id = "ping_pong"
	display_name = "Ping Pong"
	rules_text = "Slide your paddle.\nDon't let the ball past.\nFirst to 7 wins."
	match_duration = 0.0
	theme_bg = Palette.BG_PING_PONG
	view_mode = ViewMode.FIELD
	input_space = InputManager.Space.SCREEN

## Table bounds follow the live viewport; bats and ball are clamped back inside
## it rather than stranded outside (see MiniGame.layout).
func layout() -> void:
	table_top = Field.top() + TABLE_INSET * 0.5
	table_bottom = Field.bottom() - TABLE_INSET * 0.5
	field_left = Field.left() + TABLE_INSET
	field_right = Field.right() - TABLE_INSET
	paddle_length = clampf((field_right - field_left) * 0.26, 90.0, 190.0)
	p1_y = table_bottom - PADDLE_MARGIN
	p2_y = table_top + PADDLE_MARGIN
	_move_paddle(1, p1_x)
	_move_paddle(2, p2_x)
	ball_pos.x = clampf(ball_pos.x, field_left + BALL_RADIUS, field_right - BALL_RADIUS)
	ball_pos.y = clampf(ball_pos.y, table_top + BALL_RADIUS, table_bottom - BALL_RADIUS)
	queue_redraw()

func setup(_config: Dictionary) -> void:
	p1_x = Field.center().x
	p2_x = Field.center().x
	ball_pos = Field.center()
	layout()

	set_process(false)
	InputManager.player_pressed.connect(_on_touch)
	InputManager.player_dragged.connect(_on_drag)

func start_match() -> void:
	_serve(1 if randf() < 0.5 else 2)
	_match_active = true
	set_process(true)

func _on_touch(player: int, _zone: int, position: Vector2, _screen: Vector2) -> void:
	_move_paddle(player, position.x)

func _on_drag(player: int, _zone: int, position: Vector2, _delta: Vector2, _screen: Vector2) -> void:
	_move_paddle(player, position.x)

func _move_paddle(player: int, x: float) -> void:
	var clamped_x: float = clamp(x, field_left + paddle_length * 0.5, field_right - paddle_length * 0.5)
	if player == 1:
		p1_x = clamped_x
	else:
		p2_x = clamped_x
	queue_redraw()

func _process(delta: float) -> void:
	if not _match_active:
		return

	var prev_y := ball_pos.y
	ball_pos += ball_vel * delta

	if ball_pos.x - BALL_RADIUS < field_left:
		ball_pos.x = field_left + BALL_RADIUS
		ball_vel.x = abs(ball_vel.x)
		ball_squash = Vector2(0.6, 1.4)
	elif ball_pos.x + BALL_RADIUS > field_right:
		ball_pos.x = field_right - BALL_RADIUS
		ball_vel.x = -abs(ball_vel.x)
		ball_squash = Vector2(0.6, 1.4)

	_try_paddle_bounce(prev_y)
	ball_squash = Juice.decay_squash(ball_squash, delta)

	# Past the top end is Player 2's miss, so Player 1 scored, and vice versa.
	if ball_pos.y < table_top - BALL_RADIUS:
		_score(1)
	elif ball_pos.y > table_bottom + BALL_RADIUS:
		_score(2)

	queue_redraw()

## Swept along the ball's travel this frame rather than tested at its current
## position: at max rally speed on a 30fps device (the stated performance floor)
## the ball moves ~32px per frame against a ~41px hit window, which is too little
## margin to rely on (GAME_AUDIT.md L2).
func _try_paddle_bounce(prev_y: float) -> void:
	var p1_face := p1_y - PADDLE_THICKNESS * 0.5 - BALL_RADIUS
	var p2_face := p2_y + PADDLE_THICKNESS * 0.5 + BALL_RADIUS

	if ball_vel.y > 0.0 and prev_y <= p1_face and ball_pos.y >= p1_face:
		if absf(ball_pos.x - p1_x) <= paddle_length * 0.5 + BALL_RADIUS:
			_bounce_off_paddle(p1_face, p1_x, -1)
	elif ball_vel.y < 0.0 and prev_y >= p2_face and ball_pos.y <= p2_face:
		if absf(ball_pos.x - p2_x) <= paddle_length * 0.5 + BALL_RADIUS:
			_bounce_off_paddle(p2_face, p2_x, 1)

## direction is the y the ball leaves in: -1 up (off Player 1's bat toward
## Player 2), +1 down.
func _bounce_off_paddle(clamp_y: float, paddle_x: float, direction: int) -> void:
	ball_pos.y = clamp_y
	_rally_speed = min(_rally_speed + SPEED_INCREMENT, MAX_BALL_SPEED)
	# English: how far from bat centre it was hit skews the x velocity, the
	# effect growing with rally length via _rally_speed.
	var offset: float = clamp((ball_pos.x - paddle_x) / (paddle_length * 0.5), -1.0, 1.0)
	var x_component := offset * _rally_speed * 0.6
	var y_component: float = sqrt(max(_rally_speed * _rally_speed - x_component * x_component, 0.0))
	ball_vel = Vector2(x_component, y_component * direction)
	ball_squash = Vector2(1.4, 0.6)
	AudioManager.play_sfx("paddle_hit", 1 if direction < 0 else 2)

func _score(scoring_player: int) -> void:
	_match_active = false
	if scoring_player == 1:
		p1_score += 1
	else:
		p2_score += 1
	score_updated.emit(p1_score, p2_score)
	AudioManager.play_sfx("score", scoring_player)
	Juice.burst(self, ball_pos, Palette.for_player(scoring_player))

	if p1_score >= WIN_SCORE or p2_score >= WIN_SCORE:
		var winner := 1 if p1_score > p2_score else 2
		end_match(winner, p1_score, p2_score)
	else:
		await get_tree().create_timer(1.0).timeout
		_serve(2 if scoring_player == 1 else 1)
		_match_active = true

func _serve(towards: int) -> void:
	ball_pos = Field.center()
	_rally_speed = BASE_BALL_SPEED
	# Player 2 is up-screen.
	var dir := -1.0 if towards == 2 else 1.0
	ball_vel = Vector2(randf_range(-150.0, 150.0), dir * BASE_BALL_SPEED)

func _draw() -> void:
	_draw_table()
	_draw_paddle(p1_x, p1_y, Palette.PLAYER_1, 1.0)
	_draw_paddle(p2_x, p2_y, Palette.PLAYER_2, -1.0)
	Juice.cartoon_circle(self, ball_pos, BALL_RADIUS, Palette.SURFACE, ball_squash)

## A real table: green playing surface inside a heavy black frame, a white centre
## line down the length of it, and the net across the middle. In portrait the net
## falls on the seam, which is where the HUD sits — so it doubles as the seam's
## visual backing rather than fighting it.
func _draw_table() -> void:
	var table := Rect2(field_left, table_top, field_right - field_left, table_bottom - table_top)
	Juice.sticker_rect(self, table, Palette.TABLE_GREEN, 14.0, 11.0)

	var mid := Field.split_y()
	var cx := (field_left + field_right) * 0.5

	# Centre line runs the long way, as on a real doubles table.
	draw_line(Vector2(cx, table_top + 14.0), Vector2(cx, table_bottom - 14.0), Palette.SURFACE, 6.0)

	# Net across the middle: a white band with a darker seam through it.
	draw_line(Vector2(field_left + 10.0, mid), Vector2(field_right - 10.0, mid), Palette.SURFACE, 18.0)
	draw_line(Vector2(field_left + 10.0, mid), Vector2(field_right - 10.0, mid), Palette.TABLE_GREEN.darkened(0.30), 5.0)

## A bat, not a bar: rounded blade plus a handle stub pointing off the table, so
## each side reads as a held paddle the way the reference art does. facing is +1
## for the bottom player (handle points down, off the table) and -1 for the top.
func _draw_paddle(x: float, y: float, color: Color, facing: float) -> void:
	var handle := Rect2(x - 9.0, y + facing * 26.0 - 7.0, 18.0, 26.0)
	Juice.sticker_rect(self, handle, color.lerp(Palette.OUTLINE, 0.25), 6.0, 5.0)

	var blade := Rect2(x - paddle_length * 0.5, y - PADDLE_THICKNESS * 0.5, paddle_length, PADDLE_THICKNESS)
	Juice.capsule(self, blade, color, 6.0)
