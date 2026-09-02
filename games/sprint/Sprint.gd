extends SplitGame
## Sprint (100m) — alternate your two pads to build speed. Mashing one pad gives
## a fraction of the push, so spamming a single finger degrades instead of
## winning (the same anti-degenerate rule the PRD calls out for Tap Race).
##
## Where Tap Race accumulates raw progress per tap, Sprint runs on MOMENTUM:
## taps add velocity, velocity decays continuously, and distance is the integral.
## So rhythm matters rather than raw tap count — stop tapping and you visibly
## slow, which is what makes it read as running rather than as a progress bar.

const ZONE_NEAR := 1
const ZONE_FAR := 2

const RACE_DISTANCE := 100.0
const ALTERNATE_PUSH := 4.6
const MASH_PUSH := 1.1
const DRAG := 1.35
const MAX_SPEED := 13.0
const RUBBER_BAND_MAX := 0.35

var _button_rects := {}
var lane_y := 0.0
var track_start := 0.0
var track_end := 0.0

var distance := {1: 0.0, 2: 0.0}
var speed := {1: 0.0, 2: 0.0}
var _last_zone := {1: 0, 2: 0}
var _stride := {1: 0.0, 2: 0.0}
var _flash := {}
var _match_active := false

func _init() -> void:
	super()
	game_id = "sprint"
	display_name = "Sprint"
	rules_text = "Alternate your two pads to run.\nMashing one is slower.\nFirst to the line wins."
	match_duration = 0.0
	theme_bg = Palette.BG_SPRINT
	theme_dark = true

func _on_layout() -> void:
	var band := play_rect.size.y * 0.30
	_button_rects = {
		ZONE_NEAR: Rect2(play_rect.position, Vector2(play_rect.size.x, band)),
		ZONE_FAR: Rect2(Vector2(play_rect.position.x, play_rect.end.y - band), Vector2(play_rect.size.x, band)),
	}
	lane_y = play_rect.position.y + play_rect.size.y * 0.5
	track_start = play_rect.position.x + 40.0 * art_scale
	track_end = play_rect.end.x - 40.0 * art_scale

	# Both players get the identical rects, in their own local space.
	var zones := []
	for player in [1, 2]:
		for zone in [ZONE_NEAR, ZONE_FAR]:
			zones.append({"player": player, "zone": zone, "rect": _button_rects[zone]})
	InputManager.configure_zones(zones)

func setup(_config: Dictionary) -> void:
	layout()
	set_process(false)
	InputManager.player_pressed.connect(_on_press)

func start_match() -> void:
	_match_active = true
	set_process(true)

func _on_press(player: int, zone: int, _position: Vector2, _screen: Vector2) -> void:
	if not _match_active or zone == InputManager.NO_ZONE:
		return

	var push := ALTERNATE_PUSH if _last_zone[player] != zone else MASH_PUSH
	_last_zone[player] = zone

	var other := 2 if player == 1 else 1
	var behind: float = distance[other] - distance[player]
	if behind > 0.0:
		push *= 1.0 + minf(behind / RACE_DISTANCE, RUBBER_BAND_MAX)

	speed[player] = minf(speed[player] + push, MAX_SPEED)
	_flash["%d_%d" % [player, zone]] = 0.12
	AudioManager.play_sfx("tap", player)

func _process(delta: float) -> void:
	for key in _flash.keys():
		_flash[key] = maxf(0.0, _flash[key] - delta)
	for key in _flash.keys().filter(func(k): return _flash[k] <= 0.0):
		_flash.erase(key)

	if _match_active:
		for player in [1, 2]:
			# Continuous decay, so a runner who stops tapping coasts down rather
			# than freezing -- this is what separates Sprint from Tap Race.
			speed[player] = maxf(0.0, speed[player] - DRAG * speed[player] * delta - 0.6 * delta)
			distance[player] = minf(distance[player] + speed[player] * delta, RACE_DISTANCE)
			_stride[player] = fmod(_stride[player] + speed[player] * delta * 1.4, 1.0)

		score_updated.emit(int(distance[1]), int(distance[2]))

		for player in [1, 2]:
			if distance[player] >= RACE_DISTANCE:
				_match_active = false
				set_process(false)
				AudioManager.play_sfx("win", player)
				end_match(player, int(distance[1]), int(distance[2]))
				break

	queue_redraw()

func _draw_half(player: int) -> void:
	draw_ground(Palette.BG_SPRINT)
	_draw_track(player)
	_draw_pad(player, ZONE_NEAR)
	_draw_pad(player, ZONE_FAR)

	var t: float = distance[player] / RACE_DISTANCE
	_draw_runner(Vector2(lerpf(track_start, track_end, t), lane_y), Palette.for_player(player), _stride[player])

func _draw_track(player: int) -> void:
	var h := 46.0 * art_scale
	var track := Rect2(track_start - 16.0, lane_y - h, (track_end - track_start) + 32.0, h * 2.0)
	Juice.sticker_rect(self, track, Palette.TRACK_RED, 10.0, 6.0)
	draw_line(Vector2(track.position.x + 6.0, lane_y - h * 0.55), Vector2(track.end.x - 6.0, lane_y - h * 0.55), Color(Palette.SURFACE, 0.55), 3.0)
	draw_line(Vector2(track.position.x + 6.0, lane_y + h * 0.55), Vector2(track.end.x - 6.0, lane_y + h * 0.55), Color(Palette.SURFACE, 0.55), 3.0)

	# Finish line, plus a marker showing where the opponent has reached, so the
	# race is legible without either player looking at the other's half.
	draw_line(Vector2(track_end, lane_y - h), Vector2(track_end, lane_y + h), Palette.SURFACE, 6.0)
	var other := 2 if player == 1 else 1
	var ox := lerpf(track_start, track_end, distance[other] / RACE_DISTANCE)
	draw_line(Vector2(ox, lane_y - h), Vector2(ox, lane_y + h), Color(Palette.for_player(other), 0.55), 4.0)

func _draw_pad(player: int, zone: int) -> void:
	var rect: Rect2 = _button_rects.get(zone, Rect2())
	if rect.size == Vector2.ZERO:
		return
	var color := Palette.for_player(player)
	var is_next: bool = _last_zone[player] != zone
	var press: float = _flash.get("%d_%d" % [player, zone], 0.0) / 0.12

	var size := Vector2(minf(rect.size.x * 0.58, 300.0), minf(rect.size.y * 0.66, 96.0))
	var btn := Rect2(rect.get_center() - size * 0.5, size)
	btn.position.y += 5.0 * press
	var fill: Color = color if is_next else color.lerp(Palette.BG_SPRINT, 0.5)
	if press > 0.0:
		fill = fill.lightened(0.25 * press)
	Juice.sticker_rect(self, btn, fill, 20.0, 6.0)

	var font := ThemeDB.fallback_font
	var label := "GO" if is_next else "WAIT"
	var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 34)
	draw_string(
		font, btn.get_center() + Vector2(-ts.x * 0.5, ts.y * 0.34),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, 34,
		Palette.SURFACE if is_next else Color(Palette.SURFACE, 0.55),
	)

## A stick-and-blob runner whose legs and arms swing on `stride`, so speed reads
## from the animation and not only from the position.
func _draw_runner(pos: Vector2, color: Color, stride: float) -> void:
	var s := art_scale
	var swing: float = sin(stride * TAU)
	var lift: float = absf(cos(stride * TAU))

	var hip := pos + Vector2(0.0, 6.0 * s)
	for sign_ in [1.0, -1.0]:
		var knee := hip + Vector2(swing * sign_ * 15.0 * s, 14.0 * s)
		var foot := knee + Vector2(swing * sign_ * 12.0 * s, 14.0 * s - lift * 6.0 * s * sign_)
		draw_line(hip, knee, Palette.OUTLINE, 9.0 * s)
		draw_line(knee, foot, Palette.OUTLINE, 8.0 * s)

	var torso := Rect2(pos.x - 11.0 * s, pos.y - 20.0 * s, 22.0 * s, 28.0 * s)
	Juice.sticker_rect(self, torso, color, 9.0, 5.0)

	var shoulder := pos + Vector2(0.0, -14.0 * s)
	for sign_ in [1.0, -1.0]:
		var hand := shoulder + Vector2(-swing * sign_ * 18.0 * s, 6.0 * s)
		draw_line(shoulder, hand, color.lerp(Palette.OUTLINE, 0.2), 8.0 * s)

	Juice.cartoon_circle(self, pos + Vector2(0.0, -30.0 * s), 13.0 * s, Palette.SURFACE)
	# Headband in the player's colour, so the runner is identifiable at a glance.
	draw_line(
		pos + Vector2(-12.0 * s, -34.0 * s), pos + Vector2(12.0 * s, -34.0 * s),
		color, 5.0 * s,
	)
