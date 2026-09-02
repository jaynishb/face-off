# Face Off — Sports Games Audit

**Date:** 2026-09-02
**Scope:** all 12 games, verified by running them, not by reading them.
**Audits:** branch `claude/two-player-game-design-yz5xzs` (the portrait rebuild). `main`
does not yet carry the sports games, so the harnesses below only run on that branch.
**Verdict:** the six classic games are fine. All six new sports games have real defects,
and **four** of them cannot be played to a legitimate finish. Basketball (B4) is fixed;
the rest are diagnosed but untouched.

## How this was verified

Three passes, because each one catches a class the others miss:

| Pass | Command | Result |
|---|---|---|
| Parse / import | `godot --headless --path . --import` | clean, 0 errors |
| Geometry | `godot --headless --path . res://tools/GeomCheck.tscn` | **4740 assertions pass** |
| Playability | `godot --headless --path . res://tools/Playability.tscn` | **24 of 35 checks fail** |
| Shot simulation | `godot --headless --path . res://tools/ShotSim.tscn` | Basketball scored **0 of 4061** |
| Composition | `xvfb-run godot --rendering-driver opengl3 res://tools/Shots.tscn` | 6 games visibly wrong |

**This is the headline finding.** The geometry harness passes completely, and it is
still true that the halves tile exactly, that SCREEN↔PLAYER round-trips, and that every
touch lands in the right player's half. None of that says anything about whether the
target can be *reached*, whether the actor is standing on the *painted surface*, or
whether the rules card describes the game that was actually built. Those three questions
were never asked, so six games shipped with nobody having played them.

The two new harnesses below exist to close that gap permanently.

(Worth recording: the playability harness's first run reported Archery as *fine*. Its
reachability check filtered drag directions on the wrong sign, so it measured the longest
backwards drag. Same family as every bug it was written to catch — two things computing
what should be one value. It is fixed, and the comment explaining why sits on the
function.)

---

## Blocking — the game cannot be completed

### B1. Archery is mathematically unwinnable

Every match ends 0–0. Not "hard" — impossible.

The archer is at the bottom-left of the half and the target at the top-right, 559px away.
Firing is a slingshot: `pull = archer_pos - finger`, so to shoot up-and-right you drag
down-and-left. But the archer is already 112px from the left edge and 114px from the
bottom, so the longest useful drag is ~160px, giving a launch speed of **384 px/s**.

The minimum speed needed to reach that target under `GRAVITY = 620` is **714 px/s**.

```
archer=(122, 498)  target=(616, 235.8)  distance=559
max useful launch speed = 384 px/s
minimum speed to reach   = 714 px/s      REACHABLE = false
```

Every arrow falls short, all ten arrows score 0, and `_maybe_finish()` returns
`winner = 0`. **Fix:** the geometry and the power budget have to be solved together —
either move the archer inboard so there is room to draw (and raise `DRAW_POWER`), or
drop the slingshot entirely and aim with a sweeping angle/power meter, which needs no
drag room at all and suits a game where your thumb is already at the screen edge. I'd
take the meter: it is one tap, it reads at a glance on a shared phone, and it removes
the coupling between screen size and whether the game is winnable.

### B2. Diving throws the diver into the opponent's half

`vel.y = -(320 + 300 * power) * art_scale`, against `GRAVITY = 900 * art_scale` from a
board 94px below the top of the play area. The apex:

```
power 0.0  ->  apex y =   94   inside the half
power 0.5  ->  apex y =   12   past the top of the play area
power 1.0  ->  apex y = -102   past the seam, into the other player's half
```

Above roughly power 0.44 the diver leaves its own play area; at full power it is drawn
102px into the opponent's half, upside down, over their dive. There is no clamp on
`pos` anywhere in `_process`.

Worse, the power meter's drawn "sweet spot" marker sits at 12% from the top of the
track — i.e. near maximum power. **The game marks the value that breaks it as the one
to aim for.** Fix: clamp the flight to `play_rect`, and re-derive `JUMP_IMPULSE` from
the actual board-to-water distance rather than a literal tuned by eye.

### B3. Sprint ignores taps on 43% of each player's half

The two tap zones cover the inboard 319px of a 570px half. The remaining **251px is the
entire track band containing the runner and the finish gate** — the part of the screen a
player actually looks at, and therefore the first place they will tap.

The mismatch runs the other way too: each pad is *drawn* 300px wide but its touch zone is
the full 700px, so taps well outside the visible button also count.

```
play_rect height = 570   tap zone height = 319   dead = 251 (43%)
drawn pad width  = 300   touch zone width = 700
```

Fix: make the drawn rect and the registered zone the same `Rect2` — pass one rect to both
`configure_zones()` and `_draw_pad()`. Sprint is the only game that registers zones, and
it derives the two independently; that is the whole bug.

### B4. Basketball cannot be scored in at all — **FIXED**

Reported from a real phone: *"this ball is not able to put to basket."* Correct, and my
first audit got this one wrong. I called it "reachable but brutal" on the strength of a
closed-form range check. Firing every drag a thumb could actually make:

```
scoring drags: 0 of 4061 plausible (0.00%)
closest miss:  the ball never reached the rim plane at all
```

Two compounding errors in my check. The minimum-energy shot arrives at the rim with zero
velocity remaining, so it never falls *through* — the true requirement is strictly higher
than the formula's answer. And I compared a *diagonal* drag's full length against a
*vertical* requirement, crediting the shot with power it does not have along the axis that
matters. The hoop sat directly above the shooter, so the only scoring shot was a perfectly
vertical one at more than maximum available power. There wasn't one.

**Fix, tuned against `tools/ShotSim.tscn`:**

| | before | after |
|---|---|---|
| `FLICK_POWER` | 3.1 | 6.4 |
| `RIM_TOLERANCE` | 0.55 | 1.15 |
| hoop height (of play area) | 0.24 | 0.34 |
| shooter position | directly under the rim | offset 24% of the width to the side |
| **scoring drags** | **0 of 4061** | **122 of 4061** |
| usable drag directions | 0° | 65° of arc |
| length tolerance in the best direction | — | 225px |

Moving the shooter off the centre line is the change that matters most. Directly
underneath, aiming is meaningless — there is exactly one correct direction, and the
horizontal gate is unforgiving. From an angle the ball arcs *across* the rim, so it is
both easier to hit and an actual decision.

The harness now checks Basketball by **simulation** rather than by formula, and asserts
both that a scoring drag exists and that at least 20 of 120 sampled directions can score —
one working drag is not a game.

---

## Major — playable but wrong

### M1. Swimming: the swimmer swims over the deck, not the pool

`lane_y` is 55% down the half; the background art's water is a band across the middle of
the *screen*. The swimmer tracks along the painted tiled deck instead. This is the exact
bug already found and documented for Sprint's runner-on-the-infield-grass, recurring in
the next game written — which means the rule got written down but not applied.

Also, the `wall` touchpad sprite is drawn at `pool.size.y * 0.62` tall and renders as a
large white picture frame at each end of the lane, with the swimmer sometimes inside it.

### M2. Horse Jump: the horse gallops on the border, below the paddock

`ground_y` is 68% down the half, which lands on the flat brown band outside the painted
fence and grass. The horse and its hurdles sit on blank colour with the actual scenery
above them. Same root cause as M1.

The progress bars are drawn at `play_rect.position.y + 14`, which puts them in open sky
in the middle of the screen with nothing behind them.

### M3. Two rules cards describe mechanics that do not exist

- **Swimming** says *"Tap the wall to turn."* There is no turn input — `_process` flips
  `heading` automatically at `distance >= LANE_UNITS`. Tapping anything, anywhere, only
  ever strokes.
- **Diving** says *"Tap to launch, hold to tuck. Tap again to enter straight."* The
  `Phase` enum has no ENTRY. The third tap does nothing; entry angle is whatever the
  somersault happened to leave.

Both rules cards teach an input the player will then try and find dead. Fix: implement
the promised mechanic (both are better games with it) or rewrite the card. Prefer
implementing — a diving game with no entry timing has one meaningful input, and PRD §7
asks each game for a distinct verb.

### M4. Horse Jump is over in ~7 seconds and is nearly impossible to fail

`COURSE_LENGTH / BASE_SPEED = 1400 / 190 = 7.4s`, against the PRD's stated 20–60s window.
Only 5 hurdles are generated. Clearing one needs 49px of clearance from a 90px jump apex,
so the timing window is enormous and both players clear everything. Nothing distinguishes
the two runs. Fix: lengthen the course, tighten the clearance test, and vary hurdle
height so the jump has to be timed rather than merely remembered.

### ~~M5. Basketball's scoring window is brutal~~ → see B4. **FIXED**

### M6. Archery's wind indicator reads as an arrow stuck in a cloud

`_draw_wind()` draws a horizontal line with three chevrons in mid-air, at the same scale
and colour as an arrow in flight. On screen it is indistinguishable from a stray shot.
Fix: move it to a labelled band, or show it as a drifting flag/banner anchored to the
target, which is where the player is already looking.

### M7. In-match text is low-contrast, near the seam, and unstyled

`ARROW 1/5`, `DIVE 1/3` and `LENGTH 1/2` are drawn with `ThemeDB.fallback_font` at
`Color(INK, 0.75)` or `Color(SURFACE, 0.85)` directly onto busy art, positioned at the
top of the play rect — which is the seam edge, next to the score pills. "LENGTH 1/2" in
Swimming is white-on-cream and effectively invisible.

This is also the outstanding no-project-theme item: the bundled Baloo 2 / Nunito are in
`shared/art/fonts/` but no theme registers them, so every game draws its HUD in the
engine's fallback face.

---

## Risk

### R1. `await` after the node may be freed

`Archery._score_arrow()` and `Diving._judge()` both `await get_tree().create_timer(...)`
and then touch `self`. If the player exits the match during that window, MatchHost frees
the game and the coroutine resumes on a freed object. The `_match_active` guard runs
*after* the resume, so it does not prevent this. Fix: `if not is_instance_valid(self):
return` immediately after the await, or drive the delay from `_process` instead of a
coroutine.

---

## What I'd change about how this gets built

The defects above are not six unrelated mistakes. They are three patterns:

1. **Reachability was never tested.** B1, B2 and M5 are all "can the projectile get from
   where it starts to where it must go?" — a question with a closed-form answer that
   takes four lines to assert. `tools/playability_check.gd` now asserts it for every
   projectile game, and fails the build when a target is unreachable or an actor can
   leave its own half.

2. **Input geometry and drawn geometry were derived separately.** B3 is the same class of
   bug as the original `mid_x()` / hardcoded-640 split that broke Tic-Tac-Toe: two places
   computing what should be one value. The project already has the rule ("one matrix,
   both directions") for the SCREEN/PLAYER mapping; it needs the same rule one level down
   — a tap pad's rect is authored once and handed to both the drawer and the registrar.

3. **"Games own their playfield geometry; art is scenery" was written down and then not
   applied.** M1 and M2 are the same bug that was found in Sprint and documented in
   CLAUDE.md during the art pass — recurring immediately in the next two games. A written
   rule did not survive contact. What would: have each game declare the one band its
   action occupies as a named fraction of `play_rect`, and assert in `geom_check` that the
   actor's rest position is inside it. Then a runner on the grass is a failing test rather
   than something someone has to notice.

And the meta-lesson, which is the same one this repo has now learned three times in a
different costume: **a passing structural check is not evidence the thing works.** Score
changing was not proof input worked; 4740 geometry assertions were not proof the games
were playable. Every check added here asserts against the thing a player would actually
do.

## Suggested order of work

1. ~~B4 Basketball~~ — done. B1, B2, B3 — the remaining unplayables. Nothing else
   matters until these are fixed.
2. M1, M2 — actors onto the painted surfaces.
3. M3 — make the rules cards true (implement the mechanics).
4. M4, M5 — tune the two games whose difficulty curves are wrong at opposite ends.
5. R1, M6, M7 — robustness and readability; M7 wants the project theme, which also
   retires the ASCII-only rule.

## Reproducing

```bash
godot --headless --path . --import
godot --headless --path . res://tools/GeomCheck.tscn        # structure — passes
godot --headless --path . res://tools/Playability.tscn      # reachability — fails 3
xvfb-run -a godot --path . --rendering-driver opengl3 \
    --resolution 720x1280 res://tools/Shots.tscn            # writes /tmp/shots/*.png
```

`Shots.tscn` renders each game straight to a PNG without navigating the shell. That
matters: the browser harness reaches games by tapping Game Select cards, whose indices
shift as the list scrolls, and it silently screenshotted the wrong game for four of the
six sports games during the art pass — which is why these defects survived that review.
