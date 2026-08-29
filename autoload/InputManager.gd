extends Node
## InputManager — the single source of player input for every game.
##
## Screen is split down the middle: left half = Player 1, right half = Player 2.
## A touch's player ownership is decided once, at touch-begin, by which half
## it started in, and never changes for the lifetime of that touch — even if
## the finger drags across the midline.
##
## Games never read raw InputEvent touch data. They connect to the signals
## below and, if they need sub-regions (e.g. two buttons per player), pass a
## zone map into configure_zones() — zones are data, not new code paths here.

signal player_pressed(player: int, zone: int, position: Vector2)
signal player_released(player: int, zone: int, position: Vector2)
signal player_dragged(player: int, zone: int, position: Vector2, delta: Vector2)

const NO_ZONE := 0

# index -> touch record: { player: int, zone: int, position: Vector2 }
var _active_touches: Dictionary = {}

# Per-game zone rects, set via configure_zones(). Empty = whole half is zone NO_ZONE.
# Each entry: { player: int, zone: int, rect: Rect2 } in viewport coordinates.
var _zone_rects: Array = []

## Shared-board mode. Some games (Tic-Tac-Toe, Connect Four) are played on ONE
## communal board that straddles the midline and take strict turns. Splitting
## those by screen half is simply the wrong model: it makes a cell physically
## unreachable for whichever player is on the far side of it, because their
## touch gets attributed to the opponent and then rejected as out-of-turn.
##
## That is not hypothetical -- it softlocked Tic-Tac-Toe outright. On a screen
## wider than 16:9 all nine cells fell on Player 1's side, so after P1's opening
## move P2 could never place anywhere and the match could not be finished
## (GAME_AUDIT.md C3).
##
## In shared-board mode ownership comes from whose turn it is, not from where
## the finger landed, so either player can reach the whole board.
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
		var zone := _zone_for_position(player, event.position)
		_active_touches[event.index] = {
			"player": player,
			"zone": zone,
			"position": event.position,
		}
		player_pressed.emit(player, zone, event.position)
	else:
		var record: Variant = _active_touches.get(event.index)
		if record != null:
			player_released.emit(record.player, record.zone, event.position)
			_active_touches.erase(event.index)

func _handle_drag(event: InputEventScreenDrag) -> void:
	var record: Variant = _active_touches.get(event.index)
	if record == null:
		return
	record.position = event.position
	player_dragged.emit(record.player, record.zone, event.position, event.relative)

## Ownership is decided against Field.mid_x() -- the same value MatchHost draws
## its divider at and every game clamps to. Reading the viewport directly here
## (as this used to) let the input split drift away from the drawn one on any
## screen wider than 16:9; see Field.gd and GAME_AUDIT.md C1.
func _player_for_position(position: Vector2) -> int:
	if _shared_board_player != 0:
		return _shared_board_player
	return 1 if position.x < Field.mid_x() else 2

## Turn-based shared-board games call this whenever the turn changes; every
## touch is then credited to that player regardless of position. Pass 0 to
## return to positional (split-screen) ownership.
func set_shared_board_turn(player: int) -> void:
	_shared_board_player = player

func _zone_for_position(player: int, position: Vector2) -> int:
	for entry in _zone_rects:
		if entry.player == player and entry.rect.has_point(position):
			return entry.zone
	return NO_ZONE

## Called by a game's setup() to define sub-regions within a player's half.
## rects is an Array of { player: int, zone: int, rect: Rect2 }.
## Pass an empty array to reset to "whole half = zone NO_ZONE" (the default).
func configure_zones(rects: Array) -> void:
	_zone_rects = rects

func get_active_touch_count() -> int:
	return _active_touches.size()

## Debug overlay support: current touches keyed by index, each with
## player/zone/position, for a HUD to visualize live multi-touch state.
func get_active_touches() -> Dictionary:
	return _active_touches.duplicate(true)

func set_debug_overlay_enabled(enabled: bool) -> void:
	debug_overlay_enabled = enabled
