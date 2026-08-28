# Face Off — CLAUDE.md

Guidance for Claude Code (and any dev) working in this repo. Read `FACE_OFF_PRD.md` first for full product context — this file is the condensed, dev-facing operating manual.

## What this is

**Face Off** — a single mobile app containing 6 (launch) → 10 (post-launch) very short (20–60s) two-player games, both players playing simultaneously on one shared phone screen, split left/right. Fully offline. No login, no server, no network calls except the ad SDK.

Landscape-locked. No portrait mode. No tablet layout. No online multiplayer, no AI opponent, no accounts, no cloud save — see PRD §13 for the full "out of scope" list. Don't build any of that even if it seems like a natural extension.

## Engine & stack

- **Godot 4.x**, 2D renderer, **GDScript**.
- Exports to Android (.aab) and iOS from a single codebase.
- No other engine, no JS/TS game layer, no Unity. This decision is final for v1 (see PRD §4.1 for rationale) — don't relitigate it in code.

## Repo layout (target structure)

```
/faceoff
  /autoload
    GameManager.gd       # scene loading, match state, score
    InputManager.gd      # multi-touch input — build/change this with extreme care
    AudioManager.gd       # SFX bus, music bus, mute state
    SaveManager.gd        # local prefs, unlocks, ad-free flag (Godot ConfigFile)
    AdManager.gd           # ad SDK wrapper, single point of contact
  /shell
    MainMenu.tscn
    GameSelect.tscn
    RulesCard.tscn         # generic, populated per game via metadata
    Results.tscn
    Settings.tscn
  /games
    /air_hockey
    /ping_pong
    /tic_tac_toe
    /tap_race
    /connect_four
    /sumo_blob
    ... (post-launch: mirror_match, hot_potato, tower_topple, colour_flood)
  /shared
    /components            # Timer, ScoreDisplay, CountdownOverlay, WinBanner
    /art                   # shared sprites, fonts, palette resource
    /audio
```

## The MiniGame contract — the most important rule in this codebase

Every game scene extends this and only this. The shell (menu, results, ads, scoring) never contains game-specific logic — it only talks to games through this contract.

```gdscript
extends Node2D
class_name MiniGame

var game_id: String
var display_name: String
var rules_text: String
var rules_icon: Texture2D
var match_duration: float   # 0 = untimed / first-to-win

func setup(config: Dictionary) -> void
func start_match() -> void
func end_match(winner: int) -> void   # 1, 2, or 0 for draw

signal match_ended(winner: int, score_p1: int, score_p2: int)
```

Adding a new game = new folder under `/games` + one line in the game registry. If you find yourself editing shell code to add a game, stop — the contract is being violated somewhere.

## InputManager — build first, touch with care

All player input goes through one autoload. No game should read raw `InputEvent` touch data directly.

```gdscript
signal player_pressed(player: int, zone: int, position: Vector2)
signal player_released(player: int, zone: int, position: Vector2)
signal player_dragged(player: int, zone: int, position: Vector2, delta: Vector2)
```

- Screen splits left = Player 1, right = Player 2. Zones subdivide further per-game via **data**, not per-game code.
- Touch ownership is decided by which half the touch **began** in, and does not change even if the finger drags across the midline mid-touch.
- Multi-touch is mandatory and is the #1 product risk — both players touching simultaneously must register independently. Verify on real budget Android hardware, not just the editor/simulator, before trusting any game built on top of it.
- Keep the toggleable debug overlay (visualizes active touch points + assigned player) working at all times; it's how multi-touch regressions get caught.

## Persistence

Local only, via Godot `ConfigFile`. No backend, no accounts, no analytics SDK at v1.

Fields: `ad_free`, `sfx_enabled`, `music_enabled`, `head_to_head_record` (session-scoped, cleared on app close), `games_played_count` (ad frequency capping), `rules_seen` (per game_id, controls first-play auto rules card).

## Visual & UX rules that constrain implementation

- **Symmetry is sacred.** Identical control area, identical visual weight for both players, regardless of which side of the phone they're on. Any layout change must be mirrored.
- Player color coding is fixed and consistent across every game: P1 = coral `#FF5A5F`, P2 = teal `#22B8CF`. Never use red/green as the sole differentiator; always pair color with a shape/icon marker too (accessibility).
- Full palette: background `#FFF4E0`, surface `#FFFDF7`, ink `#1D2B36`, accent `#FFC857`, success `#4ECB8D`.
- Fonts: chunky rounded geometric sans for display (Baloo 2 / Fredoka / Nunito ExtraBold), Nunito for body. Body text minimum 16sp.
- Motion: back-out ease with overshoot everywhere, nothing linear. Button press = scale to 0.92 and bounce back. Screen transitions ≤200ms.
- No music during matches — ever. Menu-only bouncy loop. Every SFX needs a P1/P2 pitch-shifted variant.
- Rules cards: max 3 lines of text, always paired with a small looping diagram. If a game can't be explained in 3 lines, the game design is wrong, not the rules card.

## Monetization constraints (do not violate)

- Interstitial ads **only** between match-end and results screen. Never mid-match, never on launch, never on the rules card.
- Frequency cap: max 1 interstitial per 3 completed matches, never within 90s of the last one.
- No ads at all for the user's first 3 matches ever.
- Remove Ads is a single non-consumable IAP ($2.99–$3.99, TBD). No other IAP at v1 — no skins, no game packs (those are v1.2+, see PRD §8.3).
- Never a purchase modal that blocks play; never urgency language aimed at children.

## Performance floor

Target 60fps, must remain playable at 30fps on a cheap 2020-era Android device. Test physics-heavy games (Air Hockey, Sumo Blob) against this floor specifically, not just on dev hardware.

## Build order (see PRD §9 for full 5-day plan)

1. Foundation: project setup, landscape lock, `InputManager` + multi-touch verified on real hardware, `GameManager`/`MiniGame` contract, `SaveManager`/`AudioManager` stubs, shared component library, palette/fonts.
2. Shell fully wired end-to-end (menu → select → rules → play → results → rematch) + Air Hockey + Ping Pong.
3. Tic-Tac-Toe (best of 5), Tap Race, Connect Four.
4. Sumo Blob + full art/audio/haptics polish pass across all 6 games.
5. AdMob + IAP integration, store assets, signed builds, submit.

If day 3 slips, cut Connect Four before cutting the polish pass — a smaller set of finished-feeling games beats a larger set of janky ones.

## Commands

No build tooling exists in this repo yet (empty at time of writing). Once the Godot project is scaffolded, document actual editor/CLI export commands here — do not invent commands preemptively.

## Reference

Full product spec, personas, wireframes, store listing copy, and success metrics: `FACE_OFF_PRD.md`.
