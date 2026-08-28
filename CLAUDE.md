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

Open the project with `godot4 --editor --path .` (or the Godot 4 editor's "Import" pointed at `project.godot`). No export presets are configured yet (that's Day 5); `export_presets.cfg` is gitignored once it exists since it can carry local signing paths.

## Day 1 status

Foundation scaffold is in place: `project.godot` (landscape lock, mobile renderer, autoloads registered), `InputManager` (multi-touch, zone config, touch-begin ownership), `GameManager` (game registry + `MiniGame` contract wiring), `SaveManager` (ConfigFile-backed prefs), `AudioManager` and `AdManager` stubs (ad placement/frequency-cap rules already enforced in `AdManager`, SDK binding is a TODO), `Palette.gd`, and shared components (`CountdownOverlay`, `ScoreDisplay`, `WinBanner`, `MatchTimer`).

**Outstanding before Day 1 is truly done:** real-hardware multi-touch verification (PRD's stated exit criteria — "two fingers on opposite screen halves both register independently, verified on hardware"). This environment has no Godot binary and no device, so that check has not been run yet. Do this first thing before trusting anything built on top of `InputManager` (all of Day 2 below is currently unverified for the same reason).

## Day 2 status

Shell is wired end to end: `MainMenu` → `GameSelect` → (auto-shown `RulesCard` on first play) → `MatchHost` (countdown → live game → `WinBanner`) → interstitial gate → `Results` → rematch or menu. Air Hockey and Ping Pong are both fully playable (drag-paddle physics, scoring, win condition).

Implementation notes / deviations worth knowing about:
- Screens build their UI in code (`_ready()`) rather than hand-authored node trees in `.tscn` — each `.tscn` is a thin wrapper (root node + script). Chosen because this environment has no Godot editor to hand-verify a complex scene tree; code-built UI is easier to review for correctness by reading it. Revisit once someone can open the editor — hand-tuned `.tscn` layouts will look better and are more designer-friendly to iterate on.
- `RulesCard` is a `class_name` (`CanvasLayer` subclass) instantiated directly (`RulesCard.new()`), not a loaded `.tscn` scene, for the same reason. Same pattern as `CountdownOverlay`/`WinBanner`.
- `MiniGame` contract gained one addition beyond the PRD's literal text: an optional `score_updated(score_p1, score_p2)` signal, so the shell's live score bar (PRD 7.4's pip display) can update mid-match. `match_ended` is unchanged and still the signal that ends a match.
- `GameSelect` checks `ResourceLoader.exists()` on each registry entry's scene path and renders a disabled "SOON" tile for games not yet built (Tic-Tac-Toe, Tap Race, Connect Four, Sumo Blob), so the always-complete `GAME_REGISTRY`/`LAUNCH_ROSTER` doesn't dead-end players on a crash. This self-clears as each game lands — no code change needed.
- `AdManager`'s interstitial is still a stub (`call_deferred` immediately resolves it) — the gating logic (grace period, frequency cap, cooldown) is real and already wired into the `MatchHost` → `Results` transition; only the actual AdMob call is a placeholder (Day 5 work).

## Day 3 status

Tic-Tac-Toe (best of 5), Tap Race, and Connect Four are all implemented and registered — all 6 launch games now have a scene, so `GameSelect`'s "SOON" placeholder no longer applies to any of them.

- **Tic-Tac-Toe**: shared centered board, turn enforced via `current_turn` (a touch from the player who isn't up is ignored), best-of-5 rounds, loser of a round opens the next one, a drawn round replays without scoring either side.
- **Tap Race**: first game to use `InputManager.configure_zones()` — each half splits into a top/bottom tap button. Alternating the two buttons gives the full boost; mashing one gives a reduced "mash" boost, per the PRD's explicit anti-degenerate-strategy note. `MatchHost` now resets `InputManager.configure_zones([])` before every game's `setup()` so a zone config never leaks from one game into the next.
- **Connect Four**: standard 7x6, turn-based like Tic-Tac-Toe but a single decisive match (no rounds) — 4-in-a-row any direction wins, a full board with no winner is a draw. Token-drop bounce animation is deferred to the Day 4 polish pass; drops currently render instantly.

**Outstanding:** Sumo Blob + the art/audio/haptics polish pass (Day 4), and AdMob/IAP/store submission (Day 5) — see PRD §9. Nothing in this repo has been run in the Godot editor yet (still no Godot binary in this environment) — the multi-touch hardware check from Day 1 is still the top-priority unverified item before trusting any of this.

## Reference

Full product spec, personas, wireframes, store listing copy, and success metrics: `FACE_OFF_PRD.md`.
