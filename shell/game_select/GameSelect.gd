extends Control
## Game Select — chunky cards, two to a row, grouped under CLASSIC and SPORTS
## headers, each with its own [?] rules button. Tapping a card the first time
## auto-opens the rules card before starting; subsequent taps launch straight in.
##
## Portrait: the list scrolls vertically rather than horizontally, and the column
## count and card size are derived from the live viewport. Single-orientation —
## one person is picking a game, so nothing here is mirrored.

const COLUMNS := 2

var _scroll: ScrollContainer
var _column: VBoxContainer
var _back_btn: Button
var _title: Label
var _cards: Array[Control] = []
var _grids: Array[GridContainer] = []

func _ready() -> void:
	UIUtil.full_rect_bg(self, Palette.BACKGROUND)
	AudioManager.play_menu_music()

	_back_btn = UIUtil.make_button("<", 28, Palette.SURFACE)
	_back_btn.custom_minimum_size = Vector2(64, 64)
	_back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://shell/main_menu/MainMenu.tscn"))
	add_child(_back_btn)

	_title = UIUtil.make_label("CHOOSE A GAME", 36)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_scroll)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 18)
	_scroll.add_child(_column)

	var index := 0
	for category in GameManager.get_categories():
		_column.add_child(_build_section_header(category.name))
		var grid := GridContainer.new()
		grid.columns = COLUMNS
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 16)
		_column.add_child(grid)
		_grids.append(grid)

		for game_id: String in category.games:
			var card := _build_card(game_id)
			grid.add_child(card)
			_cards.append(card)
			UIUtil.pop_in(card, index * 0.04)
			index += 1

	get_viewport().size_changed.connect(_relayout)
	_relayout()

## Every screen-derived size in one place. Card width follows the viewport, so
## the grid never sits off-centre or overflows on a narrow or a 20:9 phone.
func _relayout() -> void:
	var w := Field.width()
	var h := Field.height()
	var margin := 22.0
	var top := Field.SAFE_OUTER + 12.0

	_back_btn.position = Vector2(margin, top)
	_title.position = Vector2(0, top + 12)
	_title.size = Vector2(w, 56)

	var content_w := w - margin * 2.0
	_scroll.position = Vector2(margin, top + 88)
	_scroll.size = Vector2(content_w, h - (top + 88) - Field.SAFE_OUTER - 12.0)

	var card_w := (content_w - 16.0 * (COLUMNS - 1)) / COLUMNS
	var card_h := card_w * 0.86
	for card in _cards:
		card.custom_minimum_size = Vector2(card_w, card_h)

func _build_section_header(text: String) -> Control:
	var header := UIUtil.make_label(text, 22, Color(Palette.INK, 0.65))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.custom_minimum_size = Vector2(0, 34)
	return header

func _build_card(game_id: String) -> Control:
	var meta := GameManager.get_game_meta(game_id)

	# Plain Control root (not a Container) so the background panel and the corner
	# [?] button can both be positioned freely without a Container forcing every
	# direct child to the same rect.
	var card := Control.new()

	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.SURFACE
	style.set_corner_radius_all(24)
	style.border_color = Palette.OUTLINE
	style.set_border_width_all(4)
	style.shadow_color = Color(0, 0, 0, 0.16)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 5)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	# Thumbnails and icons are generated art that may not have landed yet, so
	# every load is guarded -- a missing file leaves a blank slot, never a crash.
	var art_path := _card_art_path(game_id, meta)
	if art_path != "":
		var icon := TextureRect.new()
		icon.texture = load(art_path)
		icon.custom_minimum_size = Vector2(84, 84)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.pivot_offset = Vector2(42, 42)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(icon)
		UIUtil.idle_wobble(icon, randf() * 0.6)

	var name_label := UIUtil.make_label(meta.get("display_name", game_id), 20)
	vbox.add_child(name_label)

	# Games not yet built render as a disabled "SOON" card instead of a PLAY
	# button that would fail to load -- this self-corrects with no code change
	# once the scene file lands.
	var built := ResourceLoader.exists(meta.get("scene", ""))

	var play_btn := UIUtil.make_button("PLAY" if built else "SOON", 20, Palette.ACCENT if built else Palette.SURFACE)
	play_btn.custom_minimum_size = Vector2(126, 52)
	play_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_btn.disabled = not built
	play_btn.pressed.connect(func(): _on_card_pressed(game_id))
	vbox.add_child(play_btn)

	var rules_btn := UIUtil.make_button("?", 18, Palette.SURFACE)
	rules_btn.custom_minimum_size = Vector2(38, 38)
	rules_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rules_btn.pressed.connect(func(): _show_rules(game_id))
	card.add_child(rules_btn)

	return card

## Prefer the generated thumbnail from shared/art/manifest.json; fall back to the
## hand-authored vector icon; otherwise draw nothing.
func _card_art_path(game_id: String, meta: Dictionary) -> String:
	var thumb := "res://shared/art/thumbs/%s.png" % game_id
	if ResourceLoader.exists(thumb):
		return thumb
	var icon: String = meta.get("icon", "")
	if icon != "" and ResourceLoader.exists(icon):
		return icon
	return ""

func _on_card_pressed(game_id: String) -> void:
	if not SaveManager.has_seen_rules(game_id):
		var card := RulesCard.new()
		add_child(card)
		var meta := GameManager.get_game_meta(game_id)
		card.show_rules(meta.get("display_name", game_id), meta.get("rules_text", ""), _card_art_path(game_id, meta))
		SaveManager.mark_rules_seen(game_id)
		card.dismissed.connect(func(): _launch(game_id))
	else:
		_launch(game_id)

func _show_rules(game_id: String) -> void:
	var card := RulesCard.new()
	add_child(card)
	var meta := GameManager.get_game_meta(game_id)
	card.show_rules(meta.get("display_name", game_id), meta.get("rules_text", ""), _card_art_path(game_id, meta))

func _launch(game_id: String) -> void:
	GameManager.pending_game_id = game_id
	get_tree().change_scene_to_file("res://shell/match_host/MatchHost.tscn")
