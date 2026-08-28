extends Node
## AudioManager — thin wrapper around SFX/music buses. No music during
## matches, ever (see PRD Art Direction / Audio) — enforced by callers only
## triggering play_music() from menu/shell scenes, never from a MiniGame.

const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"

var _sfx_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer

## SFX registered per event name, each with distinct P1/P2 pitch-shifted
## variants so players can hear whose action registered.
## event_name -> { p1: AudioStream, p2: AudioStream } (populated as audio assets land)
var _sfx_library: Dictionary = {}

const P1_PITCH := 1.0
const P2_PITCH := 1.12

func _ready() -> void:
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = SFX_BUS
	add_child(_sfx_player)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	_music_player.finished.connect(func(): _music_player.play())
	add_child(_music_player)

	_apply_mute_state()

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

func play_menu_music(stream: AudioStream) -> void:
	if not SaveManager.music_enabled:
		return
	_music_player.stream = stream
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
