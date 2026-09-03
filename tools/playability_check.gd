extends Node
## Playability harness — asserts that each game can actually be PLAYED, which is a
## different question from the one tools/geom_check.gd answers.
##
## geom_check proves the two halves tile the viewport, that SCREEN<->PLAYER
## round-trips, and that a touch is credited to the half it landed in. All of that
## can pass while a game is still impossible: Archery shipped with a target no legal
## drag could reach, and every match ended 0-0 with 4740 geometry assertions green.
##
## So this harness asks the questions a player would:
##   * can the projectile get from where it starts to where it must go?
##   * can the actor leave its own half?
##   * does every part of the half that looks tappable actually register a tap?
##
## Run as a SCENE, never with --script: a custom SceneTree main loop never registers
## the autoloads, so Field and GameManager would not exist.
##   godot --headless --path . res://tools/Playability.tscn

const SIZES := [Vector2i(720, 1280), Vector2i(720, 1560), Vector2i(800, 1280)]

var _failures: Array[String] = []
var _checks := 0

func _ready() -> void:
	for size in SIZES:
		get_window().size = size
		await get_tree().process_frame
		print("playability: viewport %dx%d" % [size.x, size.y])
		_check_archery()
		_check_diving()
		_check_basketball()
		_check_sprint()
		_check_horse_jump()

	print("")
	if _failures.is_empty():
		print("playability: OK (%d checks)" % _checks)
		get_tree().quit(0)
	else:
		for failure in _failures:
			print("playability: FAIL  %s" % failure)
		print("playability: %d of %d checks FAILED" % [_failures.size(), _checks])
		get_tree().quit(1)

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("%dx%d  %s" % [get_window().size.x, get_window().size.y, message])

func _load(id: String) -> Node:
	var game = load(GameManager.GAME_REGISTRY[id]["scene"]).instantiate()
	add_child(game)
	game.setup({})
	return game

## Minimum launch speed that reaches a target at offset `d` under gravity `g`.
## Standard result for the optimal launch angle; if the fastest shot the controls
## can produce is below this, no aim whatsoever reaches the target.
func _min_launch_speed(d: Vector2, g: float) -> float:
	return sqrt(g) * sqrt(-d.y + d.length())

## The longest drag the player can make and still shoot toward `toward` -- which is
## what actually bounds a slingshot's power, not MAX_SPEED.
##
## The launch vector is `origin - finger`, so a shot toward the target needs the
## finger on the FAR side of the archer from it. Filtering on the wrong sign here
## finds the longest backwards drag and reports an unwinnable game as fine; that is
## how this check first passed on Archery.
func _max_pull_from(origin: Vector2, rect: Rect2, toward: Vector2) -> float:
	var best := 0.0
	for corner in [
		rect.position, Vector2(rect.end.x, rect.position.y),
		Vector2(rect.position.x, rect.end.y), rect.end,
	]:
		var pull: Vector2 = origin - corner
		if pull.normalized().dot(toward.normalized()) > 0.3:
			best = maxf(best, pull.length())
	return best

## Archery, like Basketball, is checked by SIMULATION.
##
## The closed-form version below it (_min_launch_speed) is kept because it is the
## right first question -- "is the target in range at all" -- but it is not a
## sufficient one: it answers for the minimum-energy shot, which arrives with no
## speed left, and it compares a diagonal drag's whole length against a
## requirement that is not along the drag. Both errors flatter the game. Firing
## the actual integration does not.
func _check_archery() -> void:
	var g := _load("archery")
	var hitting := 0
	var directions := 0
	var best_span := 0.0
	for angle_deg in range(0, 360, 3):
		var first := -1
		var last := -1
		for length in range(20, 601, 10):
			var pull: Vector2 = Vector2(length, 0).rotated(deg_to_rad(angle_deg))
			# The finger has to land somewhere on the player's own half.
			if not g.play_rect.has_point(g.archer_pos - pull):
				continue
			if _arrow_hits(g, pull):
				hitting += 1
				if first < 0:
					first = length
				last = length
		if first >= 0:
			directions += 1
			best_span = maxf(best_span, float(last - first))
	_expect(hitting > 0, "archery: NO drag hits the target -- every match ends 0-0")
	# A narrower arc than Basketball's, deliberately: a bow aimed across the range
	# at a small face IS a tighter instrument than a flick at a hoop, and the
	# measured band is 57 degrees centred just above the line to the target, which
	# is where a player would naturally point. What makes that a game rather than
	# a lottery is the second assertion -- inside the best direction there must be
	# real slack in how far back you pull, or every hit is an accident.
	_expect(
		directions >= 15,
		"archery: usable aim arc is only %d degrees" % (directions * 3),
	)
	_expect(
		best_span >= 150.0,
		"archery: best aim direction tolerates only %.0fpx of draw length" % best_span,
	)
	g.queue_free()

## Replays Archery's own _process integration for one draw, at zero wind (the wind
## is a skill modifier; a game that is only winnable on a favourable gust is not
## winnable). Mirrors the out-of-bounds tests, seam included.
func _arrow_hits(g, pull: Vector2) -> bool:
	var rect: Rect2 = g.play_rect
	var pos: Vector2 = g.archer_pos
	var vel: Vector2 = (pull * g.DRAW_POWER).limit_length(g.MAX_SPEED)
	var delta := 1.0 / 60.0
	for step in range(600):
		vel.y += g.GRAVITY * g.art_scale * delta
		pos += vel * delta
		if pos.distance_to(g.target_center) <= g.target_radius:
			return true
		if (
			pos.x > rect.end.x + 40.0 or pos.y > rect.end.y + 40.0
			or pos.x < rect.position.x - 40.0 or pos.y < rect.position.y - 30.0
		):
			return false
	return false

func _check_diving() -> void:
	var g := _load("diving")
	var start_y: float = g.board_tip.y - g.diver_radius
	# Worst case is a full-power launch; the apex must stay inside the player's own
	# half or the diver is drawn over the opponent's dive, upside down.
	#
	# Read from the game's own constants, never retyped here: a copy would go on
	# passing after someone raised the launch power, which is precisely the change
	# this check exists to catch.
	var v0: float = (g.LAUNCH_BASE + g.LAUNCH_RANGE) * g.art_scale
	var apex: float = start_y - (v0 * v0) / (2.0 * g.GRAVITY * g.art_scale)
	_expect(apex >= 0.0, "diving: full-power dive crosses the seam (apex y=%.0f)" % apex)
	_expect(
		apex >= g.play_rect.position.y,
		"diving: full-power dive leaves the play area (apex y=%.0f, top=%.0f)" % [apex, g.play_rect.position.y],
	)
	# The water has to be below the board and on screen, or the dive is judged
	# against a line the player cannot see.
	_expect(
		g.water_y > g.board_tip.y and g.water_y < g.play_rect.end.y,
		"diving: water line at y=%.0f is not between the board (%.0f) and the edge (%.0f)" % [
			g.water_y, g.board_tip.y, g.play_rect.end.y,
		],
	)
	g.queue_free()

## Basketball is checked by SIMULATION, not by the closed-form range test above.
##
## The formula version passed this game while it was scoring 0 shots out of 4061,
## for two compounding reasons: the minimum-energy shot arrives at the rim plane
## with no speed left and so never falls THROUGH it, and comparing a diagonal drag's
## full length against a vertical requirement credits power the shot does not have.
## Firing the actual integration is the only honest test.
func _check_basketball() -> void:
	var g := _load("basketball")
	var scoring := 0
	var directions := 0
	for angle_deg in range(0, 360, 3):
		var hit_this_direction := false
		for length in range(20, 601, 10):
			var pull: Vector2 = Vector2(length, 0).rotated(deg_to_rad(angle_deg))
			# The drag must physically fit on the player's own half.
			if not g.play_rect.has_point(g.play_rect.get_center() - pull):
				continue
			if _shot_scores(g, pull):
				scoring += 1
				hit_this_direction = true
		if hit_this_direction:
			directions += 1
	_expect(scoring > 0, "basketball: NO drag scores -- the hoop cannot be hit at all")
	# One working drag is not a game. The player needs a band wide enough to aim
	# into, or every basket is an accident.
	_expect(
		directions >= 20,
		"basketball: only %d of 120 sampled drag directions can score" % directions,
	)
	g.queue_free()

## Replays Basketball's own _process integration for one flick.
func _shot_scores(g, pull: Vector2) -> bool:
	var rect: Rect2 = g.play_rect
	var pos: Vector2 = g.shoot_from
	var vel: Vector2 = (pull * g.FLICK_POWER).limit_length(g.MAX_SHOT_SPEED)
	var delta := 1.0 / 60.0
	for step in range(600):
		var prev_y: float = pos.y
		vel.y += g.GRAVITY * delta
		pos += vel * delta
		if pos.x - g.ball_radius < rect.position.x:
			pos.x = rect.position.x + g.ball_radius
			vel.x = absf(vel.x) * 0.7
		elif pos.x + g.ball_radius > rect.end.x:
			pos.x = rect.end.x - g.ball_radius
			vel.x = -absf(vel.x) * 0.7
		if pos.y - g.ball_radius < rect.position.y:
			pos.y = rect.position.y + g.ball_radius
			vel.y = absf(vel.y) * 0.7
		var plane: float = g.hoop_center.y
		if vel.y > 0.0 and prev_y < plane and pos.y >= plane:
			if absf(pos.x - g.hoop_center.x) <= g.rim_half_width * g.RIM_TOLERANCE:
				return true
		if pos.y > rect.end.y + g.ball_radius:
			return false
	return false

## A tap that lands on a player's own half and does nothing is indistinguishable,
## to them, from a game with no controls -- the same class of bug as the input
## split disagreeing with the drawn split.
##
## Two separate questions, and the second is NOT "is the pad as big as the zone".
## A hit target larger than its affordance is a good thing; a pad drawn outside
## the zone it triggers is a lie. So: the zones must tile the half, and each
## drawn pad must lie inside the zone it belongs to.
func _check_sprint() -> void:
	var g := _load("sprint")
	var covered := 0.0
	for rect in g._button_rects.values():
		covered += (rect as Rect2).size.y
	var dead: float = g.play_rect.size.y - covered
	_expect(
		dead <= g.play_rect.size.y * 0.02,
		"sprint: %.0f%% of the half ignores taps (%.0fpx of %.0fpx)" % [
			dead / g.play_rect.size.y * 100.0, dead, g.play_rect.size.y,
		],
	)
	for zone in g._button_rects:
		var rect: Rect2 = g._button_rects[zone]
		var pad: Rect2 = g.pad_rect(zone)
		_expect(
			rect.encloses(pad),
			"sprint: zone %d's pad %s is drawn outside its own zone %s" % [zone, pad, rect],
		)
		_expect(
			pad.size.x > 0.0 and pad.size.y > 0.0,
			"sprint: zone %d has no drawn pad at all" % zone,
		)
	g.queue_free()

func _check_horse_jump() -> void:
	var g := _load("horse_jump")
	var apex: float = (g.JUMP_IMPULSE * g.JUMP_IMPULSE) / (2.0 * g.GRAVITY)
	var needed: float = g.hurdle_height * 0.72
	_expect(apex >= needed, "horse_jump: hurdle uncleavable -- apex %.0f, needs %.0f" % [apex, needed])
	# PRD 3: every game is 20-60 seconds. A 7-second race has no arc.
	var fastest: float = g.COURSE_LENGTH / g.MAX_SPEED
	var slowest: float = g.COURSE_LENGTH / g.BASE_SPEED
	_expect(
		slowest >= 20.0,
		"horse_jump: race lasts only %.1fs at base speed (PRD floor is 20s)" % slowest,
	)
	_expect(fastest >= 15.0, "horse_jump: perfect race lasts only %.1fs" % fastest)
	g.queue_free()
