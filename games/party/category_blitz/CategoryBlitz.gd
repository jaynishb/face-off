extends PartyGame
## Category Blitz — a category prompt appears, a countdown starts, and the
## phone passes around the group with everyone naming one example before the
## buzzer. Resolved by the humans, same as Movie Guess -- no scoring. Reuses
## PromptDeck (second consumer, validating it generalizes) and MatchTimer
## (already fully generic, previously unused by any shipped game).

const CONTENT_PATH := "res://shared/party_content/categories.json"
const DURATION := 20.0
const ARC_RADIUS := 70.0

var _deck := PromptDeck.new()
var _timer := MatchTimer.new()
var _pack_option: OptionButton
var _prompt_card: PanelContainer
var _prompt_label: Label
var _count_label: Label
var _buzz_label: Label
var _next_btn: Button
var _replay_btn: Button

var _progress := 0.0
var _buzzing := false
var _arc_center := Vector2.ZERO

var _content_top := 0.0

func _init() -> void:
	game_id = "category_blitz"
	display_name = "Category Blitz"
	rules_text = "A category appears, timer starts.\nPass the phone, everyone names one.\nBeat the buzzer."
	theme_bg = Palette.BG_CATEGORY_BLITZ

func setup(_config: Dictionary) -> void:
	_deck.load_from_file(CONTENT_PATH)
	add_child(_timer)
	_timer.tick.connect(_on_tick)
	_timer.time_up.connect(_on_time_up)

	_pack_option = OptionButton.new()
	_pack_option.add_item("Any Pack")
	for value in _deck.distinct_values("pack"):
		_pack_option.add_item(value.capitalize())
	_pack_option.select(0)
	_pack_option.item_selected.connect(func(_i): _deck.reset_recent())
	add_child(_pack_option)

	_prompt_card = PanelContainer.new()
	var style := UIUtil.soft_panel_style(Palette.SURFACE, 28.0)
	style.set_content_margin_all(24)
	_prompt_card.add_theme_stylebox_override("panel", style)
	_prompt_card.custom_minimum_size = Vector2(640, 120)
	add_child(_prompt_card)

	_prompt_label = UIUtil.make_label("", 28)
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_prompt_card.add_child(_prompt_label)

	_count_label = UIUtil.make_label(str(int(DURATION)), 40)
	add_child(_count_label)

	_buzz_label = UIUtil.make_label("TIME'S UP!", 32, Palette.PLAYER_1)
	_buzz_label.visible = false
	add_child(_buzz_label)

	_next_btn = UIUtil.make_soft_button("NEXT CATEGORY", 22, Palette.PARTY_PRIMARY)
	_next_btn.add_theme_color_override("font_color", Palette.SURFACE)
	_next_btn.add_theme_color_override("font_hover_color", Palette.SURFACE)
	_next_btn.add_theme_color_override("font_pressed_color", Palette.SURFACE)
	_next_btn.pressed.connect(_new_round)
	add_child(_next_btn)

	_replay_btn = UIUtil.make_soft_button("REPLAY TIMER", 20, Palette.SURFACE)
	_replay_btn.pressed.connect(_replay_timer)
	add_child(_replay_btn)

	layout()

func layout() -> void:
	if not _prompt_card:
		return
	var mid := Field.center().x
	# Centred in the play area rather than pinned to its top -- see
	# PartyGame.content_top(). The height is this game's own content block.
	_content_top = content_top(460.0)
	var top := _content_top

	_pack_option.position = Vector2(mid - 100, top)
	_pack_option.size = Vector2(200, 44)

	_prompt_card.position = Vector2(mid - 320, top + 60)
	_prompt_card.size = Vector2(640, 120)

	_arc_center = Vector2(mid, top + 280.0)
	_count_label.position = _arc_center - Vector2(24, 26)
	_buzz_label.position = Vector2(mid - 110, top + 250)

	_next_btn.position = Vector2(mid - 292, top + 370)
	_replay_btn.position = Vector2(mid + 12, top + 370)

func start() -> void:
	_new_round()

func _current_filters() -> Dictionary:
	if not _pack_option or _pack_option.selected <= 0:
		return {}
	return {"pack": _deck.distinct_values("pack")[_pack_option.selected - 1]}

func _new_round() -> void:
	var pick := _deck.draw_random(_current_filters())
	_prompt_label.text = pick.get("prompt", "No prompts match this pack") if not pick.is_empty() else "No prompts match this pack"
	_replay_timer()

func _replay_timer() -> void:
	_buzzing = false
	_buzz_label.visible = false
	_count_label.visible = true
	_progress = 0.0
	_timer.start(DURATION)
	queue_redraw()

func _on_tick(seconds_remaining: float) -> void:
	_count_label.text = str(ceili(seconds_remaining))
	_progress = _timer.get_progress()
	queue_redraw()

func _on_time_up() -> void:
	_buzzing = true
	_count_label.visible = false
	_buzz_label.visible = true
	UIUtil.punch(_buzz_label)
	if SaveManager.haptics_enabled:
		Input.vibrate_handheld(60)
	queue_redraw()

func _draw() -> void:
	if _arc_center == Vector2.ZERO:
		return
	var urgency_color: Color = Palette.ACCENT.lerp(Palette.PLAYER_1, _progress)
	draw_arc(_arc_center, ARC_RADIUS, 0.0, TAU, 48, Color(Palette.OUTLINE, 0.15), 10.0)
	if _progress < 1.0:
		var start_angle := -PI * 0.5
		var end_angle := start_angle + TAU * (1.0 - _progress)
		draw_arc(_arc_center, ARC_RADIUS, start_angle, end_angle, 48, urgency_color, 10.0)
