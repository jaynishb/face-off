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

## mirrored draws one card per half, each facing its own player -- for anywhere
## two players are both looking at the phone (in-match). Left false for Game
## Select, where one person is browsing and a single upright card is correct.
func show_rules(display_name: String, rules_text: String, icon_path: String = "", mirrored: bool = false) -> void:
	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var dim_tween := dim.create_tween()
	dim_tween.tween_property(dim, "color", Color(Palette.INK, 0.45), 0.2)

	if mirrored:
		UIUtil.mirror_for_players(self, func(_player: int) -> Control:
			var half := Field.half_size()
			var holder := Control.new()
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.size = half
			var c := _build_card(display_name, rules_text, icon_path)
			var w: float = minf(half.x - 40.0, 560.0)
			c.custom_minimum_size = Vector2(w, half.y * 0.72)
			c.position = Vector2((half.x - w) * 0.5, half.y * 0.12)
			holder.add_child(c)
			UIUtil.pop_in(c, 0.05)
			return holder
		)
	else:
		var card := _build_card(display_name, rules_text, icon_path)
		var w: float = minf(Field.width() - 48.0, 600.0)
		var h: float = minf(Field.height() * 0.56, 520.0)
		card.custom_minimum_size = Vector2(w, h)
		card.position = Vector2((Field.width() - w) * 0.5, (Field.height() - h) * 0.5)
		add_child(card)
		UIUtil.pop_in(card, 0.05)

		var close_btn := UIUtil.make_button("X", 22, Palette.SURFACE)
		close_btn.custom_minimum_size = Vector2(56, 56)
		close_btn.position = Vector2(Field.width() - 80, Field.SAFE_OUTER + 12)
		close_btn.pressed.connect(_on_dismiss)
		add_child(close_btn)

func _build_card(display_name: String, rules_text: String, icon_path: String) -> PanelContainer:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.SURFACE
	style.set_corner_radius_all(28)
	style.set_content_margin_all(28)
	style.border_color = Palette.OUTLINE
	style.set_border_width_all(4)
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	card.add_child(vbox)

	var title := UIUtil.make_label(display_name.to_upper(), 34)
	vbox.add_child(title)

	var diagram := ColorRect.new()
	diagram.color = Palette.BACKGROUND
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

	var got_it := UIUtil.make_button("GOT IT!", 26, Palette.SUCCESS)
	got_it.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	got_it.pressed.connect(_on_dismiss)
	vbox.add_child(got_it)

	return card

func _on_dismiss() -> void:
	dismissed.emit()
	queue_free()
