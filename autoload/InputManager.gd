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

func _player_for_position(position: Vector2) -> int:
	var half_width := get_viewport().get_visible_rect().size.x * 0.5
	return 1 if position.x < half_width else 2

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
