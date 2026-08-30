extends MiniGame
## Ping Pong — vertical paddles, drag up/down. Ball speeds up each rally hit,
## capped so it never becomes unreadable. First to 7.

const PADDLE_WIDTH := 26.0
const PADDLE_HEIGHT := 140.0
const PADDLE_MARGIN := 46.0
## Inset of the table from the screen edge, so the game's ground colour reads
## as a surround the table sits on rather than a thin border.
const TABLE_INSET := 26.0
const BALL_RADIUS := 14.0
const WIN_SCORE := 7
const BASE_BALL_SPEED := 420.0
const SPEED_INCREMENT := 35.0
const MAX_BALL_SPEED := 950.0

# Geometry from the real visible rect -- see Field.gd. Both paddles sit the
# same distance from their own screen edge; previously P1's was flush to the
# left edge while P2's floated ~170px inside the right one (GAME_AUDIT.md C4).
var field_top := 0.0
var field_bottom := 0.0
var table_left := 0.0
var table_right := 0.0
var p1_x := 0.0
var p2_x := 0.0

var p1_y := 0.0
var p2_y := 0.0
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

## Table bounds follow the live viewport; paddles and ball are clamped back
## inside it rather than stranded outside (see MiniGame.layout).
func layout() -> void:
	field_top = Field.top() + TABLE_INSET * 0.5
	field_bottom = Field.bottom() - TABLE_INSET * 0.5
	table_left = Field.left() + TABLE_INSET
	table_right = Field.right() - TABLE_INSET
	p1_x = table_left + PADDLE_MARGIN
	p2_x = table_right - PADDLE_MARGIN
	_move_paddle(1, p1_y)
	_move_paddle(2, p2_y)
	ball_pos.x = clampf(ball_pos.x, table_left + BALL_RADIUS, table_right - BALL_RADIUS)
	ball_pos.y = clampf(ball_pos.y, field_top + BALL_RADIUS, field_bottom - BALL_RADIUS)
	queue_redraw()

func setup(_config: Dictionary) -> void:
	p1_y = Field.center().y
	p2_y = Field.center().y
	ball_pos = Field.center()
	layout()

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
	var clamped_y: float = clamp(y, field_top + PADDLE_HEIGHT * 0.5, field_bottom - PADDLE_HEIGHT * 0.5)
	if player == 1:
		p1_y = clamped_y
	else:
		p2_y = clamped_y
	queue_redraw()

func _process(delta: float) -> void:
	if not _match_active:
		return

	var prev_x := ball_pos.x
	ball_pos += ball_vel * delta

	if ball_pos.y - BALL_RADIUS < field_top:
		ball_pos.y = field_top + BALL_RADIUS
		ball_vel.y = abs(ball_vel.y)
		ball_squash = Vector2(1.4, 0.6)
	elif ball_pos.y + BALL_RADIUS > field_bottom:
		ball_pos.y = field_bottom - BALL_RADIUS
		ball_vel.y = -abs(ball_vel.y)
		ball_squash = Vector2(1.4, 0.6)

	_try_paddle_bounce(prev_x)
	ball_squash = Juice.decay_squash(ball_squash, delta)

	if ball_pos.x < table_left - BALL_RADIUS:
		_score(2)
	elif ball_pos.x > table_right + BALL_RADIUS:
		_score(1)

	queue_redraw()

## Swept along the ball's travel this frame rather than tested at its current
## position: at max rally speed on a 30fps device (the stated performance
## floor) the ball moves ~32px per frame against a ~41px hit window, which is
## too little margin to rely on (GAME_AUDIT.md L2).
func _try_paddle_bounce(prev_x: float) -> void:
	var p1_face := p1_x + PADDLE_WIDTH * 0.5 + BALL_RADIUS
	var p2_face := p2_x - PADDLE_WIDTH * 0.5 - BALL_RADIUS

	if ball_vel.x < 0.0 and prev_x >= p1_face and ball_pos.x <= p1_face:
		if absf(ball_pos.y - p1_y) <= PADDLE_HEIGHT * 0.5 + BALL_RADIUS:
			_bounce_off_paddle(p1_face, p1_y, 1)
	elif ball_vel.x > 0.0 and prev_x <= p2_face and ball_pos.x >= p2_face:
		if absf(ball_pos.y - p2_y) <= PADDLE_HEIGHT * 0.5 + BALL_RADIUS:
			_bounce_off_paddle(p2_face, p2_y, -1)

func _bounce_off_paddle(clamp_x: float, paddle_y: float, direction: int) -> void:
	ball_pos.x = clamp_x
	_rally_speed = min(_rally_speed + SPEED_INCREMENT, MAX_BALL_SPEED)
	# English: how far from paddle center it was hit skews the y velocity,
	# effect growing with rally length via _rally_speed.
	var offset: float = clamp((ball_pos.y - paddle_y) / (PADDLE_HEIGHT * 0.5), -1.0, 1.0)
	var y_component := offset * _rally_speed * 0.6
	var x_component: float = sqrt(max(_rally_speed * _rally_speed - y_component * y_component, 0.0))
	ball_vel = Vector2(x_component * direction, y_component)
	ball_squash = Vector2(0.6, 1.4)
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
	var dir := 1.0 if towards == 2 else -1.0
	ball_vel = Vector2(dir * BASE_BALL_SPEED, randf_range(-150.0, 150.0))

func _draw() -> void:
	_draw_table()
	_draw_paddle(p1_x, p1_y, Palette.PLAYER_1, 1.0)
	_draw_paddle(p2_x, p2_y, Palette.PLAYER_2, -1.0)
	Juice.cartoon_circle(self, ball_pos, BALL_RADIUS, Palette.SURFACE, ball_squash)

## A real table: green playing surface inside a heavy black frame, a white
## centre line down the length of it, and the net across the middle.
func _draw_table() -> void:
	var table := Rect2(table_left, field_top, table_right - table_left, field_bottom - field_top)
	Juice.sticker_rect(self, table, Palette.TABLE_GREEN, 14.0, 11.0)

	var mid := Field.mid_x()
	var cy := (field_top + field_bottom) * 0.5

	# Centre line runs the long way, as on a real doubles table.
	draw_line(Vector2(table_left + 14.0, cy), Vector2(table_right - 14.0, cy), Palette.SURFACE, 6.0)

	# Net across the middle: a white band with a darker seam through it.
	draw_line(Vector2(mid, field_top + 10.0), Vector2(mid, field_bottom - 10.0), Palette.SURFACE, 18.0)
	draw_line(Vector2(mid, field_top + 10.0), Vector2(mid, field_bottom - 10.0), Palette.TABLE_GREEN.darkened(0.30), 5.0)

## A bat, not a bar: rounded blade plus a handle stub pointing off the table,
## so each side reads as a held paddle the way the reference art does.
func _draw_paddle(x: float, y: float, color: Color, facing: float) -> void:
	var handle := Rect2(x - facing * 26.0 - 7.0, y - 9.0, 26.0, 18.0)
	Juice.sticker_rect(self, handle, color.lerp(Palette.OUTLINE, 0.25), 6.0, 5.0)

	var blade := Rect2(x - PADDLE_WIDTH * 0.5, y - PADDLE_HEIGHT * 0.5, PADDLE_WIDTH, PADDLE_HEIGHT)
	Juice.capsule(self, blade, color, 6.0)
