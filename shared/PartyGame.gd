extends Node2D
class_name PartyGame
## Base contract every Party Mode scene implements. Deliberately not MiniGame:
## there is no split screen, no player 1/2, no winner, no score, and no
## match_duration. Party games are a shared "pass the phone" tool the group
## looks at together — the shell (PartyGameSelect/PartyHost) only ever talks
## to a party game through this contract, same discipline as MiniGame.

var game_id: String = ""
var display_name: String = ""
var rules_text: String = ""

## Each party game owns its full-screen ground colour, same rationale as
## MiniGame.theme_bg -- moving between party games should feel like moving
## between tools, not reskinning one screen.
var theme_bg: Color = Palette.BACKGROUND
var theme_dark: bool = false

## Emitted when a game wants to retint the ground live (e.g. Category Blitz
## reddening as its timer runs low). Optional -- most party games never emit
## this. PartyHost tweens to the new colour exactly like MatchHost does.
signal theme_changed(bg: Color)

## Called once by PartyManager right after the scene is instanced, before
## start(). config is reserved for future per-launch options (unused today).
func setup(_config: Dictionary) -> void:
	pass

## Compute every screen-derived position here, not in setup() -- called after
## setup() AND on every viewport resize, same idempotency requirement as
## MiniGame.layout() (mobile browser address-bar collapse resizes the canvas
## after first layout; see Field.gd).
func layout() -> void:
	pass

## Vertical anchor for a party game's content column, given how tall that column
## is. Party games draw ONE upright block in SCREEN space -- there is no split
## and no rotation, because everybody is looking at the phone the same way up.
##
## Anchoring that block to Field.top() was right on a 720-tall landscape screen,
## where the block filled it. On a portrait phone the play area is nearly twice
## as tall, so the same anchor pins everything to the top and leaves the bottom
## half empty -- the dice sat in the top third with nothing under them. Centring
## on the play area puts the content where the eye and the thumb both are.
##
## Pass the block's own height; each game knows its own extent, and a game that
## grows past the screen still starts at the top rather than being pushed off it.
func content_top(content_height: float) -> float:
	var play := Field.play_rect()
	return play.position.y + maxf(0.0, (play.size.y - content_height) * 0.5)

## Called by PartyHost once the scene is in the tree and laid out. No
## countdown precedes this -- party games aren't a synchronized start for two
## competing players, so a 3-2-1 beat would just be friction.
func start() -> void:
	pass

## Helper for games whose ground shifts live (Category Blitz's urgency tint).
func set_theme_bg(color: Color) -> void:
	theme_bg = color
	theme_changed.emit(color)
