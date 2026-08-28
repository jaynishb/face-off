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

func _ready() -> void:
	layer = 50
	_label = get_node_or_null(label_path)
	if not _label:
		_build_ui()
	visible = false

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.25)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_CENTER)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 96)
	_label.add_theme_color_override("font_color", Palette.INK)
	_label.pivot_offset = Vector2(60, 60)
	add_child(_label)

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
	if _label:
		_label.text = text
		# Overshoot pop per motion rules: scale 1.3 -> 1.0 on each tick.
		_label.scale = Vector2(1.3, 1.3)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(_label, "scale", Vector2.ONE, 0.25)
