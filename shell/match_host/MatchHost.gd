extends Control
## MatchHost — the universal in-game frame (PRD 7.4). Owns the seam HUD, pause
## and exit buttons, the split divider, and the 3-2-1 countdown; the game itself
## only knows its own play area. Never contains game-specific branches —
## everything it needs comes through the MiniGame contract.
##
## PORTRAIT. Player 1 holds the bottom half, Player 2 the top, and the two face
## each other across a phone lying flat. So every piece of chrome carrying TEXT
## is drawn twice, once per half, with Player 2's copy rotated by PI — otherwise
## half the audience reads the countdown, the win banner and the pause menu
## upside down. UIUtil.mirror_for_players() does that; the only single-copy
## chrome is what is rotationally symmetric anyway (the score pills' digits).

var _game: MiniGame
var _p1_score_label: Label
var _p2_score_label: Label
var _overlay: CanvasLayer
var _bg: ColorRect
var _bg_tween: Tween
var _exit_btn: Button
var _pause_btn: Button
## A second X/pause pair, built only for SHARED-board games. See _relayout.
var _exit_btn_alt: Button
var _pause_btn_alt: Button
var _divider: ColorRect
var _hud: Control

func _ready() -> void:
	# A plain Control's default mouse_filter (STOP) swallows every tap over its
	# full rect before it can ever reach InputManager's _unhandled_input, even
	# with no _gui_input override -- that's Godot's documented behavior for
	# MOUSE_FILTER_STOP. MatchHost covers the whole screen, so left at the
	# default it silently blocks all gameplay touches. IGNORE here lets touches
	# fall through to InputManager; interactive children (the pause button) still
	# get their own clicks since they hit-test independently with their own
	# (STOP) filter. Caught by a real phone reporting "no controls" -- see
	# CLAUDE.md.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg = UIUtil.full_rect_bg(self, Palette.BACKGROUND)
	AudioManager.stop_music() # never music during a match -- see CLAUDE.md

	var game_id: String = GameManager.pending_game_id
	_game = GameManager.load_game(game_id)
	if not _game:
		get_tree().change_scene_to_file("res://shell/game_select/GameSelect.tscn")
		return

	# Reset every input mode left behind by a previous game, so none of them can
	# leak across matches.
	InputManager.configure_zones([])
	InputManager.set_shared_board_turn(0)
	InputManager.set_input_space(_game.input_space)
	add_child(_game)
	_game.setup({})
	_game.score_updated.connect(_on_score_updated)
	_game.theme_changed.connect(_on_theme_changed)

	# The game owns its ground colour; the shell just paints it. No game_id
	# branching here -- it all arrives through the MiniGame contract.
	_bg.color = _game.theme_bg

	_build_hud()
	_build_divider()

	# A phone browser resizes the canvas after load (address bar collapsing,
	# orientation settling), so anything positioned once at _ready() is frozen at
	# first-frame dimensions -- that is what pushed the P2 score pill off the
	# edge on a real device. Re-lay out the HUD and the game every time the
	# viewport actually changes.
	get_viewport().size_changed.connect(_relayout)
	_relayout()

	var countdown := CountdownOverlay.new()
	add_child(countdown)
	countdown.countdown_finished.connect(func(): _game.start_match())
	countdown.play()

	_game.match_ended.connect(_on_match_ended)

## Floating pills rather than a solid bar: a bar forces one surface colour over
## every game's ground, while pills sit on any of them and leave the playfield
## uninterrupted. In portrait they live in the seam band at the centre of the
## screen, each on its own side of the split and each facing its own player —
## both on the same edge, so every player finds their score at their own left.
func _build_hud() -> void:
	_hud = Control.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)

	_p1_score_label = UIUtil.make_score_pill(1)
	_hud.add_child(_p1_score_label)

	_p2_score_label = UIUtil.make_score_pill(2)
	_hud.add_child(_p2_score_label)

	# Exit and pause live at each player's OWN outer corner, one cluster per
	# half, both wired to the same handlers. A single cluster in the middle of
	# the seam was tried and rejected: the seam is the centre of the screen, and
	# the centre of the screen is exactly where a shared board, a communal dohyo
	# and a centre circle all live -- the discs sat on top of the playfield in
	# half the roster. A single corner button (as the reference app has) is worse
	# still: it would be out of reach and upside down for one player, which
	# CLAUDE.md's "identical control area for both players" rule does not allow.
	_exit_btn = UIUtil.make_round_button("X", 52, Palette.SURFACE)
	_exit_btn.pressed.connect(_on_exit_pressed)
	_hud.add_child(_exit_btn)

	_pause_btn = UIUtil.make_round_button("II", 52, Palette.SURFACE)
	_pause_btn.pressed.connect(_on_pause_pressed)
	_hud.add_child(_pause_btn)

	_exit_btn_alt = UIUtil.make_round_button("X", 52, Palette.SURFACE)
	_exit_btn_alt.pressed.connect(_on_exit_pressed)
	_hud.add_child(_exit_btn_alt)

	_pause_btn_alt = UIUtil.make_round_button("II", 52, Palette.SURFACE)
	_pause_btn_alt.pressed.connect(_on_pause_pressed)
	_hud.add_child(_pause_btn_alt)

func _build_divider() -> void:
	# A shared board is not split between the players, so drawing a divider
	# across it would misrepresent the game.
	if _game.view_mode == MiniGame.ViewMode.SHARED:
		return
	_divider = ColorRect.new()
	_divider.color = Color(Palette.OUTLINE, 0.22)
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_divider)

## Single place where every screen-derived position is (re)computed, so the HUD
## and the game can never drift apart from the actual viewport.
func _relayout() -> void:
	var mid := Field.split_y()
	var pill_h: float = _p1_score_label.size.y

	if _game and _game.view_mode == MiniGame.ViewMode.SHARED:
		# A communal board wants the middle of the screen, which is exactly where
		# the seam HUD sits. Push the pills out to each player's own outer edge
		# instead. This branches on the MiniGame contract, never on game_id.
		_p1_score_label.position = Vector2(20, Field.height() - Field.SAFE_OUTER - pill_h - 6)
		_p2_score_label.position = Vector2(20, Field.SAFE_OUTER + 6)
	else:
		_p1_score_label.position = Vector2(20, mid + 8)
		_p2_score_label.position = Vector2(20, mid - 8 - pill_h)

	# Player 2 reads their pill from the far side of the phone.
	_p2_score_label.pivot_offset = _p2_score_label.size * 0.5
	_p2_score_label.rotation = PI

	# One cluster per player, each in that player's own outer corner and rotated
	# to face them. Right-hand side, so they never collide with the score pills.
	var right := Field.width() - 52.0 - 20.0
	var bottom_y := Field.height() - Field.SAFE_OUTER - 52.0 - 6.0
	var top_y := Field.SAFE_OUTER + 6.0
	_pause_btn.position = Vector2(right, bottom_y)
	_exit_btn.position = Vector2(right - 60.0, bottom_y)
	_pause_btn_alt.position = Vector2(right, top_y)
	_exit_btn_alt.position = Vector2(right - 60.0, top_y)
	for btn: Button in [_pause_btn_alt, _exit_btn_alt]:
		btn.pivot_offset = btn.size * 0.5
		btn.rotation = PI

	if _divider:
		# Must sit exactly on Field.split_y() -- this line is the promise the
		# input split makes to the players.
		_divider.position = Vector2(0, mid - 2)
		_divider.size = Vector2(Field.width(), 4)

	if _game:
		_game.layout()

## Turn-based games retint the whole screen to whoever is on the clock. Tween
## rather than cut, so the change reads as the game breathing instead of a flash
## between turns.
func _on_theme_changed(bg: Color) -> void:
	if _bg_tween and _bg_tween.is_running():
		_bg_tween.kill()
	_bg_tween = create_tween()
	_bg_tween.tween_property(_bg, "color", bg, 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_score_updated(score_p1: int, score_p2: int) -> void:
	_set_score(_p1_score_label, score_p1)
	_set_score(_p2_score_label, score_p2)

## Pop the pill when its number changes, so a point registers peripherally -- on
## a shared screen neither player is looking at the HUD when they score. The
## tween drives `scale`, never `rotation`, so P2's flipped pill stays flipped.
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
	_show_overlay(_build_pause_panel)

## A dedicated, always-visible exit -- separate from Pause -- so a player on the
## web build (no OS back button to rely on) has one direct tap to bail out of a
## match instead of having to discover it's hidden behind Pause.
func _on_exit_pressed() -> void:
	_show_overlay(_build_exit_panel)

## Pause and exit-confirm used to be two near-identical copies of the same
## CanvasLayer/dim/button scaffolding. One builder, mirrored into both halves, so
## whichever player reached for it can read and dismiss it.
func _show_overlay(build_panel: Callable) -> void:
	if _overlay:
		return
	get_tree().paused = true
	_overlay = CanvasLayer.new()
	_overlay.layer = 45
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(dim)

	UIUtil.mirror_for_players(_overlay, build_panel)

## Built in PLAYER space: (0,0) is this player's own top-left, extending to
## Field.half_size(). Positions are derived from the half rather than the
## hardcoded pixel y values this used to carry, which never reflowed on a height
## change.
func _build_pause_panel(_player: int) -> Control:
	var half := Field.half_size()
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = half

	var title := UIUtil.make_label("PAUSED", 40)
	title.position = Vector2(0, half.y * 0.30)
	title.size = Vector2(half.x, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var score := UIUtil.make_label("%s   -   %s" % [_p1_score_label.text, _p2_score_label.text], 30)
	score.position = Vector2(0, half.y * 0.30 + 54)
	score.size = Vector2(half.x, 40)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(score)

	_add_panel_button(root, "CONTINUE PLAYING", Palette.SUCCESS, half.y * 0.44, _on_resume_pressed)
	_add_panel_button(root, "RESTART MATCH", Palette.ACCENT, half.y * 0.56, _on_restart_pressed)
	_add_panel_button(root, "HOW TO PLAY", Palette.SURFACE, half.y * 0.68, _on_how_to_play_pressed)
	_add_panel_button(root, "MAIN MENU", Palette.SURFACE, half.y * 0.80, _to_main_menu)
	return root

func _build_exit_panel(_player: int) -> Control:
	var half := Field.half_size()
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = half

	var prompt := UIUtil.make_label("Exit this match?", 32)
	prompt.position = Vector2(0, half.y * 0.34)
	prompt.size = Vector2(half.x, 50)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt)

	_add_panel_button(root, "KEEP PLAYING", Palette.SUCCESS, half.y * 0.50, _on_resume_pressed)
	_add_panel_button(root, "EXIT TO MENU", Palette.PLAYER_1, half.y * 0.66, _to_main_menu)
	return root

func _add_panel_button(parent: Control, text: String, color: Color, y: float, handler: Callable) -> void:
	var btn := UIUtil.make_button(text, 24, color)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.position = Vector2((Field.half_size().x - btn.size.x) * 0.5, y)
	btn.pressed.connect(handler)
	parent.add_child(btn)

func _on_resume_pressed() -> void:
	get_tree().paused = false
	if _overlay:
		_overlay.queue_free()
		_overlay = null

## Mid-match, both players are looking at the phone from opposite ends, so the
## rules card is shown mirrored here -- unlike Game Select, where one person is
## browsing and a single upright card is right.
func _on_how_to_play_pressed() -> void:
	var meta := GameManager.get_game_meta(GameManager.current_game_id)
	var card := RulesCard.new()
	card.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(card)
	card.show_rules(
		meta.get("display_name", ""), meta.get("rules_text", ""), meta.get("icon", ""), true
	)

func _on_restart_pressed() -> void:
	get_tree().paused = false
	GameManager.pending_game_id = GameManager.current_game_id
	get_tree().change_scene_to_file("res://shell/match_host/MatchHost.tscn")

func _to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://shell/main_menu/MainMenu.tscn")

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
