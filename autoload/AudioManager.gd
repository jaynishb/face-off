extends Node
## AudioManager — thin wrapper around SFX/music buses. No music during
## matches, ever (see PRD Art Direction / Audio) — enforced by callers only
## triggering play_music() from menu/shell scenes, never from a MiniGame.

const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"

var _sfx_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer

## SFX registered per event name, each with distinct P1/P2 pitch-shifted
## variants so players can hear whose action registered. Procedurally
## synthesized (no audio tool in this environment -- see CLAUDE.md); a single
## stream per event is enough since P1/P2 differentiation happens via
## pitch_scale at playback time, not via separate files.
## event_name -> { p1: AudioStream }
var _sfx_library: Dictionary = {}

const SFX_DIR := "res://shared/audio/sfx/"
const MENU_MUSIC := "res://shared/audio/music/menu_loop.wav"

const SFX_EVENTS := [
	"countdown_tick", "countdown_go", "paddle_hit", "drop", "tap", "place",
	"blob_impact", "dash", "fall", "goal", "score", "win", "round_win",
]

const P1_PITCH := 1.0
const P2_PITCH := 1.12

func _ready() -> void:
	_ensure_bus(SFX_BUS)
	_ensure_bus(MUSIC_BUS)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = SFX_BUS
	add_child(_sfx_player)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	_music_player.finished.connect(func(): _music_player.play())
	add_child(_music_player)

	_load_sfx_library()
	_apply_mute_state()

func _load_sfx_library() -> void:
	for event_name in SFX_EVENTS:
		var path := "%s%s.wav" % [SFX_DIR, event_name]
		if ResourceLoader.exists(path):
			_sfx_library[event_name] = {"p1": load(path)}

## The project ships no custom audio bus layout, so SFX/Music don't exist
## until created here -- caught by actually running the project (see
## CLAUDE.md); AudioServer.get_bus_index() silently returns -1 otherwise,
## which set_bus_mute() then rejects.
func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

func _apply_mute_state() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(SFX_BUS), not SaveManager.sfx_enabled)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MUSIC_BUS), not SaveManager.music_enabled)

func play_sfx(event_name: String, player: int = 0) -> void:
	if not SaveManager.sfx_enabled:
		return
	var variant: Dictionary = _sfx_library.get(event_name, {})
	if variant.is_empty():
		return
	var stream: AudioStream = variant.p1 if player == 1 else variant.get("p2", variant.p1)
	_sfx_player.pitch_scale = P2_PITCH if player == 2 else P1_PITCH
	_sfx_player.stream = stream
	_sfx_player.play()

func play_menu_music(stream: AudioStream = null) -> void:
	if not SaveManager.music_enabled:
		return
	if _music_player.playing:
		return
	_music_player.stream = stream if stream else load(MENU_MUSIC)
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()

func set_sfx_enabled(enabled: bool) -> void:
	SaveManager.set_sfx_enabled(enabled)
	_apply_mute_state()

func set_music_enabled(enabled: bool) -> void:
	SaveManager.set_music_enabled(enabled)
	_apply_mute_state()
	if not enabled:
		stop_music()
