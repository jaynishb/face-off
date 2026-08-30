extends MiniGame
## Air Hockey — drag your paddle within your half, hit the puck into the
## other side's outer edge. First to 5 goals. Manual circle-physics (not
## RigidBody2D) so behavior stays deterministic and easy to tune for feel.

const PADDLE_RADIUS := 45.0
const PUCK_RADIUS := 20.0
const WIN_SCORE := 5
const MAX_PUCK_SPEED := 900.0
const MIN_HIT_SPEED := 260.0
## Height of the goal opening. Outside it the end wall is solid, so a shot has
## to be aimed -- previously the whole end line scored and you could not miss
## (GAME_AUDIT.md C5).
const GOAL_HEIGHT := 220.0
## How much of the paddle's own motion transfers into the puck, so a fast
## swipe smashes and a slow nudge taps (GAME_AUDIT.md L3).
const PADDLE_VELOCITY_TRANSFER := 0.55

# Geometry comes from the real visible rect -- see Field.gd.
var field_top := 0.0
var field_bottom := 0.0
var field_left := 0.0
var field_right := 0.0
var mid_x := 0.0
var goal_top := 0.0
var goal_bottom := 0.0

var p1_pos := Vector2.ZERO
var p2_pos := Vector2.ZERO
var puck_pos := Vector2.ZERO
var puck_vel := Vector2.ZERO
var puck_squash := Vector2.ONE
var p1_score := 0
var p2_score := 0
var _match_active := false
# Previous-frame paddle positions, for velocity-aware hits.
var _p1_prev := Vector2.ZERO
var _p2_prev := Vector2.ZERO

func _init() -> void:
	game_id = "air_hockey"
	display_name = "Air Hockey"
	rules_text = "Drag your paddle.\nHit the puck into their goal.\nFirst to 5 wins."
	match_duration = 0.0
	theme_bg = Palette.BG_AIR_HOCKEY
	theme_dark = true

## Rink bounds follow the live viewport. Live pieces are clamped back inside
## rather than left outside the new rink (see MiniGame.layout).
func layout() -> void:
	field_top = Field.top()
	field_bottom = Field.bottom()
	field_left = Field.left()
	field_right = Field.right()
	mid_x = Field.mid_x()
	var goal_center := (field_top + field_bottom) * 0.5
	goal_top = goal_center - GOAL_HEIGHT * 0.5
	goal_bottom = goal_center + GOAL_HEIGHT * 0.5

	_move_paddle(1, p1_pos)
	_move_paddle(2, p2_pos)
	_p1_prev = p1_pos
	_p2_prev = p2_pos
	puck_pos.x = clampf(puck_pos.x, field_left + PUCK_RADIUS, field_right - PUCK_RADIUS)
	puck_pos.y = clampf(puck_pos.y, field_top + PUCK_RADIUS, field_bottom - PUCK_RADIUS)
	queue_redraw()

func setup(_config: Dictionary) -> void:
	layout()
	p1_pos = Field.half_center(1)
	p2_pos = Field.half_center(2)
	_p1_prev = p1_pos
	_p2_prev = p2_pos
	puck_pos = Field.center()

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
	clamped.y = clamp(position.y, field_top + PADDLE_RADIUS, field_bottom - PADDLE_RADIUS)
	if player == 1:
		clamped.x = clamp(position.x, field_left + PADDLE_RADIUS, mid_x - PADDLE_RADIUS)
		p1_pos = clamped
	else:
		clamped.x = clamp(position.x, mid_x + PADDLE_RADIUS, field_right - PADDLE_RADIUS)
		p2_pos = clamped
	queue_redraw()

func _process(delta: float) -> void:
	if not _match_active:
		return

	puck_pos += puck_vel * delta

	if puck_pos.y - PUCK_RADIUS < field_top:
		puck_pos.y = field_top + PUCK_RADIUS
		puck_vel.y = abs(puck_vel.y)
		puck_squash = Vector2(1.3, 0.7)
	elif puck_pos.y + PUCK_RADIUS > field_bottom:
		puck_pos.y = field_bottom - PUCK_RADIUS
		puck_vel.y = -abs(puck_vel.y)
		puck_squash = Vector2(1.3, 0.7)

	# End walls are solid except across the goal mouth.
	var in_goal_mouth: bool = puck_pos.y > goal_top and puck_pos.y < goal_bottom
	if not in_goal_mouth:
		if puck_pos.x - PUCK_RADIUS < field_left:
			puck_pos.x = field_left + PUCK_RADIUS
			puck_vel.x = abs(puck_vel.x)
			puck_squash = Vector2(0.7, 1.3)
		elif puck_pos.x + PUCK_RADIUS > field_right:
			puck_pos.x = field_right - PUCK_RADIUS
			puck_vel.x = -abs(puck_vel.x)
			puck_squash = Vector2(0.7, 1.3)

	_resolve_paddle_collision(p1_pos, p1_pos - _p1_prev, delta)
	_resolve_paddle_collision(p2_pos, p2_pos - _p2_prev, delta)
	_p1_prev = p1_pos
	_p2_prev = p2_pos

	puck_squash = Juice.decay_squash(puck_squash, delta)

	if puck_pos.x < field_left - PUCK_RADIUS:
		_score(2)
	elif puck_pos.x > field_right + PUCK_RADIUS:
		_score(1)

	queue_redraw()

func _resolve_paddle_collision(paddle_pos: Vector2, paddle_motion: Vector2, delta: float) -> void:
	var diff := puck_pos - paddle_pos
	var dist := diff.length()
	var min_dist := PADDLE_RADIUS + PUCK_RADIUS
	if dist < min_dist and dist > 0.001:
		var normal := diff / dist
		puck_pos = paddle_pos + normal * min_dist
		# Carry the paddle's own speed into the shot, so a fast swipe smashes
		# and a slow nudge taps. Without this every hit left at an identical
		# speed and the game had no power in it.
		var paddle_speed: float = 0.0
		if delta > 0.0:
			paddle_speed = maxf((paddle_motion / delta).dot(normal), 0.0)
		var speed: float = max(puck_vel.length(), MIN_HIT_SPEED) + paddle_speed * PADDLE_VELOCITY_TRANSFER
		puck_vel = (normal * speed * 1.05).limit_length(MAX_PUCK_SPEED)
		puck_squash = Vector2(1.5, 0.6)
		AudioManager.play_sfx("paddle_hit")

func _score(scoring_player: int) -> void:
	_match_active = false
	if scoring_player == 1:
		p1_score += 1
	else:
		p2_score += 1
	score_updated.emit(p1_score, p2_score)
	AudioManager.play_sfx("goal", scoring_player)
	Juice.burst(self, puck_pos, Palette.for_player(scoring_player))

	if p1_score >= WIN_SCORE or p2_score >= WIN_SCORE:
		var winner := 1 if p1_score > p2_score else 2
		end_match(winner, p1_score, p2_score)
	else:
		await get_tree().create_timer(1.0).timeout
		_reset_puck(2 if scoring_player == 1 else 1)
		_match_active = true

func _reset_puck(serve_towards: int) -> void:
	puck_pos = Field.center()
	var dir := 1.0 if serve_towards == 2 else -1.0
	puck_vel = Vector2(dir * 320.0, randf_range(-150.0, 150.0))

func _draw() -> void:
	_draw_rink()
	Juice.cartoon_circle(self, p1_pos, PADDLE_RADIUS, Palette.PLAYER_1)
	Juice.cartoon_circle(self, p2_pos, PADDLE_RADIUS, Palette.PLAYER_2)
	Juice.cartoon_circle(self, puck_pos, PUCK_RADIUS, Palette.BOARD_CHARCOAL, puck_squash)

## The rink itself: surface, border, centre line and circle, and a goal mouth
## at each end. Previously the play area was an undifferentiated rectangle
## with no goals drawn at all (GAME_AUDIT.md C5 / M4).
func _draw_rink() -> void:
	var rink := Rect2(field_left, field_top, field_right - field_left, field_bottom - field_top)
	Juice.sticker_rect(self, rink, Palette.RINK_ICE, 26.0, 10.0)

	var center_y := (field_top + field_bottom) * 0.5
	var marking := Color(Palette.BG_AIR_HOCKEY, 0.30)
	draw_line(Vector2(mid_x, field_top + 10.0), Vector2(mid_x, field_bottom - 10.0), marking, 5.0)
	draw_arc(Vector2(mid_x, center_y), 96.0, 0.0, TAU, 56, marking, 5.0)
	draw_circle(Vector2(mid_x, center_y), 9.0, marking)

	# Goal creases + mouths, in the colour of the player defending that end.
	_draw_goal(field_left, Palette.PLAYER_1, 1.0)
	_draw_goal(field_right, Palette.PLAYER_2, -1.0)

func _draw_goal(x: float, color: Color, inward: float) -> void:
	var crease_r := (goal_bottom - goal_top) * 0.62
	# Half-circle crease, clipped naturally by sitting on the end wall.
	draw_arc(
		Vector2(x, (goal_top + goal_bottom) * 0.5), crease_r,
		-PI * 0.5 * inward, PI * 0.5 * inward, 32,
		Color(color, 0.45), 5.0,
	)

	# The mouth itself: a recess in the end wall, so it reads as an opening.
	var depth := 20.0
	var mouth := Rect2(
		x if inward > 0.0 else x - depth,
		goal_top,
		depth,
		goal_bottom - goal_top,
	)
	Juice.rounded_rect(self, mouth.grow(5.0), Palette.OUTLINE, 8.0)
	Juice.rounded_rect(self, mouth, color, 6.0)
