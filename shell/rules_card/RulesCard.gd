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

func show_rules(display_name: String, rules_text: String, icon_path: String = "") -> void:
	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var dim_tween := dim.create_tween()
	dim_tween.tween_property(dim, "color", Color(Palette.INK, 0.45), 0.2)

	var card := PanelContainer.new()
	var style := UIUtil.soft_panel_style(Palette.SURFACE, 28.0)
	style.set_content_margin_all(32)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(640, 420)
	card.position = Vector2(Field.mid_x() - 320, Field.NOMINAL_HEIGHT * 0.5 - 210)
	add_child(card)
	UIUtil.pop_in(card, 0.05)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	card.add_child(vbox)

	var title := UIUtil.make_label(display_name.to_upper(), 40)
	vbox.add_child(title)

	var diagram := Panel.new()
	diagram.add_theme_stylebox_override("panel", UIUtil.soft_panel_style(Palette.GRADIENT_RULES_TOP, 20.0))
	diagram.custom_minimum_size = Vector2(0, 140)
	vbox.add_child(diagram)

	if icon_path != "" and ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.custom_minimum_size = Vector2(96, 96)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.pivot_offset = Vector2(48, 48)
		diagram.add_child(icon)
		icon.set_anchors_preset(Control.PRESET_CENTER) # no manual .position alongside this -- see CLAUDE.md
		UIUtil.idle_float(icon, 6.0, 1.1)

	var rules_label := UIUtil.make_label(rules_text, 22)
	rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(rules_label)

	var got_it := UIUtil.make_soft_button("GOT IT!", 26, Palette.SUCCESS)
	got_it.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	got_it.pressed.connect(_on_dismiss)
	vbox.add_child(got_it)

	var close_btn := UIUtil.make_soft_round_button("X", 56, Palette.SURFACE)
	close_btn.position = Vector2(Field.width() - 80, 24)
	close_btn.pressed.connect(_on_dismiss)
	add_child(close_btn)

func _on_dismiss() -> void:
	dismissed.emit()
	queue_free()
