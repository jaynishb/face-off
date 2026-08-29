extends Control
## Game Select — chunky tiles, one per launch-roster game, each with its own
## [?] rules button. Tapping a tile the first time auto-opens the rules card
## before starting; subsequent taps launch straight in.

func _ready() -> void:
	UIUtil.full_rect_bg(self, Palette.BACKGROUND)
	AudioManager.play_menu_music()

	var back_btn := UIUtil.make_button("<", 28, Palette.SURFACE)
	back_btn.custom_minimum_size = Vector2(64, 64)
	back_btn.position = Vector2(24, 24)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://shell/main_menu/MainMenu.tscn"))
	add_child(back_btn)

	var title := UIUtil.make_label("CHOOSE A GAME", 40)
	title.position = Vector2(0, 24)
	title.size = Vector2(1280, 60)
	add_child(title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(40, 140)
	scroll.size = Vector2(1200, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	scroll.add_child(grid)

	var index := 0
	for game_id in GameManager.get_roster():
		var tile := _build_tile(game_id)
		grid.add_child(tile)
		UIUtil.pop_in(tile, index * 0.06)
		index += 1

func _build_tile(game_id: String) -> Control:
	var meta := GameManager.get_game_meta(game_id)

	# Plain Control root (not a Container) so the background panel and the
	# corner [?] button can both be positioned freely without a Container
	# forcing every direct child to the same rect.
	var tile := Control.new()
	tile.custom_minimum_size = Vector2(360, 220)

	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.SURFACE
	style.set_corner_radius_all(24)
	panel.add_theme_stylebox_override("panel", style)
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

	# Games not yet built (later PRD build-order days) render as a disabled
	# "Coming Soon" tile instead of a PLAY button that would fail to load —
	# this self-corrects with no code change once the scene file lands.
	var built := ResourceLoader.exists(meta.get("scene", ""))

	var play_btn := UIUtil.make_button("PLAY" if built else "SOON", 22, Palette.ACCENT if built else Palette.SURFACE)
	play_btn.custom_minimum_size = Vector2(180, 64)
	play_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_btn.disabled = not built
	play_btn.pressed.connect(func(): _on_tile_pressed(game_id))
	vbox.add_child(play_btn)

	var rules_btn := UIUtil.make_button("?", 20, Palette.SURFACE)
	rules_btn.custom_minimum_size = Vector2(40, 40)
	rules_btn.position = Vector2(360 - 56, 8)
	rules_btn.pressed.connect(func(): _show_rules(game_id))
	tile.add_child(rules_btn)

	return tile

func _on_tile_pressed(game_id: String) -> void:
	if not SaveManager.has_seen_rules(game_id):
		var card := RulesCard.new()
		add_child(card)
		var meta := GameManager.get_game_meta(game_id)
		card.show_rules(meta.get("display_name", game_id), meta.get("rules_text", ""), meta.get("icon", ""))
		SaveManager.mark_rules_seen(game_id)
		card.dismissed.connect(func(): _launch(game_id))
	else:
		_launch(game_id)

func _show_rules(game_id: String) -> void:
	var card := RulesCard.new()
	add_child(card)
	var meta := GameManager.get_game_meta(game_id)
	card.show_rules(meta.get("display_name", game_id), meta.get("rules_text", ""), meta.get("icon", ""))

func _launch(game_id: String) -> void:
	GameManager.pending_game_id = game_id
	get_tree().change_scene_to_file("res://shell/match_host/MatchHost.tscn")
