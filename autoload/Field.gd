extends Node
## Field — single source of truth for playfield geometry AND for the 180-degree
## rotation of Player 2's half.
##
## PORTRAIT, top/bottom split. P1 owns the BOTTOM half and reads it normally.
## P2 owns the TOP half and reads it rotated by PI, so on a shared phone lying
## flat between two players each one sees their own side right-way-up.
##
## project.godot uses window/stretch/aspect="expand", so the visible design rect
## is TALLER than the 720x1280 design box on any phone taller than 16:9 — which
## is every modern phone. Hardcoding 1280/640 once put each game's layout and
## its player-ownership split in two different places: content rendered flush to
## one edge with dead space at the other, and a ~9% strip of one player's
## visible half silently fed the other player's paddle (GAME_AUDIT.md C1/C2,
## which also softlocked Tic-Tac-Toe). Anything that needs to know where the
## screen actually is asks here, so the drawn split and the input split can
## never drift apart again.
##
## "expand" is kept deliberately rather than switching to "keep": letterboxing
## would fix the split by throwing away ~20% of a tall phone's screen.
##
## ---------------------------------------------------------------------------
## TWO COORDINATE SPACES
##
##   SCREEN space — raw viewport pixels, +y down. This is what InputEvent
##     .position carries, and it is the space every game with ONE shared object
##     (a puck, a ball, a platform) and every shared board draws in.
##
##   PLAYER space — per-player local pixels. (0,0) is that player's own
##     top-left AS THEY READ IT; +x runs left-to-right as they read it; +y runs
##     from the seam outward toward their own screen edge. It is identical for
##     both players, which is the entire point: "y = 0 is the net, y =
##     half_size().y is my back wall" is true for P1 and P2 alike, so a
##     mirrored game is authored exactly once.
##
## player_xform(p) maps PLAYER -> SCREEN and is the ONLY definition of the
## rotation anywhere in this codebase. Drawing consumes it through
## draw_set_transform_matrix(); Controls consume it through node
## rotation/position (see UIUtil.mount_for_player); InputManager inverts it to
## deliver touches. One matrix in both directions, so the drawn thing and the
## touched thing cannot disagree — the same guarantee the old mid_x() gave.

## The horizontal band centred on the split line that the HUD owns (both score
## pills, the pause/exit cluster). It eats equally from both halves — symmetry
## is sacred — unlike the old top-only score bar.
const SEAM_BAND := 84.0

const EDGE_MARGIN := 10.0

## Inset at the two far edges, where portrait phones put the notch and the home
## indicator — and where each player's own back wall / goal line lives.
const SAFE_OUTER := 18.0

func rect() -> Rect2:
	return get_viewport().get_visible_rect()

func width() -> float:
	return rect().size.x

func height() -> float:
	return rect().size.y

## The one true dividing line: above it is Player 2, below it is Player 1.
## InputManager, the drawn seam, and every clamp must agree on this value.
func split_y() -> float:
	return rect().size.y * 0.5

func left() -> float:
	return EDGE_MARGIN

func right() -> float:
	return rect().size.x - EDGE_MARGIN

## Player 2's back wall — the top edge of the play area.
func top() -> float:
	return SAFE_OUTER + EDGE_MARGIN

## Player 1's back wall — the bottom edge of the play area.
func bottom() -> float:
	return rect().size.y - SAFE_OUTER - EDGE_MARGIN

func center() -> Vector2:
	return Vector2(rect().size.x * 0.5, split_y())

func play_height() -> float:
	return bottom() - top()

## The whole play area, both halves, for FIELD-mode games.
func play_rect() -> Rect2:
	return Rect2(left(), top(), right() - left(), bottom() - top())

## The band across the middle that the HUD owns. Games must not put anything a
## player needs to see inside it.
func seam_rect() -> Rect2:
	return Rect2(0.0, split_y() - SEAM_BAND * 0.5, width(), SEAM_BAND)

# --- per-player -------------------------------------------------------------

## That player's half in SCREEN space. The two rects tile the viewport exactly:
## no gap, no overlap. tools/geom_check.gd asserts this.
func player_rect(player: int) -> Rect2:
	var s := split_y()
	if player == 2:
		return Rect2(0.0, 0.0, width(), s)
	return Rect2(0.0, s, width(), height() - s)

## That player's playable area in SCREEN space — their half, minus the seam band
## on the inside and the safe/edge margins on the outside.
func player_play_rect(player: int) -> Rect2:
	var r := player_rect(player)
	var inner := SEAM_BAND * 0.5
	var outer := SAFE_OUTER + EDGE_MARGIN
	var w := right() - left()
	if player == 2:
		return Rect2(left(), outer, w, r.size.y - inner - outer)
	return Rect2(left(), r.position.y + inner, w, r.size.y - inner - outer)

## Size of one half in PLAYER space. The same for both players, by construction.
func half_size() -> Vector2:
	return Vector2(width(), split_y())

## Centre of one player's half in SCREEN space — where their own piece starts.
func half_center(player: int) -> Vector2:
	return player_rect(player).get_center()

## PLAYER -> SCREEN. P1 is a pure translate down to the seam; P2 is a PI
## rotation whose origin lands on the far corner of the top half, so that local
## (0,0) also sits at the seam and local +y runs up-screen, away from them.
##
##   P1:  screen = (lx,      split_y + ly)
##   P2:  screen = (W - lx,  split_y - ly)
##
## A Node2D with rotation = PI and position = (W, split_y) has precisely this
## transform, which is what lets Controls and _draw() share one definition.
func player_xform(player: int) -> Transform2D:
	if player == 2:
		return Transform2D(PI, Vector2(width(), split_y()))
	return Transform2D(0.0, Vector2(0.0, split_y()))

func to_screen(player: int, local: Vector2) -> Vector2:
	return player_xform(player) * local

func to_player(player: int, screen: Vector2) -> Vector2:
	return player_xform(player).affine_inverse() * screen

## Direction-only mapping, for drag deltas — rotation without translation, so a
## drag "away from me" is +y for whoever made it, on either half.
func to_player_dir(player: int, screen_delta: Vector2) -> Vector2:
	return player_xform(player).basis_xform_inv(screen_delta)
