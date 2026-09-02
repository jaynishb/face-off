extends MiniGame
## Tap Race — alternate-tap your two buttons to accelerate. Mashing one button
## only gives a small "mash" boost, not the full "alternate" boost, so spamming a
## single finger degrades instead of winning. The trailing player gets a small
## rubber-band boost to keep it close.
##
## SPLIT mode, and the game that the whole per-player coordinate space exists
## for. Each player has their own private lane and their own two buttons, and
## never looks at the opponent's half — so the half is authored exactly once, in
## Field's PLAYER space, and drawn twice under Field.player_xform(). Player 2's
## copy comes out rotated by PI and therefore right-way-up to them.
##
## Because both halves are one piece of geometry, the two players' zone rects are
## literally the same Rect2. CLAUDE.md's "identical control area, identical visual
## weight for both players" stops being something to police in review and becomes
## structurally impossible to violate.

const ZONE_NEAR := 1  ## the button nearer the seam, in the player's own view
const ZONE_FAR := 2   ## the button nearer their own screen edge

const FINISH := 1000.0
const ALTERNATE_BOOST := 26.0
const MASH_BOOST := 6.0
const RUBBER_BAND_MAX := 0.4

# All geometry below is in PLAYER space (see Field.gd) and shared by both
# players -- there is deliberately no per-player variant of any of it.
var lane_y := 0.0
var track_start := 0.0
var track_end := 0.0
var _button_rects := {} # zone -> Rect2, so _draw can render what input listens to
var _car_scale := 1.0

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
	view_mode = ViewMode.SPLIT
	input_space = InputManager.Space.PLAYER

## Lanes AND the InputManager zone rects are both derived from the viewport, so
## a resize has to re-register the zones -- stale zone rects would leave the tap
## buttons drawn in one place and listening in another (see MiniGame.layout).
func layout() -> void:
	var half := Field.half_size()
	var inner := Field.SEAM_BAND * 0.5
	var outer := Field.SAFE_OUTER + Field.EDGE_MARGIN
	var usable := Rect2(
		Field.EDGE_MARGIN, inner,
		half.x - Field.EDGE_MARGIN * 2.0, half.y - inner - outer,
	)

	var band := usable.size.y * 0.36
	_button_rects = {
		ZONE_NEAR: Rect2(usable.position, Vector2(usable.size.x, band)),
		ZONE_FAR: Rect2(Vector2(usable.position.x, usable.end.y - band), Vector2(usable.size.x, band)),
	}

	lane_y = usable.position.y + usable.size.y * 0.5
	_car_scale = clampf(usable.size.x / 560.0, 0.7, 1.25)
	track_start = usable.position.x + 46.0 * _car_scale
	track_end = usable.end.x - 46.0 * _car_scale

	# Both players get the identical rects, in their own local space.
	var zones := []
	for player in [1, 2]:
		for zone in [ZONE_NEAR, ZONE_FAR]:
			zones.append({"player": player, "zone": zone, "rect": _button_rects[zone]})
	InputManager.configure_zones(zones)
	queue_redraw()

func setup(_config: Dictionary) -> void:
	layout()
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

func _on_touch(player: int, zone: int, _position: Vector2, _screen: Vector2) -> void:
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

## One half, drawn twice. Everything between the transform calls is in PLAYER
## space; the reset at the end is mandatory -- an un-reset canvas transform
## leaks into every later draw call in the frame.
func _draw() -> void:
	for player in [1, 2]:
		draw_set_transform_matrix(Field.player_xform(player))
		_draw_half(player)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_half(player: int) -> void:
	_draw_button(player, ZONE_NEAR)
	_draw_button(player, ZONE_FAR)
	_draw_lane()

	var t: float = progress[player] / FINISH
	_draw_car(Vector2(lerpf(track_start, track_end, t), lane_y), Palette.for_player(player))

## The two tap zones, drawn. They were configured but never rendered, so the
## rules card told players to tap two buttons that did not exist on screen
## (GAME_AUDIT.md H1). Each flashes on tap, and the one to hit next is
## highlighted, which teaches the alternate-don't-mash mechanic by showing it.
func _draw_button(player: int, zone: int) -> void:
	var rect: Rect2 = _button_rects.get(zone, Rect2())
	if rect.size == Vector2.ZERO:
		return

	var color := Palette.for_player(player)
	var is_next: bool = _last_zone[player] != zone
	var flash: float = _flash.get("%d_%d" % [player, zone], 0.0)

	# A real chunky button centred in the zone, not a tinted overlay across the
	# whole half -- a big translucent rectangle reads as a dimmed screen rather
	# than something to press. The whole zone still registers the tap.
	var size := Vector2(minf(rect.size.x * 0.62, 300.0), minf(rect.size.y * 0.62, 112.0))
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

## An asphalt strip with a dashed centre line and a chequered finish post -- a
## road the car drives on, rather than a bare rule. In PLAYER space the road runs
## left to right, which is left to right for whoever is looking at it.
func _draw_lane() -> void:
	var h := 34.0 * _car_scale
	var road := Rect2(track_start - 10.0, lane_y - h, (track_end - track_start) + 20.0, h * 2.0)
	Juice.sticker_rect(self, road, Palette.ASPHALT, 12.0, 6.0)

	var dash := 22.0
	var x := track_start + 4.0
	while x < track_end - 8.0:
		draw_line(Vector2(x, lane_y), Vector2(minf(x + dash, track_end - 8.0), lane_y), Color(Palette.ACCENT, 0.85), 4.0)
		x += dash * 2.0

	# Chequered finish post at the end of the lane.
	var square := h * 0.33
	for row in range(6):
		for col in range(2):
			var dark := (row + col) % 2 == 0
			draw_rect(
				Rect2(track_end - 4.0 + col * square, lane_y - h + 1.0 + row * square, square, square),
				Palette.OUTLINE if dark else Palette.SURFACE,
			)

## A little cartoon car -- body, cabin, wheels, headlight -- in the house sticker
## style. Replaces the flat circle these racers used to be.
func _draw_car(pos: Vector2, color: Color) -> void:
	var s := _car_scale
	var body := Rect2(pos.x - 28.0 * s, pos.y - 12.0 * s, 56.0 * s, 24.0 * s)
	var cabin := Rect2(pos.x - 14.0 * s, pos.y - 25.0 * s, 30.0 * s, 15.0 * s)

	# Wheels first, so the body sits over them.
	for wheel_x in [pos.x - 16.0 * s, pos.x + 16.0 * s]:
		draw_circle(Vector2(wheel_x, pos.y + 13.0 * s), 10.0 * s, Palette.OUTLINE)
		draw_circle(Vector2(wheel_x, pos.y + 13.0 * s), 4.0 * s, Palette.SURFACE)

	Juice.sticker_rect(self, cabin, color.lerp(Palette.SURFACE, 0.30), 7.0, 5.0)
	Juice.sticker_rect(self, body, color, 11.0, 5.0)

	# Windscreen + headlight.
	Juice.rounded_rect(self, Rect2(cabin.position.x + 5.0 * s, cabin.position.y + 4.0 * s, 20.0 * s, 7.0 * s), Color(1, 1, 1, 0.6), 3.0)
	draw_circle(Vector2(body.end.x - 6.0 * s, pos.y - 2.0 * s), 4.0 * s, Palette.ACCENT)
