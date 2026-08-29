extends Control
## Results — shown after every match (post-interstitial, if one fired).
## REMATCH is the single most important conversion point in the app: it must
## be the biggest, brightest button on the screen (PRD 7.5).

func _ready() -> void:
	UIUtil.full_rect_bg(self, Palette.BACKGROUND)
	AudioManager.play_menu_music()

	var winner: int = GameManager.last_winner
	var title_text := "DRAW!" if winner == 0 else "PLAYER %d WINS!" % winner
	var title_color := Palette.ACCENT if winner == 0 else Palette.for_player(winner)

	var title := UIUtil.make_label(title_text, 56, title_color)
	title.position = Vector2(0, 100)
	title.size = Vector2(Field.width(), 80)
	add_child(title)

	var tally := GameManager.get_session_tally(GameManager.current_game_id)
	var tally_label := UIUtil.make_label(
		"Today:  P1 %d — %d P2" % [tally.get("p1_wins", 0), tally.get("p2_wins", 0)], 26
	)
	tally_label.position = Vector2(0, 220)
	tally_label.size = Vector2(Field.width(), 40)
	add_child(tally_label)

	var rematch_btn := UIUtil.make_button("REMATCH", 40, Palette.SUCCESS)
	rematch_btn.custom_minimum_size = Vector2(440, 140)
	rematch_btn.position = Vector2(Field.mid_x() - 460, 420)
	rematch_btn.pressed.connect(_on_rematch_pressed)
	add_child(rematch_btn)

	var menu_btn := UIUtil.make_button("MENU", 32, Palette.SURFACE)
	menu_btn.custom_minimum_size = Vector2(280, 100)
	menu_btn.position = Vector2(Field.mid_x() + 40, 440)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://shell/main_menu/MainMenu.tscn"))
	add_child(menu_btn)

func _on_rematch_pressed() -> void:
	GameManager.pending_game_id = GameManager.current_game_id
	get_tree().change_scene_to_file("res://shell/match_host/MatchHost.tscn")
