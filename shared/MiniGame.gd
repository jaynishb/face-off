extends Node2D
class_name MiniGame
## Base contract every game scene must implement. The shell (menu, results,
## ad manager, scoring) only ever talks to a game through this contract —
## never through game_id branches in shell code.

var game_id: String = ""
var display_name: String = ""
var rules_text: String = ""
var rules_icon: Texture2D
var match_duration: float = 0.0 ## 0 = untimed / first-to-win

## Each game owns its full-screen ground colour, so moving between games feels
## like moving between worlds rather than reskinning one cream screen. Set in
## _init() or setup(); the shell paints it and never inspects game_id to do so.
var theme_bg: Color = Palette.BACKGROUND
## True when the ground is dark enough that the score bar and its buttons need
## light-on-dark treatment.
var theme_dark: bool = false
## True for games played on one communal board rather than two split halves.
## The shell skips the midline divider for these -- drawing a split down a
## shared board is a lie about how the game is played.
var shared_board: bool = false

signal match_ended(winner: int, score_p1: int, score_p2: int)

## Emitted when a game changes its ground mid-match — turn-based games tint the
## whole screen to whoever is on the clock. The shell tweens to the new colour.
signal theme_changed(bg: Color)

## Optional: emit whenever the live score changes so the shell's score bar
## can update mid-match (PRD 7.4's ●●●○○ pip display). Not required for
## turn-based games that track their own on-board state (e.g. Tic-Tac-Toe).
signal score_updated(score_p1: int, score_p2: int)

## Called once by GameManager right after the scene is instanced, before
## start_match(). config carries any per-launch options (currently unused,
## reserved for things like difficulty/variant flags added later).
func setup(_config: Dictionary) -> void:
	pass

## Called by GameManager once the countdown overlay finishes.
func start_match() -> void:
	pass

## Called by the game itself (never by the shell) when the match resolves.
## winner is 1, 2, or 0 for a draw. Must emit match_ended.
func end_match(winner: int, score_p1: int = 0, score_p2: int = 0) -> void:
	match_ended.emit(winner, score_p1, score_p2)

## Helper for games whose ground follows the active player.
func set_theme_bg(color: Color) -> void:
	theme_bg = color
	theme_changed.emit(color)
