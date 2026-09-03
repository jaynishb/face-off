extends SplitGame
## Archery — five arrows each. Drag back from the archer to set angle and power,
## release to loose. A drifting crosswind pushes the arrow sideways in flight, so
## the shot has to be aimed off-centre rather than just repeated. Highest total
## after five arrows wins.
##
## The wind is SHARED and drawn on both halves: both players face the same
## conditions on every arrow, so the match is decided by aim and not by luck.

const ARROWS := 5
## Gravity, wind and launch speed are all multiplied by art_scale, and the archer
## and target sit at fixed art-scale offsets, so distance, drop and drift all grow
## together: the arrow follows the SAME arc across the half on every handset.
const GRAVITY := 420.0
## Drag-to-launch-speed. Tuned against the archery pass of tools/Playability.tscn,
## which fires every drag that physically fits and counts the ones that hit the
## face: at the original 2.4 the answer was zero, because the longest drag the
## archer's corner allowed produced 384 px/s against the 714 px/s the shot needed.
const DRAW_POWER := 4.2
const MAX_SPEED := 1600.0
const WIND_MAX := 190.0
const WIND_RATE := 0.45

## Archer and target, in art-scale units from the top-left of the half.
##
## These were fractions of the play rect, which is the bug pattern Basketball hit:
## a taller handset stretched the shot while the power stayed put. Anchoring both
## to art_scale keeps the range constant and spends spare height on empty ground.
## The archer is also well clear of the corner -- the drag that shoots at the
## target runs BACK from it, so pinning the archer into a corner is what leaves
## no room to pull.
const ARCHER_ANCHOR := Vector2(220.0, 250.0)
const TARGET_ANCHOR := Vector2(470.0, 85.0)

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
	# The face is generous on purpose: the ten rings inside it are what reward
	# accuracy, so a wide face costs nothing and a narrow one just means most
	# arrows score nothing at all and the match is decided by luck.
	target_radius = clampf(play_rect.size.x * 0.15, 44.0, 108.0)
	archer_pos = play_rect.position + ARCHER_ANCHOR * art_scale
	target_center = play_rect.position + TARGET_ANCHOR * art_scale
	# Safety clamps for a half shorter or narrower than the anchors assume. They
	# only ever pull the two closer together, which makes the shot easier, never
	# impossible.
	archer_pos.y = minf(archer_pos.y, play_rect.end.y - 90.0 * art_scale)
	target_center.x = minf(target_center.x, play_rect.end.x - target_radius - 12.0)
	target_center.y = maxf(target_center.y, play_rect.position.y + target_radius + 6.0)
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
		v.y += GRAVITY * art_scale * delta
		v.x += wind * art_scale * delta
		arrow_vel[player] = v
		arrow_pos[player] += v * delta

		var p: Vector2 = arrow_pos[player]
		if p.distance_to(target_center) <= target_radius:
			_score_arrow(player, p)
		elif (
			p.x > play_rect.end.x + 40.0 or p.y > play_rect.end.y + 40.0
			or p.x < play_rect.position.x - 40.0
			# Local -y is the seam. An arrow lobbed over the top would otherwise be
			# drawn across it, into the opponent's half and upside down; out of the
			# half is out of bounds, and costs the arrow.
			or p.y < play_rect.position.y - 30.0
		):
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
	draw_scene("archery", Palette.BG_ARCHERY)
	var color := Palette.for_player(player)

	if Art.game("archery", "bg") == null:
		var grass := Rect2(play_rect.position.x, play_rect.position.y + play_rect.size.y * 0.42, play_rect.size.x, play_rect.size.y * 0.58)
		Juice.sticker_rect(self, grass, Palette.RANGE_GRASS, 12.0, 6.0)

	_draw_target()
	_draw_archer_for(player)
	_draw_wind()

	if aiming[player]:
		_draw_aim(player, color)
	if phase[player] == Phase.FLIGHT:
		_draw_arrow(arrow_pos[player], arrow_vel[player].angle(), color)
	if phase[player] == Phase.SCORED and _hit_at[player] != Vector2.INF:
		_draw_arrow(_hit_at[player], 0.0, color)

	_draw_card(player, color)

func _draw_target() -> void:
	var tex := Art.game("archery", "target")
	if tex:
		# The art includes its own tripod below the face, so it is anchored by the
		# face centre -- which is the point the ring scoring measures from.
		sprite(tex, target_center + Vector2(0.0, target_radius * 0.42), target_radius * 3.1)
		return
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

func _draw_archer_for(player: int) -> void:
	var tex := Art.char_for("archery", "char", player)
	if tex:
		sprite(tex, archer_pos + Vector2(0.0, -8.0 * art_scale), 128.0 * art_scale)
		return
	_draw_archer_fallback(Palette.for_player(player))

## Primitive stand-in, used only when the generated archer art is missing.
func _draw_archer_fallback(color: Color) -> void:
	var s := art_scale
	Juice.sticker_rect(self, Rect2(archer_pos.x - 11.0 * s, archer_pos.y - 18.0 * s, 22.0 * s, 30.0 * s), color, 9.0, 5.0)
	Juice.cartoon_circle(self, archer_pos + Vector2(0.0, -30.0 * s), 13.0 * s, Palette.SURFACE)
	# Bow: an arc facing the target.
	draw_arc(archer_pos + Vector2(16.0 * s, -8.0 * s), 22.0 * s, -PI * 0.5, PI * 0.5, 20, Palette.ACCENT, 6.0 * s)

## Direction and strength, drawn as an arrow with repeated chevrons. Both halves
## show the same value because the wind is shared.
func _draw_wind() -> void:
	var t := wind / WIND_MAX
	# On a plain sky the bare arrow read as a stray line rather than an instrument,
	# so it sits on its own labelled plate, anchored to the half's top-left instead
	# of floating over the middle of the range.
	var plate := Rect2(
		play_rect.position.x + 12.0, play_rect.position.y + 10.0,
		200.0 * art_scale, 40.0 * art_scale,
	)
	Juice.rounded_rect(self, plate, Color(Palette.SURFACE, 0.78), 12.0)

	var font := ThemeDB.fallback_font
	draw_string(
		font, Vector2(plate.position.x + 12.0, plate.get_center().y + 6.0),
		"WIND", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Palette.INK, 0.7),
	)

	var origin := Vector2(plate.position.x + 74.0 * art_scale, plate.get_center().y)
	var span: float = plate.end.x - 12.0 - origin.x
	var length: float = span * absf(t)
	var dir := signf(t)
	# A dead-calm gauge still has to look like a gauge, not like nothing.
	draw_line(origin, origin + Vector2(dir * maxf(length, 6.0), 0.0), Color(Palette.INK, 0.65), 5.0)
	for i in range(3):
		var x := origin.x + dir * (length - i * 9.0)
		draw_line(Vector2(x, origin.y), Vector2(x - dir * 8.0, origin.y - 6.0), Color(Palette.INK, 0.65), 4.0)
		draw_line(Vector2(x, origin.y), Vector2(x - dir * 8.0, origin.y + 6.0), Color(Palette.INK, 0.65), 4.0)

func _draw_aim(player: int, color: Color) -> void:
	var pull: Vector2 = archer_pos - aim_to[player]
	draw_line(archer_pos, aim_to[player], Color(color, 0.45), 5.0)

	var v: Vector2 = (pull * DRAW_POWER).limit_length(MAX_SPEED)
	var prev := archer_pos
	for i in range(16):
		var t := i * 0.03
		# Preview includes the current wind, so the aim guide never lies about
		# the shot the player is actually taking.
		var sample: Vector2 = archer_pos + v * t + Vector2(
			0.5 * wind * art_scale * t * t, 0.5 * GRAVITY * art_scale * t * t,
		)
		if i % 2 == 0:
			draw_line(prev, sample, Color(Palette.SURFACE, 0.5), 3.0)
		prev = sample

func _draw_arrow(p: Vector2, angle: float, color: Color) -> void:
	var tex := Art.game("archery", "arrow")
	if tex:
		sprite(tex, p, 26.0 * art_scale, false, angle)
		return
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
		# Below the wind plate, which owns the top-left corner of the half.
		font, Vector2(play_rect.position.x + 14.0, play_rect.position.y + 72.0 * art_scale),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(Palette.INK, 0.75),
	)
	if phase[player] == Phase.SCORED and last_points[player] >= 0:
		var big := "+%d" % last_points[player]
		var ts := font.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1, 52)
		draw_string(
			font, Vector2(play_rect.get_center().x - ts.x * 0.5, play_rect.position.y + play_rect.size.y * 0.22),
			big, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, color,
		)
