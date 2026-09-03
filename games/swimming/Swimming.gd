extends SplitGame
## Swimming — a rhythm race. A metronome sweeps back and forth across a bar; tap
## inside the green window for a full stroke, outside it for a weak one. Tap the
## wall to turn. First to two lengths wins.
##
## Deliberately NOT another tap-as-fast-as-you-can game: the tempo is fixed and
## the skill is hitting it, so Swimming and Sprint reward different things even
## though both are "tap to move".

const LENGTHS := 2
const LANE_UNITS := 100.0        ## per length
const STRONG_STROKE := 7.0
const WEAK_STROKE := 1.6
const DRAG := 1.1
const MAX_SPEED := 16.0
const BEAT_SPEED := 1.35         ## metronome sweeps per second
const WINDOW := 0.17             ## half-width of the green zone, in beat units

var lane_left := 0.0
var lane_right := 0.0
var lane_y := 0.0
var swimmer_radius := 20.0
var beat := 0.0                  ## 0..1, shared -- one tempo for both players
var beat_dir := 1.0

var distance := {1: 0.0, 2: 0.0}
var speed := {1: 0.0, 2: 0.0}
var lengths := {1: 0, 2: 0}
var heading := {1: 1.0, 2: 1.0}  ## +1 away from the wall, -1 back
var stroke := {1: 0.0, 2: 0.0}
var _feedback := {1: 0.0, 2: 0.0} ## >0 strong, <0 weak, decays
var _match_active := false

func _init() -> void:
	super()
	game_id = "swimming"
	display_name = "Swimming"
	rules_text = "Tap on the beat to stroke.\nTap the wall to turn.\nFirst to 2 lengths wins."
	match_duration = 0.0
	theme_bg = Palette.BG_SWIM
	theme_dark = true

func _on_layout() -> void:
	swimmer_radius = 20.0 * art_scale
	lane_left = play_rect.position.x + 40.0 * art_scale
	lane_right = play_rect.end.x - 40.0 * art_scale
	lane_y = play_rect.position.y + play_rect.size.y * 0.55

func setup(_config: Dictionary) -> void:
	layout()
	set_process(false)
	InputManager.player_pressed.connect(_on_press)

func start_match() -> void:
	_match_active = true
	set_process(true)

## The green window sits at the centre of the sweep, so "on the beat" is the
## moment the metronome crosses the middle -- readable without a tutorial.
func _on_beat() -> bool:
	return absf(beat - 0.5) <= WINDOW

func _on_press(player: int, _zone: int, _position: Vector2, _screen: Vector2) -> void:
	if not _match_active:
		return
	if _on_beat():
		speed[player] = minf(speed[player] + STRONG_STROKE, MAX_SPEED)
		_feedback[player] = 0.4
		AudioManager.play_sfx("tap", player)
	else:
		speed[player] = minf(speed[player] + WEAK_STROKE, MAX_SPEED)
		_feedback[player] = -0.4
		AudioManager.play_sfx("drop", player)

func _process(delta: float) -> void:
	if not _match_active:
		return

	beat += beat_dir * BEAT_SPEED * delta
	if beat >= 1.0:
		beat = 1.0
		beat_dir = -1.0
	elif beat <= 0.0:
		beat = 0.0
		beat_dir = 1.0

	for player in [1, 2]:
		_feedback[player] = move_toward(_feedback[player], 0.0, delta)
		speed[player] = maxf(0.0, speed[player] - DRAG * speed[player] * delta - 0.5 * delta)
		distance[player] += speed[player] * delta
		stroke[player] = fmod(stroke[player] + speed[player] * delta * 0.09, 1.0)

		# Reaching the far wall turns the swimmer around and banks a length.
		if distance[player] >= LANE_UNITS:
			distance[player] = 0.0
			lengths[player] += 1
			heading[player] *= -1.0
			speed[player] *= 0.55 # a turn costs momentum
			AudioManager.play_sfx("paddle_hit", player)

	score_updated.emit(
		int(lengths[1] * LANE_UNITS + distance[1]),
		int(lengths[2] * LANE_UNITS + distance[2]),
	)

	for player in [1, 2]:
		if lengths[player] >= LENGTHS:
			_match_active = false
			set_process(false)
			AudioManager.play_sfx("win", player)
			end_match(
				player,
				int(lengths[1] * LANE_UNITS + distance[1]),
				int(lengths[2] * LANE_UNITS + distance[2]),
			)
			break

	queue_redraw()

func _swimmer_x(player: int) -> float:
	var t: float = distance[player] / LANE_UNITS
	if heading[player] < 0.0:
		t = 1.0 - t
	return lerpf(lane_left, lane_right, t)

func _draw_half(player: int) -> void:
	draw_scene("swimming", Palette.BG_SWIM)

	var pool := Rect2(
		play_rect.position.x, play_rect.position.y + play_rect.size.y * 0.28,
		play_rect.size.x, play_rect.size.y * 0.56,
	)
	if Art.game("swimming", "bg") == null:
		Juice.sticker_rect(self, pool, Palette.POOL_TEAL, 14.0, 7.0)

	# Lane ropes above and below the swimmer, tiled rather than stretched so the
	# floats keep their proportions on any screen width.
	var rope := Art.game("swimming", "rope")
	for y in [pool.position.y + 18.0 * art_scale, pool.end.y - 18.0 * art_scale]:
		if rope:
			tile_h(rope, Rect2(pool.position.x, y - 8.0 * art_scale, pool.size.x, 16.0 * art_scale), 16.0 * art_scale)
			continue
		var x := pool.position.x + 14.0
		var i := 0
		while x < pool.end.x - 14.0:
			draw_circle(Vector2(x, y), 6.0 * art_scale, Palette.PLAYER_1 if i % 2 == 0 else Palette.SURFACE)
			x += 15.0 * art_scale
			i += 1

	# Touchpads at each end.
	var wall := Art.game("swimming", "wall")
	for x in [lane_left - 22.0 * art_scale, lane_right + 4.0 * art_scale]:
		if wall:
			sprite(wall, Vector2(x + 9.0 * art_scale, pool.get_center().y), pool.size.y * 0.62)
		else:
			Juice.sticker_rect(self, Rect2(x, pool.position.y + 26.0, 18.0 * art_scale, pool.size.y - 52.0), Palette.SURFACE, 5.0, 4.0)

	_draw_swimmer(player)
	_draw_metronome(player)
	_draw_lengths(player)

## Two-stroke cycle from the pack. `face` is the direction of travel: the art
## faces right, so the return length is the same image mirrored rather than a
## second file.
func _draw_swimmer(player: int) -> void:
	var tex := Art.char_for("swimming", "char" if stroke[player] < 0.5 else "pull", player)
	if tex:
		var bob: float = sin(stroke[player] * TAU) * 4.0 * art_scale
		sprite(
			tex, Vector2(_swimmer_x(player), lane_y + bob), 84.0 * art_scale,
			heading[player] < 0.0,
		)
		return
	_draw_swimmer_fallback(player)

## Primitive stand-in, used only when the generated swimmer art is missing.
func _draw_swimmer_fallback(player: int) -> void:
	var s := art_scale
	var color := Palette.for_player(player)
	var x := _swimmer_x(player)
	var bob: float = sin(stroke[player] * TAU) * 4.0 * s
	var p := Vector2(x, lane_y + bob)
	var face: float = heading[player]

	# Trailing wake, so speed reads even when the swimmer is mid-lane.
	for i in range(3):
		var t := (i + 1) * 8.0 * s
		draw_circle(p - Vector2(face * t, 0.0), (4.0 - i) * s, Color(Palette.SURFACE, 0.30))

	Juice.cartoon_circle(self, p, swimmer_radius * 0.9, color, Vector2(1.25, 0.85))
	Juice.cartoon_circle(self, p + Vector2(face * swimmer_radius * 0.8, -3.0 * s), swimmer_radius * 0.48, Palette.SURFACE, Vector2.ONE, false)
	# The stroking arm, swinging over the top.
	var arm: float = stroke[player] * TAU
	draw_line(
		p, p + Vector2(face * cos(arm) * 22.0 * s, -absf(sin(arm)) * 22.0 * s),
		color.lerp(Palette.OUTLINE, 0.25), 7.0 * s,
	)

## The tempo bar. The marker sweeps; the accent band is the window; the bar
## flashes on a hit so the feedback is immediate.
func _draw_metronome(player: int) -> void:
	var bar := Rect2(
		play_rect.position.x + 30.0, play_rect.end.y - 46.0 * art_scale,
		play_rect.size.x - 60.0, 20.0 * art_scale,
	)
	var tint := Color(Palette.INK, 0.25)
	if _feedback[player] > 0.0:
		tint = Color(Palette.SUCCESS, 0.55)
	elif _feedback[player] < 0.0:
		tint = Color(Palette.PLAYER_1, 0.40)
	Juice.rounded_rect(self, bar, tint, 10.0)

	var window_rect := Rect2(
		bar.position.x + bar.size.x * (0.5 - WINDOW), bar.position.y,
		bar.size.x * WINDOW * 2.0, bar.size.y,
	)
	Juice.rounded_rect(self, window_rect, Color(Palette.SUCCESS, 0.75), 10.0)

	var marker_x := bar.position.x + bar.size.x * beat
	Juice.capsule(self, Rect2(marker_x - 5.0, bar.position.y - 6.0, 10.0, bar.size.y + 12.0), Palette.ACCENT, 3.0)

func _draw_lengths(player: int) -> void:
	var font := ThemeDB.fallback_font
	var text := "LENGTH %d/%d" % [minf(lengths[player] + 1, LENGTHS), LENGTHS]
	draw_string(
		font, Vector2(play_rect.position.x + 10.0, play_rect.position.y + 28.0),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(Palette.SURFACE, 0.85),
	)
