extends Node
## SaveManager — local-only persistence via Godot's ConfigFile. No network,
## no accounts. head_to_head_record here is intentionally NOT this file's
## job — that's session-scoped and lives in GameManager, cleared on app close.

const SAVE_PATH := "user://faceoff.cfg"
const SECTION := "prefs"

var _config := ConfigFile.new()

var ad_free: bool = false
var sfx_enabled: bool = true
var music_enabled: bool = true
var haptics_enabled: bool = true
var games_played_count: int = 0
var rules_seen: Array = [] ## Array of game_id strings

## Party Mode fields -- kept separate from the 1v1 fields above so a party
## game_id can never collide with a 1v1 game_id in one shared "seen" list.
var party_rules_seen: Array = [] ## Array of party game_id strings
var party_last_filters: Dictionary = {} ## party game_id -> {filter_field: value}
var party_dice_count: int = 2
var party_wheel_segments: int = 4

func _ready() -> void:
	load_prefs()

func load_prefs() -> void:
	var err := _config.load(SAVE_PATH)
	if err != OK:
		return # first run / no save yet — defaults stand

	ad_free = _config.get_value(SECTION, "ad_free", false)
	sfx_enabled = _config.get_value(SECTION, "sfx_enabled", true)
	music_enabled = _config.get_value(SECTION, "music_enabled", true)
	haptics_enabled = _config.get_value(SECTION, "haptics_enabled", true)
	games_played_count = _config.get_value(SECTION, "games_played_count", 0)
	rules_seen = _config.get_value(SECTION, "rules_seen", [])
	party_rules_seen = _config.get_value(SECTION, "party_rules_seen", [])
	party_last_filters = _config.get_value(SECTION, "party_last_filters", {})
	party_dice_count = _config.get_value(SECTION, "party_dice_count", 2)
	party_wheel_segments = _config.get_value(SECTION, "party_wheel_segments", 4)

func save_prefs() -> void:
	_config.set_value(SECTION, "ad_free", ad_free)
	_config.set_value(SECTION, "sfx_enabled", sfx_enabled)
	_config.set_value(SECTION, "music_enabled", music_enabled)
	_config.set_value(SECTION, "haptics_enabled", haptics_enabled)
	_config.set_value(SECTION, "games_played_count", games_played_count)
	_config.set_value(SECTION, "rules_seen", rules_seen)
	_config.set_value(SECTION, "party_rules_seen", party_rules_seen)
	_config.set_value(SECTION, "party_last_filters", party_last_filters)
	_config.set_value(SECTION, "party_dice_count", party_dice_count)
	_config.set_value(SECTION, "party_wheel_segments", party_wheel_segments)
	_config.save(SAVE_PATH)

func set_ad_free(value: bool) -> void:
	ad_free = value
	save_prefs()

func set_sfx_enabled(value: bool) -> void:
	sfx_enabled = value
	save_prefs()

func set_music_enabled(value: bool) -> void:
	music_enabled = value
	save_prefs()

func set_haptics_enabled(value: bool) -> void:
	haptics_enabled = value
	save_prefs()

func increment_games_played() -> void:
	games_played_count += 1
	save_prefs()

func has_seen_rules(game_id: String) -> bool:
	return rules_seen.has(game_id)

func mark_rules_seen(game_id: String) -> void:
	if not rules_seen.has(game_id):
		rules_seen.append(game_id)
		save_prefs()

func has_seen_party_rules(game_id: String) -> bool:
	return party_rules_seen.has(game_id)

func mark_party_rules_seen(game_id: String) -> void:
	if not party_rules_seen.has(game_id):
		party_rules_seen.append(game_id)
		save_prefs()

func get_party_filter(game_id: String) -> Dictionary:
	return party_last_filters.get(game_id, {})

func set_party_filter(game_id: String, filters: Dictionary) -> void:
	party_last_filters[game_id] = filters
	save_prefs()

func set_party_dice_count(n: int) -> void:
	party_dice_count = n
	save_prefs()

func set_party_wheel_segments(n: int) -> void:
	party_wheel_segments = n
	save_prefs()
