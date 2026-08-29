extends MiniGame
## Tap Race — alternate-tap your two buttons (top/bottom of your half) to
## accelerate. Mashing one button only gives a small "mash" boost, not the
## full "alternate" boost, so spamming a single finger degrades instead of
## winning. Trailing player gets a small rubber-band boost to keep it close.

const ZONE_TOP := 1
const ZONE_BOTTOM := 2

const FINISH := 1000.0
const ALTERNATE_BOOST := 26.0
const MASH_BOOST := 6.0
const RUBBER_BAND_MAX := 0.4

## Geometry from the real visible rect -- see Field.gd. Each player gets their
## own lane inside their own half, running between their own two buttons,
## rather than one lane spanning the whole screen: a player should watch their
## car on their side, not track it across the opponent's controls.
var lane_y := 0.0
var track_start := {1: 0.0, 2: 0.0}
var track_end := {1: 0.0, 2: 0.0}
var _zone_rects := {} # "player_zone" -> Rect2, so _draw can render the buttons

var progress := {1: 0.0, 2: 0.0}
var _last_zone := {1: 0, 2: 0}
var _flash := {} # "player_zone" -> remaining flash time, for tap feedback
var _match_active := false

func _init() -> void:
	game_id = "tap_race"
	display_name = "Tap Race"
	rules_text = "Tap your two buttons as fast as you can.\nFirst to the finish wins!"
	match_duration = 0.0

func setup(_config: Dictionary) -> void:
	var top := Field.top()
	var bottom := Field.bottom()
	var mid := Field.mid_x()
	var half_h := (bottom - top) * 0.5

	lane_y = top + half_h
	track_start[1] = Field.left() + 46.0
	track_end[1] = mid - 34.0
	track_start[2] = mid + 34.0
	track_end[2] = Field.right() - 46.0

	var zones := [
		{"player": 1, "zone": ZONE_TOP, "rect": Rect2(Field.left(), top, mid - Field.left(), half_h)},
		{"player": 1, "zone": ZONE_BOTTOM, "rect": Rect2(Field.left(), top + half_h, mid - Field.left(), half_h)},
		{"player": 2, "zone": ZONE_TOP, "rect": Rect2(mid, top, Field.right() - mid, half_h)},
		{"player": 2, "zone": ZONE_BOTTOM, "rect": Rect2(mid, top + half_h, Field.right() - mid, half_h)},
	]
	InputManager.configure_zones(zones)
	for z in zones:
		_zone_rects["%d_%d" % [z.player, z.zone]] = z.rect

	InputManager.player_pressed.connect(_on_touch)
	set_process(true)

func start_match() -> void:
	_match_active = true

func _process(delta: float) -> void:
	if _flash.is_empty():
		return
	for key in _flash.keys():
		_flash[key] = maxf(0.0, _flash[key] - delta)
	for key in _flash.keys().filter(func(k): return _flash[k] <= 0.0):
		_flash.erase(key)
	queue_redraw()

func _on_touch(player: int, zone: int, _position: Vector2) -> void:
	if not _match_active or zone == InputManager.NO_ZONE:
		return

	var boost := ALTERNATE_BOOST if _last_zone[player] != zone else MASH_BOOST
	_last_zone[player] = zone

	var other := 2 if player == 1 else 1
	var diff: float = progress[other] - progress[player]
	if diff > 0.0:
		boost *= 1.0 + minf(diff / FINISH, RUBBER_BAND_MAX)

	progress[player] = minf(progress[player] + boost, FINISH)
	_flash["%d_%d" % [player, zone]] = 0.12
	AudioManager.play_sfx("tap", player)
	# Percent of the way to the finish -- the raw 0..1000 progress figure this
	# used to emit meant nothing to a player mid-race (GAME_AUDIT.md H2).
	score_updated.emit(
		int(progress[1] / FINISH * 100.0),
		int(progress[2] / FINISH * 100.0),
	)
	queue_redraw()

	if progress[player] >= FINISH:
		_match_active = false
		end_match(
			player,
			int(progress[1] / FINISH * 100.0),
			int(progress[2] / FINISH * 100.0),
		)

func _draw() -> void:
	for player in [1, 2]:
		_draw_button(player, ZONE_TOP)
		_draw_button(player, ZONE_BOTTOM)
		_draw_lane(player)

	for player in [1, 2]:
		var t: float = progress[player] / FINISH
		var x: float = lerpf(track_start[player], track_end[player], t)
		_draw_car(Vector2(x, lane_y), Palette.for_player(player))

## The two tap zones, drawn. They were configured but never rendered, so the
## rules card told players to tap two buttons that did not exist on screen
## (GAME_AUDIT.md H1). Each flashes on tap, and the one to hit next is
## highlighted, which teaches the alternate-don't-mash mechanic by showing it.
func _draw_button(player: int, zone: int) -> void:
	var key := "%d_%d" % [player, zone]
	var rect: Rect2 = _zone_rects.get(key, Rect2())
	if rect.size == Vector2.ZERO:
		return

	var pad := 16.0
	var inner := Rect2(rect.position + Vector2(pad, pad), rect.size - Vector2(pad, pad) * 2.0)
	var color := Palette.for_player(player)
	var is_next: bool = _last_zone[player] != zone
	var flash: float = _flash.get(key, 0.0)

	var fill_alpha: float = 0.16 if is_next else 0.06
	if flash > 0.0:
		fill_alpha += 0.34 * (flash / 0.12)
	draw_rect(inner, Color(color, fill_alpha))
	draw_rect(inner, Color(color, 0.9 if is_next else 0.35), false, 4.0)

	var font := ThemeDB.fallback_font
	var label := "TAP" if is_next else "..."
	var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 34)
	draw_string(
		font,
		inner.get_center() + Vector2(-size.x * 0.5, size.y * 0.34),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, 34,
		Color(color, 0.95 if is_next else 0.4),
	)

func _draw_lane(player: int) -> void:
	var x0: float = track_start[player]
	var x1: float = track_end[player]
	draw_line(Vector2(x0, lane_y), Vector2(x1, lane_y), Color(Palette.INK, 0.35), 4.0)

	# Chequered finish post at the end of this player's own lane.
	var square := 9.0
	for i in range(6):
		var c := Palette.INK if i % 2 == 0 else Palette.SURFACE
		draw_rect(Rect2(x1, lane_y - 27.0 + i * square, square, square), c)
		draw_rect(Rect2(x1 + square, lane_y - 27.0 + i * square, square, square),
			Palette.SURFACE if i % 2 == 0 else Palette.INK)

## A little cartoon car -- body, cabin, wheels, headlight. Replaces the flat
## circle these racers used to be (GAME_AUDIT.md M1).
func _draw_car(pos: Vector2, color: Color) -> void:
	var body := Rect2(pos.x - 26.0, pos.y - 11.0, 52.0, 22.0)
	var cabin := Rect2(pos.x - 13.0, pos.y - 23.0, 28.0, 14.0)

	draw_rect(body.grow(3.0), Palette.INK)
	draw_rect(cabin.grow(3.0), Palette.INK)
	draw_rect(body, color)
	draw_rect(cabin, color.lerp(Palette.SURFACE, 0.35))

	# Window + headlight.
	draw_rect(Rect2(cabin.position.x + 4.0, cabin.position.y + 3.0, 20.0, 8.0), Color(1, 1, 1, 0.55))
	draw_circle(Vector2(body.end.x - 4.0, pos.y - 2.0), 3.5, Palette.ACCENT)

	for wheel_x in [pos.x - 15.0, pos.x + 15.0]:
		draw_circle(Vector2(wheel_x, pos.y + 12.0), 8.5, Palette.INK)
		draw_circle(Vector2(wheel_x, pos.y + 12.0), 3.5, Palette.SURFACE)
