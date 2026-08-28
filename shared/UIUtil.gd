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
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)

	wire_bounce(btn)
	return btn

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
