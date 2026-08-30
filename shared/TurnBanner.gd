extends Node
class_name TurnBanner
## Shared "whose turn is it" indicator for the turn-based games.
##
## Replaces the bare coloured bar those games used to draw. Colour alone was
## the only signal, which the PRD's accessibility rule explicitly forbids
## (never colour as the sole differentiator) and which is a bad fit here
## anyway: the wrong player tapping is this genre's main failure mode, so the
## indicator has to be unmissable. Colour is now paired with the player's own
## shape marker (X for P1, O for P2 -- the same marks Tic-Tac-Toe plays with)
## and with plain text.

const FONT_SIZE := 24
const PILL_HEIGHT := 44.0
const MARKER_INSET := 26.0
const TEXT_GAP := 22.0
const PAD_RIGHT := 20.0

static func draw_turn(node: CanvasItem, center: Vector2, player: int) -> void:
	var color := Palette.for_player(player)
	var font := ThemeDB.fallback_font
	var text := "PLAYER %d'S TURN" % player
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)

	# Width follows the text -- a fixed pill width clipped the label.
	var pill_width: float = MARKER_INSET + TEXT_GAP + text_size.x + PAD_RIGHT
	var pill := Rect2(center - Vector2(pill_width * 0.5, PILL_HEIGHT * 0.5), Vector2(pill_width, PILL_HEIGHT))

	Juice.capsule(node, pill, color, 5.0)

	# Shape marker, so the two players differ by more than hue.
	var marker_center := Vector2(pill.position.x + MARKER_INSET, center.y)
	if player == 1:
		var d := 9.0
		node.draw_line(marker_center + Vector2(-d, -d), marker_center + Vector2(d, d), Palette.SURFACE, 5.0)
		node.draw_line(marker_center + Vector2(-d, d), marker_center + Vector2(d, -d), Palette.SURFACE, 5.0)
	else:
		node.draw_arc(marker_center, 10.0, 0.0, TAU, 20, Palette.SURFACE, 5.0)

	var text_pos := Vector2(
		marker_center.x + TEXT_GAP,
		center.y + text_size.y * 0.5 - font.get_descent(FONT_SIZE),
	)
	node.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Palette.SURFACE)
