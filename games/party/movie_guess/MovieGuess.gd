extends PartyGame
## Movie Guess — the app suggests a random movie filtered by era + language;
## the group guesses it out loud. Resolution is verbal, by the humans, so
## there's no scoring here at all -- just reveal, repeat. Era/language/timer
## are all chosen up front by MovieGuessSetupPrompt (PartyGameSelect) rather
## than live in-game controls; tap anywhere on the screen to reveal, same
## "tap anywhere" pattern Dice Roller uses.

const CONTENT_PATH := "res://shared/party_content/movies.json"
const COUNTDOWN_RADIUS := 42.0

var _deck := PromptDeck.new()
var _timer := MatchTimer.new()
var _decades: Array = []
var _languages: Array = []
var _timer_seconds := 0

var _card: PanelContainer
var _title_label: Label
var _meta_label: Label
var _hint_label: Label
var _countdown_label: Label
var _cancel_btn: Button

var _locked := false
var _progress := 0.0
var _last_tick_second := -1
var _countdown_center := Vector2.ZERO

var _content_top := 0.0

func _init() -> void:
	game_id = "movie_guess"
	display_name = "Movie Guess"
	rules_text = "Tap anywhere to reveal a movie.\nGroup guesses it out loud.\nOptional timer locks it while you guess."
	theme_bg = Palette.BG_MOVIE_GUESS

func setup(_config: Dictionary) -> void:
	_deck.load_from_file(CONTENT_PATH)

	var saved := SaveManager.get_party_filter(game_id)
	_decades = saved.get("decades", [])
	_languages = saved.get("languages", [])
	_timer_seconds = saved.get("timer_seconds", 0)

	add_child(_timer)
	_timer.tick.connect(_on_tick)
	_timer.time_up.connect(_on_time_up)

	# Tap anywhere reveals, same InputManager.player_pressed pattern Dice
	# Roller/SumoBlob use -- ignore which player/zone fired, it's one shared
	# action. Locked out entirely while a lock timer is counting down.
	InputManager.player_pressed.connect(_on_tap)

	_hint_label = UIUtil.make_label("TAP ANYWHERE TO REVEAL A MOVIE", 20)
	add_child(_hint_label)

	_card = PanelContainer.new()
	var style := UIUtil.soft_panel_style(Palette.SURFACE, 28.0)
	style.set_content_margin_all(28)
	_card.add_theme_stylebox_override("panel", style)
	_card.custom_minimum_size = Vector2(640, 300)
	add_child(_card)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	_card.add_child(vbox)

	_title_label = UIUtil.make_label("TAP ANYWHERE TO START", 36)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_title_label)

	_meta_label = UIUtil.make_label("", 20)
	_meta_label.modulate.a = 0.7
	vbox.add_child(_meta_label)

	_countdown_label = UIUtil.make_label("", 28)
	_countdown_label.visible = false
	add_child(_countdown_label)

	_cancel_btn = UIUtil.make_soft_button("CANCEL", 22, Palette.PLAYER_1)
	_cancel_btn.add_theme_color_override("font_color", Palette.SURFACE)
	_cancel_btn.add_theme_color_override("font_hover_color", Palette.SURFACE)
	_cancel_btn.add_theme_color_override("font_pressed_color", Palette.SURFACE)
	_cancel_btn.visible = false
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	add_child(_cancel_btn)

	layout()

func layout() -> void:
	if not _card:
		return
	var mid := Field.center().x
	# Centred in the play area rather than pinned to its top -- see
	# PartyGame.content_top(). The height is this game's own content block.
	_content_top = content_top(540.0)
	var top := _content_top

	_hint_label.position = Vector2(mid - 200, top)
	_hint_label.size = Vector2(400, 30)

	_card.position = Vector2(mid - 320, top + 50)
	_card.size = Vector2(640, 300)
	_card.pivot_offset = _card.size * 0.5

	_countdown_center = Vector2(mid, top + 410)
	_countdown_label.position = _countdown_center - Vector2(30, 20)
	_countdown_label.size = Vector2(60, 40)

	_cancel_btn.position = Vector2(mid - 140, top + 470)

func _current_filters() -> Dictionary:
	return {"decade": _decades, "language": _languages}

func _on_tap(_player: int, _zone: int, _position: Vector2) -> void:
	if _locked:
		return
	_reveal()

func _reveal() -> void:
	var pick := _deck.draw_random(_current_filters())
	if pick.is_empty():
		_title_label.text = "No movies match —\ntry different filters"
		_meta_label.text = ""
	else:
		_title_label.text = pick.get("title", "")
		_meta_label.text = "%s · %s" % [str(pick.get("year", "")), pick.get("language", "")]
		AudioManager.play_sfx("place")

	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.9, 0.9)
	var t := _card.create_tween()
	t.tween_property(_card, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	UIUtil.punch(_title_label)

	if _timer_seconds > 0 and not pick.is_empty():
		_lock()
	else:
		_hint_label.text = "TAP ANYWHERE FOR NEXT MOVIE"

func _lock() -> void:
	_locked = true
	_last_tick_second = -1
	_progress = 0.0
	_hint_label.text = "GUESS BEFORE TIME RUNS OUT!"
	_countdown_label.visible = true
	_cancel_btn.visible = true
	_timer.start(_timer_seconds)
	queue_redraw()

func _unlock() -> void:
	_locked = false
	_countdown_label.visible = false
	_cancel_btn.visible = false
	_hint_label.text = "TAP ANYWHERE FOR NEXT MOVIE"
	queue_redraw()

func _on_tick(seconds_remaining: float) -> void:
	_progress = _timer.get_progress()
	var whole_second := ceili(seconds_remaining)
	_countdown_label.text = str(whole_second)
	if whole_second != _last_tick_second:
		_last_tick_second = whole_second
		AudioManager.play_sfx("countdown_tick")
	queue_redraw()

func _on_time_up() -> void:
	_unlock()
	if SaveManager.haptics_enabled:
		Input.vibrate_handheld(30)

## The group already guessed it (or wants to bail) -- stop the timer early
## rather than waiting it out.
func _on_cancel_pressed() -> void:
	_timer.stop()
	_unlock()

func _draw() -> void:
	if not _locked:
		return
	var urgency_color: Color = Palette.ACCENT.lerp(Palette.PLAYER_1, _progress)
	draw_arc(_countdown_center, COUNTDOWN_RADIUS, 0.0, TAU, 48, Color(Palette.OUTLINE, 0.15), 8.0)
	if _progress < 1.0:
		var start_angle := -PI * 0.5
		var end_angle := start_angle + TAU * (1.0 - _progress)
		draw_arc(_countdown_center, COUNTDOWN_RADIUS, start_angle, end_angle, 48, urgency_color, 8.0)
