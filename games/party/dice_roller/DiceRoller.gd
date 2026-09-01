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
const TUMBLE_FLIP_INTERVAL := 0.07

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

var _dice: Array[Die] = []
var _dice_count: int = 2
var _rolling_count := 0

var _count_label: Label
var _minus_btn: Button
var _plus_btn: Button
var _roll_btn: Button
var _total_label: Label

func _init() -> void:
	game_id = "dice_roller"
	display_name = "Dice Roller"
	rules_text = "Pick how many dice.\nTap ROLL.\nRead the total."
	theme_bg = Palette.BG_DICE_ROLLER

func setup(_config: Dictionary) -> void:
	_dice_count = clampi(SaveManager.party_dice_count, MIN_DICE, MAX_DICE)
	_rebuild_dice()
	set_process(true)

	var stepper_label := UIUtil.make_label("DICE", 18)
	stepper_label.name = "stepper_label"
	add_child(stepper_label)

	_minus_btn = UIUtil.make_soft_round_button("-", 48, Palette.SURFACE)
	_minus_btn.pressed.connect(func(): _change_count(-1))
	add_child(_minus_btn)

	_count_label = UIUtil.make_label(str(_dice_count), 28)
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_count_label)

	_plus_btn = UIUtil.make_soft_round_button("+", 48, Palette.SURFACE)
	_plus_btn.pressed.connect(func(): _change_count(1))
	add_child(_plus_btn)

	_roll_btn = UIUtil.make_soft_button("ROLL", 28, Palette.SUCCESS)
	_roll_btn.pressed.connect(_on_roll_pressed)
	add_child(_roll_btn)

	_total_label = UIUtil.make_label("TOTAL: %d" % _current_total(), 24)
	add_child(_total_label)

	_stepper_label_ref = stepper_label
	layout()

var _stepper_label_ref: Label

func layout() -> void:
	if not _roll_btn:
		return
	var mid := Field.mid_x()
	var top := Field.top() + 20.0

	_stepper_label_ref.position = Vector2(mid - 90, top)
	_minus_btn.position = Vector2(mid - 100, top + 26)
	_count_label.position = Vector2(mid - 52, top + 26)
	_count_label.size = Vector2(104, 48)
	_plus_btn.position = Vector2(mid + 52, top + 26)

	_roll_btn.position = Vector2(mid - 140, top + 96)
	_total_label.position = Vector2(mid - 80, top + 200)

	_layout_dice()

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

func _change_count(delta: int) -> void:
	_dice_count = clampi(_dice_count + delta, MIN_DICE, MAX_DICE)
	SaveManager.set_party_dice_count(_dice_count)
	_count_label.text = str(_dice_count)
	UIUtil.punch(_count_label)
	_rebuild_dice()

func _current_total() -> int:
	var total := 0
	for d in _dice:
		total += d.value
	return total

func _on_roll_pressed() -> void:
	if _rolling_count > 0:
		return
	_rolling_count = _dice.size()
	for d in _dice:
		d.rolling = true
		d.start_delay = randf_range(0.0, 0.15)
		d.tumble_time_left = randf_range(0.4, 0.6)
		d.flip_timer = 0.0
	AudioManager.play_sfx("tap")

func _process(delta: float) -> void:
	for d in _dice:
		if d.rolling:
			if d.start_delay > 0.0:
				d.start_delay -= delta
				continue
			d.tumble_time_left -= delta
			d.flip_timer -= delta
			if d.flip_timer <= 0.0:
				d.flip_timer = TUMBLE_FLIP_INTERVAL
				d.value = randi_range(1, 6)
				d.squash = Vector2(1.12, 0.88) if d.value % 2 == 0 else Vector2(0.88, 1.12)
			if d.tumble_time_left <= 0.0:
				d.rolling = false
				d.value = randi_range(1, 6)
				d.squash = Vector2(1.35, 0.65)
				_rolling_count -= 1
				if _rolling_count <= 0:
					_on_all_landed()
		else:
			d.squash = Juice.decay_squash(d.squash, delta)

	_total_label.text = "TOTAL: %d" % _current_total()
	queue_redraw()

func _on_all_landed() -> void:
	AudioManager.play_sfx("drop")
	if SaveManager.haptics_enabled:
		Input.vibrate_handheld(30)

func _draw() -> void:
	var y := Field.top() + 340.0
	for d in _dice:
		_draw_die(Vector2(d.x, y), d.value, d.squash)

func _draw_die(center: Vector2, value: int, squash: Vector2) -> void:
	var half := DIE_SIZE * 0.5
	var rect := Rect2(center - Vector2(half, half) * squash, Vector2(DIE_SIZE, DIE_SIZE) * squash)
	Juice.sticker_rect(self, rect, Palette.SURFACE, 18.0, 5.0)

	var pip_r := 8.0
	var pip_offset := DIE_SIZE * 0.24
	for p in PIP_LAYOUTS.get(value, []):
		var pip_pos := center + Vector2(p.x * pip_offset * squash.x, p.y * pip_offset * squash.y)
		draw_circle(pip_pos, pip_r, Palette.INK)
