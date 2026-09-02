extends PartyGame
## Dice Roller — tap to roll 1-6 dice with a tumble-then-settle animation.
## Faces are hand-drawn (Juice.sticker_rect + pip circles), no sprites needed,
## matching the project's existing art approach. A phone standing in for
## physical dice is a real tabletop use case, so results show both individual
## faces and a running total.

const MIN_DICE := 1
const MAX_DICE := 6
const DIE_SIZE := 96.0
const DIE_GAP := 24.0
## Face-flip interval eases from fast to slow across the tumble, rather than a
## constant flicker, so the roll visibly decelerates like a real die losing
## momentum instead of just shuffling a number.
const FLIP_INTERVAL_FAST := 0.045
const FLIP_INTERVAL_SLOW := 0.16
const MOTION_BLUR_SAMPLES := 3

const PIP_LAYOUTS := {
	1: [Vector2(0, 0)],
	2: [Vector2(-1, -1), Vector2(1, 1)],
	3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)],
}

class Die:
	var value: int = 1
	var x: float = 0.0
	var rolling: bool = false
	var start_delay: float = 0.0
	var tumble_time_left: float = 0.0
	var flip_timer: float = 0.0
	var squash: Vector2 = Vector2.ONE
	## Visual lift off the table (tumble skips + landing bounces) and current
	## tilt, faking a die that actually tumbles and skids rather than a flat
	## shape flickering in place.
	var height: float = 0.0
	var rot: float = 0.0
	var bounce_phase: float = 0.0
	var tumble_total: float = 0.55
	## Decaying post-land hop sequence -- 1-2 small skips before the die is
	## fully still, instead of snapping straight from impact to rest.
	var land_bounces_left: int = 0
	var hop_amp: float = 0.0
	var hop_duration: float = 0.12
	var hop_timer: float = 0.0
	## Ring buffer of recent (height, rot, squash) samples, drawn behind the
	## current frame at falling alpha while spinning fast -- a cheap motion-blur
	## trail with no extra draw primitives beyond what _draw_die already needs.
	var trail: Array = []

var _dice: Array[Die] = []
var _dice_count: int = 2
var _rolling_count := 0

var _hint_label: Label
var _total_label: Label

func _init() -> void:
	game_id = "dice_roller"
	display_name = "Dice Roller"
	rules_text = "Pick how many dice.\nTap anywhere to roll.\nRead the total."
	theme_bg = Palette.BG_DICE_ROLLER

func setup(_config: Dictionary) -> void:
	_dice_count = clampi(SaveManager.party_dice_count, MIN_DICE, MAX_DICE)
	_rebuild_dice()
	set_process(true)

	# Dice count is chosen up front by DiceCountPrompt (PartyGameSelect) --
	# no in-game stepper. Tap anywhere on the screen rolls, same pattern
	# SumoBlob uses for tap-to-dash: connect to InputManager's player-split
	# signal and ignore which player/zone fired, since this is a single
	# shared action, not a per-player one.
	InputManager.player_pressed.connect(_on_tap)

	_hint_label = UIUtil.make_label("TAP ANYWHERE TO ROLL", 22)
	add_child(_hint_label)

	_total_label = UIUtil.make_label("TOTAL: %d" % _current_total(), 24)
	add_child(_total_label)

	layout()

func layout() -> void:
	if not _hint_label:
		return
	var mid := Field.mid_x()
	var top := Field.top() + 20.0

	_hint_label.position = Vector2(mid - 160, top + 20)
	_hint_label.size = Vector2(320, 32)
	_total_label.position = Vector2(mid - 80, top + 70)

	_layout_dice()

func _on_tap(_player: int, _zone: int, _position: Vector2) -> void:
	_on_roll_pressed()

func _layout_dice() -> void:
	var mid := Field.mid_x()
	var total_width := _dice.size() * DIE_SIZE + (_dice.size() - 1) * DIE_GAP
	var start_x := mid - total_width * 0.5 + DIE_SIZE * 0.5
	for i in range(_dice.size()):
		_dice[i].x = start_x + i * (DIE_SIZE + DIE_GAP)

func _rebuild_dice() -> void:
	var old_values := _dice.map(func(d: Die): return d.value)
	_dice.clear()
	for i in range(_dice_count):
		var d := Die.new()
		d.value = old_values[i] if i < old_values.size() else 1
		_dice.append(d)
	_layout_dice()
	queue_redraw()

func _current_total() -> int:
	var total := 0
	for d in _dice:
		total += d.value
	return total

func _on_roll_pressed() -> void:
	if _rolling_count > 0:
		return
	_hint_label.visible = false
	_rolling_count = _dice.size()
	for d in _dice:
		d.rolling = true
		d.start_delay = randf_range(0.0, 0.15)
		d.tumble_total = randf_range(0.4, 0.6)
		d.tumble_time_left = d.tumble_total
		d.flip_timer = 0.0
		d.height = 0.0
		d.rot = 0.0
		d.bounce_phase = randf() * TAU # desync dice so they don't skip in lockstep
		d.land_bounces_left = 0
		d.trail.clear()
	AudioManager.play_sfx("tap")

func _process(delta: float) -> void:
	for d in _dice:
		if d.rolling:
			if d.start_delay > 0.0:
				d.start_delay -= delta
				continue
			var progress := 1.0 - clampf(d.tumble_time_left / d.tumble_total, 0.0, 1.0)
			d.tumble_time_left -= delta

			# Decaying skip-and-spin while airborne, easing out as landing nears.
			d.bounce_phase += delta * 15.0
			d.height = absf(sin(d.bounce_phase)) * 26.0 * (1.0 - progress)
			d.rot += delta * lerpf(20.0, 3.0, progress)

			d.flip_timer -= delta
			if d.flip_timer <= 0.0:
				var flip_interval := lerpf(FLIP_INTERVAL_FAST, FLIP_INTERVAL_SLOW, progress)
				d.flip_timer = flip_interval
				if progress < 0.65:
					d.trail.append({"height": d.height, "rot": d.rot, "squash": d.squash})
					if d.trail.size() > MOTION_BLUR_SAMPLES:
						d.trail.pop_front()
				d.value = randi_range(1, 6)
				d.squash = Vector2(1.12, 0.88) if d.value % 2 == 0 else Vector2(0.88, 1.12)

			if d.tumble_time_left <= 0.0:
				d.rolling = false
				d.value = randi_range(1, 6)
				d.squash = Vector2(1.35, 0.65)
				d.height = 0.0
				d.trail.clear()
				d.land_bounces_left = 2
				d.hop_amp = 20.0
				d.hop_duration = 0.12
				d.hop_timer = 0.0
				_rolling_count -= 1
				if _rolling_count <= 0:
					_on_all_landed()
		else:
			if d.land_bounces_left > 0:
				d.hop_timer += delta
				var hop_t := clampf(d.hop_timer / d.hop_duration, 0.0, 1.0)
				d.height = sin(PI * hop_t) * d.hop_amp
				if hop_t >= 1.0:
					d.land_bounces_left -= 1
					d.hop_amp *= 0.45
					d.hop_duration *= 0.85
					d.hop_timer = 0.0
					if d.land_bounces_left <= 0:
						d.height = 0.0
			d.rot = lerpf(d.rot, 0.0, minf(delta * 10.0, 1.0))
			d.squash = Juice.decay_squash(d.squash, delta)

	_total_label.text = "TOTAL: %d" % _current_total()
	queue_redraw()

func _on_all_landed() -> void:
	_hint_label.visible = true
	AudioManager.play_sfx("drop")
	if SaveManager.haptics_enabled:
		Input.vibrate_handheld(30)

func _draw() -> void:
	var y := Field.top() + 280.0
	for d in _dice:
		_draw_shadow(Vector2(d.x, y), d.height, d.squash)
		for i in range(d.trail.size()):
			var sample: Dictionary = d.trail[i]
			var alpha := (float(i) + 1.0) / float(d.trail.size() + 1) * 0.25
			_draw_die_shape(Vector2(d.x, y - sample.height), sample.rot, d.value, sample.squash, alpha)
		_draw_die_shape(Vector2(d.x, y - d.height), d.rot, d.value, d.squash, 1.0)

## Soft ground shadow beneath the die -- grows and darkens as the die
## approaches the table, shrinks and fades as it lifts. The single strongest
## cue that the die is airborne, and the whole reason the tumble reads as a
## bounce rather than a shape wobbling in place.
func _draw_shadow(base_pos: Vector2, height: float, squash: Vector2) -> void:
	var t := clampf(height / 40.0, 0.0, 1.0)
	var shadow_scale := lerpf(1.0, 0.55, t)
	var shadow_alpha := lerpf(0.22, 0.06, t)
	var size := Vector2(DIE_SIZE * squash.x, DIE_SIZE * 0.32) * shadow_scale
	Juice.rounded_rect(self, Rect2(base_pos - size * 0.5, size), Color(0, 0, 0, shadow_alpha), size.y * 0.5)

## Draws one die face at `center`, tilted by `rot` radians. alpha < 1 renders a
## flat, unshadowed ghost copy for the motion-blur trail; alpha == 1 draws the
## full sticker (shadow, outline, gloss highlight, pip glints).
func _draw_die_shape(center: Vector2, rot: float, value: int, squash: Vector2, alpha: float) -> void:
	draw_set_transform(center, rot, Vector2.ONE)
	var half := DIE_SIZE * 0.5
	var rect := Rect2(Vector2(-half, -half) * squash, Vector2(DIE_SIZE, DIE_SIZE) * squash)
	var full := alpha >= 0.999
	if full:
		Juice.sticker_rect(self, rect, Palette.SURFACE, 18.0, 5.0)
		var gloss_size := rect.size * Vector2(0.42, 0.3)
		var gloss_pos := rect.position + rect.size * Vector2(0.1, 0.08)
		Juice.rounded_rect(self, Rect2(gloss_pos, gloss_size), Color(1, 1, 1, 0.22), gloss_size.y * 0.5)
	else:
		Juice.rounded_rect(self, rect, Color(Palette.SURFACE, alpha), 18.0)

	var pip_r := 8.0
	var pip_offset := DIE_SIZE * 0.24
	for p in PIP_LAYOUTS.get(value, []):
		var pip_pos := Vector2(p.x * pip_offset * squash.x, p.y * pip_offset * squash.y)
		draw_circle(pip_pos, pip_r, Color(Palette.INK, alpha))
		if full:
			draw_circle(pip_pos + Vector2(-pip_r * 0.3, -pip_r * 0.3), pip_r * 0.28, Color(1, 1, 1, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
