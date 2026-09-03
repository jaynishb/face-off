extends Node
## InputManager — the single source of player input for every game.
##
## PORTRAIT, top/bottom split: the TOP half is Player 2, the BOTTOM half is
## Player 1 (the player holding the phone). A touch's ownership is decided once,
## at touch-begin, by which half it started in, and never changes for the
## lifetime of that touch — even if the finger drags across the seam.
##
## Games never read raw InputEvent touch data. They connect to the signals below
## and, if they need sub-regions (e.g. two buttons per player), pass a zone map
## into configure_zones() — zones are data, not new code paths here.
##
## COORDINATE SPACE. Player 2's half is drawn rotated by PI so they read it
## right-way-up (see Field.gd). A game therefore has to receive touches in the
## same space it draws in, or the drawn thing and the touched thing disagree —
## which is the exact bug class that has broken this project twice. So a game
## declares its space via MiniGame.input_space and MatchHost forwards it here:
##
##   Space.SCREEN (default) — raw viewport pixels. For games that draw one
##     shared object both players watch (Air Hockey's puck, Ping Pong's ball,
##     Sumo Blob's platform) and for shared boards.
##   Space.PLAYER — Field's per-player local space, so the game authors one
##     half and both players get it mirrored for free.
##
## The conversion uses Field.player_xform().affine_inverse() — the inverse of
## the very matrix the game draws with. One matrix, both directions.

signal player_pressed(player: int, zone: int, position: Vector2, screen_position: Vector2)
signal player_released(player: int, zone: int, position: Vector2, screen_position: Vector2)
signal player_dragged(player: int, zone: int, position: Vector2, delta: Vector2, screen_position: Vector2)

const NO_ZONE := 0

enum Space { SCREEN, PLAYER }

# index -> touch record: { player: int, zone: int, position: Vector2 }
var _active_touches: Dictionary = {}

# Per-game zone rects, set via configure_zones(). Empty = whole half is zone
# NO_ZONE. Each entry: { player: int, zone: int, rect: Rect2 }, expressed in
# whichever space the game declared.
var _zone_rects: Array = []

var _space: int = Space.SCREEN

## Shared-board mode. Some games (Tic-Tac-Toe, Connect Four) are played on ONE
## communal board that straddles the seam and take strict turns. Splitting those
## by screen half is simply the wrong model: it makes a cell physically
## unreachable for whichever player is on the far side of it, because their
## touch gets attributed to the opponent and then rejected as out-of-turn.
##
## That is not hypothetical -- it softlocked Tic-Tac-Toe outright. On a screen
## wider than 16:9 all nine cells fell on Player 1's side, so after P1's opening
## move P2 could never place anywhere and the match could not be finished
## (GAME_AUDIT.md C3).
##
## In shared-board mode ownership comes from whose turn it is, not from where the
## finger landed, so either player can reach the whole board. It also forces
## SCREEN space regardless of the declared input_space: a communal board is drawn
## upright, unrotated, in viewport coordinates, so converting its touches into a
## player-local space would be meaningless.
var _shared_board_player: int = 0

var debug_overlay_enabled: bool = false

func _ready() -> void:
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	# Mouse fallback is handled automatically via
	# input_devices/pointing/emulate_touch_from_mouse in project settings,
	# which synthesizes InputEventScreenTouch/Drag for desktop testing.

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		var player := _player_for_position(event.position)
		var local := _to_space(player, event.position)
		var zone := _zone_for_position(player, local)
		_active_touches[event.index] = {
			"player": player,
			"zone": zone,
			"position": event.position,
		}
		player_pressed.emit(player, zone, local, event.position)
	else:
		var record: Variant = _active_touches.get(event.index)
		if record != null:
			var local := _to_space(record.player, event.position)
			player_released.emit(record.player, record.zone, local, event.position)
			_active_touches.erase(event.index)

func _handle_drag(event: InputEventScreenDrag) -> void:
	var record: Variant = _active_touches.get(event.index)
	if record == null:
		return
	record.position = event.position
	var local := _to_space(record.player, event.position)
	var delta := _to_space_dir(record.player, event.relative)
	player_dragged.emit(record.player, record.zone, local, delta, event.position)

## Ownership is decided against Field.split_y() -- the same value MatchHost draws
## its seam at and every game clamps to. Reading the viewport directly here (as
## this once did) let the input split drift away from the drawn one; see Field.gd
## and GAME_AUDIT.md C1.
##
## Note the ordering: Player 2 is the SMALLER y. P2 owns the top half because
## their UI is rotated PI to face them across the phone.
func _player_for_position(position: Vector2) -> int:
	if _shared_board_player != 0:
		return _shared_board_player
	return 2 if position.y < Field.split_y() else 1

## Turn-based shared-board games call this whenever the turn changes; every touch
## is then credited to that player regardless of position. Pass 0 to return to
## positional (split-screen) ownership.
func set_shared_board_turn(player: int) -> void:
	_shared_board_player = player

## MatchHost sets this from the game's declared input_space before setup(), and
## resets it to SCREEN between matches so a mode never leaks between games.
func set_input_space(space: int) -> void:
	_space = space

func get_input_space() -> int:
	return _space

func _to_space(player: int, position: Vector2) -> Vector2:
	if _space == Space.PLAYER and _shared_board_player == 0:
		return Field.to_player(player, position)
	return position

func _to_space_dir(player: int, delta: Vector2) -> Vector2:
	if _space == Space.PLAYER and _shared_board_player == 0:
		return Field.to_player_dir(player, delta)
	return delta

## Hit-tested in the same space the rects were authored in, which is the space
## the caller already converted `position` into.
func _zone_for_position(player: int, position: Vector2) -> int:
	for entry in _zone_rects:
		if entry.player == player and entry.rect.has_point(position):
			return entry.zone
	return NO_ZONE

## Called by a game's layout() to define sub-regions within a player's half.
## rects is an Array of { player: int, zone: int, rect: Rect2 }, in the space the
## game declared via input_space. Under Space.PLAYER both players' rects are
## identical, which is a useful proof that the halves really are symmetric.
## Pass an empty array to reset to "whole half = zone NO_ZONE" (the default).
func configure_zones(rects: Array) -> void:
	_zone_rects = rects

func get_active_touch_count() -> int:
	return _active_touches.size()

## Debug overlay support: current touches keyed by index, each with
## player/zone/position (position is SCREEN space), for a HUD to visualize live
## multi-touch state.
func get_active_touches() -> Dictionary:
	return _active_touches.duplicate(true)

func set_debug_overlay_enabled(enabled: bool) -> void:
	debug_overlay_enabled = enabled
