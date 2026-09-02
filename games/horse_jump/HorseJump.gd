extends SplitGame
## Horse Jump — your horse gallops forward on its own; tap to jump each hurdle.
## Clip one and you stumble, losing speed. First to the finish wins.
##
## The course is per-player and identical, generated from one shared seed so the
## two riders face exactly the same hurdles — a race decided by timing, never by
## who drew the easier course.

const COURSE_LENGTH := 1400.0
const BASE_SPEED := 190.0
const MAX_SPEED := 330.0
const SPEED_GAIN := 26.0      ## per clean jump
const STUMBLE_PENALTY := 90.0
const JUMP_IMPULSE := 520.0
const GRAVITY := 1500.0
const HURDLE_SPACING := 210.0
const HURDLE_WIDTH := 26.0

var ground_y := 0.0
var rider_x := 0.0
var hurdle_height := 54.0
var horse_radius := 26.0
var hurdles: Array[float] = []

var travelled := {1: 0.0, 2: 0.0}
var speed := {1: BASE_SPEED, 2: BASE_SPEED}
var air := {1: 0.0, 2: 0.0}      ## height above the ground, local -y
var air_vel := {1: 0.0, 2: 0.0}
var stumble := {1: 0.0, 2: 0.0}  ## remaining stumble time, for the wobble
var cleared := {1: 0, 2: 0}
var _next_hurdle := {1: 0, 2: 0}
var _gallop := {1: 0.0, 2: 0.0}
var _match_active := false

func _init() -> void:
	super()
	game_id = "horse_jump"
	display_name = "Horse Jump"
	rules_text = "Tap to jump each hurdle.\nClip one and you stumble.\nFirst to the finish wins."
	match_duration = 0.0
	theme_bg = Palette.BG_HORSE

func _on_layout() -> void:
	ground_y = play_rect.position.y + play_rect.size.y * 0.68
	rider_x = play_rect.position.x + play_rect.size.x * 0.28
	hurdle_height = 54.0 * art_scale
	horse_radius = 26.0 * art_scale

func setup(_config: Dictionary) -> void:
	layout()
	_build_course()
	set_process(false)
	InputManager.player_pressed.connect(_on_press)

## One course, both riders. Positions are jittered from a fixed seed so the
## course is varied between matches but identical between players.
func _build_course() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	hurdles.clear()
	var x := HURDLE_SPACING
	while x < COURSE_LENGTH - 120.0:
		hurdles.append(x)
		x += HURDLE_SPACING + rng.randf_range(-40.0, 70.0)

func start_match() -> void:
	_match_active = true
	set_process(true)

func _on_press(player: int, _zone: int, _position: Vector2, _screen: Vector2) -> void:
	if not _match_active or air[player] > 0.0:
		return
	air_vel[player] = -JUMP_IMPULSE
	air[player] = 0.01
	AudioManager.play_sfx("dash", player)

func _process(delta: float) -> void:
	if not _match_active:
		return

	for player in [1, 2]:
		_step_jump(player, delta)

		stumble[player] = maxf(0.0, stumble[player] - delta)
		var v: float = speed[player] * (0.45 if stumble[player] > 0.0 else 1.0)
		travelled[player] = minf(travelled[player] + v * delta, COURSE_LENGTH)
		_gallop[player] = fmod(_gallop[player] + v * delta * 0.012, 1.0)

		_check_hurdle(player)

	score_updated.emit(
		int(travelled[1] / COURSE_LENGTH * 100.0),
		int(travelled[2] / COURSE_LENGTH * 100.0),
	)

	for player in [1, 2]:
		if travelled[player] >= COURSE_LENGTH:
			_match_active = false
			set_process(false)
			AudioManager.play_sfx("win", player)
			end_match(
				player,
				int(travelled[1] / COURSE_LENGTH * 100.0),
				int(travelled[2] / COURSE_LENGTH * 100.0),
			)
			break

	queue_redraw()

## `air` is a height above the ground (always >= 0); `air_vel` is its downward
## rate, so a negative air_vel is rising.
func _step_jump(player: int, delta: float) -> void:
	if air[player] <= 0.0 and air_vel[player] >= 0.0:
		air[player] = 0.0
		air_vel[player] = 0.0
		return
	air_vel[player] += GRAVITY * delta
	air[player] = maxf(0.0, air[player] - air_vel[player] * delta)
	if air[player] <= 0.0:
		air[player] = 0.0
		air_vel[player] = 0.0

## A hurdle is cleared if the horse is high enough while its body overlaps the
## rail. Otherwise it clips, stumbles, and loses the speed it had built up.
func _check_hurdle(player: int) -> void:
	var idx: int = _next_hurdle[player]
	if idx >= hurdles.size():
		return
	var hurdle_x: float = hurdles[idx]
	var front: float = travelled[player] + horse_radius
	if front < hurdle_x:
		return
	if travelled[player] - horse_radius > hurdle_x + HURDLE_WIDTH:
		return

	_next_hurdle[player] = idx + 1
	if air[player] >= hurdle_height * 0.72:
		cleared[player] += 1
		speed[player] = minf(speed[player] + SPEED_GAIN, MAX_SPEED)
		AudioManager.play_sfx("place", player)
	else:
		stumble[player] = 0.55
		speed[player] = maxf(BASE_SPEED, speed[player] - STUMBLE_PENALTY)
		AudioManager.play_sfx("fall", player)
		Juice.burst(self, Field.to_screen(player, Vector2(rider_x, ground_y)), Palette.PADDOCK_SAND, 10)
		if SaveManager.haptics_enabled:
			Input.vibrate_handheld(25)

func _draw_half(player: int) -> void:
	draw_scene("horse_jump", Palette.BG_HORSE)
	if Art.game("horse_jump", "bg") == null:
		var arena := Rect2(play_rect.position.x, ground_y, play_rect.size.x, play_rect.end.y - ground_y)
		Juice.sticker_rect(self, arena, Palette.PADDOCK_SAND, 10.0, 6.0)
		_draw_fence()
	draw_line(
		Vector2(play_rect.position.x, ground_y), Vector2(play_rect.end.x, ground_y),
		Color(Palette.OUTLINE, 0.18), 3.0,
	)

	# The course scrolls past a fixed rider, so the player's eye stays in one
	# place rather than tracking a shrinking figure across the half.
	var scroll: float = travelled[player]
	for hurdle_x in hurdles:
		var sx: float = rider_x + (hurdle_x - scroll)
		if sx < play_rect.position.x - 60.0 or sx > play_rect.end.x + 60.0:
			continue
		_draw_hurdle(sx)

	var finish_x: float = rider_x + (COURSE_LENGTH - scroll)
	if finish_x < play_rect.end.x + 40.0:
		_draw_finish(finish_x)

	_draw_horse(player)
	_draw_progress(player)

func _draw_fence() -> void:
	var y := ground_y - 26.0 * art_scale
	draw_line(Vector2(play_rect.position.x, y), Vector2(play_rect.end.x, y), Color(Palette.SURFACE, 0.85), 5.0)
	var x := play_rect.position.x + 20.0
	while x < play_rect.end.x:
		draw_line(Vector2(x, y - 14.0 * art_scale), Vector2(x, ground_y), Color(Palette.SURFACE, 0.7), 4.0)
		x += 74.0 * art_scale

func _draw_hurdle(x: float) -> void:
	var tex := Art.game("horse_jump", "hurdle")
	if tex:
		sprite(tex, Vector2(x, ground_y - hurdle_height * 0.5), hurdle_height * 1.3)
		return
	var w := HURDLE_WIDTH * art_scale
	for side in [-1.0, 1.0]:
		var post := Rect2(x + side * w * 0.5 - 5.0 * art_scale, ground_y - hurdle_height, 9.0 * art_scale, hurdle_height)
		Juice.sticker_rect(self, post, Palette.SURFACE, 4.0, 4.0)
	for i in range(2):
		var rail := Rect2(x - w * 0.5 - 6.0, ground_y - hurdle_height + 8.0 * art_scale + i * 22.0 * art_scale, w + 12.0, 9.0 * art_scale)
		Juice.sticker_rect(self, rail, Palette.PLAYER_1 if i == 0 else Palette.SURFACE, 4.0, 4.0)

func _draw_finish(x: float) -> void:
	var square := 12.0 * art_scale
	for row in range(5):
		for col in range(2):
			var dark := (row + col) % 2 == 0
			draw_rect(
				Rect2(x + col * square, ground_y - square * 5.0 + row * square, square, square),
				Palette.OUTLINE if dark else Palette.SURFACE,
			)

## Horse and rider as chunky blocks with a gallop bob -- enough to read as an
## animal in motion until the generated art lands.
func _draw_horse(player: int) -> void:
	var airborne: bool = air[player] > 4.0
	var tex := Art.char_for("horse_jump", "jump" if airborne else "gallop", player)
	if tex:
		var bob: float = 0.0 if airborne else sin(_gallop[player] * TAU) * 4.0 * art_scale
		var tilt: float = sin(stumble[player] * 40.0) * 0.25 if stumble[player] > 0.0 else 0.0
		sprite(
			tex,
			Vector2(rider_x, ground_y - air[player] - bob - 46.0 * art_scale),
			132.0 * art_scale, false, tilt,
		)
		return
	_draw_horse_fallback(player)

## Primitive stand-in, used only when the generated horse art is missing.
func _draw_horse_fallback(player: int) -> void:
	var s := art_scale
	var color := Palette.for_player(player)
	var bob: float = sin(_gallop[player] * TAU) * 4.0 * s
	var tilt := 0.0
	if stumble[player] > 0.0:
		tilt = sin(stumble[player] * 40.0) * 0.25
	var base: Vector2 = Vector2(rider_x, ground_y - air[player] - bob)

	draw_set_transform(base, tilt, Vector2.ONE)

	# Legs.
	var swing: float = sin(_gallop[player] * TAU)
	for sign_ in [1.0, -1.0]:
		var hip := Vector2(sign_ * 16.0 * s, -14.0 * s)
		var hoof := hip + Vector2(swing * sign_ * 12.0 * s, 20.0 * s)
		draw_line(hip, hoof, Palette.OUTLINE, 8.0 * s)

	# Body, neck, head, tail.
	Juice.sticker_rect(self, Rect2(-30.0 * s, -34.0 * s, 60.0 * s, 24.0 * s), Palette.COURT_WOOD, 12.0, 5.0)
	draw_line(Vector2(24.0 * s, -30.0 * s), Vector2(40.0 * s, -52.0 * s), Palette.COURT_WOOD, 13.0 * s)
	Juice.cartoon_circle(self, Vector2(43.0 * s, -56.0 * s), 11.0 * s, Palette.COURT_WOOD, Vector2.ONE, false)
	draw_line(Vector2(-30.0 * s, -30.0 * s), Vector2(-44.0 * s, -18.0 * s), Palette.OUTLINE, 7.0 * s)

	# Rider.
	Juice.sticker_rect(self, Rect2(-8.0 * s, -58.0 * s, 20.0 * s, 26.0 * s), color, 8.0, 5.0)
	Juice.cartoon_circle(self, Vector2(2.0 * s, -66.0 * s), 10.0 * s, Palette.SURFACE, Vector2.ONE, false)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_progress(player: int) -> void:
	var bar := Rect2(play_rect.position.x + 10.0, play_rect.position.y + 14.0, play_rect.size.x - 20.0, 12.0)
	Juice.rounded_rect(self, bar, Color(Palette.INK, 0.20), 6.0)
	var other := 2 if player == 1 else 1
	for p in [other, player]:
		var t: float = travelled[p] / COURSE_LENGTH
		var alpha := 1.0 if p == player else 0.45
		Juice.rounded_rect(
			self, Rect2(bar.position, Vector2(bar.size.x * t, bar.size.y)),
			Color(Palette.for_player(p), alpha), 6.0,
		)
