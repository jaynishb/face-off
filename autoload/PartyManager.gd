extends Node
## PartyManager — the Party Mode equivalent of GameManager, deliberately
## smaller: no match lifecycle, no score, no session tally, no winner. Party
## games are a shared "pass the phone" tool, not a scored 2-player match, so
## this stays a separate registry rather than a second shape bolted onto
## GameManager (which also owns 1v1 match-lifecycle concerns that have no
## party analogue).

## game_id -> { scene, display_name, icon, rules_text } — same shape as
## GameManager.GAME_REGISTRY.
const PARTY_GAME_REGISTRY := {
	"movie_guess": {
		"scene": "res://games/party/movie_guess/MovieGuess.tscn",
		"display_name": "Movie Guess",
		"icon": "res://shared/art/icons/movie_guess.svg",
		"rules_text": "Pick an era and language.\nReveal a movie.\nGroup guesses it out loud.",
	},
	"dice_roller": {
		"scene": "res://games/party/dice_roller/DiceRoller.tscn",
		"display_name": "Dice Roller",
		"icon": "res://shared/art/icons/dice_roller.svg",
		"rules_text": "Pick how many dice.\nTap ROLL.\nRead the total.",
	},
	"category_blitz": {
		"scene": "res://games/party/category_blitz/CategoryBlitz.tscn",
		"display_name": "Category Blitz",
		"icon": "res://shared/art/icons/category_blitz.svg",
		"rules_text": "A category appears, timer starts.\nPass the phone, everyone names one.\nBeat the buzzer.",
	},
	"spin_the_wheel": {
		"scene": "res://games/party/spin_the_wheel/SpinTheWheel.tscn",
		"display_name": "Spin the Wheel",
		"icon": "res://shared/art/icons/spin_the_wheel.svg",
		"rules_text": "Set how many players.\nTap SPIN.\nWhoever it lands on is picked.",
	},
}

const PARTY_ROSTER := ["movie_guess", "dice_roller", "category_blitz", "spin_the_wheel"]

var current_game_id: String = ""

## Set by PartyGameSelect before changing to PartyHost.tscn; read once by
## PartyHost.
var pending_game_id: String = ""

func get_roster() -> Array:
	return PARTY_ROSTER.duplicate()

func get_party_game_meta(game_id: String) -> Dictionary:
	return PARTY_GAME_REGISTRY.get(game_id, {})

## Instances the party game scene. Caller (PartyHost) is responsible for
## adding it to the tree and calling start().
func load_party_game(game_id: String) -> PartyGame:
	var meta: Dictionary = PARTY_GAME_REGISTRY.get(game_id, {})
	if meta.is_empty():
		push_error("PartyManager: unknown party game_id '%s'" % game_id)
		return null

	var packed: PackedScene = load(meta.scene)
	var instance := packed.instantiate()
	assert(instance is PartyGame, "Party scene for '%s' must implement PartyGame" % game_id)

	current_game_id = game_id
	return instance
