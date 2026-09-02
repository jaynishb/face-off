extends Control
## Game Select — one soft, shadowed tile per launch-roster game, each with
## its own [?] rules button. Tapping a tile the first time auto-opens the
## rules card before starting; subsequent taps launch straight in.

func _ready() -> void:
	UIUtil.gradient_bg(self, Palette.GRADIENT_SELECT_TOP, Palette.GRADIENT_SELECT_BOTTOM)
	AudioManager.play_menu_music()

	var back_btn := UIUtil.make_soft_round_button("<", 64, Palette.SURFACE)
	back_btn.position = Vector2(24, 24)
	back_btn.pressed.connect(func(): UIUtil.fade_to_scene(get_tree(), "res://shell/main_menu/MainMenu.tscn"))
	add_child(back_btn)

	var title := UIUtil.make_label("CHOOSE A GAME", 40)
	title.position = Vector2(0, 24)
	title.size = Vector2(Field.width(), 60)
	add_child(title)

	# Centred on the real visible rect, not a fixed 1280-wide box, so the tile
	# grid doesn't sit left of centre on a wider-than-16:9 screen (Field.gd).
	var grid_width := 3 * 360.0 + 2 * 24.0
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(Field.mid_x() - grid_width * 0.5, 140)
	scroll.size = Vector2(grid_width, 520)
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
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

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

	# Games not yet built (later PRD build-order days) render as a disabled
	# "Coming Soon" tile instead of a PLAY button that would fail to load —
	# this self-corrects with no code change once the scene file lands.
	var built := ResourceLoader.exists(meta.get("scene", ""))

	var badge := UIUtil.make_badge("PLAY" if built else "SOON", Palette.ACCENT if built else Palette.SURFACE, Palette.INK)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(badge)

	var rules_btn := UIUtil.make_soft_round_button("?", 40, Palette.SURFACE)
	rules_btn.position = Vector2(360 - 56, 8)
	rules_btn.pressed.connect(func(): _show_rules(game_id))
	tile.add_child(rules_btn)

	# The whole tile is the tap target, not just the PLAY badge above -- a
	# smaller hit area than the visible box the player already tapped to look
	# at is an extra, unnecessary tap on mobile. Only InputEventScreenTouch,
	# not InputEventMouseButton: project.godot has emulate_touch_from_mouse=
	# true, so a single click/tap delivers both a native mouse event and a
	# synthetic touch event, and reacting to both would double-fire this.
	if built:
		tile.gui_input.connect(func(event: InputEvent):
			if event is InputEventScreenTouch and event.pressed:
				UIUtil.punch(tile)
				_on_tile_pressed(game_id)
		)

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
	UIUtil.fade_to_scene(get_tree(), "res://shell/match_host/MatchHost.tscn")
