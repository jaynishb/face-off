extends Node
## Field — the single source of truth for playfield geometry.
##
## project.godot uses window/stretch/aspect="expand", so the visible design rect
## is WIDER than the 1280x720 design box on any screen wider than 16:9 — which
## is every modern phone. Hardcoding 1280/640 therefore put each game's layout
## and its player-ownership split in two different places: content rendered
## flush-left with dead space on the right, and a ~9% strip of Player 2's
## visible half silently fed Player 1's paddle (GAME_AUDIT.md C1/C2, which also
## softlocked Tic-Tac-Toe).
##
## Anything that needs to know where the screen actually is asks here, so the
## drawn midline and the input midline can never drift apart again.
##
## "expand" is kept deliberately rather than switching to "keep": letterboxing
## would fix the split by throwing away ~20% of a tall phone's screen. Laying
## out against the real rect uses the whole display instead.

const SCORE_BAR_HEIGHT := 64.0
const EDGE_MARGIN := 10.0

func rect() -> Rect2:
	return get_viewport().get_visible_rect()

func width() -> float:
	return rect().size.x

func height() -> float:
	return rect().size.y

## The one true dividing line: left of it is Player 1, right of it is Player 2.
## InputManager and every game's clamp/draw must agree on this value.
func mid_x() -> float:
	return rect().size.x * 0.5

func left() -> float:
	return EDGE_MARGIN

func right() -> float:
	return rect().size.x - EDGE_MARGIN

## Top of the play area — below the score bar, which overlays the game.
func top() -> float:
	return SCORE_BAR_HEIGHT + 12.0

func bottom() -> float:
	return rect().size.y - EDGE_MARGIN

func center() -> Vector2:
	return Vector2(mid_x(), (top() + bottom()) * 0.5)

func play_height() -> float:
	return bottom() - top()

## Centre of one player's half — where that player's own piece should start.
func half_center(player: int) -> Vector2:
	var mid := mid_x()
	var x := mid * 0.5 if player == 1 else mid + mid * 0.5
	return Vector2(x, (top() + bottom()) * 0.5)
