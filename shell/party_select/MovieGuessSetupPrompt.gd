extends CanvasLayer
class_name MovieGuessSetupPrompt
## Pre-launch setup for Movie Guess -- multi-select era, multi-select
## language, and an optional lock timer, all settled before the group starts
## playing (same disposable CanvasLayer/dim/soft-card/queue_free() shape as
## RulesCard/DiceCountPrompt). Movie Guess's in-game screen no longer carries
## any of these controls -- to change them, back out and run this again.

const CONTENT_PATH := "res://shared/party_content/movies.json"
const TIMER_OPTIONS := [
	{"label": "No Timer", "seconds": 0},
	{"label": "15s", "seconds": 15},
	{"label": "30s", "seconds": 30},
	{"label": "45s", "seconds": 45},
	{"label": "60s", "seconds": 60},
	{"label": "120s", "seconds": 120},
]
const DEFAULT_TIMER_SECONDS := 120

signal confirmed

var _deck := PromptDeck.new()
var _era_chips: Array[Button] = []
var _lang_chips: Array[Button] = []
var _timer_chips: Array[Button] = []

func _ready() -> void:
	layer = 60

## saved_filters is whatever SaveManager.get_party_filter("movie_guess")
## returned -- {} on a first-ever launch, in which case every era/language
## chip starts unselected (meaning "Any") and the timer defaults to 120s.
func show_prompt(saved_filters: Dictionary) -> void:
	_deck.load_from_file(CONTENT_PATH)
	var saved_decades: Array = saved_filters.get("decades", [])
	var saved_languages: Array = saved_filters.get("languages", [])
	var saved_timer: int = saved_filters.get("timer_seconds", DEFAULT_TIMER_SECONDS)

	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	dim.create_tween().tween_property(dim, "color", Color(Palette.INK, 0.45), 0.2)

	var card := PanelContainer.new()
	var style := UIUtil.soft_panel_style(Palette.SURFACE, 28.0)
	style.set_content_margin_all(28)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(880, 560)
	card.position = Vector2(Field.mid_x() - 440, Field.height() * 0.5 - 280)
	add_child(card)
	UIUtil.pop_in(card, 0.05)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	var title := UIUtil.make_label("MOVIE GUESS SETUP", 30)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	content.add_child(UIUtil.make_label("ERA (pick any number, none = any)", 18))
	var era_flow := HFlowContainer.new()
	era_flow.add_theme_constant_override("h_separation", 10)
	era_flow.add_theme_constant_override("v_separation", 10)
	content.add_child(era_flow)
	for decade in _deck.distinct_values("decade"):
		var chip := _make_chip(decade, saved_decades.has(decade))
		era_flow.add_child(chip)
		_era_chips.append(chip)

	content.add_child(UIUtil.make_label("LANGUAGE (pick any number, none = any)", 18))
	var lang_flow := HFlowContainer.new()
	lang_flow.add_theme_constant_override("h_separation", 10)
	lang_flow.add_theme_constant_override("v_separation", 10)
	content.add_child(lang_flow)
	for language in _deck.distinct_values("language"):
		var chip := _make_chip(language, saved_languages.has(language))
		lang_flow.add_child(chip)
		_lang_chips.append(chip)

	content.add_child(UIUtil.make_label("LOCK TIMER (movie can't change until it runs out)", 18))
	var timer_flow := HFlowContainer.new()
	timer_flow.add_theme_constant_override("h_separation", 10)
	timer_flow.add_theme_constant_override("v_separation", 10)
	content.add_child(timer_flow)
	var timer_group := ButtonGroup.new()
	for option in TIMER_OPTIONS:
		var chip := _make_chip(option.label, option.seconds == saved_timer)
		chip.set_meta("seconds", option.seconds)
		chip.toggle_mode = true
		chip.button_group = timer_group
		timer_flow.add_child(chip)
		_timer_chips.append(chip)

	var play_btn := UIUtil.make_soft_button("PLAY", 26, Palette.SUCCESS)
	play_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_btn.pressed.connect(_on_confirm)
	vbox.add_child(play_btn)

	var back_btn := UIUtil.make_soft_round_button("<", 56, Palette.SURFACE)
	back_btn.position = Vector2(24, 24)
	back_btn.pressed.connect(_on_cancel)
	add_child(back_btn)

## A small toggleable "pill" -- unselected: neutral surface + ink text;
## selected: party-violet fill + surface text. Font colour is re-synced on
## every toggle since Godot doesn't vary font colour by theme state on its own.
func _make_chip(text: String, initially_selected: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.toggle_mode = true
	btn.button_pressed = initially_selected
	btn.custom_minimum_size = Vector2(0, 48)
	btn.add_theme_font_size_override("font_size", 20)

	var normal_style := UIUtil.soft_panel_style(Palette.SURFACE, 16.0)
	var selected_style := UIUtil.soft_panel_style(Palette.PARTY_PRIMARY, 16.0)
	for state in ["normal", "hover", "focus"]:
		btn.add_theme_stylebox_override(state, normal_style)
	for state in ["pressed", "hover_pressed"]:
		btn.add_theme_stylebox_override(state, selected_style)

	var sync_color := func():
		var color := Palette.SURFACE if btn.button_pressed else Palette.INK
		btn.add_theme_color_override("font_color", color)
		btn.add_theme_color_override("font_hover_color", color)
		btn.add_theme_color_override("font_pressed_color", color)
	btn.toggled.connect(func(_p): sync_color.call())
	sync_color.call()

	UIUtil.wire_bounce(btn)
	return btn

func _on_confirm() -> void:
	var decades: Array = _era_chips.filter(func(b): return b.button_pressed).map(func(b): return b.text)
	var languages: Array = _lang_chips.filter(func(b): return b.button_pressed).map(func(b): return b.text)
	var timer_seconds := DEFAULT_TIMER_SECONDS
	for chip in _timer_chips:
		if chip.button_pressed:
			timer_seconds = chip.get_meta("seconds")
			break
	SaveManager.set_party_filter("movie_guess", {
		"decades": decades,
		"languages": languages,
		"timer_seconds": timer_seconds,
	})
	confirmed.emit()
	queue_free()

## No signal on cancel -- PartyGameSelect just stays on the tile grid.
func _on_cancel() -> void:
	queue_free()
