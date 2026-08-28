extends MiniGame
## Sumo Blob — the personality game. Tap your side to dash toward the
## centre; knock the other blob off the platform. The platform shrinks over
## the round to force a resolution. Best of 3. Manual circle-physics with a
## simple procedural squash-and-stretch (no external art needed for the feel).

const PLATFORM_CENTER := Vector2(640, 393)
const RADIUS_START := 300.0
const RADIUS_END := 120.0
const SHRINK_DURATION := 30.0
const BLOB_RADIUS := 40.0
const DASH_IMPULSE := 520.0
const DASH_COOLDOWN := 0.4
const FRICTION := 3.0
const ROUNDS_TO_WIN := 2
const SQUASH_RECOVERY := 8.0

var platform_radius := RADIUS_START
var elapsed := 0.0

var p1_pos := PLATFORM_CENTER + Vector2(-150, 0)
var p2_pos := PLATFORM_CENTER + Vector2(150, 0)
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

func setup(_config: Dictionary) -> void:
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
	var dir := (PLATFORM_CENTER - pos).normalized()
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

	var p1_out := p1_pos.distance_to(PLATFORM_CENTER) > platform_radius
	var p2_out := p2_pos.distance_to(PLATFORM_CENTER) > platform_radius
	if p1_out or p2_out:
		_round_locked = true
		var round_winner := 0
		if p1_out and p2_out:
			round_winner = 0 # simultaneous fall -- replay the round, no score
		elif p1_out:
			round_winner = 2
		else:
			round_winner = 1
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
	p1_pos = PLATFORM_CENTER + Vector2(-150, 0)
	p2_pos = PLATFORM_CENTER + Vector2(150, 0)
	p1_vel = Vector2.ZERO
	p2_vel = Vector2.ZERO
	p1_squash = Vector2.ONE
	p2_squash = Vector2.ONE
	p1_cooldown = 0.0
	p2_cooldown = 0.0
	queue_redraw()

func _draw() -> void:
	draw_circle(PLATFORM_CENTER, platform_radius, Palette.ACCENT.lerp(Palette.SURFACE, 0.3))
	draw_arc(PLATFORM_CENTER, platform_radius, 0.0, TAU, 48, Palette.INK, 4.0)
	_draw_blob(p1_pos, p1_squash, Palette.PLAYER_1)
	_draw_blob(p2_pos, p2_squash, Palette.PLAYER_2)

func _draw_blob(pos: Vector2, squash: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for p in _unit_pts:
		pts.append(pos + Vector2(p.x * BLOB_RADIUS * squash.x, p.y * BLOB_RADIUS * squash.y))
	draw_colored_polygon(pts, color)
