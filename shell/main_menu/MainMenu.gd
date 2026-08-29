extends Control
## Main Menu — first screen on cold start. PLAY is the dominant element;
## Settings gear top-left, Remove Ads button, no login/splash gate.
## Two mascot blobs idle-animate at the bottom and react when PLAY is
## pressed, per the PRD's Main Menu wireframe.

const MASCOT_SIZE := Vector2(150, 164)

var _p1_mascot: TextureRect
var _p2_mascot: TextureRect

func _ready() -> void:
	UIUtil.full_rect_bg(self, Palette.BACKGROUND)
	GameManager.clear_session_tally()
	AudioManager.play_menu_music()

	# Plain ASCII text, not a symbol glyph -- the default engine font has no
	# coverage for gear/emoji codepoints and silently draws a tofu box
	# instead (same class of bug fixed for game-tile emoji; see CLAUDE.md).
	var settings_btn := UIUtil.make_button("SET", 20, Palette.SURFACE)
	settings_btn.custom_minimum_size = Vector2(64, 64)
	settings_btn.position = Vector2(24, 24)
	settings_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://shell/settings/Settings.tscn"))
	add_child(settings_btn)

	# NOTE: these controls rely on default (top-left) anchors with an absolute
	# .position -- do NOT add set_anchors_preset() here. Godot computes a
	# non-full-rect anchor's offset additively with .position, so combining
	# e.g. PRESET_CENTER with a hand-computed absolute position double-offsets
	# the control (caught by an actual HTML5 export run -- see CLAUDE.md).
	var title := UIUtil.make_label("FACE OFF", 68)
	title.position = Vector2(0, 44)
	title.size = Vector2(1280, 90)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	UIUtil.pop_in(title, 0.0)

	var subtitle := UIUtil.make_label("Two players. One phone. No wifi.", 22)
	subtitle.position = Vector2(0, 128)
	subtitle.size = Vector2(1280, 40)
	add_child(subtitle)

	var play_btn := UIUtil.make_button("PLAY", 40, Palette.SUCCESS)
	play_btn.custom_minimum_size = Vector2(420, 120)
	play_btn.position = Vector2(640 - 210, 210)
	play_btn.pressed.connect(_on_play_pressed)
	add_child(play_btn)
	UIUtil.pop_in(play_btn, 0.1)

	var remove_ads_btn := UIUtil.make_button(
		"ADS REMOVED" if SaveManager.ad_free else "REMOVE ADS", 22
	)
	remove_ads_btn.custom_minimum_size = Vector2(280, 64)
	remove_ads_btn.position = Vector2(640 - 140, 356)
	remove_ads_btn.disabled = SaveManager.ad_free
	remove_ads_btn.pressed.connect(_on_remove_ads_pressed)
	add_child(remove_ads_btn)

	_p1_mascot = _build_mascot("res://shared/art/mascot_p1.svg", Vector2(640 - 220, 515), false)
	_p2_mascot = _build_mascot("res://shared/art/mascot_p2.svg", Vector2(640 + 70, 515), true)
	UIUtil.idle_float(_p1_mascot, 10.0, 1.6, 0.0)
	UIUtil.idle_float(_p2_mascot, 10.0, 1.6, 0.3)

func _build_mascot(texture_path: String, pos: Vector2, flipped: bool) -> TextureRect:
	var mascot := TextureRect.new()
	mascot.texture = load(texture_path)
	mascot.custom_minimum_size = MASCOT_SIZE
	mascot.size = MASCOT_SIZE
	mascot.position = pos
	mascot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mascot.pivot_offset = MASCOT_SIZE * 0.5
	if flipped:
		mascot.scale.x = -1.0
	add_child(mascot)
	return mascot

func _react_mascots() -> void:
	for mascot: TextureRect in [_p1_mascot, _p2_mascot]:
		var flip_sign := -1.0 if mascot.scale.x < 0.0 else 1.0
		var t: Tween = mascot.create_tween()
		t.tween_property(mascot, "scale", Vector2(flip_sign * 1.15, 0.85), 0.1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(mascot, "scale", Vector2(flip_sign, 1.0), 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_play_pressed() -> void:
	_react_mascots()
	await get_tree().create_timer(0.2).timeout
	get_tree().change_scene_to_file("res://shell/game_select/GameSelect.tscn")

func _on_remove_ads_pressed() -> void:
	# TODO: wire to the platform IAP flow (Godot Android IAP plugin / StoreKit).
	# Never blocks play; this is a placeholder confirmation only.
	SaveManager.set_ad_free(true)
	get_tree().change_scene_to_file("res://shell/main_menu/MainMenu.tscn")
