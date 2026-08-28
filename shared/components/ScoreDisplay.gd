extends Control
class_name ScoreDisplay
## Thin score bar segment for one player's side. In-game layout places one
## instance on each side of the pause button (see PRD 7.4), colored via
## Palette.for_player(). Mirror any layout change for both instances.

@export var player: int = 1
@export var label_path: NodePath

var _label: Label
var _score: int = 0

func _ready() -> void:
	_label = get_node_or_null(label_path)
	_apply_color()
	_refresh()

func _apply_color() -> void:
	if _label:
		_label.add_theme_color_override("font_color", Palette.for_player(player))

func set_score(value: int) -> void:
	_score = value
	_refresh()
	_pop()

func increment() -> void:
	set_score(_score + 1)

func _refresh() -> void:
	if _label:
		_label.text = str(_score)

func _pop() -> void:
	if not _label:
		return
	_label.scale = Vector2(1.3, 1.3)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_label, "scale", Vector2.ONE, 0.25)
