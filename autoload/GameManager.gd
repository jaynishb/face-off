extends Node
## GameManager — scene loading, match lifecycle, and the game registry.
##
## This is the only place that knows the full list of games. Adding a game
## means adding one entry here and dropping a folder under /games — nothing
## else in the shell should need to change.

## game_id -> { scene: String (path to the game's .tscn), display_name: String,
##              icon: String (path to a Texture2D resource) }
const GAME_REGISTRY := {
	"air_hockey": {
		"scene": "res://games/air_hockey/AirHockey.tscn",
		"display_name": "Air Hockey",
		"icon": "res://games/air_hockey/icon.svg",
	},
	"ping_pong": {
		"scene": "res://games/ping_pong/PingPong.tscn",
		"display_name": "Ping Pong",
		"icon": "res://games/ping_pong/icon.svg",
	},
	"tic_tac_toe": {
		"scene": "res://games/tic_tac_toe/TicTacToe.tscn",
		"display_name": "Tic-Tac-Toe",
		"icon": "res://games/tic_tac_toe/icon.svg",
	},
	"tap_race": {
		"scene": "res://games/tap_race/TapRace.tscn",
		"display_name": "Tap Race",
		"icon": "res://games/tap_race/icon.svg",
	},
	"connect_four": {
		"scene": "res://games/connect_four/ConnectFour.tscn",
		"display_name": "Connect Four",
		"icon": "res://games/connect_four/icon.svg",
	},
	"sumo_blob": {
		"scene": "res://games/sumo_blob/SumoBlob.tscn",
		"display_name": "Sumo Blob",
		"icon": "res://games/sumo_blob/icon.svg",
	},
}

## Launch order — the 6 games shipped at v1. Post-launch games get added to
## GAME_REGISTRY plus this list (or a separate UPDATE_ROSTER) when they land.
const LAUNCH_ROSTER := [
	"air_hockey", "ping_pong", "tic_tac_toe", "tap_race", "connect_four", "sumo_blob",
]

var current_game_id: String = ""
var current_match: MiniGame

## Session-scoped head-to-head tally, cleared on app close (not persisted).
## game_id -> { p1_wins: int, p2_wins: int }
var session_head_to_head: Dictionary = {}

signal match_finished(game_id: String, winner: int, score_p1: int, score_p2: int)

func get_roster() -> Array:
	return LAUNCH_ROSTER.duplicate()

func get_game_meta(game_id: String) -> Dictionary:
	return GAME_REGISTRY.get(game_id, {})

## Instances the game scene, wires its match_ended signal, and returns it.
## Caller (GameSelect / the game-hosting shell scene) is responsible for
## adding it to the tree and calling start_match() after the countdown.
func load_game(game_id: String) -> MiniGame:
	var meta: Dictionary = GAME_REGISTRY.get(game_id, {})
	if meta.is_empty():
		push_error("GameManager: unknown game_id '%s'" % game_id)
		return null

	var packed: PackedScene = load(meta.scene)
	var instance := packed.instantiate()
	assert(instance is MiniGame, "Game scene for '%s' must implement MiniGame" % game_id)

	current_game_id = game_id
	current_match = instance
	instance.match_ended.connect(_on_match_ended)
	return instance

func _on_match_ended(winner: int, score_p1: int, score_p2: int) -> void:
	var tally: Dictionary = session_head_to_head.get(current_game_id, {"p1_wins": 0, "p2_wins": 0})
	if winner == 1:
		tally.p1_wins += 1
	elif winner == 2:
		tally.p2_wins += 1
	session_head_to_head[current_game_id] = tally

	SaveManager.increment_games_played()
	match_finished.emit(current_game_id, winner, score_p1, score_p2)

func clear_session_tally() -> void:
	session_head_to_head.clear()
