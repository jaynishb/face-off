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

## Sports set grounds. Each game owns a full-screen ground colour so moving
## between games feels like moving between venues rather than reskinning one
## cream screen (see MiniGame.theme_bg).
const BG_BASKETBALL := Color("#2E3A59")
const COURT_WOOD := Color("#F2DDB0")
const BG_SPRINT := Color("#3B6FA0")
const TRACK_RED := Color("#D9604F")
const INFIELD_GREEN := Color("#4ECB8D")
const BG_DIVING := Color("#8FD4E8")
const POOL_TEAL := Color("#22B8CF")
const BG_HORSE := Color("#9BC7E0")
const PADDOCK_SAND := Color("#DBA97C")
const BG_SWIM := Color("#1E6A85")
const BG_ARCHERY := Color("#A9D9B4")
const RANGE_GRASS := Color("#5FC98F")

const BOARD_CHARCOAL := Color("#2A3038")
const BOARD_HOLE := Color("#49535E")

## Per-party-game grounds -- same "each game owns a full-screen colour"
## convention as the 1v1 games above, just lighter/softer since Party Mode's
## games are mostly Control-UI tools rather than a rendered playfield.
const BG_MOVIE_GUESS := Color("#F1E9FB") # soft violet, matches the party gradient
const BG_DICE_ROLLER := Color("#FFF4E0") # warm cream, calm backdrop for the dice
const BG_CATEGORY_BLITZ := Color("#FFE9E5") # warm blush, ramps toward urgency red
const BG_SPIN_WHEEL := Color("#E6F7F1") # cool mint, sets off the colourful wheel

## Soft pastel gradients for the shell (menu/select/rules/results/settings) --
## each screen gets its own muted mood the same way each game owns a
## full-screen ground colour above. This is the "smooth, clean" shell look
## layered on top of the sticker style, which still governs in-game
## rendering (Juice.gd) and the match HUD -- see CLAUDE.md.
const GRADIENT_MENU_TOP := Color("#FFF3E4")
const GRADIENT_MENU_BOTTOM := Color("#FFE1C2")

const GRADIENT_SELECT_TOP := Color("#EAF7F0")
const GRADIENT_SELECT_BOTTOM := Color("#D8EFE6")

const GRADIENT_RULES_TOP := Color("#E8F5F7")
const GRADIENT_RULES_BOTTOM := Color("#D6ECEF")

const GRADIENT_RESULTS_TOP := Color("#FFF6DE")
const GRADIENT_RESULTS_BOTTOM := Color("#FFE9B8")

const GRADIENT_SETTINGS_TOP := Color("#F3EFEA")
const GRADIENT_SETTINGS_BOTTOM := Color("#E7E1D8")

## Party Mode's own accent -- distinct from every 1v1 player/accent colour so
## the group-play section reads as its own thing on the Main Menu, not a
## variant of PLAY.
const PARTY_PRIMARY := Color("#9B5DE5") # violet

const GRADIENT_PARTY_TOP := Color("#F1E9FB")
const GRADIENT_PARTY_BOTTOM := Color("#E3D3F5")

static func for_player(player: int) -> Color:
	return PLAYER_1 if player == 1 else PLAYER_2

## Full-screen ground for whoever's turn it is.
static func turn_tint(player: int) -> Color:
	return TURN_TINT_P1 if player == 1 else TURN_TINT_P2
