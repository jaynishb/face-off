# Face Off — Playtest & Design Audit

**Date:** 2026-08-29
**Build audited:** Web (HTML5) export, commit `f6a5772`, served at viewport 844×390 (a realistic landscape phone, ~19.5:9).
**Method:** Automated two-player playthrough of all 6 launch games driving real `Input.dispatchTouchEvent` touch events through Chrome DevTools Protocol — including genuinely simultaneous two-finger input — plus a source read of every game, `InputManager`, and `MatchHost`.

> **Testing note that matters:** every issue below was confirmed by *observing the thing input is supposed to move* (paddle position, piece placement, board state), not by watching the score change. A score can change from unattended physics alone — that false positive already burned this project once (see `CLAUDE.md`). Screenshots backing each finding are referenced by name.

---

## Verdict

**3 of the 6 games are currently unshippable**, and one of them (**Tic-Tac-Toe**) hard-softlocks on any modern phone. All three failures trace to a **single root cause**: the input system splits the screen at a different place than the renderer draws it, and every game's layout is hardcoded to a 1280×720 design box that no real phone actually is.

Fixing that one root cause (**C1 + C2**) resolves or de-risks most of the critical list. It should be done before any art work.

| # | Area | Severity | Status |
|---|------|----------|--------|
| C1 | Input midline ≠ drawn midline | **Critical** | Confirmed |
| C2 | Layout anchored top-left, not centred | **Critical** | Confirmed |
| C3 | Tic-Tac-Toe softlock / Connect Four unreachable columns | **Critical** | Confirmed |
| C4 | Ping Pong left/right asymmetry | **Critical** | Confirmed |
| C5 | Air Hockey has no goal mouths | **High** | Confirmed |
| H1 | Tap Race draws no buttons | **High** | Confirmed |
| H2 | Score bar shows meaningless numbers | **High** | Confirmed |
| H3 | Turn indicator is colour-only | **High** | Confirmed |
| M1–M5 | Art / polish gaps | **Medium** | Confirmed |
| L1–L4 | Minor correctness & cleanup | **Low** | Confirmed |

---

## CRITICAL

### C1 — The input midline is not the drawn midline (affects all 6 games)

`InputManager._player_for_position()` decides ownership with:

```gdscript
var half_width := get_viewport().get_visible_rect().size.x * 0.5
return 1 if position.x < half_width else 2
```

But `project.godot` uses `window/stretch/aspect="expand"`, so on a screen wider than 16:9 the *visible design rect grows past 1280*. At the tested 844×390 viewport the visible rect is **1558 design px wide, so the input split lands at design x≈779** — while `MatchHost` draws its divider at a hardcoded **x=638** and every game uses `MID_X = 640`.

That leaves a **139 design-px strip (~9% of the screen) that is visually inside Player 2's half but is handed to Player 1.** On a 20:9 phone (2400×1080, very common) it is worse: visible width 1600, split at 800, a **160px strip**.

**Confirmed empirically** (`mid_before.png` → `mid_after.png`): a single tap at screen x=390 — unmistakably right of the drawn divider at x=346 — moved **Player 1's** paddle across to the midline. Player 2's paddle did not move.

This directly violates the PRD's *"Symmetry is sacred"* rule and is the root cause of C3.

**Fix direction:** ownership must be decided against the same coordinate the game draws with. Either split on a shared constant (`MID_X = 640` in design space) rather than the runtime viewport, or — better, and this also fixes C2 — stop letting the visible rect drift from the design box at all.

### C2 — On a non-16:9 screen the whole game sits flush-left with dead space on the right

Because `aspect="expand"` widens the design rect but every scene positions content inside `0..1280`, the playfield is **anchored to the left edge rather than centred**. Measured in every screenshot: board/platform centres land at screen x≈346 when the true screen centre is x≈422 — the game is **76px left of centre**, with a ~150px unused strip on the right (~180px on a 20:9 phone).

Visible in `play_connect_four.png`, `play_tic_tac_toe.png`, `play_sumo_blob.png` — the board, grid and sumo platform all sit noticeably left of centre with empty space to their right.

**Fix direction:** either switch the stretch aspect to `keep` (letterbox, guarantees the design box is exactly what's on screen and instantly fixes C1 too), or make every scene lay out against the *actual* visible rect instead of hardcoded 1280/640 constants. `keep` is the smaller, safer change and preserves the "symmetry is sacred" guarantee by construction; the cost is letterbox bars on very wide phones.

### C3 — Tic-Tac-Toe softlocks; Connect Four columns are unreachable

Both turn-based games put **one shared board straddling the midline**, then reject any move where `player != current_turn`. But ownership comes from *which half of the screen the finger is in* (C1). So a player physically cannot play a cell on the other player's side — their touch is attributed to the opponent and thrown away.

**Tic-Tac-Toe — total softlock (confirmed, `ttt_softlock.png`).** The grid spans design x 445–835, so all three column centres (510, 640, 770) are **below the 779 input split — every one of the 9 cells belongs to Player 1.** After P1's opening move it becomes P2's turn, and P2 can never place anywhere. The test tapped all 8 remaining cells: **nothing happened.** The match cannot progress; the only escape is the exit button. On an exact 16:9 screen it is less total but still broken — P1 gets only the left column, P2 the other two.

**Connect Four — grossly asymmetric (confirmed, `play_connect_four.png`).** Board spans design 367–913. At the 779 split, **P1 can reach columns 0–4 and P2 only columns 5–6.** A 7-tap alternating test produced **one** piece on the board.

**Fix direction:** for a shared-board game, screen-half ownership is the wrong model — the board is *communal*, not split. These games should opt out of positional ownership and take turns explicitly (the game already tracks `current_turn`; it can simply accept any touch inside the board while it is that player's turn). This is a `MiniGame`-contract-level concern: worth an explicit "shared board" input mode in `InputManager` rather than a per-game hack, so the shell stays game-agnostic.

### C4 — Ping Pong is left/right asymmetric

`PADDLE_MARGIN = 40`, so P1's paddle sits at design x=40 — **flush against the left screen edge** — while P2's sits at design x=1240, which on the tested screen is **~170px in from the right edge**, floating in open space (`play_ping_pong.png`).

Worse, scoring triggers at `ball_pos.x > 1280.0`, so on a wide screen **the ball vanishes and a point is awarded while the ball is still visibly mid-screen**, ~150px short of the edge.

Both are consequences of C2, and both break the symmetry rule outright. Player 2 is defending a goal line that isn't where their screen edge is.

### C5 — Air Hockey has no goals

`_score()` fires whenever the puck passes the **entire** left or right edge:

```gdscript
if puck_pos.x < FIELD_LEFT - PUCK_RADIUS * 2.0: _score(2)
```

There are no side walls and **no goal mouth is drawn or modelled**. The full height of each end is a goal, so there is no defensive skill — you cannot "miss". This contradicts the game's own rules card ("Hit the puck into their **goal**") and the PRD.

**Fix direction:** add a goal mouth (a centred opening ~200 design px tall), bounce the puck off the solid wall outside it, and draw the goal + a proper rink (border, centre line, centre circle).

---

## HIGH — controls, rules & readability

### H1 — Tap Race never draws its buttons

The rules card says *"Tap your two buttons as fast as you can"*, and `setup()` does configure four zones (top/bottom of each half). **But nothing renders them.** `_draw()` only draws two lane lines, two racers and a finish tick (`play_tap_race.png`). The player is told to find two buttons that are invisible.

This also hides the game's central mechanic: alternating the two zones gives a 26-point boost, mashing one gives 6 — a player who cannot see two buttons will mash and lose without understanding why.

### H2 — The score bar shows numbers that aren't scores

- **Tap Race** emits raw progress toward a 1000-unit finish → the bar reads **"P1 312 / 319 P2"** (`play_tap_race.png`). Meaningless to a player mid-race.
- **Connect Four** emits *piece counts* → both players are always within one of each other, so it conveys nothing.

Both should show something a player can act on (percentage, or nothing at all for Connect Four, where the board *is* the state).

### H3 — Turn indicator is colour-only

Tic-Tac-Toe and Connect Four signal whose turn it is with a **thin coloured bar** above the board and nothing else. The PRD explicitly requires colour to be paired with a shape/icon marker for accessibility, and never used as the sole differentiator. There is also no text ("P1's turn"), which is the clearest possible signal for a game where the wrong player tapping is already the main failure mode.

---

## MEDIUM — art & polish (the visual gap called out directly)

- **M1 — Tap Race racers are flat circles.** `draw_circle(..., 24, Palette.PLAYER_1)` — no outline, no highlight, not even the existing `Juice.cartoon_circle()` the other games use, let alone a car. This is the single most visually unfinished screen in the app.
- **M2 — Sumo Blob blobs are flat circles with no faces.** The game is *called* Sumo Blob and the project already has a cute blob mascot (`shared/art/mascot_p1.svg`) that is used **only on the main menu**. The blobs should be the mascot.
- **M3 — Connect Four board has no fill.** Empty cells draw `Palette.SURFACE` circles directly on the `Palette.BACKGROUND` — cream on cream, near-zero contrast (`play_connect_four.png`). It reads as floating dots, not a Connect Four board, which conventionally is a solid coloured slab with holes punched in it.
- **M4 — No playfield framing.** Air Hockey and Ping Pong draw only their moving pieces: no rink border, no centre circle, no net, no goal. The play area is an undifferentiated cream rectangle.
- **M5 — Mascot art is used on exactly one screen.** Not in Game Select, not on Results, not in any game.

---

## LOW — minor correctness & cleanup

- **L1** — `TicTacToe._round_draw()` resets the board but never resets `current_turn`, and gives the players no indication a draw happened before the board clears.
- **L2** — Ping Pong tunneling risk: the paddle-hit window is ~41 design px wide, but at `MAX_BALL_SPEED` (950) on a 30fps device the ball travels ~32px/frame. That is within tolerance but with very little margin — and 30fps is the PRD's stated performance floor, so it should be a swept collision, not a positional one.
- **L3** — Air Hockey's paddle collision ignores paddle velocity: the puck always leaves at `max(current_speed, 260) * 1.15`, so a fast swipe and a slow nudge hit identically. There is no "smash", which is most of the feel of air hockey.
- **L4** — `GAME_REGISTRY`'s `emoji` field is dead data since the art pass replaced tile emoji with SVG icons.

---

## Recommended order of work

1. **C1 + C2 together** — one coordinate-space fix. Everything else is measured against it, so doing art first would mean redoing it.
2. **C3** — shared-board input mode; unblocks two of the six games.
3. **C4, C5** — Ping Pong symmetry, Air Hockey goals.
4. **H1, H2, H3** — make controls and state legible.
5. **M1–M5** — the art pass: car for Tap Race, mascots for Sumo Blob, board fill, rink framing.
6. **L1–L4** — cleanup.

Art (step 5) is deliberately last despite being the original request: items 1–3 change *where things are on screen* and *which pixels belong to whom*, so any sprite work done before them would have to be repositioned afterward.
