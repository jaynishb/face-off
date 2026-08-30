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
	theme_bg = Palette.BG_TAP_RACE

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

	var color := Palette.for_player(player)
	var is_next: bool = _last_zone[player] != zone
	var flash: float = _flash.get(key, 0.0)

	# A real chunky button centred in the zone, not a tinted overlay across the
	# whole half -- a big translucent rectangle reads as a dimmed screen rather
	# than something to press. The whole zone still registers the tap.
	var size := Vector2(minf(rect.size.x * 0.62, 260.0), minf(rect.size.y * 0.52, 108.0))
	var btn := Rect2(rect.get_center() - size * 0.5, size)

	# Pressed buttons sink into their shadow; the next one to hit sits proud.
	var press: float = flash / 0.12
	btn.position.y += 5.0 * press
	var fill: Color = color if is_next else color.lerp(Palette.ASPHALT, 0.45)
	if press > 0.0:
		fill = fill.lightened(0.25 * press)

	Juice.sticker_rect(self, btn, fill, 22.0, 6.0)

	var font := ThemeDB.fallback_font
	var label := "TAP" if is_next else "WAIT"
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 40)
	draw_string(
		font,
		btn.get_center() + Vector2(-text_size.x * 0.5, text_size.y * 0.34),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, 40,
		Palette.SURFACE if is_next else Color(Palette.SURFACE, 0.55),
	)

## An asphalt strip with a dashed centre line and a chequered finish post --
## a road the car drives on, rather than a bare rule.
func _draw_lane(player: int) -> void:
	var x0: float = track_start[player]
	var x1: float = track_end[player]
	var road := Rect2(x0 - 10.0, lane_y - 34.0, (x1 - x0) + 20.0, 68.0)
	Juice.sticker_rect(self, road, Palette.ASPHALT, 12.0, 6.0)

	var dash := 22.0
	var x := x0 + 4.0
	while x < x1 - 8.0:
		draw_line(Vector2(x, lane_y), Vector2(minf(x + dash, x1 - 8.0), lane_y), Color(Palette.ACCENT, 0.85), 4.0)
		x += dash * 2.0

	# Chequered finish post at the end of this player's own lane.
	var square := 11.0
	for row in range(6):
		for col in range(2):
			var dark := (row + col) % 2 == 0
			draw_rect(
				Rect2(x1 - 4.0 + col * square, lane_y - 33.0 + row * square, square, square),
				Palette.OUTLINE if dark else Palette.SURFACE,
			)

## A little cartoon car -- body, cabin, wheels, headlight -- in the house
## sticker style. Replaces the flat circle these racers used to be.
func _draw_car(pos: Vector2, color: Color) -> void:
	var body := Rect2(pos.x - 28.0, pos.y - 12.0, 56.0, 24.0)
	var cabin := Rect2(pos.x - 14.0, pos.y - 25.0, 30.0, 15.0)

	# Wheels first, so the body sits over them.
	for wheel_x in [pos.x - 16.0, pos.x + 16.0]:
		draw_circle(Vector2(wheel_x, pos.y + 13.0), 10.0, Palette.OUTLINE)
		draw_circle(Vector2(wheel_x, pos.y + 13.0), 4.0, Palette.SURFACE)

	Juice.sticker_rect(self, cabin, color.lerp(Palette.SURFACE, 0.30), 7.0, 5.0)
	Juice.sticker_rect(self, body, color, 11.0, 5.0)

	# Windscreen + headlight.
	Juice.rounded_rect(self, Rect2(cabin.position.x + 5.0, cabin.position.y + 4.0, 20.0, 7.0), Color(1, 1, 1, 0.6), 3.0)
	draw_circle(Vector2(body.end.x - 6.0, pos.y - 2.0), 4.0, Palette.ACCENT)
