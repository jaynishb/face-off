extends CanvasLayer
class_name DiceCountPrompt
## A disposable pre-launch prompt for Dice Roller's dice count -- same
## CanvasLayer/dim/soft-card/queue_free() shape as RulesCard, shown by
## PartyGameSelect right before entering PartyHost so the count is settled
## before the group starts playing instead of via an in-game stepper.

const MIN_DICE := 1
const MAX_DICE := 6

signal confirmed(count: int)

var _count := 2
var _count_label: Label

func _ready() -> void:
	layer = 60

func show_prompt(initial_count: int) -> void:
	_count = clampi(initial_count, MIN_DICE, MAX_DICE)

	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	dim.create_tween().tween_property(dim, "color", Color(Palette.INK, 0.45), 0.2)

	var card := PanelContainer.new()
	var style := UIUtil.soft_panel_style(Palette.SURFACE, 28.0)
	style.set_content_margin_all(32)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(480, 300)
	card.position = Vector2(Field.mid_x() - 240, Field.NOMINAL_HEIGHT * 0.5 - 150)
	add_child(card)
	UIUtil.pop_in(card, 0.05)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	card.add_child(vbox)

	var title := UIUtil.make_label("HOW MANY DICE?", 30)
	vbox.add_child(title)

	var stepper := HBoxContainer.new()
	stepper.alignment = BoxContainer.ALIGNMENT_CENTER
	stepper.add_theme_constant_override("separation", 20)
	vbox.add_child(stepper)

	var minus_btn := UIUtil.make_soft_round_button("-", 56, Palette.SURFACE)
	minus_btn.pressed.connect(func(): _change_count(-1))
	stepper.add_child(minus_btn)

	_count_label = UIUtil.make_label(str(_count), 36)
	_count_label.custom_minimum_size = Vector2(80, 56)
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stepper.add_child(_count_label)

	var plus_btn := UIUtil.make_soft_round_button("+", 56, Palette.SURFACE)
	plus_btn.pressed.connect(func(): _change_count(1))
	stepper.add_child(plus_btn)

	var play_btn := UIUtil.make_soft_button("PLAY", 26, Palette.SUCCESS)
	play_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_btn.pressed.connect(_on_confirm)
	vbox.add_child(play_btn)

	var back_btn := UIUtil.make_soft_round_button("<", 56, Palette.SURFACE)
	back_btn.position = Vector2(24, 24)
	back_btn.pressed.connect(_on_cancel)
	add_child(back_btn)

func _change_count(delta: int) -> void:
	_count = clampi(_count + delta, MIN_DICE, MAX_DICE)
	_count_label.text = str(_count)
	UIUtil.punch(_count_label)

func _on_confirm() -> void:
	confirmed.emit(_count)
	queue_free()

## No signal on cancel -- PartyGameSelect just stays on the tile grid,
## same as backing out of RulesCard without playing.
func _on_cancel() -> void:
	queue_free()
