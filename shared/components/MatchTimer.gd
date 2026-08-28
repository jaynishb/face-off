extends Node
class_name MatchTimer
## Countdown timer for games with a fixed match_duration (0 = untimed,
## handled by the game itself via first-to-N logic instead). Games with a
## duration > 0 should instance this in setup() and connect time_up.

signal time_up
signal tick(seconds_remaining: float)

var _duration: float = 0.0
var _remaining: float = 0.0
var _running: bool = false

func start(duration_seconds: float) -> void:
	_duration = duration_seconds
	_remaining = duration_seconds
	_running = true

func stop() -> void:
	_running = false

func _process(delta: float) -> void:
	if not _running:
		return
	_remaining = max(0.0, _remaining - delta)
	tick.emit(_remaining)
	if _remaining <= 0.0:
		_running = false
		time_up.emit()

func get_remaining() -> float:
	return _remaining

func get_progress() -> float:
	if _duration <= 0.0:
		return 0.0
	return 1.0 - (_remaining / _duration)
