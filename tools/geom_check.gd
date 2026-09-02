extends Node
## Headless geometry harness. Pure math, no rendering:
##
##   godot --headless --path . res://tools/GeomCheck.tscn
##
## Run as a SCENE, not with --script: a custom SceneTree main loop never
## registers the project's autoloads, so Field/InputManager/GameManager would
## not resolve at compile time.
##
## Every input bug this project has shipped came from two coordinate spaces
## disagreeing — the drawn midline against the input midline (GAME_AUDIT.md
## C1/C2/C3), and later a rotated canvas against Godot's untransformed pixel
## buffer. Those are all assertions about arithmetic, so they do not need a
## browser to catch. This runs in about a second and is the cheapest guard the
## project has; run it before every Web export.
##
## It deliberately also exercises the 20:9 case, which is the aspect ratio that
## produced the original audit's softlock and which a 720x1280 dev window never
## reproduces.

const EPS := 0.001

var _failures: Array[String] = []
var _checks := 0

func _ready() -> void:
	for size in [Vector2i(720, 1280), Vector2i(720, 1560), Vector2i(800, 1280)]:
		await _run_suite(size)

	print("")
	if _failures.is_empty():
		print("geom_check: OK (%d assertions)" % _checks)
		get_tree().quit(0)
	else:
		print("geom_check: %d FAILURE(S) of %d assertions" % [_failures.size(), _checks])
		for f in _failures:
			print("  - ", f)
		get_tree().quit(1)

func _run_suite(size: Vector2i) -> void:
	var window := get_window()
	window.content_scale_size = size
	window.size = size
	await get_tree().process_frame
	print("geom_check: viewport %dx%d" % [size.x, size.y])

	_check_halves_tile()
	_check_round_trip()
	_check_ownership_matches_geometry()
	_check_player_space_is_symmetric()
	_check_play_rects_inside_halves()
	_check_games_layout()

## The two halves must cover the viewport with no gap and no overlap. A gap is a
## dead strip that belongs to nobody; an overlap is a strip that two players both
## think is theirs.
func _check_halves_tile() -> void:
	var r1 := Field.player_rect(1)
	var r2 := Field.player_rect(2)
	_assert(is_equal_approx(r2.position.y, 0.0), "P2 half must start at y=0")
	_assert(is_equal_approx(r2.end.y, r1.position.y), "halves must meet exactly at the split")
	_assert(is_equal_approx(r1.end.y, Field.height()), "P1 half must reach the bottom")
	_assert(is_equal_approx(r1.size.x, Field.width()), "P1 half must span the full width")
	_assert(is_equal_approx(r2.size.x, Field.width()), "P2 half must span the full width")
	_assert(is_equal_approx(r1.size.y + r2.size.y, Field.height()), "halves must sum to the height")

## Screen -> player -> screen must be the identity. If it is not, whatever a game
## draws under player_xform() and whatever InputManager hands it back are
## different points, and the game silently stops responding where it looks like
## it should.
func _check_round_trip() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260902
	for player in [1, 2]:
		for _i in range(500):
			var v := Vector2(rng.randf() * Field.width(), rng.randf() * Field.height())
			var back := Field.to_screen(player, Field.to_player(player, v))
			_assert(
				back.distance_to(v) < EPS,
				"P%d round-trip %.2f,%.2f -> %.2f,%.2f" % [player, v.x, v.y, back.x, back.y],
			)

## The portrait restatement of the C1/C2 invariant: the player InputManager
## credits a touch to must be the player whose half actually contains it. This is
## the assertion that catches an inverted split axis, which otherwise looks
## completely healthy -- paddles move, scores count, everything just belongs to
## the wrong person.
func _check_ownership_matches_geometry() -> void:
	InputManager.set_shared_board_turn(0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var r2 := Field.player_rect(2)
	for _i in range(500):
		var v := Vector2(rng.randf() * Field.width(), rng.randf() * Field.height())
		var expected := 2 if r2.has_point(v) else 1
		var actual: int = InputManager._player_for_position(v)
		_assert(actual == expected, "ownership at %.1f,%.1f: got P%d want P%d" % [v.x, v.y, actual, expected])

	# Shared-board mode must override position entirely, or a communal board is
	# unreachable from one side (the Tic-Tac-Toe softlock, GAME_AUDIT.md C3).
	for turn in [1, 2]:
		InputManager.set_shared_board_turn(turn)
		for _i in range(20):
			var v := Vector2(rng.randf() * Field.width(), rng.randf() * Field.height())
			_assert(
				InputManager._player_for_position(v) == turn,
				"shared-board turn %d must own every point" % turn,
			)
	InputManager.set_shared_board_turn(0)

## Player space must be identical for both players: local (0,0) at the seam, +y
## running outward toward that player's own edge. If this drifts, a SPLIT game
## authored once stops being symmetric.
func _check_player_space_is_symmetric() -> void:
	var half := Field.half_size()
	for player in [1, 2]:
		var origin := Field.to_screen(player, Vector2.ZERO)
		_assert(
			is_equal_approx(origin.y, Field.split_y()),
			"P%d local origin must sit on the split (got y=%.2f)" % [player, origin.y],
		)
		var back_wall := Field.to_screen(player, Vector2(0.0, half.y))
		var expected_y: float = Field.height() if player == 1 else 0.0
		_assert(
			absf(back_wall.y - expected_y) < EPS,
			"P%d back wall should be y=%.1f, got %.2f" % [player, expected_y, back_wall.y],
		)
		# A whole half's worth of local points must land inside that half.
		for p in [Vector2(1, 1), Vector2(half.x - 1, 1), Vector2(1, half.y - 1), Vector2(half.x - 1, half.y - 1)]:
			var s := Field.to_screen(player, p)
			_assert(
				Field.player_rect(player).has_point(s),
				"P%d local %.0f,%.0f mapped outside its own half" % [player, p.x, p.y],
			)

	# A drag away from the seam must read as +y for whoever made it, on either
	# side. This is what lets one piece of gameplay code serve both players.
	_assert(Field.to_player_dir(1, Vector2(0, 10)).y > 0.0, "P1 drag down-screen should be +y local")
	_assert(Field.to_player_dir(2, Vector2(0, -10)).y > 0.0, "P2 drag up-screen should be +y local")

func _check_play_rects_inside_halves() -> void:
	for player in [1, 2]:
		var play := Field.player_play_rect(player)
		var half := Field.player_rect(player)
		_assert(play.size.x > 0.0 and play.size.y > 0.0, "P%d play rect must be non-empty" % player)
		_assert(
			half.encloses(play),
			"P%d play rect must sit inside its half" % player,
		)

## Instantiate every registered game, lay it out twice, and check the second
## layout() is a no-op and that any zone rects it registered are sane. layout()
## is called on every viewport resize, mid-match, so it has to be idempotent.
func _check_games_layout() -> void:
	for game_id in GameManager.get_roster():
		var meta := GameManager.get_game_meta(game_id)
		var scene_path: String = meta.get("scene", "")
		if not ResourceLoader.exists(scene_path):
			continue # not built yet -- GameSelect renders it as SOON

		# A script that fails to parse still yields a scene whose root is a bare
		# Node2D, so instantiate() succeeds and every later check quietly passes
		# over a game that cannot even load. Assert the type before trusting it.
		var instance: Node = load(scene_path).instantiate()
		if not (instance is MiniGame):
			_assert(false, "%s did not instantiate as a MiniGame (script failed to load?)" % game_id)
			instance.free()
			continue
		var game: MiniGame = instance
		# Each game connects to InputManager in setup(); reset the shared modes
		# first so one game's leftovers cannot mask the next one's bug.
		InputManager.configure_zones([])
		InputManager.set_shared_board_turn(0)
		InputManager.set_input_space(game.input_space)
		add_child(game)
		game.setup({})
		game.layout()
		game.layout()
		_check_zone_rects(game_id, game)
		remove_child(game)
		game.free()

## Zones are registered in the space the game declared. Under PLAYER space they
## must map inside the owning player's own half, and the two players' zones must
## not overlap on screen -- otherwise one player's button steals the other's tap.
func _check_zone_rects(game_id: String, game: MiniGame) -> void:
	var zones: Array = InputManager._zone_rects
	if zones.is_empty():
		return
	var screen_rects := {1: [], 2: []}
	for entry in zones:
		var rect: Rect2 = entry.rect
		var player: int = entry.player
		var corners := [
			rect.position, Vector2(rect.end.x, rect.position.y),
			Vector2(rect.position.x, rect.end.y), rect.end,
		]
		var mapped := Rect2(Field.to_screen(player, corners[0]), Vector2.ZERO)
		for c in corners:
			mapped = mapped.expand(Field.to_screen(player, c))
		_assert(
			Field.player_rect(player).grow(1.0).encloses(mapped),
			"%s: P%d zone %d maps outside its own half" % [game_id, player, entry.zone],
		)
		screen_rects[player].append(mapped)

	for a in screen_rects[1]:
		for b in screen_rects[2]:
			_assert(
				not a.intersects(b, false),
				"%s: a P1 zone overlaps a P2 zone on screen" % game_id,
			)

func _assert(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("%dx%d: %s" % [int(Field.width()), int(Field.height()), message])
