extends Control
## Party Game Select — the group-play equivalent of GameSelect. One soft,
## shadowed tile per party game, each with its own [?] rules button. Tapping
## a tile the first time auto-opens the rules card before starting;
## subsequent taps launch straight in. Deliberately separate from GameSelect/
## GameManager -- Party Mode games have no score/winner, so they get their
## own registry (PartyManager) rather than reusing the 1v1 one.
##
## Portrait, and laid out the same way GameSelect is: the list scrolls
## VERTICALLY in two columns whose width follows the live viewport. It used to
## be a 3-wide horizontally-scrolling grid pinned at 1128px, which is wider than
## the whole 720px portrait screen -- the tiles ran off both edges.

const COLUMNS := 2

var _scroll: ScrollContainer
var _grid: GridContainer
var _back_btn: Button
var _title: Label
var _subtitle: Label
var _tiles: Array[Control] = []

func _ready() -> void:
	UIUtil.gradient_bg(self, Palette.GRADIENT_PARTY_TOP, Palette.GRADIENT_PARTY_BOTTOM)
	AudioManager.play_menu_music()

	_back_btn = UIUtil.make_soft_round_button("<", 64, Palette.SURFACE)
	_back_btn.pressed.connect(func(): UIUtil.fade_to_scene(get_tree(), "res://shell/main_menu/MainMenu.tscn"))
	add_child(_back_btn)

	_title = UIUtil.make_label("PARTY MODE", 36)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)

	_subtitle = UIUtil.make_label("Pass the phone around the group.", 20)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_subtitle)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	# Every Control between the ScrollContainer and the tiles has to be IGNORE,
	# or the first one that is not swallows the drag and the list can only be
	# scrolled from the thin gaps that happen to miss all of them. Container
	# inherits Control's STOP default, so the grid needs this as much as the
	# tiles do (GameSelect.gd carries the same note).
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_grid)

	var index := 0
	for game_id in PartyManager.get_roster():
		var tile := _build_tile(game_id)
		_grid.add_child(tile)
		_tiles.append(tile)
		UIUtil.pop_in(tile, index * 0.06)
		index += 1

	get_viewport().size_changed.connect(_relayout)
	_relayout()

## Every screen-derived size in one place, so the grid never sits off-centre or
## overflows on a narrow or a 20:9 phone.
func _relayout() -> void:
	var w := Field.width()
	var h := Field.height()
	var margin := 22.0
	var top := Field.SAFE_OUTER + 12.0

	_back_btn.position = Vector2(margin, top)
	_title.position = Vector2(0, top + 12)
	_title.size = Vector2(w, 56)
	_subtitle.position = Vector2(0, top + 66)
	_subtitle.size = Vector2(w, 32)

	var content_w := w - margin * 2.0
	var content_top := top + 112.0
	_scroll.position = Vector2(margin, content_top)
	_scroll.size = Vector2(content_w, h - content_top - Field.SAFE_OUTER - 12.0)

	var tile_w := (content_w - 16.0 * (COLUMNS - 1)) / COLUMNS
	for tile in _tiles:
		tile.custom_minimum_size = Vector2(tile_w, tile_w * 0.86)

func _build_tile(game_id: String) -> Control:
	var meta := PartyManager.get_party_game_meta(game_id)

	# Size is set by _relayout() from the live viewport, not fixed here.
	var tile := Control.new()
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", UIUtil.soft_panel_style(Palette.SURFACE, 24.0))
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	tile.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	tile.add_child(vbox)

	var icon := TextureRect.new()
	icon.texture = load(meta.get("icon", ""))
	icon.custom_minimum_size = Vector2(72, 72)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.pivot_offset = Vector2(36, 36)
	vbox.add_child(icon)
	UIUtil.idle_wobble(icon, randf() * 0.6)

	var name_label := UIUtil.make_label(meta.get("display_name", game_id), 24)
	vbox.add_child(name_label)

	var built := ResourceLoader.exists(meta.get("scene", ""))

	var badge := UIUtil.make_badge(
		"PLAY" if built else "SOON",
		Palette.PARTY_PRIMARY if built else Palette.SURFACE,
		Palette.SURFACE if built else Palette.INK
	)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(badge)

	# Anchored to the tile's right edge by anchors PLUS offsets. A fixed
	# .position assumed a 360px tile and would drift now that the width follows
	# the viewport; PRESET_TOP_RIGHT alone anchors the button's LEFT edge to the
	# tile's right edge so it hangs outside and overlaps its neighbour; and a
	# manual .position on top of a preset double-offsets (see CLAUDE.md).
	var rules_btn := UIUtil.make_soft_round_button("?", 38, Palette.SURFACE)
	rules_btn.anchor_left = 1.0
	rules_btn.anchor_right = 1.0
	rules_btn.offset_left = -46.0
	rules_btn.offset_right = -8.0
	rules_btn.offset_top = 8.0
	rules_btn.offset_bottom = 46.0
	rules_btn.pressed.connect(func(): _show_rules(game_id))
	tile.add_child(rules_btn)

	# The whole tile is the tap target, not just the PLAY badge above -- see
	# GameSelect.gd's matching comment for why only InputEventScreenTouch is
	# checked (emulate_touch_from_mouse=true would otherwise double-fire this).
	if built:
		tile.gui_input.connect(func(event: InputEvent):
			if event is InputEventScreenTouch and event.pressed:
				UIUtil.punch(tile)
				_on_tile_pressed(game_id)
		)

	return tile

func _on_tile_pressed(game_id: String) -> void:
	if not SaveManager.has_seen_party_rules(game_id):
		var card := RulesCard.new()
		add_child(card)
		var meta := PartyManager.get_party_game_meta(game_id)
		card.show_rules(meta.get("display_name", game_id), meta.get("rules_text", ""), meta.get("icon", ""))
		SaveManager.mark_party_rules_seen(game_id)
		card.dismissed.connect(func(): _proceed_to_launch(game_id))
	else:
		_proceed_to_launch(game_id)

## A couple of party games need one value picked before they load (Dice
## Roller's dice count, Movie Guess's era/language/timer) -- named special
## cases here rather than a general "pre-launch config" mechanism nothing
## else needs yet. Runs on every launch, not just first-play like RulesCard,
## since these are per-session choices.
func _proceed_to_launch(game_id: String) -> void:
	if game_id == "dice_roller":
		var prompt := DiceCountPrompt.new()
		add_child(prompt)
		prompt.show_prompt(SaveManager.party_dice_count)
		prompt.confirmed.connect(func(count: int):
			SaveManager.set_party_dice_count(count)
			_launch(game_id)
		)
	elif game_id == "movie_guess":
		var prompt := MovieGuessSetupPrompt.new()
		add_child(prompt)
		prompt.show_prompt(SaveManager.get_party_filter(game_id))
		prompt.confirmed.connect(func(): _launch(game_id))
	else:
		_launch(game_id)

func _show_rules(game_id: String) -> void:
	var card := RulesCard.new()
	add_child(card)
	var meta := PartyManager.get_party_game_meta(game_id)
	card.show_rules(meta.get("display_name", game_id), meta.get("rules_text", ""), meta.get("icon", ""))

func _launch(game_id: String) -> void:
	PartyManager.pending_game_id = game_id
	UIUtil.fade_to_scene(get_tree(), "res://shell/party_host/PartyHost.tscn")
