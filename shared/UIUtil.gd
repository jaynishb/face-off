extends Node
class_name UIUtil
## Small shared helpers so every shell/game screen gets the same button feel
## and background treatment without duplicating boilerplate. Day 4's polish
## pass replaces the flat StyleBoxFlat treatment with real art; the bounce
## and layout behavior here should carry through unchanged.

static func full_rect_bg(parent: Control, color: Color) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = color
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	parent.move_child(bg, 0)
	return bg

static func make_button(text: String, font_size: int = 28, bg_color: Color = Palette.ACCENT) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 84)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Palette.INK)
	btn.add_theme_color_override("font_hover_color", Palette.INK)
	btn.add_theme_color_override("font_pressed_color", Palette.INK)

	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(20)
	# Hard black edge + a soft drop shadow, matching the sticker look the games
	# draw with (see Juice.gd), so UI and gameplay read as one visual system.
	style.border_color = Palette.OUTLINE
	style.set_border_width_all(5)
	style.shadow_color = Color(0, 0, 0, 0.18)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 5)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)
	btn.add_theme_stylebox_override("disabled", style)

	wire_bounce(btn)
	return btn

## A circular icon button (exit, pause) -- the reference HUD style: a small
## floating disc rather than a control welded into a solid bar, so it works
## over any game's ground colour.
static func make_round_button(text: String, diameter: float = 56.0, bg_color: Color = Palette.SURFACE) -> Button:
	var btn := make_button(text, 22, bg_color)
	btn.custom_minimum_size = Vector2(diameter, diameter)
	btn.size = Vector2(diameter, diameter)
	var style: StyleBoxFlat = btn.get_theme_stylebox("normal").duplicate()
	style.set_corner_radius_all(int(diameter * 0.5))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, style)
	return btn

## A score pill in a player's colour, for the floating in-match HUD.
static func make_score_pill(player: int) -> Label:
	var lbl := make_label("0", 30, Palette.SURFACE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(96, 52)
	lbl.size = Vector2(96, 52)

	var style := StyleBoxFlat.new()
	style.bg_color = Palette.for_player(player)
	style.set_corner_radius_all(26)
	style.border_color = Palette.OUTLINE
	style.set_border_width_all(5)
	style.shadow_color = Color(0, 0, 0, 0.18)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 5)
	lbl.add_theme_stylebox_override("normal", style)
	return lbl

## Button press = scale to 0.92 and bounce back, per the motion rules — apply
## to any Button, hand-built or scene-authored, so the feel stays consistent.
static func wire_bounce(btn: Button) -> void:
	btn.button_down.connect(func():
		var t := btn.create_tween()
		t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.08)
	)
	btn.button_up.connect(func():
		var t := btn.create_tween()
		t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(btn, "scale", Vector2.ONE, 0.15)
	)
	btn.resized.connect(func(): btn.pivot_offset = btn.size * 0.5)

static func make_label(text: String, font_size: int = 24, color: Color = Palette.INK) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl

## A slight looping rock back and forth, staggered per-node via `delay` so a
## row of tiles/icons doesn't all wobble in lockstep -- "tiles have a slight
## idle wobble, stagger-animated" per the PRD's Game Select spec.
static func idle_wobble(node: CanvasItem, delay: float = 0.0) -> void:
	var t := node.create_tween()
	t.set_loops()
	t.tween_interval(delay)
	t.tween_property(node, "rotation", deg_to_rad(-4.0), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "rotation", deg_to_rad(4.0), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "rotation", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## A gentle continuous vertical float, e.g. for mascot idle animation.
static func idle_float(node: Control, amplitude: float = 8.0, duration: float = 1.4, delay: float = 0.0) -> void:
	var base_y: float = node.position.y
	var t := node.create_tween()
	t.set_loops()
	t.tween_interval(delay)
	t.tween_property(node, "position:y", base_y - amplitude, duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "position:y", base_y, duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Scale-in with overshoot -- used for tile/panel pop-in on screen load.
## Waits a frame before reading node.size since a freshly-added Container
## child may not have its final layout size yet.
static func pop_in(node: Control, delay: float = 0.0, target_scale: float = 1.0) -> void:
	node.scale = Vector2.ZERO
	await node.get_tree().process_frame
	node.pivot_offset = node.size * 0.5
	var t := node.create_tween()
	t.tween_interval(delay)
	t.tween_property(node, "scale", Vector2(target_scale, target_scale), 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Mount a Control subtree into one player's half, oriented so that player reads
## it right-way-up. Player 2's mount is rotated by PI (see Field.player_xform),
## which is what makes a shared phone lying flat between two people work at all.
##
## `build` is called once and must return a fresh Control laid out in PLAYER
## space -- (0,0) at that player's own top-left as they read it, extending to
## Field.half_size(). Call mirror_for_players() to get one copy per player.
##
## Two pitfalls are handled here so callers cannot reintroduce them:
##   * pivot_offset stays ZERO. The transform's origin IS the pivot, so adding a
##     centre pivot would double-offset -- and under PI rotation the offset is
##     negated, so the control flies off in the opposite direction from the usual
##     symptom and the cause is much harder to spot.
##   * mouse_filter is IGNORE. Each mount covers half the screen; left at a
##     Control's default STOP it would silently swallow every gameplay touch in
##     exactly one half, which reads as "the rotation broke input" and sends you
##     hunting in the wrong place.
## Content built inside must not combine set_anchors_preset() with a manual
## position either -- PRESET_FULL_RECT with no manual position is the one safe
## combination.
static func mount_for_player(parent: Node, player: int, build: Callable) -> Control:
	var mount := Control.new()
	mount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t: Transform2D = Field.player_xform(player)
	mount.position = t.origin
	mount.rotation = t.get_rotation()
	mount.pivot_offset = Vector2.ZERO
	mount.size = Field.half_size()
	parent.add_child(mount)
	var content: Control = build.call(player)
	if content:
		mount.add_child(content)
	return mount

## Anything a player has to READ -- a countdown, a win banner, a pause panel, a
## rules card -- must appear once per half or somebody reads it upside down.
## Both copies are built from the same callable and wired to the same handlers,
## so either player can act on it.
static func mirror_for_players(parent: Node, build: Callable) -> Array:
	return [
		mount_for_player(parent, 1, build),
		mount_for_player(parent, 2, build),
	]

## A round button carrying an icon from the art pack instead of an ASCII label.
## Falls back to `fallback_text` when the icon is missing, which is what keeps
## the shell usable before the art pack lands (and readable if one file is ever
## dropped) -- the ASCII labels are not decoration, they are the degraded mode.
static func make_icon_button(
	icon_name: String, fallback_text: String, diameter: float = 56.0,
	bg_color: Color = Palette.SURFACE,
) -> Button:
	var btn := make_round_button("", diameter, bg_color)
	var texture := Art.icon(icon_name)
	if texture == null:
		btn.text = fallback_text
		return btn
	var icon := TextureRect.new()
	icon.texture = texture
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# A TextureRect defaults to EXPAND_KEEP_SIZE, which reports the SOURCE
	# texture's size as the control's minimum size. A 256x256 icon inside a 52px
	# disc therefore lays itself out at 256px, and its strokes land entirely
	# outside the button -- the button renders as an empty circle. Caught by
	# looking at the rendered screen; nothing about it errors.
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Full-rect with no manual position: the one anchors-preset combination that
	# does not double-offset (see CLAUDE.md).
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	var pad := diameter * 0.26
	icon.offset_left = pad
	icon.offset_top = pad
	icon.offset_right = -pad
	icon.offset_bottom = -pad
	btn.add_child(icon)
	return btn

## Prefix an ordinary text button with a small icon, for the menu-style rows on
## Settings and the pause panel.
static func add_button_icon(btn: Button, icon_name: String) -> void:
	var texture := Art.icon(icon_name)
	if texture == null:
		return
	btn.icon = texture
	btn.expand_icon = true
	btn.add_theme_constant_override("icon_max_width", 28)
	btn.add_theme_constant_override("h_separation", 12)
