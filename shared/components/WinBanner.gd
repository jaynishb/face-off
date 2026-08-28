extends CanvasLayer
class_name WinBanner
## "PLAYER X WINS!" banner used on the Results screen. Populated with the
## winner's color/label; winner == 0 renders a draw state.

@export var title_label_path: NodePath

var _title_label: Label

func _ready() -> void:
	layer = 40
	_title_label = get_node_or_null(title_label_path)
	if not _title_label:
		_build_ui()
	visible = false

func _build_ui() -> void:
	_title_label = Label.new()
	_title_label.set_anchors_preset(Control.PRESET_CENTER)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 64)
	_title_label.pivot_offset = Vector2(160, 40)
	add_child(_title_label)

func show_winner(winner: int) -> void:
	visible = true
	if not _title_label:
		return

	if winner == 0:
		_title_label.text = "DRAW!"
		_title_label.add_theme_color_override("font_color", Palette.ACCENT)
	else:
		_title_label.text = "PLAYER %d WINS!" % winner
		_title_label.add_theme_color_override("font_color", Palette.for_player(winner))

	_title_label.scale = Vector2(0.5, 0.5)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_title_label, "scale", Vector2.ONE, 0.35)
