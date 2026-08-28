extends Control
## Main Menu — first screen on cold start. PLAY is the dominant element;
## Settings gear top-left, Remove Ads button, no login/splash gate.

func _ready() -> void:
	UIUtil.full_rect_bg(self, Palette.BACKGROUND)
	GameManager.clear_session_tally()

	var settings_btn := UIUtil.make_button("⚙", 28, Palette.SURFACE)
	settings_btn.custom_minimum_size = Vector2(64, 64)
	settings_btn.position = Vector2(24, 24)
	settings_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://shell/settings/Settings.tscn"))
	add_child(settings_btn)

	var title := UIUtil.make_label("FACE OFF", 72)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(0, 90)
	title.size = Vector2(1280, 100)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var subtitle := UIUtil.make_label("Two players. One phone. No wifi.", 22)
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.position = Vector2(0, 180)
	subtitle.size = Vector2(1280, 40)
	add_child(subtitle)

	var play_btn := UIUtil.make_button("▶  PLAY", 40, Palette.SUCCESS)
	play_btn.custom_minimum_size = Vector2(420, 120)
	play_btn.set_anchors_preset(Control.PRESET_CENTER)
	play_btn.position = Vector2(640 - 210, 360 - 60)
	play_btn.pressed.connect(_on_play_pressed)
	add_child(play_btn)

	var remove_ads_btn := UIUtil.make_button(
		"Ads Removed ✓" if SaveManager.ad_free else "★ REMOVE ADS", 22
	)
	remove_ads_btn.custom_minimum_size = Vector2(280, 64)
	remove_ads_btn.position = Vector2(640 - 140, 520)
	remove_ads_btn.disabled = SaveManager.ad_free
	remove_ads_btn.pressed.connect(_on_remove_ads_pressed)
	add_child(remove_ads_btn)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://shell/game_select/GameSelect.tscn")

func _on_remove_ads_pressed() -> void:
	# TODO: wire to the platform IAP flow (Godot Android IAP plugin / StoreKit).
	# Never blocks play; this is a placeholder confirmation only.
	SaveManager.set_ad_free(true)
	get_tree().change_scene_to_file("res://shell/main_menu/MainMenu.tscn")
