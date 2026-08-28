# Face Off — Product Requirements Document

**Version:** 1.0
**Date:** 28 August 2026
**Owner:** Jaynish Buddhdev
**Status:** Pre-development — ready for build

---

## 0. How to use this document

This PRD is written to be self-contained. Any developer or LLM picking this up should be able to read this file alone and understand the product, the stack, the scope, the visual direction, and the build order — without needing prior conversation context.

---

## 1. Product Vision

**One line:** Two people, one phone, no internet — a pocket arcade of fast head-to-head games playable on a single shared screen.

**The problem:** Almost all mobile multiplayer requires a connection, an account, matchmaking, and a second device. There is no good answer for "two people sitting next to each other with one phone and no wifi."

**The product:** A single app containing a collection of very short (20–60 second) two-player games. Both players play simultaneously on the same screen, each controlling their half via dedicated touch zones. Fully offline. No login. No server. Instant to start.

**Positioning statement:** The offline angle is the marketing story, not the game count. Store listing, screenshots, and keywords should lead with "no wifi needed, one phone, two players."

### Naming

Primary candidate: **Face Off**

Alternates (check store + domain availability before locking):
- Two Thumbs
- Duel Up
- Split Screen
- Thumb War

Bundle ID placeholder: `com.<yourorg>.faceoff`

---

## 2. Target Audience

### Persona A — "The Parent"
- Parent or guardian of two children aged 5–12
- Context: car journeys, restaurants, flights, waiting rooms, medical appointments
- Need: hand over one phone, keep two kids occupied and not fighting, no data used
- Cares about: no ads mid-play, no in-app purchase traps aimed at kids, quick to explain
- Search terms: "games without wifi", "2 player games one phone", "offline games for kids"

### Persona B — "The Pair"
- Teens, couples, flatmates, colleagues on a break — ages 13–30
- Context: killing five minutes together, a bar, a commute, a lunch break
- Need: something instantly competitive with zero setup or explanation
- Cares about: pace, humour, rematch speed, bragging rights
- Search terms: "2 player games", "offline 2 player", "same screen multiplayer"

Same product, two messaging angles. Store screenshots should show both a kid pair and an adult pair.

### Anti-audience
Not building for: solo players, online competitive players, anyone wanting depth or progression. Session length is the product, not a limitation.

---

## 3. Core Design Principles

1. **Zero to playing in under 10 seconds.** No splash video, no login, no tutorial gate.
2. **Every game readable in one sentence.** If the rules card needs a paragraph, cut the game.
3. **A match is 20–60 seconds.** Rematch button is the biggest button on the results screen.
4. **Never interrupt a match.** No ad, no popup, no notification between round start and round end.
5. **Symmetry is sacred.** Both players get identical control area, identical visual weight, no advantage from which side of the phone they sit on.
6. **Fail gracefully at 30fps.** Target 60fps but every game must be playable on a cheap Android device from 2020.

---

## 4. Technical Specification

### 4.1 Engine — Godot 4.x

**Decision: Godot 4 (2D renderer), GDScript.**

Rationale:
- Purpose-built 2D pipeline with a real physics engine — no fighting a general-purpose UI framework for 60fps collision response
- Free, MIT licensed, no revenue share, no seat fees
- Small export size (~40–60MB for the full app with 10 games)
- Single codebase exports to both Android (.aab) and iOS
- Scene system maps perfectly to "one game = one scene" architecture

**Rejected alternatives:**
- *React Native / Expo* — fine for the shell UI, but every game would need a canvas or Skia layer bolted on, plus a physics library, plus a game loop. You end up writing a game engine badly. Touch latency and dropped frames under physics load are the specific failure mode.
- *Unity* — capable, but heavier export size, licensing overhead, and slower iteration for simple 2D. The asset store advantage doesn't matter when the art is custom and cartoonish.
- *Flutter / Flame* — closer than React Native, but a smaller ecosystem and weaker physics than Godot for this exact use case.

### 4.2 Platform Targets

| | Minimum | Target |
|---|---|---|
| Android | API 24 (Android 7.0) | API 34 |
| iOS | iOS 14 | iOS 17+ |
| Orientation | Landscape locked | Landscape locked |
| Screen | 5.0" and up | 6.1"–6.7" |
| Frame rate | 30fps floor | 60fps |
| Install size | — | Under 70MB |

Landscape is locked because both players need equal screen real estate side by side. Do not build a portrait mode.

### 4.3 Architecture

```
/faceoff
  /autoload
    GameManager.gd        # scene loading, match state, score
    InputManager.gd       # THE critical one — see 4.4
    AudioManager.gd       # SFX bus, music bus, mute state
    SaveManager.gd        # local prefs, unlocks, ad-free flag
    AdManager.gd          # ad SDK wrapper, single point of contact
  /shell
    MainMenu.tscn
    GameSelect.tscn
    RulesCard.tscn        # generic, populated per game
    Results.tscn
    Settings.tscn
  /games
    /air_hockey
    /ping_pong
    /tic_tac_toe
    /tap_race
    /connect_four
    /sumo_blob
    ...
  /shared
    /components           # Timer, ScoreDisplay, CountdownOverlay, WinBanner
    /art                  # shared sprites, fonts, palette resource
    /audio
```

**Every game scene implements the same contract:**

```gdscript
extends Node2D
class_name MiniGame

# Required metadata
var game_id: String
var display_name: String
var rules_text: String
var rules_icon: Texture2D
var match_duration: float   # 0 = untimed / first-to-win

# Required lifecycle
func setup(config: Dictionary) -> void
func start_match() -> void
func end_match(winner: int) -> void   # 1, 2, or 0 for draw

# Required signal
signal match_ended(winner: int, score_p1: int, score_p2: int)
```

The shell never needs to know anything game-specific. Adding game #10 means dropping in a folder and registering one line in the game registry.

### 4.4 Input Manager — build this first, on day one

This is the single highest-leverage piece of the codebase. Every game reads player input from one abstraction. Get this wrong and each new game becomes a rewrite.

```gdscript
# InputManager.gd (autoload)

signal player_pressed(player: int, zone: int, position: Vector2)
signal player_released(player: int, zone: int, position: Vector2)
signal player_dragged(player: int, zone: int, position: Vector2, delta: Vector2)

# Screen is split: left half = Player 1, right half = Player 2
# Each half can optionally subdivide into zones (e.g. left/right buttons)
```

Requirements:
- **Multi-touch mandatory.** Both players touching simultaneously must both register. This is the number one bug risk. Test on real hardware early — some cheap Android panels have poor multi-touch tracking.
- Touch ownership is assigned by which screen half the touch *began* in, and stays with that player even if the finger drags across the midline.
- Zone config is per-game data, not per-game code.
- Include a debug overlay (toggleable in settings) that visualises active touch points and their assigned player.

### 4.5 Data & Persistence

Local only. No network calls anywhere in the app except the ad SDK.

Stored via Godot's `ConfigFile` in user data:
- `ad_free: bool`
- `sfx_enabled`, `music_enabled`
- `head_to_head_record: { game_id: {p1_wins, p2_wins} }` — session-scoped tally, cleared on app close
- `games_played_count` — used for ad frequency capping
- `rules_seen: [game_id]` — so the rules card auto-shows on first play of each game only

### 4.6 Third-party dependencies

Keep this list short.

- **AdMob** via the Godot AdMob plugin (or Unity LevelPlay if mediation is wanted later)
- **In-app purchase** — Godot's Android IAP plugin + StoreKit for iOS, single non-consumable product
- Nothing else. No analytics SDK at launch — Play Console and App Store Connect give enough for v1. Add analytics in v1.1 if needed.

---

## 5. Game Roster

### Scope decision — read this before building

**Ship 6 polished games at launch, not 10.** A janky game damages reviews more than a missing game does. The remaining 4 ship as a free content update 2–3 weeks post-launch, which also gives a re-engagement hook and a "new games added" store update.

The store listing can still say "10+ games" once the update lands. Do not claim it at launch.

### 5.1 Launch Six

#### 1. Air Hockey
- **Mechanic:** Each player drags a paddle within their half. Puck bounces with momentum. First to 5 goals.
- **Rules card:** "Drag your paddle. Hit the puck into their goal. First to 5 wins."
- **Why:** Instantly understood, satisfying physics, the flagship screenshot.
- **Build notes:** Simple `CharacterBody2D` puck with high bounce, paddle clamped to half-screen. Add slight paddle velocity transfer for feel.

#### 2. Ping Pong
- **Mechanic:** Vertical paddles, drag up/down. Ball speeds up on each rally hit. First to 7.
- **Rules card:** "Slide your paddle. Don't let the ball past. First to 7 wins."
- **Why:** The most universally known game on earth. Zero explanation needed.
- **Build notes:** Cap max ball speed. Increase paddle-english effect with rally length.

#### 3. Tic-Tac-Toe (Best of 5)
- **Mechanic:** Standard 3×3, but a match is best-of-five rounds so it resolves in under 60 seconds and draws don't feel like nothing happened.
- **Rules card:** "Tap a square. Three in a row wins the round. First to 3 rounds wins."
- **Why:** The universal fallback. Also the only turn-based game in the launch set — good pacing variety.
- **Build notes:** Grid is centred; both players tap the same board. Highlight whose turn it is with a strong colour cue on their side of the screen.

#### 4. Tap Race
- **Mechanic:** Two cars on parallel tracks. Alternate-tap two buttons to accelerate. First across the line wins.
- **Rules card:** "Tap your two buttons as fast as you can. First to the finish wins!"
- **Why:** Pure chaos, zero skill barrier, works for a 5-year-old and a 25-year-old equally.
- **Build notes:** Alternating taps must be enforced (mashing one button gives less speed) or it degrades into a single-finger spam contest. Add a rubber-band boost for the trailing player so races stay close.

#### 5. Connect Four
- **Mechanic:** Standard 7×6 drop-token grid. Tap a column to drop.
- **Rules card:** "Tap a column to drop your piece. Four in a row — any direction — wins."
- **Why:** Familiar, slightly deeper than tic-tac-toe, good for the older audience.
- **Build notes:** Animate the token drop with a bounce. Win detection is a simple 4-direction scan.

#### 6. Sumo Blob
- **Mechanic:** Two round blobs on a circular platform that shrinks over time. Tap your side to dash toward the centre. Knock the other blob off. Best of 3.
- **Rules card:** "Tap to dash. Push them off the edge. Best of 3 wins."
- **Why:** This is the *original* one that gives the app personality. Physics comedy, high replay.
- **Build notes:** Dash is an impulse with a short cooldown (~0.4s) so it's rhythmic not spammy. Blobs squash-and-stretch on impact. Platform shrinks from 100% to 40% over 30 seconds to force resolution.

### 5.2 Update Four (post-launch)

#### 7. Mirror Match
- **Mechanic:** Both players control the *same* character — P1 controls horizontal, P2 controls jump. Cooperate to reach the exit before the timer.
- **Why:** The one co-op game. Genuinely funny and gets people talking to each other.
- **Risk:** Hardest to design levels for. Correctly deferred out of launch.

#### 8. Hot Potato
- **Mechanic:** A lit bomb bounces between the two halves. Tap to whack it back. Random fuse timer — whoever's holding it when it blows loses.
- **Why:** Tension and screaming. Very short rounds.

#### 9. Tower Topple
- **Mechanic:** Turn-based. Each player taps to drop a wobbly block onto a growing stack. Knock it over and you lose.
- **Why:** The calm one. Good pacing contrast against everything else.

#### 10. Colour Flood
- **Mechanic:** A shared grid. Each player taps to spread their paint into adjacent cells. Most territory after 20 seconds wins.
- **Why:** The most strategic of the set, and visually the best-looking one.

---

## 6. Art Direction

### The vibe
Funky, cute, chunky cartoon. Think bold rounded shapes, thick outlines, exaggerated squash-and-stretch, and a palette that pops on a cheap screen. Everything should look tappable and slightly bouncy. Playful, not childish — it has to work for a 25-year-old as much as a 7-year-old.

Reference feel: rounded vector illustration, high-saturation flat colours with a single soft shadow, no gradients-as-texture, no realism, no gloss.

### Colour system

Players are colour-coded consistently across every single game — this is a core usability rule, not a style choice.

| Role | Colour | Hex |
|---|---|---|
| Player 1 | Coral / warm red | `#FF5A5F` |
| Player 2 | Teal / cool blue | `#22B8CF` |
| Background base | Warm cream | `#FFF4E0` |
| Surface / cards | Off-white | `#FFFDF7` |
| Ink / outlines | Deep navy-black | `#1D2B36` |
| Accent / highlight | Sunshine yellow | `#FFC857` |
| Success | Mint | `#4ECB8D` |

Never use red/green as the sole player differentiator (colour-blindness). Coral/teal is safe. Additionally, always pair colour with a shape or icon marker per player.

### Typography
- **Display / headings:** a chunky rounded geometric sans — e.g. Baloo 2, Fredoka, or Nunito ExtraBold
- **Body / rules text:** the same family at regular weight, or Nunito
- Minimum body size 16sp. Rules text must be legible to a parent reading it aloud.

### Motion
- Everything eases with a slight overshoot (back-out easing). Nothing moves linearly.
- Button press: scale to 0.92 and back with a bounce.
- Score increment: pop to 1.3 scale, settle.
- Screen transitions: 200ms slide or wipe. Never longer.
- Impact events: 3–6 frame squash on both objects, plus a short haptic buzz.

### Audio
- Chunky, cartoonish SFX — pops, boings, whooshes. No realistic sounds.
- Light bouncy loop on menus only. **No music during matches** — it competes with two people shouting at each other.
- Every SFX must have a distinct P1 and P2 variant (slight pitch shift) so players can hear whose action registered.

---

## 7. Screens & Wireframes

All screens are landscape.

### 7.1 Main Menu

```
┌──────────────────────────────────────────────────┐
│  [⚙]                                        [?]  │
│                                                  │
│              ╔══════════════════╗                │
│              ║    F A C E  O F F ║               │
│              ╚══════════════════╝                │
│                                                  │
│           ┌────────────────────────┐             │
│           │       ▶  P L A Y       │             │
│           └────────────────────────┘             │
│                                                  │
│           ┌────────────────────────┐             │
│           │   ★ REMOVE ADS         │             │
│           └────────────────────────┘             │
│                                                  │
│   [ two cartoon blobs facing each other, idle ]  │
└──────────────────────────────────────────────────┘
```

- Logo animates in with a bounce on cold start only
- PLAY is the dominant element, roughly 40% of screen width
- Settings gear top-left, credits/info top-right
- The two mascot blobs idle-animate and react when PLAY is pressed

### 7.2 Game Select

```
┌──────────────────────────────────────────────────┐
│  [←]            CHOOSE A GAME                    │
│                                                  │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐    │
│  │  🏒    │ │  🏓    │ │  ⭕❌  │ │  🏎    │    │
│  │  AIR   │ │  PING  │ │  TIC   │ │  TAP   │    │
│  │ HOCKEY │ │  PONG  │ │TAC TOE │ │  RACE  │    │
│  │    [?] │ │    [?] │ │    [?] │ │    [?] │    │
│  └────────┘ └────────┘ └────────┘ └────────┘    │
│                                                  │
│  ┌────────┐ ┌────────┐                          │
│  │  🔴🟡  │ │  🟠🔵  │      ← scrolls           │
│  │CONNECT │ │  SUMO  │        horizontally      │
│  │  FOUR  │ │  BLOB  │                          │
│  │    [?] │ │    [?] │                          │
│  └────────┘ └────────┘                          │
└──────────────────────────────────────────────────┘
```

- Chunky card tiles, 2 rows, horizontal scroll
- Each tile has its own **[?] rules button** in the corner — tapping it opens the rules card without launching the game
- Tiles have a slight idle wobble, stagger-animated
- Tapping a tile the first time auto-opens the rules card before starting

### 7.3 Rules Card (generic component)

```
┌──────────────────────────────────────────────────┐
│                                            [✕]   │
│      ┌────────────────────────────────────┐      │
│      │                                    │      │
│      │        A I R   H O C K E Y         │      │
│      │                                    │      │
│      │    ┌──────────────────────┐        │      │
│      │    │   [simple diagram:   │        │      │
│      │    │    paddle + puck +   │        │      │
│      │    │    goal, animated]   │        │      │
│      │    └──────────────────────┘        │      │
│      │                                    │      │
│      │  Drag your paddle.                 │      │
│      │  Hit the puck into their goal.     │      │
│      │  First to 5 wins.                  │      │
│      │                                    │      │
│      │      ┌──────────────────┐          │      │
│      │      │   GOT IT!  ▶     │          │      │
│      │      └──────────────────┘          │      │
│      └────────────────────────────────────┘      │
└──────────────────────────────────────────────────┘
```

- **Maximum three short lines of text.** If a game needs more, redesign the game.
- Always paired with a small looping diagram or animated GIF-style illustration
- Reachable from: the [?] on the game tile, auto-shown on first play, and a [?] in the pause menu
- One shared scene, populated from the game's `rules_text` and `rules_icon` metadata

### 7.4 In-Game Layout (universal)

```
┌──────────────────────────────────────────────────┐
│  P1  ●●●○○           [⏸]           ○○○○  P2      │
├──────────────────────┬───────────────────────────┤
│                      │                           │
│                      │                           │
│    PLAYER 1 ZONE     │      PLAYER 2 ZONE        │
│      (coral)         │        (teal)             │
│                      │                           │
│                      │                           │
└──────────────────────┴───────────────────────────┘
```

- Thin score bar at top, player colour on their respective side
- Pause button dead centre top — equidistant, no player advantage
- The midline divider is subtly visible in every game so ownership is never ambiguous
- 3-2-1 countdown overlay before every match start (with a distinct sound)

### 7.5 Results

```
┌──────────────────────────────────────────────────┐
│                                                  │
│              ★  P L A Y E R  1  ★                │
│                    W I N S !                     │
│                                                  │
│         [winning blob doing a victory jig]       │
│                                                  │
│              Today:  P1 3  —  2 P2               │
│                                                  │
│   ┌──────────────────┐   ┌──────────────────┐   │
│   │   🔄 REMATCH     │   │   ☰ MENU         │   │
│   └──────────────────┘   └──────────────────┘   │
│                                                  │
└──────────────────────────────────────────────────┘
```

- **REMATCH is the biggest, brightest button on the screen.** This is the single most important conversion point in the app for session length.
- Session head-to-head tally shown to fuel "one more go"
- Interstitial ad, when shown, appears *before* this screen renders — never on top of it

### 7.6 Settings

Minimal: SFX toggle, Music toggle, Haptics toggle, Remove Ads (or "Ads Removed ✓"), Restore Purchase, Privacy Policy link, version number.

---

## 8. Monetisation

### Model: ad-supported free, with a single ad-removal purchase.

### 8.1 Advertising

**Placement rules (non-negotiable):**
- Interstitial **only** on the transition from match-end to results screen
- **Never** during a match. Never on app launch. Never on the rules card.
- **Frequency cap:** show at most 1 interstitial per 3 completed matches, and never within 90 seconds of the previous ad
- **First-session grace:** no ads at all for the user's first 3 matches ever. Let them fall in love first.
- Optional rewarded video: "watch an ad to unlock a skin" — purely opt-in, never gating a game

**Expected performance:** offline casual games typically see low eCPM (roughly $2–8 per 1000 impressions depending on geography, with tier-1 markets at the higher end). Ad revenue alone on a small install base is not a business. Treat ads as the floor, not the plan.

### 8.2 In-App Purchase

**"Remove Ads" — one-time, non-consumable, priced at $2.99–$3.99.**

This is where the actual revenue is. Casual offline apps often see 1–3% conversion on ad-removal at this price point.

Placement of the offer:
- A permanent, tasteful button on the main menu
- A single non-aggressive prompt after the 10th interstitial has been shown
- Never a modal that blocks play. Never aimed at children with urgency language.

### 8.3 Future revenue (v1.2+)

- **Skin packs** — cosmetic blob/paddle/car skins, $0.99–$1.99 per pack or a $4.99 bundle. Purely visual, no gameplay effect.
- **Game pack expansions** — a themed set of 5 additional games as a paid add-on
- Do not build either of these before launch.

### 8.4 Compliance — important

If the app is rated for children or appears in Play's Families programme, ad content and data handling rules tighten significantly (COPPA in the US, GDPR-K in the EU, Google Play Families Policy). Decide the target age rating **before** integrating the ad SDK, because it changes the required ad configuration and the SDKs you're permitted to use. Safest v1 route: rate the app for a general audience, keep the content clean, and configure ads as child-directed to be conservative.

---

## 9. Build Plan — 5 Day Sprint

The critical insight: **the shell is the product.** Build it once on day one and each subsequent game costs a fraction of the previous.

### Day 1 — Foundation
- Godot project setup, landscape lock, resolution/scaling config
- `InputManager` with multi-touch, zone assignment, drag tracking, debug overlay
- `GameManager` scene loader and the `MiniGame` contract
- `SaveManager`, `AudioManager` stubs
- Palette, fonts, and shared component library (Timer, ScoreBar, Countdown, WinBanner)
- **Test multi-touch on a real cheap Android device today.** Do not defer this.

**Exit criteria:** two fingers on opposite screen halves both register independently, verified on hardware.

### Day 2 — Shell + first two games
- Main Menu, Game Select, Rules Card, Results, Settings — all wired
- Air Hockey (full)
- Ping Pong (full)

**Exit criteria:** you can launch the app, pick a game, read rules, play a full match, see results, and rematch — end to end.

### Day 3 — Games 3, 4, 5
- Tic-Tac-Toe (best of 5)
- Tap Race
- Connect Four

**Exit criteria:** five games playable, all reading input through the shared manager.

### Day 4 — Game 6 + polish pass
- Sumo Blob
- Art pass: final sprites, squash-and-stretch, particle pops
- Audio pass: all SFX in, menu music, haptics
- Write all six rules cards + their diagrams

**Exit criteria:** it looks and sounds like a finished product.

### Day 5 — Monetisation, store, ship
- AdMob integration + frequency capping + first-session grace
- IAP: Remove Ads, purchase + restore flow, tested in sandbox
- Store assets: icon, feature graphic, 6–8 screenshots, 30s preview video
- Store listing copy + keywords
- Build signed .aab and iOS archive, submit

**Exit criteria:** submitted to Google Play. (Note: iOS review typically takes 1–3 days, Android a few hours — plan for Android first if the 5-day deadline is hard.)

### Realism note
Five days is aggressive but achievable **at six games**. If day 3 slips, cut Connect Four before cutting the polish pass. A smaller set of games that feel great beats a larger set that feels cheap — reviews in the first two weeks determine everything.

---

## 10. Store Listing

### Title
`Face Off — 2 Player Offline Games`

### Short description
`Two players, one phone, no wifi. Six fast head-to-head games on a single screen.`

### Keywords / ASO targets
`2 player games`, `offline games`, `games without wifi`, `two player games one phone`, `same screen multiplayer`, `2 player offline`, `no internet games`, `couples games`, `games for kids offline`, `split screen games`

### Screenshot plan (in order)
1. Air Hockey mid-match with two hands visible on the phone — sells the concept in one image
2. Big text overlay: "NO WIFI NEEDED"
3. Game select screen showing the full roster
4. Sumo Blob mid-collision (the personality shot)
5. Two kids playing in the back of a car
6. Two adults playing at a table
7. Big text overlay: "ONE PHONE. TWO PLAYERS. ZERO SETUP."

### Long description — key beats
Lead with the offline/one-phone hook. List the games. Mention no login, no account, no data. Mention rules cards for kids. Mention ad-free option. Keep it short and scannable.

---

## 11. Success Metrics

| Metric | Target (30 days post-launch) |
|---|---|
| Day-1 retention | > 30% |
| Matches per session | > 4 |
| Rematch rate | > 50% |
| Session length | > 6 min |
| Store rating | > 4.2 |
| Ad-removal conversion | > 1% of MAU |

The metric that matters most is **matches per session** — it validates the entire "rematch is the biggest button" design bet.

---

## 12. Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Multi-touch unreliable on budget Android | Critical — breaks the core product | Test on real cheap hardware on day 1, not day 5 |
| 6 games in 5 days slips | High | Pre-agreed cut order: Connect Four → Tap Race. Never cut polish. |
| Ad revenue is negligible at low install volume | Medium | Expected. IAP is the real model; ads are the floor. |
| Discoverability — crowded casual category | High | ASO built around "offline / no wifi", not "fun games". Niche keyword wins. |
| Kids' privacy compliance misstep | High (removal risk) | Decide age rating before SDK integration; configure ads conservatively |
| Two players fighting over screen space on small phones | Medium | Locked landscape, strict symmetry, midline always visible |

---

## 13. Out of Scope for v1

Explicitly not building: online multiplayer, single-player vs AI, accounts or profiles, leaderboards, cloud save, achievements, more than one language, portrait mode, tablet-optimised layouts, and any form of progression or unlock system beyond cosmetics.

---

## 14. Open Decisions

- [ ] Final app name — check Play Store, App Store, and domain availability
- [ ] Target age rating (drives ad SDK configuration — decide before day 5)
- [ ] Ad-removal price point: $2.99 vs $3.99
- [ ] Android-only launch vs simultaneous iOS (affects the 5-day deadline)
- [ ] Art: commission a designer vs build with a vector asset kit
