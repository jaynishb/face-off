extends Control
## Settings — grouped sections with toggle pills, matching the reference layout:
## GENERAL (audio + haptics), MORE (rate / remove ads / contact), ACCOUNT
## (restore purchases, privacy policy), with the version pinned at the bottom.
##
## Single-orientation: one person is changing a setting, so nothing here is
## mirrored. Portrait, laid out against the live viewport.

const VERSION := "0.1.0-dev"
const PRIVACY_POLICY_URL := "https://example.com/faceoff/privacy" # TODO: replace with the real hosted URL before submission (see PRIVACY_POLICY.md)

var _back_btn: Button
var _title: Label
var _scroll: ScrollContainer
var _column: VBoxContainer

func _ready() -> void:
	UIUtil.full_rect_bg(self, Palette.BACKGROUND)
	AudioManager.play_menu_music()

	_back_btn = UIUtil.make_icon_button("back", "<", 64, Palette.SURFACE)
	_back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://shell/main_menu/MainMenu.tscn"))
	add_child(_back_btn)

	_title = UIUtil.make_label("SETTINGS", 36)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_scroll)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 12)
	_scroll.add_child(_column)

	_column.add_child(_make_section_header("GENERAL"))
	_column.add_child(_make_toggle_row("Music", "music", SaveManager.music_enabled, func(v): AudioManager.set_music_enabled(v)))
	_column.add_child(_make_toggle_row("Sound FX", "sound_on", SaveManager.sfx_enabled, func(v): AudioManager.set_sfx_enabled(v)))
	_column.add_child(_make_toggle_row("Haptics", "star", SaveManager.haptics_enabled, func(v): SaveManager.set_haptics_enabled(v)))

	_column.add_child(_make_section_header("MORE"))
	var ads_btn := UIUtil.make_button(
		"ADS REMOVED" if SaveManager.ad_free else "REMOVE ADS", 22
	)
	UIUtil.add_button_icon(ads_btn, "star")
	ads_btn.disabled = SaveManager.ad_free
	ads_btn.pressed.connect(func():
		SaveManager.set_ad_free(true)
		get_tree().change_scene_to_file("res://shell/settings/Settings.tscn")
	)
	_column.add_child(ads_btn)

	_column.add_child(_make_section_header("ACCOUNT"))
	var restore_btn := UIUtil.make_button("RESTORE PURCHASES", 18, Palette.SURFACE)
	UIUtil.add_button_icon(restore_btn, "restart")
	restore_btn.pressed.connect(_on_restore_pressed)
	_column.add_child(restore_btn)

	var privacy_btn := UIUtil.make_button("PRIVACY POLICY", 18, Palette.SURFACE)
	UIUtil.add_button_icon(privacy_btn, "question")
	privacy_btn.pressed.connect(_on_privacy_pressed)
	_column.add_child(privacy_btn)

	var version_label := UIUtil.make_label("v%s" % VERSION, 16)
	version_label.modulate.a = 0.6
	version_label.custom_minimum_size = Vector2(0, 44)
	_column.add_child(version_label)

	get_viewport().size_changed.connect(_relayout)
	_relayout()

func _relayout() -> void:
	var w := Field.width()
	var h := Field.height()
	var margin := 26.0
	var top := Field.SAFE_OUTER + 12.0

	_back_btn.position = Vector2(margin, top)
	_title.position = Vector2(0, top + 12)
	_title.size = Vector2(w, 56)

	var content_w := minf(w - margin * 2.0, 460.0)
	_scroll.position = Vector2((w - content_w) * 0.5, top + 88)
	_scroll.size = Vector2(content_w, h - (top + 88) - Field.SAFE_OUTER - 12.0)
	_column.custom_minimum_size = Vector2(content_w, 0)

## A section band, so the list reads as three grouped panels rather than one long
## run of controls.
func _make_section_header(text: String) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.ACCENT
	style.set_corner_radius_all(14)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var label := UIUtil.make_label(text, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel

func _make_toggle_row(label_text: String, icon_name: String, initial: bool, on_toggled: Callable) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.SURFACE
	style.set_corner_radius_all(16)
	style.set_content_margin_all(10)
	style.border_color = Palette.OUTLINE
	style.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var icon_texture := Art.icon(icon_name)
	if icon_texture:
		var icon := TextureRect.new()
		icon.texture = icon_texture
		icon.custom_minimum_size = Vector2(30, 30)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)

	var label := UIUtil.make_label(label_text, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var check := CheckButton.new()
	check.button_pressed = initial
	check.toggled.connect(on_toggled)
	row.add_child(check)

	return panel

func _on_restore_pressed() -> void:
	# TODO: wire to platform purchase restore (Android IAP plugin / StoreKit).
	pass

func _on_privacy_pressed() -> void:
	OS.shell_open(PRIVACY_POLICY_URL)
