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
