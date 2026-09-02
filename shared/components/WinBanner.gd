extends CanvasLayer
class_name WinBanner
## "PLAYER X WINS!" banner used on the Results screen. Populated with the
## winner's color/label; winner == 0 renders a draw state.

@export var title_label_path: NodePath

var _title_label: Label
## One banner per half. The win is the emotional peak of a match -- having half
## the audience read it upside down is the worst possible place to save a node.
var _labels: Array[Label] = []

func _ready() -> void:
	layer = 40
	_title_label = get_node_or_null(title_label_path)
	if not _title_label:
		_build_ui()
	else:
		_labels = [_title_label]
	visible = false

func _build_ui() -> void:
	UIUtil.mirror_for_players(self, func(_player: int) -> Control:
		var half := Field.half_size()
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 56)
		label.size = Vector2(half.x, 80)
		label.position = Vector2(0, half.y * 0.5 - 40.0)
		label.pivot_offset = label.size * 0.5
		_labels.append(label)
		return label
	)
	_title_label = _labels[0] if not _labels.is_empty() else null

func show_winner(winner: int) -> void:
	visible = true
	var text := "DRAW!" if winner == 0 else "PLAYER %d WINS!" % winner
	var color: Color = Palette.ACCENT if winner == 0 else Palette.for_player(winner)

	for label in _labels:
		label.text = text
		label.add_theme_color_override("font_color", color)
		label.scale = Vector2(0.5, 0.5)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "scale", Vector2.ONE, 0.35)
