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
## How this game occupies the portrait screen. The shell frames a game by its
## view_mode and never by its game_id.
##
##   SPLIT  — each player has their own private, mirrored half. The game authors
##            one half in Field's PLAYER space and draws it twice under
##            Field.player_xform(), so Player 2's side is rotated PI and reads
##            right-way-up to them. Symmetry is structural, not hand-mirrored.
##   SHARED — one communal board straddling the seam, drawn upright in SCREEN
##            space. No rotation is possible or meaningful. Turn ownership comes
##            from InputManager.set_shared_board_turn(). The shell skips the seam
##            divider for these -- drawing a split down a shared board is a lie
##            about how the game is played -- and moves the score pills out to
##            each player's outer edge so the board can own the middle.
##   FIELD  — one continuous field both players act on, with a single shared
##            object (a puck, a ball, a platform) that both watch. Drawn upright
##            in SCREEN space, geometry symmetric about the seam so neither
##            player is upside-down. Rotating half of a shared rink would tear it
##            in two, so FIELD games never rotate.
enum ViewMode { SPLIT, SHARED, FIELD }
var view_mode: int = ViewMode.FIELD

## The coordinate space this game wants its touches in; MatchHost forwards it to
## InputManager before setup(). SPLIT games want PLAYER; everything else wants
## SCREEN. Must agree with what the game draws in, or input and art disagree.
var input_space: int = InputManager.Space.SCREEN

## True for games played on one communal board rather than two split halves.
var shared_board: bool:
	get: return view_mode == ViewMode.SHARED

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

## Compute every position derived from the screen here, not in setup(), and
## read them from Field rather than any stored size.
##
## The shell calls this after setup() AND on every viewport resize. That is not
## a rare event on the web: a phone browser resizes the canvas whenever its
## address bar collapses or the orientation settles, which happens *after* the
## scene has already laid itself out. Geometry computed once in setup() is
## frozen at first-frame dimensions -- that is what pushed the Player 2 score
## pill clean off the right edge of a real phone.
##
## Implementations must be idempotent: this can be called many times, mid-match,
## with live pieces on the board.
func layout() -> void:
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
