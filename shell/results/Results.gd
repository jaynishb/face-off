extends Control
## Results — shown after every match (post-interstitial, if one fired).
## REMATCH is the single most important conversion point in the app: it must be
## the biggest, brightest button on the screen (PRD 7.5).
##
## Both players just finished a match on a phone lying between them, and either
## one might reach for REMATCH — so the whole panel is drawn once per half, with
## Player 2's copy rotated by PI. Both copies drive the same handlers.

func _ready() -> void:
	UIUtil.full_rect_bg(self, Palette.BACKGROUND)
	AudioManager.play_menu_music()
	UIUtil.mirror_for_players(self, _build_panel)

## Built in PLAYER space: (0,0) is this player's own top-left, extending to
## Field.half_size().
func _build_panel(_player: int) -> Control:
	var half := Field.half_size()
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = half

	var winner: int = GameManager.last_winner
	var title_text := "DRAW!" if winner == 0 else "PLAYER %d WINS!" % winner
	var title_color: Color = Palette.ACCENT if winner == 0 else Palette.for_player(winner)

	var title := UIUtil.make_label(title_text, 44, title_color)
	title.position = Vector2(0, half.y * 0.18)
	title.size = Vector2(half.x, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var tally := GameManager.get_session_tally(GameManager.current_game_id)
	var tally_label := UIUtil.make_label(
		"Today:  P1 %d - %d P2" % [tally.get("p1_wins", 0), tally.get("p2_wins", 0)], 24
	)
	tally_label.position = Vector2(0, half.y * 0.18 + 74)
	tally_label.size = Vector2(half.x, 40)
	tally_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(tally_label)

	var rematch_size := Vector2(minf(half.x - 80, 420), 116)
	var rematch_btn := UIUtil.make_button("REMATCH", 36, Palette.SUCCESS)
	rematch_btn.custom_minimum_size = rematch_size
	rematch_btn.size = rematch_size
	rematch_btn.position = Vector2((half.x - rematch_size.x) * 0.5, half.y * 0.44)
	rematch_btn.pressed.connect(_on_rematch_pressed)
	root.add_child(rematch_btn)

	var menu_size := Vector2(minf(half.x - 220, 260), 74)
	var menu_btn := UIUtil.make_button("MENU", 26, Palette.SURFACE)
	menu_btn.custom_minimum_size = menu_size
	menu_btn.size = menu_size
	menu_btn.position = Vector2((half.x - menu_size.x) * 0.5, half.y * 0.44 + rematch_size.y + 22)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://shell/main_menu/MainMenu.tscn"))
	root.add_child(menu_btn)

	return root

func _on_rematch_pressed() -> void:
	GameManager.pending_game_id = GameManager.current_game_id
	get_tree().change_scene_to_file("res://shell/match_host/MatchHost.tscn")
