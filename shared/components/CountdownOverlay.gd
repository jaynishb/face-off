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
	_label = get_node_or_null(label_path)
	visible = false

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
