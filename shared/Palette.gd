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
const BACKGROUND := Color("#FFF4E0") # warm cream
const SURFACE := Color("#FFFDF7") # off-white
const INK := Color("#1D2B36") # deep navy-black, outlines/text
const ACCENT := Color("#FFC857") # sunshine yellow
const SUCCESS := Color("#4ECB8D") # mint

static func for_player(player: int) -> Color:
	return PLAYER_1 if player == 1 else PLAYER_2
