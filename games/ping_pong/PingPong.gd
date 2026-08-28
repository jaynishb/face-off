extends MiniGame
## Ping Pong — vertical paddles, drag up/down. Ball speeds up each rally hit,
## capped so it never becomes unreadable. First to 7.

const PADDLE_WIDTH := 18.0
const PADDLE_HEIGHT := 140.0
const PADDLE_MARGIN := 40.0
const BALL_RADIUS := 14.0
const FIELD_TOP := 76.0
const FIELD_BOTTOM := 710.0
const WIN_SCORE := 7
const BASE_BALL_SPEED := 420.0
const SPEED_INCREMENT := 35.0
const MAX_BALL_SPEED := 950.0

var p1_y := 393.0
var p2_y := 393.0
var ball_pos := Vector2(640, 393)
var ball_vel := Vector2.ZERO
var p1_score := 0
var p2_score := 0
var _match_active := false
var _rally_speed := BASE_BALL_SPEED

func _init() -> void:
	game_id = "ping_pong"
	display_name = "Ping Pong"
	rules_text = "Slide your paddle.\nDon't let the ball past.\nFirst to 7 wins."
	match_duration = 0.0

func setup(_config: Dictionary) -> void:
	set_process(false)
	InputManager.player_pressed.connect(_on_touch)
	InputManager.player_dragged.connect(_on_drag)

func start_match() -> void:
	_serve(1 if randf() < 0.5 else 2)
	_match_active = true
	set_process(true)

func _on_touch(player: int, _zone: int, position: Vector2) -> void:
	_move_paddle(player, position.y)

func _on_drag(player: int, _zone: int, position: Vector2, _delta: Vector2) -> void:
	_move_paddle(player, position.y)

func _move_paddle(player: int, y: float) -> void:
	var clamped_y: float = clamp(y, FIELD_TOP + PADDLE_HEIGHT * 0.5, FIELD_BOTTOM - PADDLE_HEIGHT * 0.5)
	if player == 1:
		p1_y = clamped_y
	else:
		p2_y = clamped_y
	queue_redraw()

func _process(delta: float) -> void:
	if not _match_active:
		return

	ball_pos += ball_vel * delta

	if ball_pos.y - BALL_RADIUS < FIELD_TOP:
		ball_pos.y = FIELD_TOP + BALL_RADIUS
		ball_vel.y = abs(ball_vel.y)
	elif ball_pos.y + BALL_RADIUS > FIELD_BOTTOM:
		ball_pos.y = FIELD_BOTTOM - BALL_RADIUS
		ball_vel.y = -abs(ball_vel.y)

	_try_paddle_bounce()

	if ball_pos.x < 0.0:
		_score(2)
	elif ball_pos.x > 1280.0:
		_score(1)

	queue_redraw()

func _try_paddle_bounce() -> void:
	var p1_x := PADDLE_MARGIN
	var p2_x := 1280.0 - PADDLE_MARGIN

	if ball_vel.x < 0.0 and ball_pos.x - BALL_RADIUS <= p1_x + PADDLE_WIDTH * 0.5 \
			and ball_pos.x > p1_x - PADDLE_WIDTH:
		if absf(ball_pos.y - p1_y) <= PADDLE_HEIGHT * 0.5 + BALL_RADIUS:
			_bounce_off_paddle(p1_x + PADDLE_WIDTH * 0.5 + BALL_RADIUS, p1_y, 1)
	elif ball_vel.x > 0.0 and ball_pos.x + BALL_RADIUS >= p2_x - PADDLE_WIDTH * 0.5 \
			and ball_pos.x < p2_x + PADDLE_WIDTH:
		if absf(ball_pos.y - p2_y) <= PADDLE_HEIGHT * 0.5 + BALL_RADIUS:
			_bounce_off_paddle(p2_x - PADDLE_WIDTH * 0.5 - BALL_RADIUS, p2_y, -1)

func _bounce_off_paddle(clamp_x: float, paddle_y: float, direction: int) -> void:
	ball_pos.x = clamp_x
	_rally_speed = min(_rally_speed + SPEED_INCREMENT, MAX_BALL_SPEED)
	# English: how far from paddle center it was hit skews the y velocity,
	# effect growing with rally length via _rally_speed.
	var offset: float = clamp((ball_pos.y - paddle_y) / (PADDLE_HEIGHT * 0.5), -1.0, 1.0)
	var y_component := offset * _rally_speed * 0.6
	var x_component: float = sqrt(max(_rally_speed * _rally_speed - y_component * y_component, 0.0))
	ball_vel = Vector2(x_component * direction, y_component)
	AudioManager.play_sfx("paddle_hit", 1 if direction < 0 else 2)

func _score(scoring_player: int) -> void:
	_match_active = false
	if scoring_player == 1:
		p1_score += 1
	else:
		p2_score += 1
	score_updated.emit(p1_score, p2_score)
	AudioManager.play_sfx("score", scoring_player)

	if p1_score >= WIN_SCORE or p2_score >= WIN_SCORE:
		var winner := 1 if p1_score > p2_score else 2
		end_match(winner, p1_score, p2_score)
	else:
		await get_tree().create_timer(1.0).timeout
		_serve(2 if scoring_player == 1 else 1)
		_match_active = true

func _serve(towards: int) -> void:
	ball_pos = Vector2(640, 393)
	_rally_speed = BASE_BALL_SPEED
	var dir := 1.0 if towards == 2 else -1.0
	ball_vel = Vector2(dir * BASE_BALL_SPEED, randf_range(-150.0, 150.0))

func _draw() -> void:
	draw_rect(Rect2(PADDLE_MARGIN - PADDLE_WIDTH * 0.5, p1_y - PADDLE_HEIGHT * 0.5, PADDLE_WIDTH, PADDLE_HEIGHT), Palette.PLAYER_1)
	draw_rect(Rect2(1280.0 - PADDLE_MARGIN - PADDLE_WIDTH * 0.5, p2_y - PADDLE_HEIGHT * 0.5, PADDLE_WIDTH, PADDLE_HEIGHT), Palette.PLAYER_2)
	draw_circle(ball_pos, BALL_RADIUS, Palette.INK)
