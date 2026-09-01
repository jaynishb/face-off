extends PartyGame
## Movie Guess — the app suggests a random movie filtered by era + language;
## the group guesses it out loud. Resolution is verbal, by the humans, so
## there's no scoring here at all -- just filter, reveal, repeat. Pure
## Control-children UI (no _draw() needed), built the same code-in-setup()
## way every other shell/game screen in this project is built.

const CONTENT_PATH := "res://shared/party_content/movies.json"

var _deck := PromptDeck.new()
var _era_label_node: Label
var _lang_label_node: Label
var _era_option: OptionButton
var _lang_option: OptionButton
var _card: PanelContainer
var _title_label: Label
var _meta_label: Label
var _reveal_btn: Button
var _revealed_once := false

func _init() -> void:
	game_id = "movie_guess"
	display_name = "Movie Guess"
	rules_text = "Pick an era and language.\nReveal a movie.\nGroup guesses it out loud."
	theme_bg = Palette.BG_MOVIE_GUESS

func setup(_config: Dictionary) -> void:
	_deck.load_from_file(CONTENT_PATH)

	var saved_filters := SaveManager.get_party_filter(game_id)

	_era_label_node = UIUtil.make_label("ERA", 18)
	_era_label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_era_label_node)

	_era_option = OptionButton.new()
	_era_option.add_item("Any Era")
	for value in _deck.distinct_values("decade"):
		_era_option.add_item(value)
	_select_option(_era_option, saved_filters.get("decade", "Any Era"))
	_era_option.item_selected.connect(func(_i): _on_filters_changed())
	add_child(_era_option)

	_lang_label_node = UIUtil.make_label("LANGUAGE", 18)
	_lang_label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_lang_label_node)

	_lang_option = OptionButton.new()
	_lang_option.add_item("Any Language")
	for value in _deck.distinct_values("language"):
		_lang_option.add_item(value)
	_select_option(_lang_option, saved_filters.get("language", "Any Language"))
	_lang_option.item_selected.connect(func(_i): _on_filters_changed())
	add_child(_lang_option)

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

	_title_label = UIUtil.make_label("TAP REVEAL TO START", 36)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_title_label)

	_meta_label = UIUtil.make_label("", 20)
	_meta_label.modulate.a = 0.7
	vbox.add_child(_meta_label)

	_reveal_btn = UIUtil.make_soft_button("REVEAL", 26, Palette.PARTY_PRIMARY)
	_reveal_btn.add_theme_color_override("font_color", Palette.SURFACE)
	_reveal_btn.add_theme_color_override("font_hover_color", Palette.SURFACE)
	_reveal_btn.add_theme_color_override("font_pressed_color", Palette.SURFACE)
	_reveal_btn.pressed.connect(_on_reveal_pressed)
	add_child(_reveal_btn)

	layout()

func layout() -> void:
	if not _era_option:
		return
	var mid := Field.mid_x()
	var top := Field.top() + 20.0

	_era_label_node.position = Vector2(mid - 220, top)
	_era_option.position = Vector2(mid - 220, top + 28)
	_era_option.size = Vector2(200, 48)

	_lang_label_node.position = Vector2(mid + 20, top)
	_lang_option.position = Vector2(mid + 20, top + 28)
	_lang_option.size = Vector2(200, 48)

	_card.position = Vector2(mid - 320, top + 110)
	_card.size = Vector2(640, 300)
	_card.pivot_offset = _card.size * 0.5

	_reveal_btn.position = Vector2(mid - 140, top + 430)

func _select_option(option: OptionButton, value: String) -> void:
	for i in range(option.item_count):
		if option.get_item_text(i) == value:
			option.select(i)
			return
	option.select(0)

func _current_filters() -> Dictionary:
	var era := _era_option.get_item_text(_era_option.selected)
	var lang := _lang_option.get_item_text(_lang_option.selected)
	return {
		"decade": "Any" if era == "Any Era" else era,
		"language": "Any" if lang == "Any Language" else lang,
	}

func _on_filters_changed() -> void:
	SaveManager.set_party_filter(game_id, _current_filters())
	_deck.reset_recent()

func _on_reveal_pressed() -> void:
	var pick := _deck.draw_random(_current_filters())
	if pick.is_empty():
		_title_label.text = "No movies match —\ntry different filters"
		_meta_label.text = ""
	else:
		_title_label.text = pick.get("title", "")
		_meta_label.text = "%s · %s" % [str(pick.get("year", "")), pick.get("language", "")]
		AudioManager.play_sfx("place")

	if not _revealed_once:
		_revealed_once = true
		_reveal_btn.text = "NEXT MOVIE"

	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.9, 0.9)
	var t := _card.create_tween()
	t.tween_property(_card, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	UIUtil.punch(_title_label)
