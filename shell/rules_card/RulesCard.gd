extends CanvasLayer
class_name RulesCard
## Generic rules card, populated per game from GameManager.GAME_REGISTRY
## metadata (display_name + rules_text). Reachable from: the [?] on a game
## tile, auto-shown on first play of a game, and (later) a [?] in the pause
## menu. One class, never game-specific logic.
##
## Max three short lines of text — if a game's rules_text needs more, the
## game design is wrong, not this card (see CLAUDE.md).

signal dismissed

func _ready() -> void:
	layer = 60

func show_rules(display_name: String, rules_text: String) -> void:
	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.SURFACE
	style.set_corner_radius_all(28)
	style.set_content_margin_all(32)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(640, 420)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(640 - 320, 360 - 210)
	add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	card.add_child(vbox)

	var title := UIUtil.make_label(display_name.to_upper(), 40)
	vbox.add_child(title)

	var diagram := ColorRect.new()
	diagram.color = Palette.BACKGROUND
	diagram.custom_minimum_size = Vector2(0, 140)
	vbox.add_child(diagram)
	var diagram_hint := UIUtil.make_label("[diagram]", 16, Palette.INK)
	diagram_hint.modulate.a = 0.4
	diagram.add_child(diagram_hint)
	diagram_hint.set_anchors_preset(Control.PRESET_CENTER)

	var rules_label := UIUtil.make_label(rules_text, 22)
	rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(rules_label)

	var got_it := UIUtil.make_button("GOT IT!  ▶", 26, Palette.SUCCESS)
	got_it.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	got_it.pressed.connect(_on_dismiss)
	vbox.add_child(got_it)

	var close_btn := UIUtil.make_button("✕", 22, Palette.SURFACE)
	close_btn.custom_minimum_size = Vector2(56, 56)
	close_btn.position = Vector2(1280 - 80, 24)
	close_btn.pressed.connect(_on_dismiss)
	add_child(close_btn)

func _on_dismiss() -> void:
	dismissed.emit()
	queue_free()
