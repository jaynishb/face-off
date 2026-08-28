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

const LANE1_Y := 220.0
const LANE2_Y := 520.0
const TRACK_LEFT := 60.0
const TRACK_RIGHT := 1220.0

var progress := {1: 0.0, 2: 0.0}
var _last_zone := {1: 0, 2: 0}
var _match_active := false

func _init() -> void:
	game_id = "tap_race"
	display_name = "Tap Race"
	rules_text = "Tap your two buttons as fast as you can.\nFirst to the finish wins!"
	match_duration = 0.0

func setup(_config: Dictionary) -> void:
	InputManager.configure_zones([
		{"player": 1, "zone": ZONE_TOP, "rect": Rect2(0, 76, 640, 317)},
		{"player": 1, "zone": ZONE_BOTTOM, "rect": Rect2(0, 393, 640, 317)},
		{"player": 2, "zone": ZONE_TOP, "rect": Rect2(640, 76, 640, 317)},
		{"player": 2, "zone": ZONE_BOTTOM, "rect": Rect2(640, 393, 640, 317)},
	])
	InputManager.player_pressed.connect(_on_touch)

func start_match() -> void:
	_match_active = true

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
	AudioManager.play_sfx("tap", player)
	score_updated.emit(int(progress[1]), int(progress[2]))
	queue_redraw()

	if progress[player] >= FINISH:
		_match_active = false
		end_match(player, int(progress[1]), int(progress[2]))

func _draw() -> void:
	draw_line(Vector2(TRACK_LEFT, LANE1_Y), Vector2(TRACK_RIGHT, LANE1_Y), Palette.INK, 3)
	draw_line(Vector2(TRACK_LEFT, LANE2_Y), Vector2(TRACK_RIGHT, LANE2_Y), Palette.INK, 3)
	draw_line(Vector2(TRACK_RIGHT, LANE1_Y - 40), Vector2(TRACK_RIGHT, LANE1_Y + 40), Palette.ACCENT, 6)
	draw_line(Vector2(TRACK_RIGHT, LANE2_Y - 40), Vector2(TRACK_RIGHT, LANE2_Y + 40), Palette.ACCENT, 6)

	var p1x: float = TRACK_LEFT + (TRACK_RIGHT - TRACK_LEFT) * (progress[1] / FINISH)
	var p2x: float = TRACK_LEFT + (TRACK_RIGHT - TRACK_LEFT) * (progress[2] / FINISH)
	draw_circle(Vector2(p1x, LANE1_Y), 24, Palette.PLAYER_1)
	draw_circle(Vector2(p2x, LANE2_Y), 24, Palette.PLAYER_2)
