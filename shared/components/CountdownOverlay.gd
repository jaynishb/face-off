extends CanvasLayer
class_name CountdownOverlay
## Universal 3-2-1 countdown shown before every match. GameManager (or the
## scene hosting the current MiniGame) plays this, then calls start_match()
## on the loaded game once countdown_finished fires.

signal countdown_finished

@export var label_path: NodePath
@export var count_from: int = 3
@export var tick_seconds: float = 0.8

var _label: Label
## One label per half. A single centred "3" is upside down for one of the two
## players on a shared portrait phone, so the count is drawn twice -- see
## UIUtil.mirror_for_players.
var _labels: Array[Label] = []

func _ready() -> void:
	layer = 50
	_label = get_node_or_null(label_path)
	if not _label:
		_build_ui()
	else:
		_labels = [_label]
	visible = false

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.25)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	UIUtil.mirror_for_players(self, func(_player: int) -> Control:
		var half := Field.half_size()
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 96)
		label.add_theme_color_override("font_color", Palette.INK)
		label.size = Vector2(half.x, 120)
		label.position = Vector2(0, half.y * 0.5 - 60.0)
		label.pivot_offset = label.size * 0.5
		_labels.append(label)
		return label
	)
	_label = _labels[0] if not _labels.is_empty() else null

func play() -> void:
	visible = true
	var count := count_from
	while count > 0:
		_set_text(str(count))
		AudioManager.play_sfx("countdown_tick")
		await get_tree().create_timer(tick_seconds).timeout
		count -= 1
	_set_text("GO!")
	AudioManager.play_sfx("countdown_go")
	await get_tree().create_timer(tick_seconds * 0.5).timeout
	visible = false
	countdown_finished.emit()

func _set_text(text: String) -> void:
	for label in _labels:
		label.text = text
		# Overshoot pop per motion rules: scale 1.3 -> 1.0 on each tick. Only
		# `scale` is tweened, never `rotation` -- the P2 copy's PI comes from its
		# mount and must survive every animation.
		label.scale = Vector2(1.3, 1.3)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "scale", Vector2.ONE, 0.25)
