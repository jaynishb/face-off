extends MiniGame
## Sumo Blob — the personality game. Tap your side to dash toward the
## centre; knock the other blob off the platform. The platform shrinks over
## the round to force a resolution. Best of 3. Manual circle-physics with a
## simple procedural squash-and-stretch (no external art needed for the feel).

const RADIUS_START := 300.0
const RADIUS_END := 120.0
const SHRINK_DURATION := 30.0
const BLOB_RADIUS := 52.0
const DASH_IMPULSE := 520.0
const DASH_COOLDOWN := 0.4
const FRICTION := 3.0
const ROUNDS_TO_WIN := 2
const SQUASH_RECOVERY := 8.0

var platform_center := Vector2.ZERO # from the real visible rect -- see Field.gd
var platform_radius := RADIUS_START
var elapsed := 0.0

var p1_pos := Vector2.ZERO
var p2_pos := Vector2.ZERO
var p1_vel := Vector2.ZERO
var p2_vel := Vector2.ZERO
var p1_squash := Vector2.ONE
var p2_squash := Vector2.ONE
var p1_cooldown := 0.0
var p2_cooldown := 0.0
var p1_rounds := 0
var p2_rounds := 0

var _match_active := false
var _round_locked := false
var _unit_pts: PackedVector2Array = _build_unit_circle()

static func _build_unit_circle() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var segments := 24
	for i in range(segments):
		var a := TAU * i / segments
		pts.append(Vector2(cos(a), sin(a)))
	return pts

func _init() -> void:
	game_id = "sumo_blob"
	display_name = "Sumo Blob"
	rules_text = "Tap to dash.\nPush them off the edge.\nBest of 3 wins."
	match_duration = 0.0
	theme_bg = Palette.BG_SUMO
	theme_dark = true

func setup(_config: Dictionary) -> void:
	platform_center = Field.center()
	set_process(false)
	_reset_round()
	InputManager.player_pressed.connect(_on_touch)

func start_match() -> void:
	_match_active = true
	set_process(true)

func _on_touch(player: int, _zone: int, _position: Vector2) -> void:
	if not _match_active or _round_locked:
		return
	var cooldown: float = p1_cooldown if player == 1 else p2_cooldown
	if cooldown > 0.0:
		return

	var pos: Vector2 = p1_pos if player == 1 else p2_pos
	var dir := (platform_center - pos).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT if player == 1 else Vector2.LEFT

	if player == 1:
		p1_vel += dir * DASH_IMPULSE
		p1_cooldown = DASH_COOLDOWN
		p1_squash = Vector2(1.3, 0.7)
	else:
		p2_vel += dir * DASH_IMPULSE
		p2_cooldown = DASH_COOLDOWN
		p2_squash = Vector2(1.3, 0.7)

	AudioManager.play_sfx("dash", player)
	if SaveManager.haptics_enabled:
		Input.vibrate_handheld(30)

func _process(delta: float) -> void:
	if not _match_active or _round_locked:
		return

	elapsed = minf(elapsed + delta, SHRINK_DURATION)
	platform_radius = lerpf(RADIUS_START, RADIUS_END, elapsed / SHRINK_DURATION)

	p1_cooldown = maxf(0.0, p1_cooldown - delta)
	p2_cooldown = maxf(0.0, p2_cooldown - delta)

	var r1 := _step_blob(p1_pos, p1_vel, delta)
	p1_pos = r1[0]
	p1_vel = r1[1]
	var r2 := _step_blob(p2_pos, p2_vel, delta)
	p2_pos = r2[0]
	p2_vel = r2[1]

	_resolve_blob_collision()

	var recovery := minf(delta * SQUASH_RECOVERY, 1.0)
	p1_squash = p1_squash.lerp(Vector2.ONE, recovery)
	p2_squash = p2_squash.lerp(Vector2.ONE, recovery)

	var p1_out := p1_pos.distance_to(platform_center) > platform_radius
	var p2_out := p2_pos.distance_to(platform_center) > platform_radius
	if p1_out or p2_out:
		_round_locked = true
		var round_winner := 0
		if p1_out and p2_out:
			round_winner = 0 # simultaneous fall -- replay the round, no score
			Juice.burst(self, p1_pos, Palette.PLAYER_1)
			Juice.burst(self, p2_pos, Palette.PLAYER_2)
		elif p1_out:
			round_winner = 2
			Juice.burst(self, p1_pos, Palette.PLAYER_1)
		else:
			round_winner = 1
			Juice.burst(self, p2_pos, Palette.PLAYER_2)
		_resolve_round(round_winner)

	queue_redraw()

func _step_blob(pos: Vector2, vel: Vector2, delta: float) -> Array:
	var new_pos := pos + vel * delta
	var new_vel := vel.lerp(Vector2.ZERO, minf(FRICTION * delta, 1.0))
	return [new_pos, new_vel]

func _resolve_blob_collision() -> void:
	var diff := p2_pos - p1_pos
	var dist := diff.length()
	var min_dist := BLOB_RADIUS * 2.0
	if dist >= min_dist or dist <= 0.001:
		return

	var normal := diff / dist
	var overlap := min_dist - dist
	p1_pos -= normal * overlap * 0.5
	p2_pos += normal * overlap * 0.5

	var impact := (p1_vel - p2_vel).dot(normal)
	if impact > 0.0:
		p1_vel -= normal * impact
		p2_vel += normal * impact
		p1_squash = Vector2(0.7, 1.3)
		p2_squash = Vector2(0.7, 1.3)
		AudioManager.play_sfx("blob_impact")
		if SaveManager.haptics_enabled:
			Input.vibrate_handheld(20)

func _resolve_round(round_winner: int) -> void:
	AudioManager.play_sfx("fall", round_winner)
	if round_winner == 1:
		p1_rounds += 1
	elif round_winner == 2:
		p2_rounds += 1
	score_updated.emit(p1_rounds, p2_rounds)

	await get_tree().create_timer(1.0).timeout

	if p1_rounds >= ROUNDS_TO_WIN or p2_rounds >= ROUNDS_TO_WIN:
		var match_winner := 1 if p1_rounds > p2_rounds else 2
		end_match(match_winner, p1_rounds, p2_rounds)
	else:
		_reset_round()
		_round_locked = false

func _reset_round() -> void:
	platform_radius = RADIUS_START
	elapsed = 0.0
	p1_pos = platform_center + Vector2(-150, 0)
	p2_pos = platform_center + Vector2(150, 0)
	p1_vel = Vector2.ZERO
	p2_vel = Vector2.ZERO
	p1_squash = Vector2.ONE
	p2_squash = Vector2.ONE
	p1_cooldown = 0.0
	p2_cooldown = 0.0
	queue_redraw()

func _draw() -> void:
	# A raised clay dohyo: cast shadow, hard black rim, clay mat, and a lighter
	# inner ring for the boundary the blobs are fighting over.
	draw_circle(platform_center + Vector2(0, 14), platform_radius + 8.0, Color(0, 0, 0, 0.22))
	draw_circle(platform_center, platform_radius + 9.0, Palette.OUTLINE)
	draw_circle(platform_center, platform_radius, Palette.DOHYO_CLAY)
	draw_arc(platform_center, platform_radius * 0.80, 0.0, TAU, 56, Palette.SURFACE.lerp(Palette.DOHYO_CLAY, 0.35), 6.0)

	# Face the blobs toward each other so they read as opponents.
	_draw_blob(p1_pos, p1_squash, Palette.PLAYER_1, 1.0 if p1_pos.x < p2_pos.x else -1.0)
	_draw_blob(p2_pos, p2_squash, Palette.PLAYER_2, 1.0 if p2_pos.x < p1_pos.x else -1.0)

## The blobs are the game's mascot, drawn procedurally so they can squash and
## stretch with the physics -- a static sprite can't. Body, blush, eyes with
## pupils that lean into the direction of travel, and a mouth. Previously these
## were flat untextured circles in a game called Sumo Blob (GAME_AUDIT.md M2).
func _draw_blob(pos: Vector2, squash: Vector2, color: Color, facing: float) -> void:
	var rx := BLOB_RADIUS * squash.x
	var ry := BLOB_RADIUS * squash.y

	var ow := Juice.outline_width(BLOB_RADIUS)
	var cast := PackedVector2Array()
	for p in _unit_pts:
		cast.append(pos + Juice.SHADOW_OFFSET + Vector2(p.x * (rx + ow), p.y * (ry + ow)))
	draw_colored_polygon(cast, Color(0, 0, 0, Juice.SHADOW_ALPHA))

	var shadow := PackedVector2Array()
	for p in _unit_pts:
		shadow.append(pos + Vector2(p.x * (rx + ow), p.y * (ry + ow)))
	draw_colored_polygon(shadow, Palette.OUTLINE)

	var pts := PackedVector2Array()
	for p in _unit_pts:
		pts.append(pos + Vector2(p.x * rx, p.y * ry))
	draw_colored_polygon(pts, color)

	# Soft highlight, top-left.
	var hi := PackedVector2Array()
	for p in _unit_pts:
		hi.append(pos + Vector2(-rx * 0.34, -ry * 0.36) + Vector2(p.x * rx * 0.26, p.y * ry * 0.26))
	draw_colored_polygon(hi, Color(1, 1, 1, 0.34))

	var eye_dx := rx * 0.30
	var eye_y := pos.y - ry * 0.12
	var eye_r := maxf(rx * 0.20, 4.0)
	for side in [-1.0, 1.0]:
		var eye_c := Vector2(pos.x + side * eye_dx, eye_y)
		draw_circle(eye_c, eye_r, Palette.SURFACE)
		draw_circle(eye_c + Vector2(facing * eye_r * 0.32, 0.0), eye_r * 0.52, Palette.INK)

	# Blush + a small determined mouth.
	var blush := Color(1, 1, 1, 0.28)
	draw_circle(Vector2(pos.x - rx * 0.56, pos.y + ry * 0.16), rx * 0.13, blush)
	draw_circle(Vector2(pos.x + rx * 0.56, pos.y + ry * 0.16), rx * 0.13, blush)
	draw_line(
		Vector2(pos.x - rx * 0.16, pos.y + ry * 0.40),
		Vector2(pos.x + rx * 0.16, pos.y + ry * 0.40),
		Palette.INK, maxf(rx * 0.09, 2.0),
	)
