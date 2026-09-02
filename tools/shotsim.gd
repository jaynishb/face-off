extends Node
## Brute-force Basketball: fire every drag a thumb could plausibly make and count
## how many actually score. A closed-form "can it reach" test is not enough -- the
## minimum-energy shot arrives at the rim plane with zero velocity and never falls
## THROUGH it, so a game can pass reachability and still be unscorable.

func _ready() -> void:
	get_window().size = Vector2i(720, 1280)
	await get_tree().process_frame
	var g = load("res://games/basketball/Basketball.tscn").instantiate()
	add_child(g); g.setup({})
	var pr: Rect2 = g.play_rect
	print("play_rect=", pr, "  shoot_from=", g.shoot_from, "  hoop=", g.hoop_center)
	print("FLICK_POWER=", g.FLICK_POWER, " rim window=+-", g.rim_half_width * g.RIM_TOLERANCE, "px")

	var made := 0
	var tried := 0
	var best_miss := 1e9
	# Every drag from any start point, in any direction, at any plausible length.
	for angle_deg in range(0, 360, 3):
		for length in range(20, 601, 10):
			var pull: Vector2 = Vector2(length, 0).rotated(deg_to_rad(angle_deg))
			# The drag has to physically fit: finger start and end both on screen.
			var finger_end: Vector2 = pr.get_center() - pull
			if not pr.has_point(finger_end):
				continue
			tried += 1
			var r: Dictionary = _sim(g, pull)
			if r["made"]:
				made += 1
			else:
				best_miss = minf(best_miss, r["miss"])
	print("\nscoring drags: %d of %d plausible (%.2f%%)" % [made, tried, 100.0 * made / maxf(tried, 1)])
	print("closest miss: %.0f px from the rim centre" % best_miss)
	_tolerance(g)
	g.queue_free()
	get_tree().quit()

## Replays Basketball's own _process integration exactly.
func _sim(g, pull: Vector2) -> Dictionary:
	var pos: Vector2 = g.shoot_from
	var vel: Vector2 = (pull * g.FLICK_POWER).limit_length(g.MAX_SHOT_SPEED)
	var pr: Rect2 = g.play_rect
	var delta := 1.0 / 60.0
	var closest := 1e9
	for step in range(600):
		var prev_y: float = pos.y
		vel.y += g.GRAVITY * delta
		pos += vel * delta
		if pos.x - g.ball_radius < pr.position.x:
			pos.x = pr.position.x + g.ball_radius
			vel.x = absf(vel.x) * 0.7
		elif pos.x + g.ball_radius > pr.end.x:
			pos.x = pr.end.x - g.ball_radius
			vel.x = -absf(vel.x) * 0.7
		if pos.y - g.ball_radius < pr.position.y:
			pos.y = pr.position.y + g.ball_radius
			vel.y = absf(vel.y) * 0.7
		var plane: float = g.hoop_center.y
		if vel.y > 0.0 and prev_y < plane and pos.y >= plane:
			var dx: float = absf(pos.x - g.hoop_center.x)
			closest = minf(closest, dx)
			if dx <= g.rim_half_width * g.RIM_TOLERANCE:
				return {"made": true, "miss": 0.0}
		if pos.y > pr.end.y + g.ball_radius:
			break
	return {"made": false, "miss": closest}

## How precisely must the player drag? A shot nobody can repeat is as bad as one
## nobody can make, so this reports the width of the scoring band in both axes.
func _tolerance(g) -> void:
	var pr: Rect2 = g.play_rect
	var best_angle := -1
	var best_span := 0
	for angle_deg in range(0, 360, 1):
		var span := 0
		for length in range(20, 601, 5):
			var pull: Vector2 = Vector2(length, 0).rotated(deg_to_rad(angle_deg))
			if not pr.has_point(pr.get_center() - pull):
				continue
			if _sim(g, pull)["made"]:
				span += 5
		if span > best_span:
			best_span = span
			best_angle = angle_deg
	if best_angle < 0:
		print("tolerance: NO scoring drag exists")
		return
	var angle_span := 0
	for angle_deg in range(0, 360, 1):
		for length in range(20, 601, 5):
			var pull: Vector2 = Vector2(length, 0).rotated(deg_to_rad(angle_deg))
			if not pr.has_point(pr.get_center() - pull):
				continue
			if _sim(g, pull)["made"]:
				angle_span += 1
				break
	print("best drag direction: %d deg, scoring length band %d px wide" % [best_angle, best_span])
	print("directions with at least one scoring length: %d of 360 deg" % angle_span)
