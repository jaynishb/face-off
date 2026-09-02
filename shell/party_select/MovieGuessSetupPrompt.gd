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
var _era_chips: Array[PanelContainer] = []
var _lang_chips: Array[PanelContainer] = []
var _timer_chips: Array[PanelContainer] = []

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
	card.position = Vector2(Field.mid_x() - 440, Field.NOMINAL_HEIGHT * 0.5 - 280)
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
		chip.gui_input.connect(_on_chip_input.bind(chip, _toggle_multi_chip))
		era_flow.add_child(chip)
		_era_chips.append(chip)

	content.add_child(UIUtil.make_label("LANGUAGE (pick any number, none = any)", 18))
	var lang_flow := HFlowContainer.new()
	lang_flow.add_theme_constant_override("h_separation", 10)
	lang_flow.add_theme_constant_override("v_separation", 10)
	content.add_child(lang_flow)
	for language in _deck.distinct_values("language"):
		var chip := _make_chip(language, saved_languages.has(language))
		chip.gui_input.connect(_on_chip_input.bind(chip, _toggle_multi_chip))
		lang_flow.add_child(chip)
		_lang_chips.append(chip)

	content.add_child(UIUtil.make_label("LOCK TIMER (movie can't change until it runs out)", 18))
	var timer_flow := HFlowContainer.new()
	timer_flow.add_theme_constant_override("h_separation", 10)
	timer_flow.add_theme_constant_override("v_separation", 10)
	content.add_child(timer_flow)
	for option in TIMER_OPTIONS:
		var chip := _make_chip(option.label, option.seconds == saved_timer)
		chip.set_meta("seconds", option.seconds)
		chip.gui_input.connect(_on_chip_input.bind(chip, _select_timer_chip))
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

## A small toggleable "pill" built from a plain PanelContainer + Label rather
## than a toggle-mode Button. A Button resolves its rendered font colour and
## stylebox from a combination of hover/pressed/focus state, and in practice
## some combination reliably ends up uncovered -- reproduced repeatedly in
## this HFlowContainer regardless of how many per-state colour/stylebox
## overrides were added, rendering as fully invisible text on an otherwise
## normal-looking pill. A Panel has exactly one stylebox slot and a Label
## exactly one font colour -- neither has per-state resolution to get wrong,
## so this sidesteps the whole bug class instead of chasing it further.
## Selection state lives in metadata (`selected`) rather than a Button's
## built-in `button_pressed`, and `_refresh_chip()` is the only place that
## paints it.
func _make_chip(text: String, initially_selected: bool) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.set_meta("selected", initially_selected)

	var normal_style := UIUtil.soft_panel_style(Palette.SURFACE, 16.0)
	var selected_style := UIUtil.soft_panel_style(Palette.PARTY_PRIMARY, 16.0)
	for s in [normal_style, selected_style]:
		s.content_margin_left = 20.0
		s.content_margin_right = 20.0
		s.content_margin_top = 10.0
		s.content_margin_bottom = 10.0
	chip.set_meta("normal_style", normal_style)
	chip.set_meta("selected_style", selected_style)

	var label := UIUtil.make_label(text, 20)
	chip.add_child(label)
	chip.set_meta("label", label)

	_refresh_chip(chip)
	return chip

func _refresh_chip(chip: PanelContainer) -> void:
	var selected: bool = chip.get_meta("selected")
	chip.add_theme_stylebox_override(
		"panel", chip.get_meta("selected_style") if selected else chip.get_meta("normal_style")
	)
	var label: Label = chip.get_meta("label")
	label.add_theme_color_override("font_color", Palette.SURFACE if selected else Palette.INK)

## Common tap handler for all chips -- checks for an actual press (mouse or
## touch) before calling the given `on_press` behaviour (multi-select toggle
## or single-select group pick), so the chip reacts the same way on desktop
## click and mobile tap.
## Only InputEventScreenTouch, not InputEventMouseButton -- project.godot has
## emulate_touch_from_mouse=true (see InputManager.gd, which follows the same
## rule), so a single click/tap delivers BOTH a native mouse event and a
## synthetic touch event. Reacting to both double-fires this handler per
## click, which for a multi-select toggle means toggling on then immediately
## back off -- the chip would silently never end up selected.
func _on_chip_input(event: InputEvent, chip: PanelContainer, on_press: Callable) -> void:
	if event is InputEventScreenTouch and event.pressed:
		on_press.call(chip)
		UIUtil.punch(chip)

func _toggle_multi_chip(chip: PanelContainer) -> void:
	chip.set_meta("selected", not chip.get_meta("selected"))
	_refresh_chip(chip)

## Timer chips are single-select -- picking one deselects every other.
func _select_timer_chip(chip: PanelContainer) -> void:
	for c in _timer_chips:
		c.set_meta("selected", c == chip)
		_refresh_chip(c)

func _on_confirm() -> void:
	var decades: Array = _era_chips.filter(func(c): return c.get_meta("selected")) \
		.map(func(c): return (c.get_meta("label") as Label).text)
	var languages: Array = _lang_chips.filter(func(c): return c.get_meta("selected")) \
		.map(func(c): return (c.get_meta("label") as Label).text)
	var timer_seconds := DEFAULT_TIMER_SECONDS
	for chip in _timer_chips:
		if chip.get_meta("selected"):
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
