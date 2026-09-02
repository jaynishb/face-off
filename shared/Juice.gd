extends Node
class_name Juice
## Small, game-agnostic "juice" helpers for Node2D gameplay: particle bursts,
## squash-stretch decay, and the chunky-sticker draw primitives every game
## renders with. Kept separate from UIUtil (which is Control/UI focused) since
## games render in Node2D space via _draw().
##
## House style, matched across all six games: flat colour, a hard near-black
## outline whose weight scales with the shape, one soft top-left highlight,
## and a soft drop shadow offset down-right. No gradients, no gloss.

const SHADOW_OFFSET := Vector2(0, 7)
const SHADOW_ALPHA := 0.18
## Outline weight as a fraction of a shape's radius, floored so small shapes
## keep a visible edge. Tuned to read as "thick marker pen".
const OUTLINE_RATIO := 0.17
const OUTLINE_MIN := 4.0

static func outline_width(radius: float) -> float:
	return maxf(radius * OUTLINE_RATIO, OUTLINE_MIN)

## One-shot colored particle burst at a world position, e.g. on a goal or
## impact. Auto-frees itself once the burst finishes.
static func burst(parent: Node2D, pos: Vector2, color: Color, count: int = 16) -> void:
	var particles := CPUParticles2D.new()
	parent.add_child(particles)
	particles.position = pos
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = count
	particles.lifetime = 0.7
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, 620)
	particles.initial_velocity_min = 140.0
	particles.initial_velocity_max = 320.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 8.0
	particles.color = color
	particles.emitting = true
	particles.finished.connect(particles.queue_free)

## Returns a squash Vector2 (x,y scale factors) that decays toward
## Vector2.ONE at the given recovery rate. Call once per _process with the
## previous squash value; pass a fresh Vector2(sx, sy) right after an impact.
static func decay_squash(current: Vector2, delta: float, recovery: float = 8.0) -> Vector2:
	return current.lerp(Vector2.ONE, minf(delta * recovery, 1.0))

## A chunky-sticker circle: drop shadow, hard outline, flat fill, soft
## highlight. Must be called from inside the given node's own _draw().
static func cartoon_circle(
	node: CanvasItem,
	pos: Vector2,
	radius: float,
	color: Color,
	squash: Vector2 = Vector2.ONE,
	shadow: bool = true,
) -> void:
	var ow := outline_width(radius)
	if shadow:
		node.draw_colored_polygon(
			_ellipse_points(pos + SHADOW_OFFSET, radius + ow, squash),
			Color(0, 0, 0, SHADOW_ALPHA),
		)
	node.draw_colored_polygon(_ellipse_points(pos, radius + ow, squash), Palette.OUTLINE)
	node.draw_colored_polygon(_ellipse_points(pos, radius, squash), color)
	var highlight_pos := pos + Vector2(-radius * 0.30, -radius * 0.36)
	node.draw_colored_polygon(
		_ellipse_points(highlight_pos, radius * 0.24, Vector2.ONE),
		Color(1, 1, 1, 0.32),
	)

static func _ellipse_points(center: Vector2, radius: float, squash: Vector2, segments: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var a := TAU * i / segments
		pts.append(center + Vector2(cos(a) * radius * squash.x, sin(a) * radius * squash.y))
	return pts

## Rounded rectangle with an optional hard outline, via StyleBoxFlat so the
## corners are genuinely round rather than mitred. `corner` is the radius.
static func rounded_rect(
	node: CanvasItem,
	rect: Rect2,
	color: Color,
	corner: float = 12.0,
	outline: float = 0.0,
	outline_color: Color = Palette.OUTLINE,
) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(corner))
	if outline > 0.0:
		sb.border_color = outline_color
		sb.set_border_width_all(int(outline))
	node.draw_style_box(sb, rect)

## Rounded rect with the house drop shadow behind it.
static func sticker_rect(
	node: CanvasItem,
	rect: Rect2,
	color: Color,
	corner: float = 12.0,
	outline: float = 6.0,
) -> void:
	rounded_rect(node, Rect2(rect.position + SHADOW_OFFSET, rect.size), Color(0, 0, 0, SHADOW_ALPHA), corner)
	rounded_rect(node, rect, color, corner, outline)

## A capsule (stadium) shape — a rounded rect whose corner radius is half its
## short side. Used for paddles and pills.
static func capsule(node: CanvasItem, rect: Rect2, color: Color, outline: float = 6.0) -> void:
	sticker_rect(node, rect, color, minf(rect.size.x, rect.size.y) * 0.5, outline)

# --- textured art -----------------------------------------------------------
#
# Every helper below takes an explicit `base` transform and RESTORES it before
# returning. This is not ceremony: draw_set_transform* REPLACES the canvas
# transform rather than composing with it, so a helper that called
# draw_set_transform() directly would silently clobber the player transform a
# SPLIT game is drawing under and render its sprite in screen space instead --
# on the wrong half of the phone, right way up. Callers inside a per-player
# _draw pass Field.player_xform(player); everyone else passes IDENTITY.

## Draw a texture centred on `center`, scaled to `height`, preserving aspect.
## flip_h mirrors it (the pack's characters all face right, so anything facing
## left is the same art flipped).
static func sprite(
	node: CanvasItem, base: Transform2D, texture: Texture2D, center: Vector2,
	height: float, flip_h: bool = false, rotation: float = 0.0,
	modulate: Color = Color.WHITE,
) -> void:
	if texture == null or height <= 0.0:
		return
	var scale := height / float(texture.get_height())
	var w := texture.get_width() * scale
	var local := Transform2D(rotation, Vector2(-1.0 if flip_h else 1.0, 1.0), 0.0, center)
	node.draw_set_transform_matrix(base * local)
	node.draw_texture_rect(texture, Rect2(-w * 0.5, -height * 0.5, w, height), false, modulate)
	node.draw_set_transform_matrix(base)

## Fill `rect` with `texture`, cropping rather than squashing -- CSS
## `background-size: cover`. The pack's backgrounds are 1440x1280 (9:8) while a
## player's half is much wider than it is tall, so stretching them to fit would
## visibly distort the crowd and the horizon.
static func cover(node: CanvasItem, base: Transform2D, texture: Texture2D, rect: Rect2) -> void:
	if texture == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var ts := texture.get_size()
	var scale: float = maxf(rect.size.x / ts.x, rect.size.y / ts.y)
	var drawn := ts * scale
	# Centre the overflow, then clip to the target rect.
	var src := Rect2(
		(drawn.x - rect.size.x) * 0.5 / scale,
		(drawn.y - rect.size.y) * 0.5 / scale,
		rect.size.x / scale,
		rect.size.y / scale,
	)
	node.draw_set_transform_matrix(base)
	node.draw_texture_rect_region(texture, rect, src)

## Repeat `texture` horizontally across `rect` at a fixed height -- lane ropes,
## fences, anything that has to run the width of a half without stretching.
static func tile_h(
	node: CanvasItem, base: Transform2D, texture: Texture2D, rect: Rect2, height: float,
) -> void:
	if texture == null or height <= 0.0:
		return
	var tile_w := texture.get_width() * (height / float(texture.get_height()))
	if tile_w <= 1.0:
		return
	node.draw_set_transform_matrix(base)
	var x := rect.position.x
	var y := rect.position.y + (rect.size.y - height) * 0.5
	while x < rect.end.x:
		var w: float = minf(tile_w, rect.end.x - x)
		var src := Rect2(0.0, 0.0, texture.get_width() * (w / tile_w), texture.get_height())
		node.draw_texture_rect_region(texture, Rect2(x, y, w, height), src)
		x += tile_w
