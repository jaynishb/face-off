extends Node
class_name Juice
## Small, game-agnostic "juice" helpers for Node2D gameplay: particle bursts
## and squash-stretch decay. Kept separate from UIUtil (which is Control/UI
## focused) since games render in Node2D space via _draw().

## One-shot colored particle burst at a world position, e.g. on a goal or
## impact. Auto-frees itself once the burst finishes.
static func burst(parent: Node2D, pos: Vector2, color: Color, count: int = 14) -> void:
	var particles := CPUParticles2D.new()
	parent.add_child(particles)
	particles.position = pos
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = count
	particles.lifetime = 0.6
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, 500)
	particles.initial_velocity_min = 120.0
	particles.initial_velocity_max = 280.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = color
	particles.emitting = true
	particles.finished.connect(particles.queue_free)

## Returns a squash Vector2 (x,y scale factors) that decays toward
## Vector2.ONE at the given recovery rate. Call once per _process with the
## previous squash value; pass a fresh Vector2(sx, sy) right after an impact.
static func decay_squash(current: Vector2, delta: float, recovery: float = 8.0) -> Vector2:
	return current.lerp(Vector2.ONE, minf(delta * recovery, 1.0))

## A chunky-cartoon circle: thick ink outline + flat fill + a soft highlight,
## matching the palette's "bold outlines, single soft highlight, no gloss"
## direction. Must be called from inside the given node's own _draw().
static func cartoon_circle(node: CanvasItem, pos: Vector2, radius: float, color: Color, squash: Vector2 = Vector2.ONE) -> void:
	node.draw_colored_polygon(_ellipse_points(pos, radius + 4.0, squash), Palette.INK)
	node.draw_colored_polygon(_ellipse_points(pos, radius, squash), color)
	var highlight_pos := pos + Vector2(-radius * 0.32, -radius * 0.38)
	node.draw_colored_polygon(_ellipse_points(highlight_pos, radius * 0.26, Vector2.ONE), Color(1, 1, 1, 0.4))

static func _ellipse_points(center: Vector2, radius: float, squash: Vector2, segments: int = 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var a := TAU * i / segments
		pts.append(center + Vector2(cos(a) * radius * squash.x, sin(a) * radius * squash.y))
	return pts

## A chunky-cartoon rect: thick ink outline + flat fill + a soft highlight
## strip, for paddles/blocks. `rect` is the fill rect (outline is drawn 4px
## larger on each side).
static func cartoon_rect(node: CanvasItem, rect: Rect2, color: Color) -> void:
	var outline_rect := rect.grow(4.0)
	node.draw_rect(outline_rect, Palette.INK)
	node.draw_rect(rect, color)
	var highlight := Rect2(rect.position + Vector2(rect.size.x * 0.15, rect.size.y * 0.1), Vector2(rect.size.x * 0.25, rect.size.y * 0.3))
	node.draw_rect(highlight, Color(1, 1, 1, 0.3))
