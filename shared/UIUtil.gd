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

## A soft top-to-bottom gradient background, for the shell's smooth/clean
## look (as opposed to the flat sticker grounds games render with). Same
## call shape as full_rect_bg -- drop-in replacement on shell screens.
static func gradient_bg(parent: Control, top_color: Color, bottom_color: Color) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, top_color)
	gradient.set_color(1, bottom_color)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 2
	tex.height = 512

	var bg := TextureRect.new()
	bg.texture = tex
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	parent.move_child(bg, 0)
	return bg

## A soft blurred glow, e.g. behind a mascot or hero element -- radial,
## fading to transparent, no hard edge. Purely decorative (ignores input).
static func soft_glow(parent: Control, color: Color, diameter: float = 240.0) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color, 0.35))
	gradient.set_color(1, Color(color, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128

	var glow := TextureRect.new()
	glow.texture = tex
	glow.custom_minimum_size = Vector2(diameter, diameter)
	glow.size = Vector2(diameter, diameter)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(glow)
	return glow

## A soft, borderless rounded panel style -- the shell's "smooth card" look:
## no hard outline (unlike the sticker style's thick ink edge), just a
## gentle drop shadow. Used for shell cards/tiles/panels.
static func soft_panel_style(bg_color: Color = Palette.SURFACE, corner: float = 28.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(int(corner))
	style.shadow_color = Color(0, 0, 0, 0.10)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	return style

## A smooth, borderless button for shell screens -- rounded corners and a
## soft shadow, no thick ink outline (that's reserved for the sticker style
## games/match-HUD use). Same call shape as make_button.
static func make_soft_button(text: String, font_size: int = 28, bg_color: Color = Palette.ACCENT, text_color: Color = Palette.INK) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 84)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color)
	btn.add_theme_color_override("font_pressed_color", text_color)

	var style := soft_panel_style(bg_color, 28.0)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, style)

	wire_bounce(btn)
	return btn

## A static, non-interactive pill label -- mouse_filter IGNORE so it never
## intercepts taps meant for whatever it's layered on top of (e.g. a tile
## that's the actual tap target). Built from a plain PanelContainer + Label,
## not a Button: a Button resolves its rendered font colour from a
## combination of hover/pressed/focus state, and some combination reliably
## ends up uncovered in this project's Web/WASM export, rendering blank text
## (see MovieGuessSetupPrompt's chip fix) -- a Panel has one stylebox slot and
## a Label one font colour, so there's nothing left to get wrong.
static func make_badge(text: String, bg_color: Color, text_color: Color) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := soft_panel_style(bg_color, 16.0)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	badge.add_theme_stylebox_override("panel", style)
	var label := make_label(text, 22, text_color)
	badge.add_child(label)
	return badge

## A circular soft icon button (back/close/settings) matching make_soft_button.
static func make_soft_round_button(text: String, diameter: float = 56.0, bg_color: Color = Palette.SURFACE) -> Button:
	var btn := make_soft_button(text, 22, bg_color)
	btn.custom_minimum_size = Vector2(diameter, diameter)
	btn.size = Vector2(diameter, diameter)
	var style: StyleBoxFlat = btn.get_theme_stylebox("normal").duplicate()
	style.set_corner_radius_all(int(diameter * 0.5))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, style)
	return btn

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

## A quick scale-punch for a value that just changed -- a stepper count, a
## revealed result, a buzzer. Same shape as MatchHost's score-pill pop
## (1.25x back-out, settle to 1.0); pulled out here so every new "the number
## just changed" moment gets the same feel without re-deriving it per game.
## Waits a frame first so pivot_offset reflects the post-text-change size,
## same reasoning as pop_in above.
static func punch(node: Control) -> void:
	await node.get_tree().process_frame
	node.pivot_offset = node.size * 0.5
	var t := node.create_tween()
	t.tween_property(node, "scale", Vector2(1.25, 1.25), 0.1) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Web-only: toggles a class on the HTML shell's <body>, so the rotate-prompt
## gate in export_presets.example.cfg's html/head_include only fires while an
## actual match is running -- shell/menu screens are portrait-friendly and
## should never be blocked by it (see MatchHost.gd/PartyHost.gd, the only
## callers). A no-op on every other platform; JavaScriptBridge has nothing to
## talk to there.
static func set_web_match_active(active: bool) -> void:
	if OS.get_name() != "Web":
		return
	var js := "document.body.classList.add('match-active')" if active else "document.body.classList.remove('match-active')"
	JavaScriptBridge.eval(js)

## Cross-fades to a new scene instead of an instant cut, per CLAUDE.md's
## "Screen transitions <=200ms" rule -- every change_scene_to_file() call in
## the app should route through this rather than calling it directly.
## The overlay is added directly under the tree's root (not the current
## scene) so it survives change_scene_to_file's swap; the freshly-loaded
## scene is appended as root's newest child right after the swap, which
## would draw over our overlay, so it's re-parented to the end of root's
## children before fading back out.
static func fade_to_scene(tree: SceneTree, scene_path: String, duration: float = 0.1) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(Palette.INK, 0.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	tree.root.add_child(overlay)

	var fade_in := overlay.create_tween()
	fade_in.tween_property(overlay, "color:a", 1.0, duration)
	await fade_in.finished

	tree.change_scene_to_file(scene_path)
	await tree.process_frame
	tree.root.move_child(overlay, tree.root.get_child_count() - 1)

	var fade_out := overlay.create_tween()
	fade_out.tween_property(overlay, "color:a", 0.0, duration)
	await fade_out.finished
	overlay.queue_free()
