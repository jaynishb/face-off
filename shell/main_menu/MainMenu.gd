extends Control
## Main Menu — first screen on cold start. PLAY is the dominant element;
## Settings gear top-right, Remove Ads button, no login/splash gate. Two mascot
## blobs idle-animate in the middle and react when PLAY is pressed, per the PRD's
## Main Menu wireframe.
##
## Single-orientation: one person is navigating a menu, so unlike the in-match
## chrome nothing here is mirrored. It is laid out for portrait, in proportions
## of the live viewport rather than fixed pixel rows, so it survives a phone
## browser resizing the canvas after load.

var _p1_mascot: TextureRect
var _p2_mascot: TextureRect
var _settings_btn: Button
var _title: Label
var _subtitle: Label
var _play_btn: Button
var _party_btn: Button
var _remove_ads_btn: Button
var _mascot_size := Vector2(150, 164)
var _mascot_floats: Array[Tween] = []

func _ready() -> void:
	UIUtil.full_rect_bg(self, Palette.BACKGROUND)
	GameManager.clear_session_tally()
	AudioManager.play_menu_music()

	# The gear is a real icon from the art pack, with "SET" as the fallback label.
	# The fallback is not decoration: the default engine font has no coverage for
	# gear/emoji codepoints and silently draws a tofu box, so a missing icon must
	# degrade to ASCII rather than to a symbol glyph (see CLAUDE.md).
	_settings_btn = UIUtil.make_icon_button("gear", "SET", 64, Palette.SURFACE)
	_settings_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://shell/settings/Settings.tscn"))
	add_child(_settings_btn)

	# NOTE: these controls rely on default (top-left) anchors with an absolute
	# .position -- do NOT add set_anchors_preset() here. Godot computes a
	# non-full-rect anchor's offset additively with .position, so combining e.g.
	# PRESET_CENTER with a hand-computed absolute position double-offsets the
	# control (caught by an actual HTML5 export run -- see CLAUDE.md).
	_title = UIUtil.make_label("FACE OFF", 64)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)
	UIUtil.pop_in(_title, 0.0)

	_subtitle = UIUtil.make_label("Two players. One phone. No wifi.", 22)
	add_child(_subtitle)

	# The generated mascots face the viewer, so the P2 copy is mirrored in code
	# rather than shipped as a third file -- that also guarantees the two are
	# exactly the same size and weight, which the symmetry rule requires.
	_p1_mascot = _build_mascot(_mascot_texture(1), false)
	_p2_mascot = _build_mascot(_mascot_texture(2), true)

	_play_btn = UIUtil.make_button("2 PLAYERS", 38, Palette.SUCCESS)
	_play_btn.pressed.connect(_on_play_pressed)
	add_child(_play_btn)
	UIUtil.pop_in(_play_btn, 0.1)

	# Party Mode is a second, group-play roster rather than a variant of the 1v1
	# games, so it gets its own entry point rather than a tab inside Game Select.
	_party_btn = UIUtil.make_button("PARTY MODE", 28, Palette.PARTY_PRIMARY)
	_party_btn.add_theme_color_override("font_color", Palette.SURFACE)
	_party_btn.add_theme_color_override("font_hover_color", Palette.SURFACE)
	_party_btn.add_theme_color_override("font_pressed_color", Palette.SURFACE)
	_party_btn.pressed.connect(_on_party_pressed)
	add_child(_party_btn)
	UIUtil.pop_in(_party_btn, 0.15)

	_remove_ads_btn = UIUtil.make_button(
		"ADS REMOVED" if SaveManager.ad_free else "REMOVE ADS", 22
	)
	_remove_ads_btn.disabled = SaveManager.ad_free
	_remove_ads_btn.pressed.connect(_on_remove_ads_pressed)
	add_child(_remove_ads_btn)

	get_viewport().size_changed.connect(_relayout)
	_relayout()

## Every screen-derived position in one place, recomputed whenever the viewport
## actually changes -- a phone browser resizes its canvas after load.
func _relayout() -> void:
	var w := Field.width()
	var h := Field.height()

	_settings_btn.position = Vector2(w - 64 - 24, Field.SAFE_OUTER + 12)

	_title.position = Vector2(0, h * 0.08)
	_title.size = Vector2(w, 90)

	_subtitle.position = Vector2(0, h * 0.08 + 78)
	_subtitle.size = Vector2(w, 40)

	# Mascots face each other across the centre of the screen, at a size that
	# follows the screen rather than a fixed 150px.
	_mascot_size = Vector2(w * 0.26, w * 0.285)
	var mascot_y := h * 0.34
	for mascot: TextureRect in [_p1_mascot, _p2_mascot]:
		mascot.custom_minimum_size = _mascot_size
		mascot.size = _mascot_size
		mascot.pivot_offset = _mascot_size * 0.5
	_p1_mascot.position = Vector2(w * 0.5 - _mascot_size.x - 14, mascot_y)
	_p2_mascot.position = Vector2(w * 0.5 + 14, mascot_y)

	# The idle float has to be (re)started AFTER the mascots are positioned: it
	# captures its base y once, so starting it in _ready() -- before the first
	# _relayout() -- left both mascots bobbing around y=0, drawn on top of the
	# title. Restarted on every relayout for the same reason.
	for tween in _mascot_floats:
		if is_instance_valid(tween):
			tween.kill()
	_mascot_floats = [
		UIUtil.idle_float(_p1_mascot, 10.0, 1.6, 0.0),
		UIUtil.idle_float(_p2_mascot, 10.0, 1.6, 0.3),
	]

	var play_size := Vector2(minf(w - 72, 460), 116)
	_play_btn.custom_minimum_size = play_size
	_play_btn.size = play_size
	_play_btn.position = Vector2((w - play_size.x) * 0.5, h * 0.62)

	# The three buttons stack from the same anchor, each below the last, so a
	# size change anywhere in the column cannot leave a gap or an overlap.
	var party_size := Vector2(minf(w - 96, 420), 84)
	_party_btn.custom_minimum_size = party_size
	_party_btn.size = party_size
	var party_y := h * 0.62 + play_size.y + 20.0
	_party_btn.position = Vector2((w - party_size.x) * 0.5, party_y)

	var ads_size := Vector2(minf(w - 160, 300), 64)
	_remove_ads_btn.custom_minimum_size = ads_size
	_remove_ads_btn.size = ads_size
	_remove_ads_btn.position = Vector2((w - ads_size.x) * 0.5, party_y + party_size.y + 20.0)

## Generated mascot if the art pack is installed, otherwise the hand-authored SVG
## the project shipped with -- the menu should never come up empty-handed.
func _mascot_texture(player: int) -> Texture2D:
	var generated := Art.shell("mascot_p%d" % player)
	if generated:
		return generated
	var svg := "res://shared/art/mascot_p%d.svg" % player
	return load(svg) if ResourceLoader.exists(svg) else null

func _build_mascot(texture: Texture2D, flipped: bool) -> TextureRect:
	var mascot := TextureRect.new()
	mascot.texture = texture
	mascot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mascot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
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

func _on_party_pressed() -> void:
	_react_mascots()
	await get_tree().create_timer(0.2).timeout
	get_tree().change_scene_to_file("res://shell/party_select/PartyGameSelect.tscn")

func _on_remove_ads_pressed() -> void:
	# TODO: wire to the platform IAP flow (Godot Android IAP plugin / StoreKit).
	# Never blocks play; this is a placeholder confirmation only.
	SaveManager.set_ad_free(true)
	get_tree().change_scene_to_file("res://shell/main_menu/MainMenu.tscn")
