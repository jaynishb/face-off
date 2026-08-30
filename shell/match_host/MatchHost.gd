extends Control
## MatchHost — the universal in-game frame (PRD 7.4). Owns the score bar,
## pause button, midline divider, and the 3-2-1 countdown; the game itself
## only knows its own play area. Never contains game-specific branches —
## everything it needs comes through the MiniGame contract.

var _game: MiniGame
var _p1_score_label: Label
var _p2_score_label: Label
var _paused_overlay: CanvasLayer
var _bg: ColorRect
var _bg_tween: Tween
var _exit_btn: Button
var _pause_btn: Button
var _divider: ColorRect

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
	_bg = UIUtil.full_rect_bg(self, Palette.BACKGROUND)
	AudioManager.stop_music() # never music during a match -- see CLAUDE.md

	var game_id: String = GameManager.pending_game_id
	_game = GameManager.load_game(game_id)
	if not _game:
		get_tree().change_scene_to_file("res://shell/game_select/GameSelect.tscn")
		return

	# Reset any input config left behind by a previous game, so a mode never
	# leaks across matches.
	InputManager.configure_zones([])
	InputManager.set_shared_board_turn(0)
	add_child(_game)
	_game.setup({})
	_game.score_updated.connect(_on_score_updated)
	_game.theme_changed.connect(_on_theme_changed)

	# The game owns its ground colour; the shell just paints it. No game_id
	# branching here -- it all arrives through the MiniGame contract.
	_bg.color = _game.theme_bg

	_build_score_bar()
	_build_midline()

	# A phone browser resizes the canvas after load (address bar collapsing,
	# orientation settling), so anything positioned once at _ready() is frozen
	# at first-frame dimensions -- that is what pushed the P2 score pill off
	# the right edge on a real device. Re-lay out the HUD and the game every
	# time the viewport actually changes.
	get_viewport().size_changed.connect(_relayout)
	_relayout()

	var countdown := CountdownOverlay.new()
	add_child(countdown)
	countdown.countdown_finished.connect(func(): _game.start_match())
	countdown.play()

	_game.match_ended.connect(_on_match_ended)

## Floating pills rather than a solid bar across the top: a bar forces one
## surface colour over every game's ground, while pills sit on any of them and
## leave the playfield uninterrupted.
func _build_score_bar() -> void:
	var bar := Control.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size = Vector2(0, Field.SCORE_BAR_HEIGHT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

	_p1_score_label = UIUtil.make_score_pill(1)
	_p1_score_label.position = Vector2(20, 8)
	bar.add_child(_p1_score_label)

	_p2_score_label = UIUtil.make_score_pill(2)
	bar.add_child(_p2_score_label)

	_exit_btn = UIUtil.make_round_button("X", 52, Palette.SURFACE)
	_exit_btn.pressed.connect(_on_exit_pressed)
	bar.add_child(_exit_btn)

	_pause_btn = UIUtil.make_round_button("II", 52, Palette.SURFACE)
	_pause_btn.pressed.connect(_on_pause_pressed)
	bar.add_child(_pause_btn)

func _build_midline() -> void:
	# A shared board is not split between the players, so drawing a divider
	# across it would misrepresent the game.
	if _game.shared_board:
		return
	_divider = ColorRect.new()
	_divider.color = Color(Palette.OUTLINE, 0.22)
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_divider)

## Single place where every screen-derived position is (re)computed, so the
## HUD and the game can never drift apart from the actual viewport.
func _relayout() -> void:
	var mid := Field.mid_x()

	_p2_score_label.position = Vector2(Field.width() - 20 - _p2_score_label.size.x, 8)
	_exit_btn.position = Vector2(mid - 26 - 60, 8)
	_pause_btn.position = Vector2(mid + 8, 8)

	if _divider:
		# Must sit exactly on Field.mid_x() -- this line is the promise the
		# input split makes to the players.
		_divider.position = Vector2(mid - 2, Field.SCORE_BAR_HEIGHT)
		_divider.size = Vector2(4, Field.height() - Field.SCORE_BAR_HEIGHT)

	if _game:
		_game.layout()

## Turn-based games retint the whole screen to whoever is on the clock. Tween
## rather than cut, so the change reads as the game breathing instead of a
## flash between turns.
func _on_theme_changed(bg: Color) -> void:
	if _bg_tween and _bg_tween.is_running():
		_bg_tween.kill()
	_bg_tween = create_tween()
	_bg_tween.tween_property(_bg, "color", bg, 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_score_updated(score_p1: int, score_p2: int) -> void:
	_set_score(_p1_score_label, score_p1)
	_set_score(_p2_score_label, score_p2)

## Pop the pill when its number changes, so a point registers peripherally --
## on a shared screen neither player is looking at the HUD when they score.
func _set_score(pill: Label, value: int) -> void:
	var text := str(value)
	if pill.text == text:
		return
	pill.text = text
	pill.pivot_offset = pill.size * 0.5
	var t := pill.create_tween()
	t.tween_property(pill, "scale", Vector2(1.25, 1.25), 0.1) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(pill, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
	resume_btn.position = Vector2(Field.mid_x() - 140, 300)
	resume_btn.pressed.connect(_on_resume_pressed)
	_paused_overlay.add_child(resume_btn)

	var menu_btn := UIUtil.make_button("MENU", 24, Palette.SURFACE)
	menu_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_btn.position = Vector2(Field.mid_x() - 140, 420)
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
	prompt.size = Vector2(Field.width(), 50)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.process_mode = Node.PROCESS_MODE_ALWAYS
	_paused_overlay.add_child(prompt)

	var confirm_btn := UIUtil.make_button("EXIT TO MENU", 24, Palette.PLAYER_1)
	confirm_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	confirm_btn.position = Vector2(Field.mid_x() - 140, 320)
	confirm_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://shell/main_menu/MainMenu.tscn")
	)
	_paused_overlay.add_child(confirm_btn)

	var cancel_btn := UIUtil.make_button("KEEP PLAYING", 24, Palette.SUCCESS)
	cancel_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	cancel_btn.position = Vector2(Field.mid_x() - 140, 440)
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
