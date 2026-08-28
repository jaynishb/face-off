extends MiniGame
## Air Hockey — drag your paddle within your half, hit the puck into the
## other side's outer edge. First to 5 goals. Manual circle-physics (not
## RigidBody2D) so behavior stays deterministic and easy to tune for feel.

const PADDLE_RADIUS := 45.0
const PUCK_RADIUS := 20.0
const FIELD_TOP := 76.0
const FIELD_BOTTOM := 710.0
const FIELD_LEFT := 10.0
const FIELD_RIGHT := 1270.0
const MID_X := 640.0
const WIN_SCORE := 5
const MAX_PUCK_SPEED := 900.0
const MIN_HIT_SPEED := 260.0

var p1_pos := Vector2(320, 393)
var p2_pos := Vector2(960, 393)
var puck_pos := Vector2(MID_X, 393)
var puck_vel := Vector2.ZERO
var p1_score := 0
var p2_score := 0
var _match_active := false

func _init() -> void:
	game_id = "air_hockey"
	display_name = "Air Hockey"
	rules_text = "Drag your paddle.\nHit the puck into their goal.\nFirst to 5 wins."
	match_duration = 0.0

func setup(_config: Dictionary) -> void:
	set_process(false)
	InputManager.player_pressed.connect(_on_touch)
	InputManager.player_dragged.connect(_on_drag)

func start_match() -> void:
	_reset_puck(1 if randf() < 0.5 else 2)
	_match_active = true
	set_process(true)

func _on_touch(player: int, _zone: int, position: Vector2) -> void:
	_move_paddle(player, position)

func _on_drag(player: int, _zone: int, position: Vector2, _delta: Vector2) -> void:
	_move_paddle(player, position)

func _move_paddle(player: int, position: Vector2) -> void:
	var clamped := position
	clamped.y = clamp(position.y, FIELD_TOP + PADDLE_RADIUS, FIELD_BOTTOM - PADDLE_RADIUS)
	if player == 1:
		clamped.x = clamp(position.x, FIELD_LEFT + PADDLE_RADIUS, MID_X - PADDLE_RADIUS)
		p1_pos = clamped
	else:
		clamped.x = clamp(position.x, MID_X + PADDLE_RADIUS, FIELD_RIGHT - PADDLE_RADIUS)
		p2_pos = clamped
	queue_redraw()

func _process(delta: float) -> void:
	if not _match_active:
		return

	puck_pos += puck_vel * delta

	if puck_pos.y - PUCK_RADIUS < FIELD_TOP:
		puck_pos.y = FIELD_TOP + PUCK_RADIUS
		puck_vel.y = abs(puck_vel.y)
	elif puck_pos.y + PUCK_RADIUS > FIELD_BOTTOM:
		puck_pos.y = FIELD_BOTTOM - PUCK_RADIUS
		puck_vel.y = -abs(puck_vel.y)

	_resolve_paddle_collision(p1_pos)
	_resolve_paddle_collision(p2_pos)

	if puck_pos.x < FIELD_LEFT - PUCK_RADIUS * 2.0:
		_score(2)
	elif puck_pos.x > FIELD_RIGHT + PUCK_RADIUS * 2.0:
		_score(1)

	queue_redraw()

func _resolve_paddle_collision(paddle_pos: Vector2) -> void:
	var diff := puck_pos - paddle_pos
	var dist := diff.length()
	var min_dist := PADDLE_RADIUS + PUCK_RADIUS
	if dist < min_dist and dist > 0.001:
		var normal := diff / dist
		puck_pos = paddle_pos + normal * min_dist
		var speed: float = max(puck_vel.length(), MIN_HIT_SPEED)
		puck_vel = (normal * speed * 1.15).limit_length(MAX_PUCK_SPEED)
		AudioManager.play_sfx("paddle_hit")

func _score(scoring_player: int) -> void:
	_match_active = false
	if scoring_player == 1:
		p1_score += 1
	else:
		p2_score += 1
	score_updated.emit(p1_score, p2_score)
	AudioManager.play_sfx("goal", scoring_player)

	if p1_score >= WIN_SCORE or p2_score >= WIN_SCORE:
		var winner := 1 if p1_score > p2_score else 2
		end_match(winner, p1_score, p2_score)
	else:
		await get_tree().create_timer(1.0).timeout
		_reset_puck(2 if scoring_player == 1 else 1)
		_match_active = true

func _reset_puck(serve_towards: int) -> void:
	puck_pos = Vector2(MID_X, 393)
	var dir := 1.0 if serve_towards == 2 else -1.0
	puck_vel = Vector2(dir * 320.0, randf_range(-150.0, 150.0))

func _draw() -> void:
	draw_circle(p1_pos, PADDLE_RADIUS, Palette.PLAYER_1)
	draw_circle(p2_pos, PADDLE_RADIUS, Palette.PLAYER_2)
	draw_circle(puck_pos, PUCK_RADIUS, Palette.INK)
