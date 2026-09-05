extends SplitGame
## Swimming — a rhythm race. A metronome sweeps back and forth across a bar; tap
## inside the green window for a full stroke, outside it for a weak one. Tap the
## wall to turn. First to four lengths wins.
##
## Deliberately NOT another tap-as-fast-as-you-can game: the tempo is fixed and
## the skill is hitting it, so Swimming and Sprint reward different things even
## though both are "tap to move".

## Four lengths, not two. Two was a 15.5-second race -- under the PRD's 20-second
## floor -- and it only ever contained ONE turn, which is the verb this game just
## gained. Four puts three turns in the middle of a ~31s race.
const LENGTHS := 4
const LANE_UNITS := 100.0        ## per length
const STRONG_STROKE := 7.0
const WEAK_STROKE := 1.6
const DRAG := 1.1
const MAX_SPEED := 16.0
const BEAT_SPEED := 1.35         ## metronome sweeps per second
const WINDOW := 0.17             ## half-width of the green zone, in beat units

## The turn at the wall. The rules card has always said "tap the wall to turn",
## and it was not true: _process flipped `heading` on its own and the tap did
## nothing there. A card that teaches an input the player then finds dead is
## worse than no card, so the input exists now.
##
## React fast and you push off hard. TURN_TIMEOUT is the safety valve: without
## it a player who never taps never turns, and the match cannot end at all --
## tools/Playability.tscn asserts the race still finishes on its own.
const PUSH_STRONG := 11.0
const PUSH_WEAK := 3.0
const TURN_GRACE := 0.75         ## seconds within which the push-off is full strength
const TURN_TIMEOUT := 3.0        ## after this the swimmer turns anyway, at PUSH_WEAK

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
var at_wall := {1: false, 2: false} ## touched the far wall, waiting for the turn tap
var wall_t := {1: 0.0, 2: 0.0}      ## seconds spent waiting at the wall
var _match_active := false

func _init() -> void:
	super()
	game_id = "swimming"
	display_name = "Swimming"
	rules_text = "Tap on the beat to stroke.\nTap the wall to turn.\nFirst to 4 lengths wins."
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
	if at_wall[player]:
		_push_off(player)
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

		# Reaching the far wall stops the swimmer dead against it. The length is
		# not banked until the turn is taken, so the score stays honest about how
		# far they have actually swum while they hang there.
		if not at_wall[player] and distance[player] >= LANE_UNITS:
			distance[player] = LANE_UNITS
			speed[player] = 0.0
			AudioManager.play_sfx("paddle_hit", player)
			# The final wall is the finish line, not a turn -- asking for a tap
			# there would be asking the winner to confirm they have won.
			if lengths[player] + 1 >= LENGTHS:
				lengths[player] += 1
			else:
				at_wall[player] = true
				wall_t[player] = 0.0

		if at_wall[player]:
			wall_t[player] += delta
			if wall_t[player] >= TURN_TIMEOUT:
				_push_off(player)

	score_updated.emit(_progress(1), _progress(2))

	for player in [1, 2]:
		if lengths[player] >= LENGTHS:
			_match_active = false
			set_process(false)
			AudioManager.play_sfx("win", player)
			end_match(player, _progress(1), _progress(2))
			break

	queue_redraw()

## Total distance swum, in lane units. One definition, used by the live score
## and by the final result, so the number cannot change at the moment the match
## ends.
func _progress(player: int) -> int:
	return int(lengths[player] * LANE_UNITS + distance[player])

## Kick off the wall. Reacting inside TURN_GRACE gives the full push; dawdling
## fades it to PUSH_WEAK, which is what makes the tap worth timing rather than
## just worth remembering.
func _push_off(player: int) -> void:
	var t: float = clampf(wall_t[player] / TURN_GRACE, 0.0, 1.0)
	at_wall[player] = false
	wall_t[player] = 0.0
	lengths[player] += 1
	distance[player] = 0.0
	heading[player] *= -1.0
	speed[player] = lerpf(PUSH_STRONG, PUSH_WEAK, t)
	_feedback[player] = 0.4 if t < 1.0 else -0.4
	AudioManager.play_sfx("dash", player)

func _swimmer_x(player: int) -> float:
	var t: float = distance[player] / LANE_UNITS
	if heading[player] < 0.0:
		t = 1.0 - t
	return lerpf(lane_left, lane_right, t)

func _draw_half(player: int) -> void:
	draw_scene("swimming", Palette.BG_SWIM)

	# The lane is derived FROM lane_y rather than from its own fraction of the
	# half, so the ropes always bracket the swimmer and the wall pads always sit
	# at the ends of the lane he actually swims. The two used to be independent
	# fractions that happened to overlap; which band of the cropped background
	# lands under a given local y depends on the viewport, and the art is
	# scenery -- anything the rules depend on is positioned by code (CLAUDE.md).
	var band := play_rect.size.y * 0.46
	var pool := Rect2(
		play_rect.position.x, lane_y - band * 0.5,
		play_rect.size.x, band,
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

	# Touchpads at each end of the lane. At 0.62 of the pool height the sprite
	# came out as a large white picture frame with the swimmer sometimes inside
	# it; a touchpad is a plate on the wall, not a proscenium arch.
	var wall := Art.game("swimming", "wall")
	var pad_h: float = minf(pool.size.y * 0.30, 96.0 * art_scale)
	for x in [lane_left - 18.0 * art_scale, lane_right + 18.0 * art_scale]:
		if wall:
			sprite(wall, Vector2(x, lane_y), pad_h)
		else:
			Juice.sticker_rect(
				self, Rect2(x - 9.0 * art_scale, lane_y - pad_h * 0.5, 18.0 * art_scale, pad_h),
				Palette.SURFACE, 5.0, 4.0,
			)

	_draw_swimmer(player)
	_draw_turn_prompt(player)
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

## Shown only while the swimmer is pinned against the wall waiting for the turn.
## The ring shrinks as the push-off fades from PUSH_STRONG to PUSH_WEAK, so the
## cost of hesitating is visible rather than something the player has to be told.
func _draw_turn_prompt(player: int) -> void:
	if not at_wall[player]:
		return
	var p := Vector2(_swimmer_x(player), lane_y)
	var t: float = clampf(wall_t[player] / TURN_GRACE, 0.0, 1.0)
	var radius: float = lerpf(48.0, 26.0, t) * art_scale
	draw_arc(p, radius, 0.0, TAU, 32, Color(Palette.ACCENT, 0.9), 5.0 * art_scale)

	var font := ThemeDB.fallback_font
	var label := "TAP!"
	var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
	draw_string(
		font, p + Vector2(-size.x * 0.5, -radius - 10.0 * art_scale),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Palette.ACCENT,
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

## On its own plate. Pale text straight onto the scene put "LENGTH 1/4" over the
## cream tiles of the painted deck, which is very nearly the same colour -- and
## which band of the crop lands there depends on the viewport, so there is no
## text colour that is safe everywhere. The plate makes it safe anywhere.
func _draw_lengths(player: int) -> void:
	var font := ThemeDB.fallback_font
	var text := "LENGTH %d/%d" % [minf(lengths[player] + 1, LENGTHS), LENGTHS]
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	var origin := Vector2(play_rect.position.x + 14.0, play_rect.position.y + 30.0)
	Juice.rounded_rect(
		self,
		Rect2(origin.x - 10.0, origin.y - size.y, size.x + 20.0, size.y + 12.0),
		Color(Palette.INK, 0.55), 10.0,
	)
	draw_string(
		font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.SURFACE,
	)
