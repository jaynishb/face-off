extends Control
## Party Game Select — the group-play equivalent of GameSelect. One soft,
## shadowed tile per party game, each with its own [?] rules button. Tapping
## a tile the first time auto-opens the rules card before starting;
## subsequent taps launch straight in. Deliberately separate from GameSelect/
## GameManager -- Party Mode games have no score/winner, so they get their
## own registry (PartyManager) rather than reusing the 1v1 one.

func _ready() -> void:
	UIUtil.gradient_bg(self, Palette.GRADIENT_PARTY_TOP, Palette.GRADIENT_PARTY_BOTTOM)
	AudioManager.play_menu_music()

	var back_btn := UIUtil.make_soft_round_button("<", 64, Palette.SURFACE)
	back_btn.position = Vector2(24, 24)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://shell/main_menu/MainMenu.tscn"))
	add_child(back_btn)

	var title := UIUtil.make_label("PARTY MODE", 40)
	title.position = Vector2(0, 24)
	title.size = Vector2(Field.width(), 60)
	add_child(title)

	var subtitle := UIUtil.make_label("Pass the phone around the group.", 20)
	subtitle.position = Vector2(0, 84)
	subtitle.size = Vector2(Field.width(), 32)
	add_child(subtitle)

	# Centred on the real visible rect, not a fixed 1280-wide box, so the tile
	# grid doesn't sit left of centre on a wider-than-16:9 screen (Field.gd).
	var grid_width := 3 * 360.0 + 2 * 24.0
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(Field.mid_x() - grid_width * 0.5, 150)
	scroll.size = Vector2(grid_width, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	scroll.add_child(grid)

	var index := 0
	for game_id in PartyManager.get_roster():
		var tile := _build_tile(game_id)
		grid.add_child(tile)
		UIUtil.pop_in(tile, index * 0.06)
		index += 1

func _build_tile(game_id: String) -> Control:
	var meta := PartyManager.get_party_game_meta(game_id)

	var tile := Control.new()
	tile.custom_minimum_size = Vector2(360, 220)

	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", UIUtil.soft_panel_style(Palette.SURFACE, 24.0))
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	tile.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	tile.add_child(vbox)

	var icon := TextureRect.new()
	icon.texture = load(meta.get("icon", ""))
	icon.custom_minimum_size = Vector2(72, 72)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.pivot_offset = Vector2(36, 36)
	vbox.add_child(icon)
	UIUtil.idle_wobble(icon, randf() * 0.6)

	var name_label := UIUtil.make_label(meta.get("display_name", game_id), 24)
	vbox.add_child(name_label)

	var built := ResourceLoader.exists(meta.get("scene", ""))

	var play_btn := UIUtil.make_soft_button("PLAY" if built else "SOON", 22, Palette.PARTY_PRIMARY if built else Palette.SURFACE)
	if built:
		play_btn.add_theme_color_override("font_color", Palette.SURFACE)
		play_btn.add_theme_color_override("font_hover_color", Palette.SURFACE)
		play_btn.add_theme_color_override("font_pressed_color", Palette.SURFACE)
	play_btn.custom_minimum_size = Vector2(180, 64)
	play_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_btn.disabled = not built
	play_btn.pressed.connect(func(): _on_tile_pressed(game_id))
	vbox.add_child(play_btn)

	var rules_btn := UIUtil.make_soft_round_button("?", 40, Palette.SURFACE)
	rules_btn.position = Vector2(360 - 56, 8)
	rules_btn.pressed.connect(func(): _show_rules(game_id))
	tile.add_child(rules_btn)

	return tile

func _on_tile_pressed(game_id: String) -> void:
	if not SaveManager.has_seen_party_rules(game_id):
		var card := RulesCard.new()
		add_child(card)
		var meta := PartyManager.get_party_game_meta(game_id)
		card.show_rules(meta.get("display_name", game_id), meta.get("rules_text", ""), meta.get("icon", ""))
		SaveManager.mark_party_rules_seen(game_id)
		card.dismissed.connect(func(): _launch(game_id))
	else:
		_launch(game_id)

func _show_rules(game_id: String) -> void:
	var card := RulesCard.new()
	add_child(card)
	var meta := PartyManager.get_party_game_meta(game_id)
	card.show_rules(meta.get("display_name", game_id), meta.get("rules_text", ""), meta.get("icon", ""))

func _launch(game_id: String) -> void:
	PartyManager.pending_game_id = game_id
	get_tree().change_scene_to_file("res://shell/party_host/PartyHost.tscn")
