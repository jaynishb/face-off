extends SplitGame
## Diving — three dives each, judged out of 10.
##
## One tap per phase, each judged on timing:
##   READY  tap to launch. A power meter sweeps up and down; the closer to the
##          top of the sweep, the more height, and height buys rotation time.
##   FLIGHT hold to tuck (spin fast), release to open out. You want to land on a
##          whole number of somersaults.
##   ENTRY  tap to straighten. Judged on how close the body is to vertical when
##          it meets the water.
##
## Nothing here is shared between the two players, so the whole dive is authored
## once in PLAYER space and drawn twice (see SplitGame).

const DIVES := 3
const GRAVITY := 900.0
const POWER_RATE := 1.9
const TUCK_SPIN := 6.4
const OPEN_SPIN := 1.5

enum Phase { READY, FLIGHT, SPLASH, DONE }

var board_tip := Vector2.ZERO
var water_y := 0.0
var diver_radius := 20.0

var phase := {1: Phase.READY, 2: Phase.READY}
var power := {1: 0.0, 2: 0.0}
var power_dir := {1: 1.0, 2: 1.0}
var launch_power := {1: 0.0, 2: 0.0}
var pos := {1: Vector2.ZERO, 2: Vector2.ZERO}
var vel := {1: Vector2.ZERO, 2: Vector2.ZERO}
var spin := {1: 0.0, 2: 0.0}
var rotation_total := {1: 0.0, 2: 0.0}
var tucking := {1: false, 2: false}
var dives_done := {1: 0, 2: 0}
var total := {1: 0, 2: 0}
var last_score := {1: -1.0, 2: -1.0}

var _match_active := false

func _init() -> void:
	super()
	game_id = "diving"
	display_name = "Diving"
	rules_text = "Tap to launch, hold to tuck.\nTap again to enter straight.\nBest of 3 dives wins."
	match_duration = 0.0
	theme_bg = Palette.BG_DIVING

func _on_layout() -> void:
	diver_radius = 20.0 * art_scale
	board_tip = Vector2(play_rect.position.x + play_rect.size.x * 0.28, play_rect.position.y + play_rect.size.y * 0.26)
	water_y = play_rect.end.y - play_rect.size.y * 0.24
	for player in [1, 2]:
		if phase[player] == Phase.READY:
			pos[player] = board_tip + Vector2(0.0, -diver_radius)

func setup(_config: Dictionary) -> void:
	layout()
	for player in [1, 2]:
		_ready_dive(player)
	set_process(false)
	InputManager.player_pressed.connect(_on_press)
	InputManager.player_released.connect(_on_release)

func start_match() -> void:
	_match_active = true
	set_process(true)

func _ready_dive(player: int) -> void:
	phase[player] = Phase.READY
	power[player] = 0.0
	power_dir[player] = 1.0
	spin[player] = 0.0
	rotation_total[player] = 0.0
	tucking[player] = false
	vel[player] = Vector2.ZERO
	pos[player] = board_tip + Vector2(0.0, -diver_radius)

func _on_press(player: int, _zone: int, _position: Vector2, _screen: Vector2) -> void:
	if not _match_active:
		return
	match phase[player]:
		Phase.READY:
			launch_power[player] = power[player]
			# The board throws the diver up-court (toward the seam, -y local) and
			# slightly out over the water.
			vel[player] = Vector2(120.0 * art_scale, -(320.0 + 300.0 * power[player]) * art_scale)
			phase[player] = Phase.FLIGHT
			tucking[player] = true
			AudioManager.play_sfx("dash", player)
		Phase.FLIGHT:
			tucking[player] = true

func _on_release(player: int, _zone: int, _position: Vector2, _screen: Vector2) -> void:
	if phase[player] == Phase.FLIGHT:
		tucking[player] = false

func _process(delta: float) -> void:
	if not _match_active:
		return
	for player in [1, 2]:
		match phase[player]:
			Phase.READY:
				# Meter sweeps 0..1 and back; tapping at the top buys height.
				power[player] += power_dir[player] * POWER_RATE * delta
				if power[player] >= 1.0:
					power[player] = 1.0
					power_dir[player] = -1.0
				elif power[player] <= 0.0:
					power[player] = 0.0
					power_dir[player] = 1.0
			Phase.FLIGHT:
				spin[player] = TUCK_SPIN if tucking[player] else OPEN_SPIN
				rotation_total[player] += spin[player] * delta
				var v: Vector2 = vel[player]
				v.y += GRAVITY * delta * art_scale
				vel[player] = v
				pos[player] += v * delta
				if pos[player].y >= water_y:
					_judge(player)
			_:
				pass
	queue_redraw()

## Score out of 10: half for landing on a whole number of somersaults, half for
## how close to vertical the body is at entry, with a small height bonus. Both
## halves are pure timing, so a good dive is repeatable rather than lucky.
func _judge(player: int) -> void:
	phase[player] = Phase.SPLASH
	AudioManager.play_sfx("drop", player)
	Juice.burst(self, Field.to_screen(player, Vector2(pos[player].x, water_y)), Palette.POOL_TEAL)

	var turns: float = rotation_total[player] / TAU
	var rotation_error: float = absf(turns - roundf(turns)) * 2.0 # 0 clean .. 1 flat
	var entry_error: float = absf(sin(rotation_total[player]))    # 0 vertical .. 1 sideways
	var height_bonus: float = launch_power[player] * 1.5

	var raw: float = 8.5 * (1.0 - rotation_error) * 0.5 + 8.5 * (1.0 - entry_error) * 0.5 + height_bonus
	var points := int(round(clampf(raw, 0.0, 10.0)))
	last_score[player] = points
	total[player] += points
	dives_done[player] += 1
	score_updated.emit(total[1], total[2])

	await get_tree().create_timer(1.1).timeout
	if not _match_active:
		return
	if dives_done[player] >= DIVES:
		phase[player] = Phase.DONE
		_maybe_finish()
	else:
		_ready_dive(player)

func _maybe_finish() -> void:
	if dives_done[1] < DIVES or dives_done[2] < DIVES:
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
	draw_ground(Palette.BG_DIVING)
	var color := Palette.for_player(player)

	# Water, drawn from water_y down to the player's own edge.
	var pool := Rect2(play_rect.position.x, water_y, play_rect.size.x, play_rect.end.y - water_y)
	Juice.sticker_rect(self, pool, Palette.POOL_TEAL, 12.0, 6.0)
	for i in range(4):
		var y := water_y + 16.0 * art_scale * (i + 1)
		draw_line(
			Vector2(pool.position.x + 16.0 + i * 9.0, y), Vector2(pool.end.x - 16.0 - i * 9.0, y),
			Color(Palette.SURFACE, 0.30), 3.0,
		)

	_draw_board()

	if phase[player] == Phase.READY:
		_draw_power_meter(player, color)
	if phase[player] != Phase.DONE:
		_draw_diver(player, color)

	_draw_scorecard(player, color)

func _draw_board() -> void:
	var plank := Rect2(play_rect.position.x, board_tip.y, board_tip.x - play_rect.position.x, 14.0 * art_scale)
	Juice.sticker_rect(self, plank, Palette.SURFACE, 6.0, 5.0)
	var post := Rect2(plank.position.x + 20.0 * art_scale, plank.end.y, 22.0 * art_scale, 46.0 * art_scale)
	Juice.sticker_rect(self, post, Palette.POOL_TEAL, 6.0, 5.0)

func _draw_power_meter(player: int, color: Color) -> void:
	var w := 22.0 * art_scale
	var h := play_rect.size.y * 0.34
	var track := Rect2(play_rect.end.x - w - 18.0, board_tip.y, w, h)
	Juice.sticker_rect(self, track, Color(Palette.INK, 0.25), 10.0, 4.0)
	# Fills from the bottom up, so "more" is visually higher.
	var fill_h: float = h * power[player]
	Juice.rounded_rect(self, Rect2(track.position.x + 3.0, track.end.y - fill_h, w - 6.0, fill_h), color, 8.0)
	# The sweet spot the launch is judged against.
	draw_line(
		Vector2(track.position.x - 6.0, track.position.y + h * 0.12),
		Vector2(track.end.x + 6.0, track.position.y + h * 0.12),
		Palette.ACCENT, 4.0,
	)

## The diver as a rotating capsule with a head, so the somersault count is
## readable in flight -- which is the thing the score is actually judging.
func _draw_diver(player: int, color: Color) -> void:
	var p: Vector2 = pos[player]
	var angle: float = rotation_total[player]
	var body_len: float = diver_radius * (1.1 if tucking[player] and phase[player] == Phase.FLIGHT else 2.1)
	var dir := Vector2(sin(angle), -cos(angle))

	draw_line(p - dir * body_len * 0.5, p + dir * body_len * 0.5, Palette.OUTLINE, diver_radius * 1.15)
	draw_line(p - dir * body_len * 0.45, p + dir * body_len * 0.45, color, diver_radius * 0.8)
	Juice.cartoon_circle(self, p - dir * body_len * 0.5, diver_radius * 0.52, Palette.SURFACE, Vector2.ONE, false)

func _draw_scorecard(player: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var text := "DIVE %d/%d   TOTAL %d" % [minf(dives_done[player] + 1, DIVES), DIVES, total[player]]
	draw_string(
		font, Vector2(play_rect.position.x + 8.0, play_rect.position.y + 26.0),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(Palette.INK, 0.75),
	)
	if phase[player] == Phase.SPLASH and last_score[player] >= 0.0:
		var big := "%d" % int(last_score[player])
		var ts := font.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1, 64)
		draw_string(
			font,
			Vector2(play_rect.get_center().x - ts.x * 0.5, play_rect.position.y + play_rect.size.y * 0.5),
			big, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, color,
		)
