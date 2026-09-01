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

## Day 4 status

Sumo Blob is implemented: manual circle-physics blobs on a platform that shrinks from radius 300→120 over 30 seconds per round, tap-to-dash toward the platform centre with a 0.4s cooldown, blob-blob elastic collision, procedural squash-and-stretch (drawn as a scaled polygon, no sprite needed), haptic pulses on dash/impact via `Input.vibrate_handheld()` gated by `SaveManager.haptics_enabled`, best-of-3. A simultaneous double-fall replays the round without scoring either side.

**All 6 launch games are now implemented and registered** — `GameSelect` no longer shows any "SOON" tile for the launch roster.

What Day 4 explicitly asked for that is **not** done, and can't be done from this environment:
- **Real-hardware multi-touch verification** — still the single most important unresolved item from Day 1, and nothing since has changed that.

(Audio was also listed here as impossible; it since turned out not to be — see "Audio pass" below.)

**Outstanding overall:** Day 5 (AdMob SDK binding via the actual Godot AdMob plugin, platform IAP via the Android IAP plugin/StoreKit, store listing screenshots/video, signed builds, submission) — see PRD §9. `AdManager`'s placement/frequency-cap *logic* is already real and enforced; only the SDK call itself is a stub.

## Art & polish pass (visual — done without an art tool)

There's no image-generation tool in this environment, so "real sprites" means hand-authored vector art rather than commissioned/generated bitmaps. That turned out to be enough to replace every flat-shape placeholder:

- **`shared/art/mascot_p1.svg` / `mascot_p2.svg`** — the cute blob mascot from the PRD's Main Menu wireframe, hand-built as SVG (big eyes, blush, stub arms/legs, thick ink outline, single soft drop shadow — matches the palette's stated art direction). `MainMenu.gd` places both, mirrored via negative `scale.x` on the P2 instance so they face each other, each with an independent looping idle float (`UIUtil.idle_float`) and a hop/squash reaction (`_react_mascots()`) when PLAY is pressed.
- **`shared/art/icons/*.svg`** — one small vector icon per launch game, replacing the emoji labels that rendered as blank tofu boxes (the default Godot theme font has no emoji glyph coverage — a real, if minor, correctness bug fixed as part of this pass, not just cosmetic). Used on `GameSelect` tiles (with a per-tile idle wobble, staggered so tiles don't move in lockstep) and inside `RulesCard`'s diagram slot (replacing the literal "[diagram]" placeholder text), where it idle-floats.
- **`shared/Juice.gd`** — shared Node2D-space helpers for game rendering: `cartoon_circle()`/`cartoon_rect()` draw a thick ink outline + flat fill + soft highlight instead of a flat primitive (used by Air Hockey's puck/paddles, Ping Pong's ball/paddles, Connect Four's tokens); `burst()` spawns a one-shot `CPUParticles2D` confetto burst (Air Hockey goals, Ping Pong points, Sumo Blob eliminations); `decay_squash()` is the shared squash-stretch decay math, now applied to Air Hockey's puck and Ping Pong's ball on every wall/paddle hit (previously only Sumo Blob had this).
- **Connect Four's token-drop bounce animation** — flagged as deferred back on Day 3 — is now implemented (`_falling` dict in `ConnectFour.gd`, simple gravity + damped bounce, drawn separately from the settled grid so a piece visibly falls and bounces into place instead of appearing instantly).
- **Tic-Tac-Toe pieces** now pop in with a back-out overshoot scale animation on placement instead of appearing instantly.
- `UIUtil` gained `pop_in()` (scale-in with overshoot, used for menu title/PLAY button and Game Select tiles on load) and `idle_wobble()`/`idle_float()` (looping, staggerable via a `delay` param so multiple instances don't move in lockstep).

None of this required new engine features — it's all `_draw()`/`Tween`/`CPUParticles2D`, which is why it was reachable without an art pipeline.

## Audio pass — correction to "real audio can't be done here"

Every status section above claimed real audio needed "an audio tool/library this session doesn't have." That was wrong for the same reason the "no Godot binary" claim was wrong: a WAV file is just a header plus PCM samples, and Python's stdlib `wave` module writes one with no third-party dependency at all. There is now a full SFX set and a menu music loop, synthesized from scratch.

- **`shared/audio/sfx/*.wav`** — 13 events (`countdown_tick`, `countdown_go`, `paddle_hit`, `drop`, `tap`, `place`, `blob_impact`, `dash`, `fall`, `goal`, `score`, `win`, `round_win`), each built from simple oscillators (sine/square/triangle/noise) with a linear-attack + exponential-decay envelope; scoring/win cues are short arpeggios up a C-major triad rather than a single tone, so a win reads as celebratory and not just "another blip."
- **`shared/audio/music/menu_loop.wav`** — a bouncy ~118bpm C-pentatonic melody over a slower triangle-wave bass, mixed and peak-normalized. Menu-only, per the PRD's hard "no music during matches" rule.
- **`AudioManager`** now loads every file named in `SFX_EVENTS` from `SFX_DIR` at `_ready()` (guarded by `ResourceLoader.exists()`, so a missing file degrades to the old silent no-op rather than crashing). The PRD's P1/P2 differentiation is done with `pitch_scale` at playback time, not two separate files per event — `play_sfx(event, player)` was already passing the player index everywhere, so this needed no call-site changes.
- `play_menu_music()` now defaults to the bundled loop (no argument needed) and no-ops if music is already playing, so navigating menu → select → settings doesn't restart the track on every scene change. `MatchHost._ready()` calls `stop_music()`, which is what actually enforces "no music during a match."

The generator script is not checked in — the `.wav` files are the artifact. If the sounds ever need regenerating, the approach is just `wave` + `struct` + `math` from the stdlib.

**Glyph coverage cleanup (same root cause as the emoji-tofu bug).** The art pass fixed emoji on game tiles but left the same bug in button labels — `▶ PLAY`, `⚙`, `←`, `✕`, `⏸`, `☰ MENU`, `🔄 REMATCH`, `★ REMOVE ADS`, `Ads Removed ✓` all drew a tofu box for the symbol because the default theme font has no glyph for any of them. All of these are now plain ASCII (`PLAY`, `SET`, `<`, `X`, `II`, `MENU`, `REMATCH`, `REMOVE ADS`, `ADS REMOVED`). **Rule for this project: no non-ASCII in any user-facing string until a font with real glyph coverage is bundled** — comments and docs are fine, `Label`/`Button` text is not.

## Mobile web layout + in-match exit

- **Portrait phones.** The web build previously rendered as a small sideways strip on a portrait phone. The obvious fix — CSS-rotating `#canvas` 90° — was implemented, tested, and **rejected**: Godot's web input reads pointer position from the canvas's post-transform `getBoundingClientRect()` and maps it onto the untransformed pixel buffer, so a rotated canvas scrambles every tap coordinate. That is the *exact* "no controls" bug class already fixed once in this project, and the rotation reintroduced it (verified: taps on a rotated canvas hit nothing). **Do not CSS-transform the Godot canvas.** Instead, the export preset's `html/head_include` adds a full-screen `#rotate-prompt` overlay shown via `@media (orientation: portrait)` asking the player to turn the phone — appropriate since the game is landscape-locked by design anyway. In landscape the canvas fills the viewport with no transform, and touch mapping is untouched.
- **`export_presets.cfg` is gitignored** (it will carry local signing paths once Day 5's Android preset exists), but the Web preset now holds real, non-local configuration — the whole mobile layout fix lives in its `html/head_include`. So **`export_presets.example.cfg` is tracked** as the source of truth for the Web preset: copy it to `export_presets.cfg` in a fresh clone before exporting, and mirror any Web-preset change back into it. Losing this file silently reverts the portrait handling with no compile error to warn you.
- The head include also sets a proper mobile viewport meta (`user-scalable=no`, `viewport-fit=cover`) and `overscroll-behavior: none`, so a stray drag doesn't pan or pull-to-refresh the page mid-match.
- **In-match exit.** `MatchHost` now has a dedicated `X` button in the score bar, next to pause, opening an "Exit this match?" confirm with EXIT TO MENU / KEEP PLAYING. Previously the only way out mid-match was to discover it hidden behind Pause — fine on Android with a hardware back button, a dead end on the web build. It is `Palette.PLAYER_1`, deliberately not `SURFACE`: the score bar behind it is already `SURFACE`, which rendered the button invisible.

## Day 5 status

Everything Day 5 that's pure text/code is done:

- `STORE_LISTING.md` — full title/short description/keywords/long description/screenshot plan, expanded from PRD §10.
- `PRIVACY_POLICY.md` — a real draft (offline-only, ad SDK disclosure, no data collection, IAP handled by the platform, children's-privacy note tied to PRD §8.4/§14's open age-rating decision). Has `[TODO]` markers for a real date/contact/ad-network confirmation before it's hosted.
- Settings now has a working Privacy Policy button (`shell/settings/Settings.gd`) that opens a URL via `OS.shell_open()` — currently a placeholder (`PRIVACY_POLICY_URL`) that needs to point at wherever `PRIVACY_POLICY.md` actually gets hosted.

**What Day 5 also calls for that genuinely cannot be done from this environment**, regardless of effort — these need tools/access this session doesn't have, not just more time:
- **AdMob SDK binding.** Installing the actual Godot AdMob plugin means pulling a native Android (Java/Kotlin + Gradle) and/or iOS plugin into the export pipeline — this needs the Godot editor's AssetLib/export system, not just source files.
- **Platform IAP** (Android IAP plugin / StoreKit) — same constraint, plus a real Google Play Console / App Store Connect product needs to exist first.
- **Store screenshots, preview video, app icon/feature graphic at store resolutions.** Every game currently draws with placeholder `_draw()` shapes (see Day 4 status) — there's nothing screenshot-worthy to capture yet, and no device/simulator here to capture it with anyway.
- **Signed `.aab` / iOS archive.** Requires the Godot editor, export templates, and real signing keys/certificates.
- **Real-hardware multi-touch verification** — unresolved since Day 1, and still the single highest-priority item before any of this ships, per PRD's own stated Day 1 exit criteria.

In short: the app's game logic and shell are code-complete for all 6 launch games (Days 1–4), and the Day 5 paperwork that doesn't require a device or the Godot editor is done. What remains — SDK integration, IAP, real assets, signing, submission — needs a human with a Godot editor, an Android device, and store console access.

## Automated GitHub Pages deployment

GitHub Pages for this repo is already configured as "Deploy from a branch: `gh-pages`" (that's how the Web build referenced in "Engine verification" below first got hosted for on-device testing). `.github/workflows/deploy-pages.yml` automates keeping that branch current: it builds the same Web export described below in CI (fetches Godot + export templates, copies `export_presets.example.cfg` into place, imports, exports release) and pushes the result to `gh-pages` via `peaceiris/actions-gh-pages`. Runs on every push to `main`; can also be triggered manually (Actions tab → "Deploy Web build to GitHub Pages" → Run workflow) against any branch/ref to refresh the live preview before merging. No repo Settings change is needed — it reuses the existing branch-based Pages config rather than switching to the Actions-native deployment method.

## Engine verification (HTML5/Web export) — correction to earlier day logs

Every status section above says "no Godot binary in this environment" — that assumption was wrong wherever the session has network access. Godot 4.3 stable can be fetched directly:

```
curl -sSL -o godot.zip "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip"
curl -sSL -o templates.tpz "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz"
# unzip templates.tpz's templates/ dir to ~/.local/share/godot/export_templates/4.3.stable/
godot --headless --path . --import                       # validates the whole project, prints every parse/scene error
godot --headless --path . --export-debug "Web" build/web/index.html   # needs an export_presets.cfg with a "Web" preset
```

Running this for the first time immediately caught three real bugs that had been sitting unverified since Day 1–2 (see git history for the exact fix commit):

1. **`shared/Palette.gd` was missing `class_name Palette`.** Every script that referenced `Palette.*` failed to compile. Caught by `--import`.
2. **`AudioManager` referenced "SFX"/"Music" audio buses that don't exist** — the project has no custom bus layout, so `AudioServer.get_bus_index()` returned -1 and `set_bus_mute()` threw. Fixed by having `AudioManager._ready()` create the buses at runtime if missing (`_ensure_bus()`).
3. **A real Control layout bug**: combining a non-full-rect `anchors_preset` (e.g. `PRESET_CENTER`, `PRESET_CENTER_TOP`) with a subsequently hand-computed absolute `.position` double-offsets the control — Godot adds `.position` on top of the anchor's own offset rather than treating it as the final absolute position. This silently misplaced the main menu's title/subtitle/PLAY button, GameSelect's/Settings'/Results' titles, and the rules card panel — all rendered off in a corner instead of centered. Fix: don't call `set_anchors_preset()` on a control that also gets a hand-computed absolute `.position` — leave it at the default top-left anchor, where `.position` behaves as plain pixel coordinates. (A `set_anchors_preset()` call with **no** subsequent manual `.position` — e.g. every `PRESET_FULL_RECT` background — is unaffected and still correct.)

None of these three were catchable by reading the code — they only surfaced by actually running Godot. Confirmed via a `--headless --path . --import` full reimport (zero errors) and a Playwright/headless-Chromium smoke test that clicked through Main Menu → Game Select → Rules Card → a live Air Hockey match.

**Correction — a fourth bug slipped past that smoke test, and was only caught by a real device.** The Web build was hosted on GitHub Pages and opened on an actual phone, which reported the game had no controls at all (paddles never moved; the puck drifted into goals on its own). The earlier smoke test's "correctly-scored goal" was a false positive — it only checked that the score changed, not that the paddle had actually moved, and the score can change from unattended physics alone. The real bug: **`MatchHost`'s root node is a full-screen `Control`, and a `Control`'s default `mouse_filter` is `MOUSE_FILTER_STOP`**, which per Godot's own docs "stops the event from propagating further" *even with no `_gui_input` override*. Covering the whole viewport, it silently swallowed every tap/drag over the game area before `InputManager._unhandled_input()` ever saw it — on the Web export *and* on any native build, since this is core `Control` behavior, nothing Web-specific. Fix: `MatchHost.gd` now sets `mouse_filter = Control.MOUSE_FILTER_IGNORE` on itself in `_ready()`, before building its children — interactive children (the pause button) are unaffected since they hit-test with their own filter regardless of their parent's.

Re-verified properly this time using real touch events (Chrome DevTools Protocol `Input.dispatchTouchEvent`, not mouse emulation) and checking paddle *position*, not just score: a single-finger drag moved the paddle to the exact drop point, and a **two-finger simultaneous drag** — one touch beginning on each half, moving at the same time — moved both paddles independently to their own targets. That is the actual Day 1 exit criterion, finally satisfied, even if only in a Web build so far.

**Lesson for future verification passes on this project**: score/outcome changing is not proof that input worked — always check the thing input is supposed to move (paddle/piece position), not just the downstream effect, since downstream effects can happen on their own.

**Practical implication for multi-touch verification**: the HTML5/Web export is a much more reachable way to test real multi-touch than the native Android build — `project.godot` already has `input_devices/pointing/emulate_touch_from_mouse=true`, and a real phone's browser generates genuine `TouchEvent`s against the exact same `InputManager` code path a native build would use. Export with the Web preset, host the `build/web/` output somewhere reachable (e.g. GitHub Pages), and open it on two real fingers on an actual phone screen.

**Still true and unchanged:** no native Android/iOS export has been attempted (needs the Android SDK/NDK, Gradle, and signing keys for a real `.aab`, well beyond a Web export). Real-hardware confirmation now exists for the Web build's control scheme; native input handling (same `InputManager` code, but a different platform input backend) is still unconfirmed on a device.

## Playtest audit pass — the coordinate-space bug that broke three games

`GAME_AUDIT.md` is the full report (two-player playthrough of all 6 games with real CDP touch events). The headline finding, and the rule that came out of it:

**`InputManager` used to split players at `get_visible_rect().x/2` while everything drawn used a hardcoded `640`.** `project.godot` sets `window/stretch/aspect="expand"`, so the visible *design* rect is wider than 1280 on any screen wider than 16:9 — every modern phone. At a 19.5:9 viewport the rect is 1558 design px, putting the input split at x≈779 against a divider drawn at 638. Consequences, all confirmed on screen, not inferred:

- A ~9% strip of Player 2's visible half fed Player 1's paddle.
- All content sat ~76px left of centre with dead space on the right.
- **Tic-Tac-Toe softlocked outright**: all nine cells resolved to P1, so after P1's opening move P2 could never place anywhere and the match could not be finished. Connect Four was similarly broken (P1 reached columns 0–4, P2 only 5–6).

**Rule: never hardcode 1280/720/640 in layout or input code.** `autoload/Field.gd` is the single source of truth for playfield geometry (`mid_x()`, `left()`, `right()`, `top()`, `bottom()`, `center()`, `half_center()`), and `InputManager` splits on `Field.mid_x()` — the same value `MatchHost` draws its divider at. Anything that needs to know where the screen is asks `Field`. `expand` was kept deliberately over switching to `keep`, which would have fixed the split by throwing away ~20% of a tall phone's screen to letterboxing.

**Shared-board games are a different input model.** Tic-Tac-Toe and Connect Four play on one communal board straddling the midline, so screen-half ownership is simply wrong for them — it makes the far side of the board unreachable. `InputManager.set_shared_board_turn(player)` credits every touch to whoever's turn it is; `MatchHost` resets it to 0 before each match so the mode never leaks between games.

Also landed in this pass: real Air Hockey goal mouths (the whole end line used to score) with a drawn rink and velocity-aware hits; symmetric Ping Pong paddles with a swept collision; visible Tap Race tap zones (the rules card referred to two buttons that were never drawn) with a cartoon car replacing the flat-circle racer; mascot faces on the Sumo Blob blobs; a filled Connect Four board; and a shared `TurnBanner` pairing colour with a shape marker and text, per the accessibility rule.

**Verification lesson, restated because it keeps mattering:** check the thing input is supposed to move — paddle position, piece placement — never just the score. The playtest harness lives in `/tmp/pt` (not checked in); it drives `Input.dispatchTouchEvent` through CDP, including genuinely simultaneous two-finger input.

## Shell "smooth, clean" visual pass

The shell screens (Main Menu, Game Select, Rules Card, Results, the win banner, Settings) got a second, distinct visual language layered on top of the sticker style — soft pastel gradient backgrounds and borderless rounded cards/buttons with a gentle drop shadow, closer to a modern wellness-app onboarding flow than a game HUD. **This is additive, not a replacement**: in-game rendering (`Juice.gd`'s cartoon circles/rects, used by every game's pucks/paddles/tokens) and the match HUD (`UIUtil.make_button`/`make_round_button`/`make_score_pill`, used by `MatchHost`'s pause/exit/score chrome) are untouched and still use the thick-ink-outline sticker look on purpose — the two styles are meant to read as "calm shell, energetic match," not as an inconsistency to fix.

- **`Palette.gd`** gained five `GRADIENT_*_TOP`/`_BOTTOM` pairs, one per shell screen (menu/select/rules/results/settings), each its own soft mood the same way each game already owns a full-screen ground colour. `PLAYER_1`/`PLAYER_2` and every other existing constant are unchanged — the fixed player color-coding rule is a gameplay/accessibility invariant, not a shell "look," and stayed out of scope for this pass.
- **`UIUtil.gd`** gained `gradient_bg()` (a `GradientTexture2D`-backed drop-in replacement for `full_rect_bg()`), `soft_glow()` (a radial fade, used behind the Main Menu mascots), `soft_panel_style()` (borderless rounded `StyleBoxFlat` with a soft shadow, no hard ink outline), and `make_soft_button()`/`make_soft_round_button()` (the borderless equivalents of `make_button()`/`make_round_button()`). The original sticker-style helpers are untouched and still used verbatim by `MatchHost` and every game.
- Applied `gradient_bg` + the soft button/panel helpers across `MainMenu.gd`, `GameSelect.gd`, `RulesCard.gd`, `Results.gd`, `WinBanner.gd`, and `Settings.gd`. `WinBanner`'s floating "PLAYER X WINS!" text now sits on a soft card instead of bare on the screen. The Main Menu's mascots get a soft brand-coloured (coral/teal) glow behind them, echoing a hero-character glow without adding a new art asset.
- Verified end-to-end via a real Godot 4.3 Web export (fetched per the "Engine verification" section below) served locally and driven with Playwright/Chromium: Main Menu → Game Select → Rules Card all render and interact correctly with the new styling (screenshots taken, not just a headless import check).

If a future pass wants the sticker style itself softened (i.e. changing how games/match-HUD render), that's a bigger, separate decision — it touches every game's `_draw()` code and the accessibility-driven color/shape pairing rule, not just shell chrome.

## Reference

Full product spec, personas, wireframes, store listing copy, and success metrics: `FACE_OFF_PRD.md`.
