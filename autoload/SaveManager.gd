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

func save_prefs() -> void:
	_config.set_value(SECTION, "ad_free", ad_free)
	_config.set_value(SECTION, "sfx_enabled", sfx_enabled)
	_config.set_value(SECTION, "music_enabled", music_enabled)
	_config.set_value(SECTION, "haptics_enabled", haptics_enabled)
	_config.set_value(SECTION, "games_played_count", games_played_count)
	_config.set_value(SECTION, "rules_seen", rules_seen)
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
