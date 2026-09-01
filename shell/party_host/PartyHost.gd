extends Control
## PartyHost — the Party Mode equivalent of MatchHost, deliberately smaller:
## no score bar, no midline divider, no countdown (a party game isn't a
## synchronized start for two competing players). Owns only a back button and
## the ground colour; the game itself owns everything else. Never contains
## game-specific branches -- everything it needs comes through PartyGame.

var _game: PartyGame
var _bg: ColorRect
var _bg_tween: Tween
var _back_btn: Button

func _ready() -> void:
	# See MatchHost.gd -- a full-screen Control's default mouse_filter (STOP)
	# swallows every tap before InputManager ever sees it. IGNORE lets touches
	# fall through; the back button still gets its own clicks independently.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg = UIUtil.full_rect_bg(self, Palette.BACKGROUND)
	AudioManager.stop_music() # no music during play -- see CLAUDE.md

	var game_id: String = PartyManager.pending_game_id
	_game = PartyManager.load_party_game(game_id)
	if not _game:
		get_tree().change_scene_to_file("res://shell/party_select/PartyGameSelect.tscn")
		return

	# Party games never use screen-half or shared-board input ownership, but
	# reset defensively so nothing leaks in from (or out to) a 1v1 match
	# played before or after this session.
	InputManager.configure_zones([])
	InputManager.set_shared_board_turn(0)

	add_child(_game)
	_game.setup({})
	_game.theme_changed.connect(_on_theme_changed)

	_bg.color = _game.theme_bg

	_back_btn = UIUtil.make_soft_round_button("<", 56, Palette.SURFACE)
	_back_btn.pressed.connect(_on_back_pressed)
	add_child(_back_btn)

	# A phone browser resizes the canvas after load (address bar collapsing) --
	# re-layout on every real viewport change, not just once at _ready().
	get_viewport().size_changed.connect(_relayout)
	_relayout()

	_game.start()

func _relayout() -> void:
	_back_btn.position = Vector2(24, 24)
	if _game:
		_game.layout()

## Turn-based/urgency games retint the whole screen live. Tween rather than
## cut, same as MatchHost.
func _on_theme_changed(bg: Color) -> void:
	if _bg_tween and _bg_tween.is_running():
		_bg_tween.kill()
	_bg_tween = create_tween()
	_bg_tween.tween_property(_bg, "color", bg, 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Returns to PartyGameSelect (not MainMenu) -- Party Mode's use case is
## trying several tools in one sitting. No "exit this match?" confirm: unlike
## MatchHost, nothing is "in progress" to lose -- a party game is open-ended,
## not a match with a winner.
func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://shell/party_select/PartyGameSelect.tscn")
