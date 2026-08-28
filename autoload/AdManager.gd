extends Node
## AdManager — single point of contact for the ad SDK. No game or shell
## scene talks to AdMob directly; everything goes through here so the
## placement/frequency rules below are enforced in exactly one place.
##
## Placement rules (non-negotiable, see PRD 8.1):
## - Interstitial only between match-end and the results screen.
## - Never mid-match, never on launch, never on the rules card.
## - Max 1 interstitial per 3 completed matches, never within 90s of the last.
## - Zero ads for the user's first 3 matches ever.
##
## The actual SDK binding (Godot AdMob plugin) is not wired yet — this is a
## stub that implements the gating logic so shell code can integrate against
## a stable interface from day one.

const MIN_MATCHES_BEFORE_FIRST_AD := 3
const MATCHES_BETWEEN_ADS := 3
const MIN_SECONDS_BETWEEN_ADS := 90.0

var _matches_since_last_ad: int = 0
var _last_ad_unix_time: float = -INF
var _sdk_ready: bool = false

signal interstitial_requested
signal interstitial_dismissed

func _ready() -> void:
	GameManager.match_finished.connect(_on_match_finished)

func _on_match_finished(_game_id: String, _winner: int, _score_p1: int, _score_p2: int) -> void:
	_matches_since_last_ad += 1

## Called by the results-transition flow right before showing the results
## screen. Returns true and fires the ad if eligible; the caller must wait
## for interstitial_dismissed before proceeding to Results if this returns true.
func maybe_show_interstitial() -> bool:
	if SaveManager.ad_free:
		return false
	if SaveManager.games_played_count < MIN_MATCHES_BEFORE_FIRST_AD:
		return false
	if _matches_since_last_ad < MATCHES_BETWEEN_ADS:
		return false
	if Time.get_unix_time_from_system() - _last_ad_unix_time < MIN_SECONDS_BETWEEN_ADS:
		return false

	_show_interstitial()
	return true

func _show_interstitial() -> void:
	interstitial_requested.emit()
	_matches_since_last_ad = 0
	_last_ad_unix_time = Time.get_unix_time_from_system()
	# TODO: bind to the Godot AdMob plugin here; call _on_ad_dismissed() from
	# its dismissal callback instead of the deferred call below once wired.
	call_deferred("_on_ad_dismissed")

func _on_ad_dismissed() -> void:
	interstitial_dismissed.emit()

func request_rewarded_video(_on_reward: Callable, _on_no_reward: Callable) -> void:
	# Opt-in only (e.g. "watch an ad to unlock a skin"); never gates a game.
	# TODO: bind to SDK. Stub declines immediately so callers have a path to test.
	_on_no_reward.call()
