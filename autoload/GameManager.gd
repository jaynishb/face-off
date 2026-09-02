extends Node
## GameManager — scene loading, match lifecycle, and the game registry.
##
## This is the only place that knows the full list of games. Adding a game
## means adding one entry here and dropping a folder under /games — nothing
## else in the shell should need to change.

## game_id -> { scene: String (path to the game's .tscn), display_name: String,
##              icon: String (path to a Texture2D resource) }
## rules_text is authoritative for GameSelect/RulesCard, which need it before
## a game scene is instantiated. Each MiniGame also sets its own rules_text
## on itself, matching this, per the shell contract in CLAUDE.md.
const GAME_REGISTRY := {
	"air_hockey": {
		"scene": "res://games/air_hockey/AirHockey.tscn",
		"display_name": "Air Hockey",
		"icon": "res://shared/art/icons/air_hockey.svg",
		"rules_text": "Drag your paddle.\nHit the puck into their goal.\nFirst to 5 wins.",
	},
	"ping_pong": {
		"scene": "res://games/ping_pong/PingPong.tscn",
		"display_name": "Ping Pong",
		"icon": "res://shared/art/icons/ping_pong.svg",
		"rules_text": "Slide your paddle.\nDon't let the ball past.\nFirst to 7 wins.",
	},
	"tic_tac_toe": {
		"scene": "res://games/tic_tac_toe/TicTacToe.tscn",
		"display_name": "Tic-Tac-Toe",
		"icon": "res://shared/art/icons/tic_tac_toe.svg",
		"rules_text": "Tap a square.\nThree in a row wins the round.\nFirst to 3 rounds wins.",
	},
	"tap_race": {
		"scene": "res://games/tap_race/TapRace.tscn",
		"display_name": "Tap Race",
		"icon": "res://shared/art/icons/tap_race.svg",
		"rules_text": "Tap your two buttons as fast as you can.\nFirst to the finish wins!",
	},
	"connect_four": {
		"scene": "res://games/connect_four/ConnectFour.tscn",
		"display_name": "Connect Four",
		"icon": "res://shared/art/icons/connect_four.svg",
		"rules_text": "Tap a column to drop your piece.\nFour in a row — any direction — wins.",
	},
	"sumo_blob": {
		"scene": "res://games/sumo_blob/SumoBlob.tscn",
		"display_name": "Sumo Blob",
		"icon": "res://shared/art/icons/sumo_blob.svg",
		"rules_text": "Tap to dash.\nPush them off the edge.\nBest of 3 wins.",
	},

	# --- Sports set --------------------------------------------------------
	# All SPLIT-mode: each player has their own private, mirrored half. Scenes
	# land progressively; until one exists GameSelect renders it as a disabled
	# "SOON" tile rather than a PLAY button that would fail to load, and that
	# self-corrects with no code change when the file appears.
	"basketball": {
		"scene": "res://games/basketball/Basketball.tscn",
		"display_name": "Basketball",
		"icon": "res://shared/art/icons/basketball.svg",
		"rules_text": "Flick to shoot at your hoop.\nMost baskets in 45 seconds wins.",
	},
	"sprint": {
		"scene": "res://games/sprint/Sprint.tscn",
		"display_name": "Sprint",
		"icon": "res://shared/art/icons/sprint.svg",
		"rules_text": "Alternate your two pads to run.\nMashing one is slower.\nFirst to the line wins.",
	},
	"diving": {
		"scene": "res://games/diving/Diving.tscn",
		"display_name": "Diving",
		"icon": "res://shared/art/icons/diving.svg",
		"rules_text": "Tap to launch, hold to tuck.\nTap again to enter straight.\nBest of 3 dives wins.",
	},
	"horse_jump": {
		"scene": "res://games/horse_jump/HorseJump.tscn",
		"display_name": "Horse Jump",
		"icon": "res://shared/art/icons/horse_jump.svg",
		"rules_text": "Tap to jump each hurdle.\nClip one and you stumble.\nFirst to the finish wins.",
	},
	"swimming": {
		"scene": "res://games/swimming/Swimming.tscn",
		"display_name": "Swimming",
		"icon": "res://shared/art/icons/swimming.svg",
		"rules_text": "Tap on the beat to stroke.\nTap the wall to turn.\nFirst to 2 lengths wins.",
	},
	"archery": {
		"scene": "res://games/archery/Archery.tscn",
		"display_name": "Archery",
		"icon": "res://shared/art/icons/archery.svg",
		"rules_text": "Drag to aim, release to shoot.\nMind the wind.\nBest of 5 arrows wins.",
	},
}

## Display order, grouped into the sections Game Select renders. This is the
## only place the roster's shape is described; the shell reads it and never
## hardcodes a game list of its own.
const CATEGORIES := [
	{
		"name": "CLASSIC",
		"games": ["air_hockey", "ping_pong", "tic_tac_toe", "tap_race", "connect_four", "sumo_blob"],
	},
	{
		"name": "SPORTS",
		"games": ["basketball", "sprint", "diving", "horse_jump", "swimming", "archery"],
	},
]

## Flat display order, derived from CATEGORIES so the two can never disagree.
static func _flatten_roster() -> Array:
	var out := []
	for category in CATEGORIES:
		out.append_array(category.games)
	return out

var current_game_id: String = ""
var current_match: MiniGame

## Set by GameSelect before changing to MatchHost.tscn; read once by MatchHost.
var pending_game_id: String = ""

## Set right before the Results scene is loaded, since change_scene_to_file()
## discards local state. Results reads these in _ready().
var last_winner: int = 0
var last_score_p1: int = 0
var last_score_p2: int = 0

## Session-scoped head-to-head tally, cleared on app close (not persisted).
## game_id -> { p1_wins: int, p2_wins: int }
var session_head_to_head: Dictionary = {}

signal match_finished(game_id: String, winner: int, score_p1: int, score_p2: int)

func get_roster() -> Array:
	return _flatten_roster()

## Sections for Game Select, each { name: String, games: Array }.
func get_categories() -> Array:
	return CATEGORIES.duplicate(true)

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

	last_winner = winner
	last_score_p1 = score_p1
	last_score_p2 = score_p2

	SaveManager.increment_games_played()
	match_finished.emit(current_game_id, winner, score_p1, score_p2)

func get_session_tally(game_id: String) -> Dictionary:
	return session_head_to_head.get(game_id, {"p1_wins": 0, "p2_wins": 0})

func clear_session_tally() -> void:
	session_head_to_head.clear()
