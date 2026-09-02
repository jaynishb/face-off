extends SplitGame
## Archery — five arrows each. Drag back from the archer to set angle and power,
## release to loose. A drifting crosswind pushes the arrow sideways in flight, so
## the shot has to be aimed off-centre rather than just repeated. Highest total
## after five arrows wins.
##
## The wind is SHARED and drawn on both halves: both players face the same
## conditions on every arrow, so the match is decided by aim and not by luck.

const ARROWS := 5
const GRAVITY := 620.0
const DRAW_POWER := 2.4
const MAX_SPEED := 1250.0
const WIND_MAX := 190.0
const WIND_RATE := 0.45

enum Phase { AIM, FLIGHT, SCORED, DONE }

var archer_pos := Vector2.ZERO
var target_center := Vector2.ZERO
var target_radius := 62.0

var wind := 0.0
var _wind_phase := 0.0

var phase := {1: Phase.AIM, 2: Phase.AIM}
var arrow_pos := {1: Vector2.ZERO, 2: Vector2.ZERO}
var arrow_vel := {1: Vector2.ZERO, 2: Vector2.ZERO}
var aim_to := {1: Vector2.ZERO, 2: Vector2.ZERO}
var aiming := {1: false, 2: false}
var shots := {1: 0, 2: 0}
var total := {1: 0, 2: 0}
var last_points := {1: -1, 2: -1}
var _hit_at := {1: Vector2.ZERO, 2: Vector2.ZERO}

var _match_active := false

func _init() -> void:
	super()
	game_id = "archery"
	display_name = "Archery"
	rules_text = "Drag to aim, release to shoot.\nMind the wind.\nBest of 5 arrows wins."
	match_duration = 0.0
	theme_bg = Palette.BG_ARCHERY

func _on_layout() -> void:
	target_radius = clampf(play_rect.size.x * 0.11, 34.0, 76.0)
	archer_pos = Vector2(play_rect.position.x + play_rect.size.x * 0.16, play_rect.end.y - play_rect.size.y * 0.20)
	target_center = Vector2(play_rect.end.x - target_radius - 18.0, play_rect.position.y + play_rect.size.y * 0.34)
	for player in [1, 2]:
		if phase[player] == Phase.AIM:
			arrow_pos[player] = archer_pos

func setup(_config: Dictionary) -> void:
	layout()
	for player in [1, 2]:
		arrow_pos[player] = archer_pos
	set_process(false)
	InputManager.player_pressed.connect(_on_press)
	InputManager.player_dragged.connect(_on_drag)
	InputManager.player_released.connect(_on_release)

func start_match() -> void:
	_match_active = true
	set_process(true)

func _on_press(player: int, _zone: int, position: Vector2, _screen: Vector2) -> void:
	if not _match_active or phase[player] != Phase.AIM:
		return
	aiming[player] = true
	aim_to[player] = position
	queue_redraw()

func _on_drag(player: int, _zone: int, position: Vector2, _delta: Vector2, _screen: Vector2) -> void:
	if not aiming[player]:
		return
	aim_to[player] = position
	queue_redraw()

## Drag back from the archer and let go: the arrow leaves along the vector from
## the finger to the bow, so pulling further back and lower shoots harder and
## flatter — the same slingshot grammar Basketball uses.
func _on_release(player: int, _zone: int, position: Vector2, _screen: Vector2) -> void:
	if not aiming[player]:
		return
	aiming[player] = false
	var pull: Vector2 = archer_pos - position
	if pull.length() < 14.0:
		queue_redraw()
		return
	arrow_pos[player] = archer_pos
	arrow_vel[player] = (pull * DRAW_POWER).limit_length(MAX_SPEED)
	phase[player] = Phase.FLIGHT
	AudioManager.play_sfx("dash", player)
	queue_redraw()

func _process(delta: float) -> void:
	if not _match_active:
		return

	_wind_phase += WIND_RATE * delta
	wind = sin(_wind_phase) * WIND_MAX

	for player in [1, 2]:
		if phase[player] != Phase.FLIGHT:
			continue
		var v: Vector2 = arrow_vel[player]
		v.y += GRAVITY * delta
		v.x += wind * delta
		arrow_vel[player] = v
		arrow_pos[player] += v * delta

		var p: Vector2 = arrow_pos[player]
		if p.distance_to(target_center) <= target_radius:
			_score_arrow(player, p)
		elif p.x > play_rect.end.x + 40.0 or p.y > play_rect.end.y + 40.0 or p.x < play_rect.position.x - 40.0:
			_score_arrow(player, Vector2.INF)

	queue_redraw()

## Ten rings, scored by distance from the bullseye. A miss is worth nothing but
## still burns an arrow, so wild shots cost.
func _score_arrow(player: int, hit: Vector2) -> void:
	phase[player] = Phase.SCORED
	var points := 0
	if hit != Vector2.INF:
		var d := hit.distance_to(target_center) / target_radius
		points = int(clampf(ceilf((1.0 - d) * 10.0), 1.0, 10.0))
		_hit_at[player] = hit
		AudioManager.play_sfx("place", player)
	else:
		_hit_at[player] = Vector2.INF
		AudioManager.play_sfx("fall", player)

	last_points[player] = points
	total[player] += points
	shots[player] += 1
	score_updated.emit(total[1], total[2])

	if points >= 9:
		Juice.burst(self, Field.to_screen(player, target_center), Palette.for_player(player))

	await get_tree().create_timer(1.0).timeout
	if not _match_active:
		return
	if shots[player] >= ARROWS:
		phase[player] = Phase.DONE
		_maybe_finish()
	else:
		phase[player] = Phase.AIM
		arrow_pos[player] = archer_pos

func _maybe_finish() -> void:
	if shots[1] < ARROWS or shots[2] < ARROWS:
		return
	_match_active = false
	set_process(false)
	var winner := 0
	if total[1] > total[2]:
		winner = 1
	elif total[2] > total[1]:
		winner = 2
	end_match(winner, total[1], total[2])

func _draw_half(player: int) -> void:
	draw_ground(Palette.BG_ARCHERY)
	var color := Palette.for_player(player)

	var grass := Rect2(play_rect.position.x, play_rect.position.y + play_rect.size.y * 0.42, play_rect.size.x, play_rect.size.y * 0.58)
	Juice.sticker_rect(self, grass, Palette.RANGE_GRASS, 12.0, 6.0)

	_draw_target()
	_draw_archer(color)
	_draw_wind()

	if aiming[player]:
		_draw_aim(player, color)
	if phase[player] == Phase.FLIGHT:
		_draw_arrow(arrow_pos[player], arrow_vel[player].angle(), color)
	if phase[player] == Phase.SCORED and _hit_at[player] != Vector2.INF:
		_draw_arrow(_hit_at[player], 0.0, color)

	_draw_card(player, color)

func _draw_target() -> void:
	# Stand first, so the face sits over it.
	var leg := Rect2(target_center.x - 5.0, target_center.y, 10.0, target_radius + 40.0)
	Juice.sticker_rect(self, leg, Palette.PADDOCK_SAND, 4.0, 4.0)

	var rings := [
		[1.00, Palette.SURFACE], [0.78, Palette.INK], [0.58, Palette.PLAYER_2],
		[0.38, Palette.PLAYER_1], [0.18, Palette.ACCENT],
	]
	Juice.cartoon_circle(self, target_center, target_radius, Palette.SURFACE)
	for ring in rings:
		draw_circle(target_center, target_radius * ring[0], ring[1])
	draw_arc(target_center, target_radius, 0.0, TAU, 40, Palette.OUTLINE, 5.0)

func _draw_archer(color: Color) -> void:
	var s := art_scale
	Juice.sticker_rect(self, Rect2(archer_pos.x - 11.0 * s, archer_pos.y - 18.0 * s, 22.0 * s, 30.0 * s), color, 9.0, 5.0)
	Juice.cartoon_circle(self, archer_pos + Vector2(0.0, -30.0 * s), 13.0 * s, Palette.SURFACE)
	# Bow: an arc facing the target.
	draw_arc(archer_pos + Vector2(16.0 * s, -8.0 * s), 22.0 * s, -PI * 0.5, PI * 0.5, 20, Palette.ACCENT, 6.0 * s)

## Direction and strength, drawn as an arrow with repeated chevrons. Both halves
## show the same value because the wind is shared.
func _draw_wind() -> void:
	var t := wind / WIND_MAX
	var origin := Vector2(play_rect.get_center().x, play_rect.position.y + 34.0)
	var length := play_rect.size.x * 0.22 * absf(t)
	var dir := signf(t)
	draw_line(origin, origin + Vector2(dir * length, 0.0), Color(Palette.INK, 0.5), 5.0)
	for i in range(3):
		var x := origin.x + dir * (length - i * 9.0)
		draw_line(Vector2(x, origin.y), Vector2(x - dir * 8.0, origin.y - 6.0), Color(Palette.INK, 0.5), 4.0)
		draw_line(Vector2(x, origin.y), Vector2(x - dir * 8.0, origin.y + 6.0), Color(Palette.INK, 0.5), 4.0)

func _draw_aim(player: int, color: Color) -> void:
	var pull: Vector2 = archer_pos - aim_to[player]
	draw_line(archer_pos, aim_to[player], Color(color, 0.45), 5.0)

	var v: Vector2 = (pull * DRAW_POWER).limit_length(MAX_SPEED)
	var prev := archer_pos
	for i in range(16):
		var t := i * 0.03
		# Preview includes the current wind, so the aim guide never lies about
		# the shot the player is actually taking.
		var sample: Vector2 = archer_pos + v * t + Vector2(0.5 * wind * t * t, 0.5 * GRAVITY * t * t)
		if i % 2 == 0:
			draw_line(prev, sample, Color(Palette.SURFACE, 0.5), 3.0)
		prev = sample

func _draw_arrow(p: Vector2, angle: float, color: Color) -> void:
	var s := art_scale
	var dir := Vector2.RIGHT.rotated(angle)
	draw_line(p - dir * 22.0 * s, p, Palette.OUTLINE, 5.0 * s)
	draw_line(p - dir * 20.0 * s, p - dir * 2.0 * s, color, 3.0 * s)
	# Fletching.
	var perp := dir.orthogonal()
	draw_line(p - dir * 22.0 * s, p - dir * 15.0 * s + perp * 6.0 * s, color, 3.0 * s)
	draw_line(p - dir * 22.0 * s, p - dir * 15.0 * s - perp * 6.0 * s, color, 3.0 * s)

func _draw_card(player: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var text := "ARROW %d/%d   TOTAL %d" % [minf(shots[player] + 1, ARROWS), ARROWS, total[player]]
	draw_string(
		font, Vector2(play_rect.position.x + 8.0, play_rect.position.y + 26.0),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(Palette.INK, 0.75),
	)
	if phase[player] == Phase.SCORED and last_points[player] >= 0:
		var big := "+%d" % last_points[player]
		var ts := font.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1, 52)
		draw_string(
			font, Vector2(play_rect.get_center().x - ts.x * 0.5, play_rect.position.y + play_rect.size.y * 0.22),
			big, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, color,
		)
