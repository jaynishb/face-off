extends PartyGame
## Spin the Wheel — set a segment count, tap SPIN, and a hand-drawn wedge
## wheel decelerates onto one segment. A "who goes first / who's it" picker;
## the purest randomizer of the four party games, needing no content file.

const MIN_SEGMENTS := 2
const MAX_SEGMENTS := 8
const WHEEL_RADIUS := 150.0
const WEDGE_COLORS := [Palette.PLAYER_1, Palette.PLAYER_2, Palette.ACCENT, Palette.SUCCESS]

var _segment_count: int = 4
var _rotation := 0.0
var _spinning := false
var _spin_elapsed := 0.0
var _spin_duration := 0.0
var _spin_start_rotation := 0.0
var _spin_target_rotation := 0.0
var _winning_index := -1

var _wheel_center := Vector2.ZERO
var _seg_label: Label
var _minus_btn: Button
var _plus_btn: Button
var _spin_btn: Button
var _result_label: Label

var _content_top := 0.0

func _init() -> void:
	game_id = "spin_the_wheel"
	display_name = "Spin the Wheel"
	rules_text = "Set how many players.\nTap SPIN.\nWhoever it lands on is picked."
	theme_bg = Palette.BG_SPIN_WHEEL

func setup(_config: Dictionary) -> void:
	_segment_count = clampi(SaveManager.party_wheel_segments, MIN_SEGMENTS, MAX_SEGMENTS)
	set_process(true)

	var stepper_label := UIUtil.make_label("PLAYERS", 18)
	add_child(stepper_label)
	_stepper_label_ref = stepper_label

	_minus_btn = UIUtil.make_soft_round_button("-", 48, Palette.SURFACE)
	_minus_btn.pressed.connect(func(): _change_segments(-1))
	add_child(_minus_btn)

	_seg_label = UIUtil.make_label(str(_segment_count), 28)
	_seg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_seg_label)

	_plus_btn = UIUtil.make_soft_round_button("+", 48, Palette.SURFACE)
	_plus_btn.pressed.connect(func(): _change_segments(1))
	add_child(_plus_btn)

	_spin_btn = UIUtil.make_soft_button("SPIN", 28, Palette.SUCCESS)
	_spin_btn.pressed.connect(_on_spin_pressed)
	add_child(_spin_btn)

	_result_label = UIUtil.make_label("TAP SPIN", 26)
	add_child(_result_label)

	layout()

var _stepper_label_ref: Label

func layout() -> void:
	if not _spin_btn:
		return
	var mid := Field.center().x
	# Centred in the play area rather than pinned to its top -- see
	# PartyGame.content_top(). The height is this game's own content block.
	_content_top = content_top(620.0)
	var top := _content_top

	_stepper_label_ref.position = Vector2(mid - 90, top)
	_minus_btn.position = Vector2(mid - 100, top + 26)
	_seg_label.position = Vector2(mid - 52, top + 26)
	_seg_label.size = Vector2(104, 48)
	_plus_btn.position = Vector2(mid + 52, top + 26)

	_wheel_center = Vector2(mid, top + 280.0)

	_spin_btn.position = Vector2(mid - 140, top + 450)
	_result_label.position = Vector2(mid - 100, top + 550)

func _change_segments(delta: int) -> void:
	if _spinning:
		return
	_segment_count = clampi(_segment_count + delta, MIN_SEGMENTS, MAX_SEGMENTS)
	SaveManager.set_party_wheel_segments(_segment_count)
	_seg_label.text = str(_segment_count)
	UIUtil.punch(_seg_label)
	_winning_index = -1
	_result_label.text = "TAP SPIN"
	queue_redraw()

func _on_spin_pressed() -> void:
	if _spinning:
		return
	_spinning = true
	_winning_index = -1
	_result_label.text = "..."
	_spin_elapsed = 0.0
	_spin_duration = randf_range(2.6, 3.4)
	_spin_start_rotation = _rotation
	var extra_turns := randi_range(4, 7)
	var random_offset := randf() * TAU
	_spin_target_rotation = _rotation + TAU * extra_turns + random_offset
	AudioManager.play_sfx("tap")

func _process(delta: float) -> void:
	if not _spinning:
		return
	_spin_elapsed += delta
	var t := clampf(_spin_elapsed / _spin_duration, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 3.0) # cubic ease-out -- fast start, gentle settle
	_rotation = lerpf(_spin_start_rotation, _spin_target_rotation, eased)
	if t >= 1.0:
		_spinning = false
		_rotation = _spin_target_rotation
		_resolve_winner()
	queue_redraw()

func _resolve_winner() -> void:
	var seg_angle := TAU / _segment_count
	_winning_index = int(floor(wrapf(-_rotation, 0.0, TAU) / seg_angle)) % _segment_count
	_result_label.text = "PLAYER %d" % (_winning_index + 1)
	UIUtil.punch(_result_label)
	AudioManager.play_sfx("win")
	if SaveManager.haptics_enabled:
		Input.vibrate_handheld(40)

func _draw() -> void:
	if _wheel_center == Vector2.ZERO:
		return
	var seg_angle := TAU / _segment_count
	var font := ThemeDB.fallback_font
	var font_size := 24

	for i in range(_segment_count):
		var a0 := -PI * 0.5 + _rotation + i * seg_angle
		var a1 := a0 + seg_angle
		var color: Color = WEDGE_COLORS[i % WEDGE_COLORS.size()]
		var points := PackedVector2Array([_wheel_center])
		var subdivisions := maxi(2, int(ceil(seg_angle / 0.3)))
		for s in range(subdivisions + 1):
			var a := lerpf(a0, a1, float(s) / subdivisions)
			points.append(_wheel_center + Vector2(cos(a), sin(a)) * WHEEL_RADIUS)
		draw_colored_polygon(points, color)

		var mid_angle := (a0 + a1) * 0.5
		var label_pos := _wheel_center + Vector2(cos(mid_angle), sin(mid_angle)) * (WHEEL_RADIUS * 0.62)
		var text := "P%d" % (i + 1)
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, label_pos - text_size * 0.5 + Vector2(0, text_size.y * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Palette.SURFACE)

	draw_arc(_wheel_center, WHEEL_RADIUS, 0.0, TAU, 64, Palette.OUTLINE, 5.0)
	draw_circle(_wheel_center, 12.0, Palette.SURFACE)
	draw_arc(_wheel_center, 12.0, 0.0, TAU, 24, Palette.OUTLINE, 3.0)

	# Fixed pointer, top of the wheel, always pointing straight down into it.
	var tip := _wheel_center + Vector2(0, -WHEEL_RADIUS - 6.0)
	var pointer := PackedVector2Array([
		tip,
		tip + Vector2(-16, -24),
		tip + Vector2(16, -24),
	])
	draw_colored_polygon(pointer, Palette.INK)
