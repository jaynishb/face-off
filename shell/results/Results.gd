extends Control
## Results — shown after every match (post-interstitial, if one fired).
## REMATCH is the single most important conversion point in the app: it must
## be the biggest, brightest button on the screen (PRD 7.5).

func _ready() -> void:
	UIUtil.gradient_bg(self, Palette.GRADIENT_RESULTS_TOP, Palette.GRADIENT_RESULTS_BOTTOM)
	AudioManager.play_menu_music()

	# Vertically centers the whole content block in portrait instead of
	# leaving it pinned to the top with empty space below -- see
	# Field.shell_top_offset(). 0 in landscape, so no change there.
	var y := Field.shell_top_offset()

	var winner: int = GameManager.last_winner
	var title_text := "DRAW!" if winner == 0 else "PLAYER %d WINS!" % winner
	var title_color := Palette.ACCENT if winner == 0 else Palette.for_player(winner)

	var title := UIUtil.make_label(title_text, 56, title_color)
	title.position = Vector2(0, 100 + y)
	title.size = Vector2(Field.width(), 80)
	add_child(title)

	var tally := GameManager.get_session_tally(GameManager.current_game_id)
	var tally_card := Panel.new()
	tally_card.add_theme_stylebox_override("panel", UIUtil.soft_panel_style(Palette.SURFACE, 24.0))
	tally_card.custom_minimum_size = Vector2(360, 56)
	tally_card.position = Vector2(Field.mid_x() - 180, 210 + y)
	add_child(tally_card)

	var tally_label := UIUtil.make_label(
		"Today:  P1 %d — %d P2" % [tally.get("p1_wins", 0), tally.get("p2_wins", 0)], 26
	)
	tally_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	tally_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tally_card.add_child(tally_label)

	var rematch_btn := UIUtil.make_soft_button("REMATCH", 40, Palette.SUCCESS)
	rematch_btn.custom_minimum_size = Vector2(440, 140)
	rematch_btn.position = Vector2(Field.mid_x() - 380, 420 + y)
	rematch_btn.pressed.connect(_on_rematch_pressed)
	add_child(rematch_btn)

	var menu_btn := UIUtil.make_soft_button("MENU", 32, Palette.SURFACE)
	menu_btn.custom_minimum_size = Vector2(280, 100)
	menu_btn.position = Vector2(Field.mid_x() + 100, 440 + y)
	menu_btn.pressed.connect(func(): UIUtil.fade_to_scene(get_tree(), "res://shell/main_menu/MainMenu.tscn"))
	add_child(menu_btn)

func _on_rematch_pressed() -> void:
	GameManager.pending_game_id = GameManager.current_game_id
	UIUtil.fade_to_scene(get_tree(), "res://shell/match_host/MatchHost.tscn")
