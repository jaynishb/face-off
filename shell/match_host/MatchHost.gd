extends Control
## MatchHost — the universal in-game frame (PRD 7.4). Owns the score bar,
## pause button, midline divider, and the 3-2-1 countdown; the game itself
## only knows its own play area. Never contains game-specific branches —
## everything it needs comes through the MiniGame contract.

var _game: MiniGame
var _p1_score_label: Label
var _p2_score_label: Label
var _paused_overlay: CanvasLayer

func _ready() -> void:
	# A plain Control's default mouse_filter (STOP) swallows every tap over
	# its full rect before it can ever reach InputManager's _unhandled_input,
	# even with no _gui_input override -- that's Godot's documented behavior
	# for MOUSE_FILTER_STOP. MatchHost covers the whole screen, so left at
	# the default it silently blocks all gameplay touches. IGNORE here lets
	# touches fall through to InputManager; interactive children (the pause
	# button) still get their own clicks since they hit-test independently
	# with their own (STOP) filter. Caught by a real phone reporting "no
	# controls" -- see CLAUDE.md.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIUtil.full_rect_bg(self, Palette.BACKGROUND)
	AudioManager.stop_music() # never music during a match -- see CLAUDE.md

	var game_id: String = GameManager.pending_game_id
	_game = GameManager.load_game(game_id)
	if not _game:
		get_tree().change_scene_to_file("res://shell/game_select/GameSelect.tscn")
		return

	InputManager.configure_zones([]) # reset any zone config left by a previous game
	add_child(_game)
	_game.setup({})
	_game.score_updated.connect(_on_score_updated)

	_build_score_bar()
	_build_midline()

	var countdown := CountdownOverlay.new()
	add_child(countdown)
	countdown.countdown_finished.connect(func(): _game.start_match())
	countdown.play()

	_game.match_ended.connect(_on_match_ended)

func _build_score_bar() -> void:
	var bar := Control.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size = Vector2(0, 64)
	add_child(bar)

	var bar_bg := ColorRect.new()
	bar_bg.color = Palette.SURFACE
	bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.add_child(bar_bg)

	_p1_score_label = UIUtil.make_label("P1  0", 28, Palette.PLAYER_1)
	_p1_score_label.position = Vector2(24, 16)
	bar.add_child(_p1_score_label)

	_p2_score_label = UIUtil.make_label("0  P2", 28, Palette.PLAYER_2)
	_p2_score_label.position = Vector2(1280 - 24 - 100, 16)
	bar.add_child(_p2_score_label)

	# Not SURFACE -- the score bar behind it is already SURFACE, so a SURFACE
	# button is invisible against it.
	var exit_btn := UIUtil.make_button("X", 22, Palette.PLAYER_1)
	exit_btn.custom_minimum_size = Vector2(48, 48)
	exit_btn.position = Vector2(640 - 24 - 56, 8)
	exit_btn.pressed.connect(_on_exit_pressed)
	bar.add_child(exit_btn)

	var pause_btn := UIUtil.make_button("II", 22, Palette.ACCENT)
	pause_btn.custom_minimum_size = Vector2(48, 48)
	pause_btn.position = Vector2(640 - 24, 8)
	pause_btn.pressed.connect(_on_pause_pressed)
	bar.add_child(pause_btn)

func _build_midline() -> void:
	var divider := ColorRect.new()
	divider.color = Color(Palette.INK, 0.15)
	divider.position = Vector2(638, 64)
	divider.size = Vector2(4, 720 - 64)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(divider)

func _on_score_updated(score_p1: int, score_p2: int) -> void:
	_p1_score_label.text = "P1  %d" % score_p1
	_p2_score_label.text = "%d  P2" % score_p2

func _on_pause_pressed() -> void:
	if _paused_overlay:
		return
	get_tree().paused = true
	_paused_overlay = CanvasLayer.new()
	_paused_overlay.layer = 45
	add_child(_paused_overlay)

	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_paused_overlay.add_child(dim)

	var resume_btn := UIUtil.make_button("RESUME", 28, Palette.SUCCESS)
	resume_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	resume_btn.position = Vector2(640 - 140, 300)
	resume_btn.pressed.connect(_on_resume_pressed)
	_paused_overlay.add_child(resume_btn)

	var menu_btn := UIUtil.make_button("MENU", 24, Palette.SURFACE)
	menu_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_btn.position = Vector2(640 - 140, 420)
	menu_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://shell/main_menu/MainMenu.tscn")
	)
	_paused_overlay.add_child(menu_btn)

## A dedicated, always-visible exit -- separate from Pause -- so a player on
## the web build (no OS back button to rely on) has one direct tap to bail
## out of a match instead of having to discover it's hidden behind Pause.
func _on_exit_pressed() -> void:
	if _paused_overlay:
		return
	get_tree().paused = true
	_paused_overlay = CanvasLayer.new()
	_paused_overlay.layer = 45
	add_child(_paused_overlay)

	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_paused_overlay.add_child(dim)

	var prompt := UIUtil.make_label("Exit this match?", 32)
	prompt.position = Vector2(0, 240)
	prompt.size = Vector2(1280, 50)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.process_mode = Node.PROCESS_MODE_ALWAYS
	_paused_overlay.add_child(prompt)

	var confirm_btn := UIUtil.make_button("EXIT TO MENU", 24, Palette.PLAYER_1)
	confirm_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	confirm_btn.position = Vector2(640 - 140, 320)
	confirm_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://shell/main_menu/MainMenu.tscn")
	)
	_paused_overlay.add_child(confirm_btn)

	var cancel_btn := UIUtil.make_button("KEEP PLAYING", 24, Palette.SUCCESS)
	cancel_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	cancel_btn.position = Vector2(640 - 140, 440)
	cancel_btn.pressed.connect(_on_resume_pressed)
	_paused_overlay.add_child(cancel_btn)

func _on_resume_pressed() -> void:
	get_tree().paused = false
	if _paused_overlay:
		_paused_overlay.queue_free()
		_paused_overlay = null

func _on_match_ended(winner: int, _score_p1: int, _score_p2: int) -> void:
	if _game.score_updated.is_connected(_on_score_updated):
		_game.score_updated.disconnect(_on_score_updated)

	var win_banner := WinBanner.new()
	add_child(win_banner)
	win_banner.show_winner(winner)

	await get_tree().create_timer(1.2).timeout

	var ad_shown := AdManager.maybe_show_interstitial()
	if ad_shown:
		await AdManager.interstitial_dismissed
	get_tree().change_scene_to_file("res://shell/results/Results.tscn")
