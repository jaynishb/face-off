extends Control
## Settings — SFX/Music/Haptics toggles, Remove Ads / Ads Removed state,
## Restore Purchase, Privacy Policy link, version number. Minimal by design.

const VERSION := "0.1.0-dev"

func _ready() -> void:
	UIUtil.full_rect_bg(self, Palette.BACKGROUND)

	var back_btn := UIUtil.make_button("←", 28, Palette.SURFACE)
	back_btn.custom_minimum_size = Vector2(64, 64)
	back_btn.position = Vector2(24, 24)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://shell/main_menu/MainMenu.tscn"))
	add_child(back_btn)

	var title := UIUtil.make_label("SETTINGS", 40)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(0, 24)
	title.size = Vector2(1280, 60)
	add_child(title)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	vbox.position = Vector2(440, 140)
	vbox.size = Vector2(400, 400)
	add_child(vbox)

	vbox.add_child(_make_toggle_row("SFX", SaveManager.sfx_enabled, func(v): AudioManager.set_sfx_enabled(v)))
	vbox.add_child(_make_toggle_row("Music", SaveManager.music_enabled, func(v): AudioManager.set_music_enabled(v)))
	vbox.add_child(_make_toggle_row("Haptics", SaveManager.haptics_enabled, func(v): SaveManager.set_haptics_enabled(v)))

	var ads_btn := UIUtil.make_button(
		"Ads Removed ✓" if SaveManager.ad_free else "★ REMOVE ADS", 22
	)
	ads_btn.disabled = SaveManager.ad_free
	ads_btn.pressed.connect(func():
		SaveManager.set_ad_free(true)
		get_tree().change_scene_to_file("res://shell/settings/Settings.tscn")
	)
	vbox.add_child(ads_btn)

	var restore_btn := UIUtil.make_button("Restore Purchase", 20, Palette.SURFACE)
	restore_btn.pressed.connect(_on_restore_pressed)
	vbox.add_child(restore_btn)

	var version_label := UIUtil.make_label("v%s" % VERSION, 16)
	version_label.modulate.a = 0.6
	vbox.add_child(version_label)

func _make_toggle_row(label_text: String, initial: bool, on_toggled: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var label := UIUtil.make_label(label_text, 26)
	label.custom_minimum_size = Vector2(160, 0)
	row.add_child(label)

	var check := CheckButton.new()
	check.button_pressed = initial
	check.toggled.connect(on_toggled)
	row.add_child(check)

	return row

func _on_restore_pressed() -> void:
	# TODO: wire to platform purchase restore (Android IAP plugin / StoreKit).
	pass
