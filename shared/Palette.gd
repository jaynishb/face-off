extends Node
class_name Palette
## Palette — the fixed color system. Every game and shell scene should pull
## colors from here rather than hardcoding hex values, so the system stays
## consistent if a shade ever needs tuning.
##
## Player colors are fixed and never swapped: P1 is always coral, P2 is
## always teal, regardless of which physical side of the phone they sit on.

const PLAYER_1 := Color("#FF5A5F") # coral / warm red
const PLAYER_2 := Color("#22B8CF") # teal / cool blue
const BACKGROUND := Color("#FFF4E0") # warm cream (shell screens)
const SURFACE := Color("#FFFDF7") # off-white
const INK := Color("#1D2B36") # deep navy-black, text
const ACCENT := Color("#FFC857") # sunshine yellow
const SUCCESS := Color("#4ECB8D") # mint

## Outlines are near-black and heavier than INK, which is a text colour. The
## chunky-sticker look this project is going for reads as flat colour bounded
## by a hard black edge; a softer navy outline muddies it.
const OUTLINE := Color("#12181D")

## Per-game grounds. Each game owns a full-screen colour rather than every
## screen sharing one cream, so switching games feels like switching worlds.
## Values are chosen so coral and teal both stay legible against them.
const BG_AIR_HOCKEY := Color("#2F4858") # dark slate, so the pale rink pops
const RINK_ICE := Color("#E9F3F8")

const BG_PING_PONG := Color("#F2BE4C") # tournament yellow surround
const TABLE_GREEN := Color("#67B939")

const BG_TAP_RACE := Color("#7CC7E0") # open sky above the track
const ASPHALT := Color("#3A4048")

const BG_SUMO := Color("#3E4A63") # deep indigo hall
const DOHYO_CLAY := Color("#E5C089")

## Turn-based games tint the whole screen to whoever is on the clock, which is
## the single clearest "it's you" signal on a shared screen.
const TURN_TINT_P1 := Color("#EE9078")
const TURN_TINT_P2 := Color("#67AFD6")

const BOARD_CHARCOAL := Color("#2A3038")
const BOARD_HOLE := Color("#49535E")

static func for_player(player: int) -> Color:
	return PLAYER_1 if player == 1 else PLAYER_2

## Full-screen ground for whoever's turn it is.
static func turn_tint(player: int) -> Color:
	return TURN_TINT_P1 if player == 1 else TURN_TINT_P2
