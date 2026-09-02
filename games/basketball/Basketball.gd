extends SplitGame
## Basketball — drag back from your ball and release to flick a shot at your own
## hoop. Most baskets in 45 seconds wins.
##
## Each player has their own half-court, so the whole thing is authored once in
## PLAYER space and drawn twice (see SplitGame). In that space +y runs from the
## seam outward toward the player, which means gravity is simply +y and the hoop
## sits near the seam — up-court from wherever the shooter is standing.

const MATCH_SECONDS := 45.0
const GRAVITY := 1500.0
const FLICK_POWER := 3.1
const MAX_SHOT_SPEED := 1500.0
## A shot counts when the ball crosses the rim's plane downward while inside the
## rim's span. Tested on the CROSSING rather than on overlap, so a ball resting
## against the rim can't tick the score repeatedly.
const RIM_TOLERANCE := 0.55

var hoop_center := Vector2.ZERO
var rim_half_width := 46.0
var ball_radius := 22.0
var shoot_from := Vector2.ZERO

var ball_pos := {1: Vector2.ZERO, 2: Vector2.ZERO}
var ball_vel := {1: Vector2.ZERO, 2: Vector2.ZERO}
var ball_live := {1: false, 2: false}
var ball_prev_y := {1: 0.0, 2: 0.0}
var aim_from := {1: Vector2.ZERO, 2: Vector2.ZERO}
var aim_to := {1: Vector2.ZERO, 2: Vector2.ZERO}
var aiming := {1: false, 2: false}
var score := {1: 0, 2: 0}

var _match_active := false
var _remaining := MATCH_SECONDS

func _init() -> void:
	super()
	game_id = "basketball"
	display_name = "Basketball"
	rules_text = "Flick to shoot at your hoop.\nMost baskets in 45 seconds wins."
	match_duration = MATCH_SECONDS
	theme_bg = Palette.BG_BASKETBALL
	theme_dark = true

func _on_layout() -> void:
	ball_radius = 22.0 * art_scale
	rim_half_width = 46.0 * art_scale
	hoop_center = Vector2(play_rect.get_center().x, play_rect.position.y + play_rect.size.y * 0.24)
	shoot_from = Vector2(play_rect.get_center().x, play_rect.end.y - 74.0 * art_scale)
	for player in [1, 2]:
		if not ball_live[player]:
			ball_pos[player] = shoot_from

func setup(_config: Dictionary) -> void:
	layout()
	for player in [1, 2]:
		ball_pos[player] = shoot_from
	set_process(false)
	InputManager.player_pressed.connect(_on_press)
	InputManager.player_dragged.connect(_on_drag)
	InputManager.player_released.connect(_on_release)

func start_match() -> void:
	_match_active = true
	_remaining = MATCH_SECONDS
	set_process(true)

func _on_press(player: int, _zone: int, position: Vector2, _screen: Vector2) -> void:
	if not _match_active or ball_live[player]:
		return
	aiming[player] = true
	aim_from[player] = position
	aim_to[player] = position
	queue_redraw()

func _on_drag(player: int, _zone: int, position: Vector2, _delta: Vector2, _screen: Vector2) -> void:
	if not aiming[player]:
		return
	aim_to[player] = position
	queue_redraw()

## Pull back and let go, like a slingshot: the shot leaves along the vector from
## where the finger ended to where it started.
func _on_release(player: int, _zone: int, position: Vector2, _screen: Vector2) -> void:
	if not aiming[player]:
		return
	aiming[player] = false
	var pull: Vector2 = aim_from[player] - position
	if pull.length() < 12.0:
		queue_redraw()
		return
	ball_pos[player] = shoot_from
	ball_prev_y[player] = shoot_from.y
	ball_vel[player] = (pull * FLICK_POWER).limit_length(MAX_SHOT_SPEED)
	ball_live[player] = true
	AudioManager.play_sfx("tap", player)
	queue_redraw()

func _process(delta: float) -> void:
	if not _match_active:
		return

	_remaining = maxf(0.0, _remaining - delta)

	for player in [1, 2]:
		if not ball_live[player]:
			continue
		var pos: Vector2 = ball_pos[player]
		var vel: Vector2 = ball_vel[player]
		ball_prev_y[player] = pos.y
		vel.y += GRAVITY * delta
		pos += vel * delta

		# Side walls bounce; the ball is only lost off the player's own baseline.
		if pos.x - ball_radius < play_rect.position.x:
			pos.x = play_rect.position.x + ball_radius
			vel.x = absf(vel.x) * 0.7
		elif pos.x + ball_radius > play_rect.end.x:
			pos.x = play_rect.end.x - ball_radius
			vel.x = -absf(vel.x) * 0.7
		if pos.y - ball_radius < play_rect.position.y:
			pos.y = play_rect.position.y + ball_radius
			vel.y = absf(vel.y) * 0.7

		ball_pos[player] = pos
		ball_vel[player] = vel

		if _crossed_rim(player):
			_score(player)
		elif pos.y > play_rect.end.y + ball_radius:
			_reset_ball(player)

	if _remaining <= 0.0:
		_finish()
	queue_redraw()

## True on the frame the ball passes down through the rim plane inside its span.
func _crossed_rim(player: int) -> bool:
	if ball_vel[player].y <= 0.0:
		return false
	var prev: float = ball_prev_y[player]
	var now: float = ball_pos[player].y
	var plane := hoop_center.y
	if prev >= plane or now < plane:
		return false
	return absf(ball_pos[player].x - hoop_center.x) <= rim_half_width * RIM_TOLERANCE

func _score(player: int) -> void:
	score[player] += 1
	score_updated.emit(score[1], score[2])
	AudioManager.play_sfx("goal", player)
	Juice.burst(self, Field.to_screen(player, hoop_center), Palette.for_player(player))
	_reset_ball(player)

func _reset_ball(player: int) -> void:
	ball_live[player] = false
	ball_vel[player] = Vector2.ZERO
	ball_pos[player] = shoot_from

func _finish() -> void:
	_match_active = false
	set_process(false)
	var winner := 0
	if score[1] > score[2]:
		winner = 1
	elif score[2] > score[1]:
		winner = 2
	end_match(winner, score[1], score[2])

func _draw_half(player: int) -> void:
	var color := Palette.for_player(player)
	draw_ground(Palette.BG_BASKETBALL)

	# Court floor, key and arc.
	var floor_rect := Rect2(play_rect.position, play_rect.size)
	Juice.sticker_rect(self, floor_rect, Palette.COURT_WOOD, 20.0, 8.0)
	var marking := Color(color, 0.35)
	var key := Rect2(
		hoop_center.x - 84.0 * art_scale, play_rect.position.y,
		168.0 * art_scale, play_rect.size.y * 0.34,
	)
	draw_rect(key, marking, false, 5.0)
	draw_arc(hoop_center, play_rect.size.x * 0.42, 0.0, PI, 40, marking, 5.0)

	_draw_hoop(color)

	if aiming[player]:
		_draw_aim(player, color)

	Juice.cartoon_circle(self, ball_pos[player], ball_radius, Palette.ACCENT)
	# Seam lines, so the ball reads as a basketball rather than a dot.
	draw_arc(ball_pos[player], ball_radius * 0.92, 0.0, TAU, 24, Color(Palette.OUTLINE, 0.7), 2.5)
	draw_line(
		ball_pos[player] - Vector2(ball_radius * 0.9, 0.0),
		ball_pos[player] + Vector2(ball_radius * 0.9, 0.0),
		Color(Palette.OUTLINE, 0.7), 2.5,
	)

	_draw_clock()

func _draw_hoop(color: Color) -> void:
	var board := Rect2(
		hoop_center.x - 76.0 * art_scale, hoop_center.y - 74.0 * art_scale,
		152.0 * art_scale, 62.0 * art_scale,
	)
	Juice.sticker_rect(self, board, Palette.SURFACE, 10.0, 6.0)
	Juice.rounded_rect(self, Rect2(
		hoop_center.x - 30.0 * art_scale, hoop_center.y - 58.0 * art_scale,
		60.0 * art_scale, 40.0 * art_scale,
	), Color(color, 0.30), 6.0, 4.0, color)

	# The rim, drawn at exactly the plane the score test uses.
	Juice.capsule(self, Rect2(
		hoop_center.x - rim_half_width, hoop_center.y - 5.0 * art_scale,
		rim_half_width * 2.0, 10.0 * art_scale,
	), Palette.ACCENT, 4.0)

	# Net: a few tapering strokes rather than a mesh.
	for i in range(5):
		var t := i / 4.0
		var top := Vector2(lerpf(hoop_center.x - rim_half_width, hoop_center.x + rim_half_width, t), hoop_center.y + 4.0)
		var bottom := Vector2(lerpf(hoop_center.x - rim_half_width * 0.45, hoop_center.x + rim_half_width * 0.45, t), hoop_center.y + 40.0 * art_scale)
		draw_line(top, bottom, Color(Palette.SURFACE, 0.85), 3.0)

## Slingshot guide: the pull vector, plus a dotted preview of the launch arc, so
## the flick reads as aimable rather than random.
func _draw_aim(player: int, color: Color) -> void:
	var pull: Vector2 = aim_from[player] - aim_to[player]
	draw_line(shoot_from, shoot_from + pull, Color(color, 0.5), 6.0)

	var v: Vector2 = (pull * FLICK_POWER).limit_length(MAX_SHOT_SPEED)
	var p := shoot_from
	for i in range(18):
		var t := i * 0.035
		var sample: Vector2 = shoot_from + v * t + Vector2(0.0, 0.5 * GRAVITY * t * t)
		if i % 2 == 0:
			draw_line(p, sample, Color(Palette.SURFACE, 0.45), 3.0)
		p = sample

func _draw_clock() -> void:
	var font := ThemeDB.fallback_font
	var text := "%.0f" % ceilf(_remaining)
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
	# Centred on this player's OUTER edge. Anything near the seam collides with
	# the score pills, which live there for every non-shared game.
	draw_string(
		font,
		Vector2(play_rect.get_center().x - size.x * 0.5, play_rect.end.y - 10.0),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(Palette.SURFACE, 0.9),
	)
