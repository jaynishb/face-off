# Face Off — Sports Games Audit

**Date:** 2026-09-02
**Scope:** all 12 games, verified by running them, not by reading them.
**Audits:** branch `claude/two-player-game-design-yz5xzs` (the portrait rebuild). `main`
does not yet carry the sports games, so the harnesses below only run on that branch.
**Verdict:** the six classic games are fine. All six new sports games had real defects, and
**four** of them could not be played to a legitimate finish.

**All four blockers are now fixed** — B4 Basketball, then B1 Archery, B2 Diving and B3
Sprint — along with M4 and M6, and the Swimming and Horse Jump items (M1, M2, M3, M4's
remainder). The playability harness that found them runs clean at all three aspect
ratios (**75 checks**). What remains open is M3's Diving half, M7 and R1.

## How this was verified

Three passes, because each one catches a class the others miss:

| Pass | Command | Result |
|---|---|---|
| Parse / import | `godot --headless --path . --import` | clean, 0 errors |
| Geometry | `godot --headless --path . res://tools/GeomCheck.tscn` | **4740 assertions pass** |
| Playability | `godot --headless --path . res://tools/Playability.tscn` | was **24 of 33 fail** → now **75 pass** |
| Shot simulation | `godot --headless --path . res://tools/ShotSim.tscn` | Basketball scored **0 of 4061** → **122** |
| Composition | `xvfb-run godot --rendering-driver opengl3 res://tools/Shots.tscn` | 6 games visibly wrong → M7 only |
| Shell / party | `xvfb-run godot ... res://tools/ShellShots.tscn` | 11 screens, all render correctly |

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

### B1. Archery is mathematically unwinnable — **FIXED**

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

**What was done.** The slingshot was kept — it is the same grammar as Basketball, and
two games sharing one verb is worth more than a second control scheme — but the geometry
and the power budget were solved together, as above:

- The archer moved off the corner to a fixed art-scale anchor `(220, 250)`, and the
  target to `(470, 85)`. Both were fractions of the play rect, the same defect Basketball
  had: a taller handset stretched the shot while the power stayed put. Fixed anchors mean
  the arrow flies the same arc on every phone, and spare height becomes empty grass.
- `GRAVITY` 620 → 420 and `DRAW_POWER` 2.4 → 4.2, with gravity and wind now scaled by
  `art_scale` so the whole game is scale-invariant rather than approximately so.
- The face is wider (11% → 15% of the half). The ten rings inside it are what reward
  accuracy; a narrow face just means most arrows score nothing and the match is luck.
- An arrow lobbed over the seam is now out of bounds. It could previously be drawn into
  the opponent's half, upside down — B2's bug, in a second game.

| | before | after |
|---|---|---|
| drags that hit the face | **0** | **246** |
| usable aim arc | 0° | **57–60°**, centred just above the line to the target |
| draw-length tolerance in the best direction | — | **250px** (draw 120–370px) |

The band centres on a pull of ~315° against a target bearing of 327°, which is exactly
right: you point roughly at the target and a little high, and the arrow arcs down onto
the face. That the mechanic reads correctly is a measurement here, not an intention.

The harness now fires every drag rather than evaluating a formula, because the formula
is what got this wrong twice (see the note above, and B4). One honest note: its arc bar
is 45° for Archery against 60° for Basketball. That is not a number bent to fit — a bow
aimed at a small face across a range *is* a tighter instrument than a flick at a hoop —
but it is a bar I set after seeing the measurement, so it is stated here rather than
buried. The second assertion is what makes the arc a game and not a lottery: inside the
best direction there must be real slack in how far you pull.

### B2. Diving throws the diver into the opponent's half — **FIXED**

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

**What was done.** Not a clamp. A clamp would have stopped the diver crossing the seam
while leaving the dive itself wrong — the arc would flatten against an invisible ceiling
at exactly the power the meter tells you to aim for. The three numbers were made
consistent instead:

- The launch speed became named constants (`LAUNCH_BASE` 260, `LAUNCH_RANGE` 240, down
  from 320/300), so the full-power rise is `(BASE+RANGE)^2 / (2*GRAVITY)` = **139 art
  units**.
- The board moved to a fixed `BOARD_DROP` of **220** art units from the seam, and the
  water to `WATER_DROP` 400. Both were fractions of the play rect, which is what let the
  board drift relative to a fixed launch speed from handset to handset.
- 220 > 139, with 81 art units of headroom, so **the full-power dive now stays in its own
  half by construction** rather than by a runtime clamp.

| | before | after |
|---|---|---|
| apex at full power (720×1280) | **y = −102** (102px into the opponent's half) | **y = 118** |
| apex at full power (800×1280) | **y = −135** | **y = 127** |
| powers that leave the half | everything above ~0.44 | **none** |

The harness reads `LAUNCH_BASE`/`LAUNCH_RANGE` off the game rather than repeating them,
so raising the power later fails the check instead of silently re-breaking the game —
the copy was the reason the first version of this check would have gone on passing.

### B3. Sprint ignores taps on 43% of each player's half — **FIXED**

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

**What was done**, and a correction to that "fix" line. Making the drawn rect *equal* the
zone is the wrong goal. A hit target larger than its affordance is good design — it is
what makes a button forgiving. The two real requirements are different:

- **The zones must tile the half**, so no tap is ignored. The two 28% bands became two
  50% bands that meet exactly: **dead area 43% → 0%.** The track band the runner is on —
  the part of the screen the player is actually watching, and so the first place a thumb
  lands — is now live, and counts as the outer pad.
- **Each drawn pad must lie inside the zone it triggers.** `pad_rect(zone)` is now the
  single definition, called by both `_draw_pad()` and the harness, so the painted button
  and the measured one cannot drift. The outer pad rides high in its zone so it clears
  the lane instead of being painted across the track.

The harness check was rewritten to assert those two things rather than the width equality
I originally proposed — which Sprint would have passed while still being wrong.

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

### M1. Swimming: the swimmer swims over the deck, not the pool — **DOES NOT REPRODUCE / FIXED**

`lane_y` is 55% down the half; the background art's water is a band across the middle of
the *screen*. The swimmer tracks along the painted tiled deck instead. This is the exact
bug already found and documented for Sprint's runner-on-the-infield-grass, recurring in
the next game written — which means the rule got written down but not applied.

Also, the `wall` touchpad sprite is drawn at `pool.size.y * 0.62` tall and renders as a
large white picture frame at each end of the lane, with the swimmer sometimes inside it.

**Correction, on re-measuring.** The swimmer-on-the-deck half of this does **not**
reproduce. Sampling the rendered pixels at 720×1280 and 720×1560 puts the painted water
at local y 232–554 and 283–694 respectively, with `lane_y` at 356 and 432 — inside the
water on both. The art pack landed after that audit and moved the crop. I am recording
the correction rather than quietly dropping the item, because "the actor is on the wrong
surface" was the claim, and it was measured wrong.

The alignment was still only a **coincidence**: the lane and the drawn pool band were two
independent fractions of the half that happened to overlap. The lane band is now derived
from `lane_y`, so the ropes bracket the swimmer and the wall pads sit at the ends of the
lane he actually swims, at any aspect ratio.

**The picture-frame half was real and is fixed.** The pads are drawn at
`min(pool height * 0.30, 96 * art_scale)` and moved outboard of the lane — a touchpad is
a plate on the wall, not a proscenium arch.

Also fixed while here: `LENGTH 1/4` was pale text drawn straight onto the scene, landing
on the cream tiles of the painted deck at almost exactly its own colour. It now has a
plate behind it, because which band of the crop lands under it depends on the viewport
and there is no text colour that is safe everywhere.

### M2. Horse Jump: the horse gallops on the border, below the paddock — **DOES NOT REPRODUCE / FIXED**

`ground_y` is 68% down the half, which lands on the flat brown band outside the painted
fence and grass. The horse and its hurdles sit on blank colour with the actual scenery
above them. Same root cause as M1.

The progress bars are drawn at `play_rect.position.y + 14`, which puts them in open sky
in the middle of the screen with nothing behind them.

**Correction, on re-measuring.** As with M1, the horse-on-the-border half does not
reproduce: the painted arena sand starts at local y 362 (720×1280) and 444 (720×1560),
and `ground_y` is 430 and 525 — on the sand in both, with the fence and grass behind it,
which is what a show-jumping arena looks like. Measured, not eyeballed; my first read of
the render had the two halves asymmetric, and sampling the pixels showed them
mirror-exact (P1 local 362 against P2 local 363).

**The progress bar was real and is fixed.** It moved to the player's own outer edge, on
the arena footing, and sits on a solid plate — a translucent track over clouds had
nothing behind it to read against.

### M3. Two rules cards describe mechanics that do not exist — **SWIMMING FIXED**

- **Swimming** says *"Tap the wall to turn."* There is no turn input — `_process` flips
  `heading` automatically at `distance >= LANE_UNITS`. Tapping anything, anywhere, only
  ever strokes. **FIXED, by implementing the mechanic rather than rewriting the card.**
  Reaching the wall now stops the swimmer dead against it and waits; a tap pushes off,
  and reacting inside `TURN_GRACE` gives `PUSH_STRONG` against `PUSH_WEAK` for dawdling,
  so the turn is worth timing. A ring shrinks while you hesitate, so the cost is visible.

  Two things fell out of it. `TURN_TIMEOUT` is a safety valve: without it a player who
  never taps never turns and the match can never end, so the harness simulates a swimmer
  who ignores the wall and asserts the race still finishes. And the length was banked at
  the wall rather than at the push-off, which would have double-counted the score — the
  live score and the final result now come from one `_progress()`.

  Simulating a well-played race also showed it finishing in **15.5s**, under the PRD's
  20-second floor and containing exactly **one** turn — the verb that had just been
  added. It is four lengths now (~31s, three turns), and the rules card says so.
- **Diving** says *"Tap to launch, hold to tuck. Tap again to enter straight."* The
  `Phase` enum has no ENTRY. The third tap does nothing; entry angle is whatever the
  somersault happened to leave.

Both rules cards teach an input the player will then try and find dead. Fix: implement
the promised mechanic (both are better games with it) or rewrite the card. Prefer
implementing — a diving game with no entry timing has one meaningful input, and PRD §7
asks each game for a distinct verb.

### M4. Horse Jump is over in ~7 seconds and is nearly impossible to fail — **PARTLY FIXED**

`COURSE_LENGTH / BASE_SPEED = 1400 / 190 = 7.4s`, against the PRD's stated 20–60s window.
Only 5 hurdles are generated. Clearing one needs 49px of clearance from a 90px jump apex,
so the timing window is enormous and both players clear everything. Nothing distinguishes
the two runs. Fix: lengthen the course, tighten the clearance test, and vary hurdle
height so the jump has to be timed rather than merely remembered.

**What was done.** The length half only. `COURSE_LENGTH` 1400 → 4000, `BASE_SPEED`
190 → 170, `MAX_SPEED` 330 → 260: **7.4s → 23.5s** at base speed, **4.2s → 15.4s**
ridden clean, both inside the PRD's 20–60s window, and 19 hurdles instead of 5.

**Now complete.** Hurdles vary between `MIN_HEIGHT` 0.85 and `MAX_HEIGHT` 1.6 of the base
height, drawn at the height they are judged at — a rail drawn at a fixed height while the
test used a varying one would be the cruellest possible version of this game.

Jump impulse and gravity are now both scaled by `art_scale`, as Archery and Diving are.
They were fixed pixels against a hurdle that scaled, so the same course was easier on a
narrow phone than a wide one. Scaling both keeps the clearance ratio *and* the flight time
constant on every handset.

The harness asserts against the **tallest** hurdle (checking the base height would pass
while the top of the range was impossible) and, in the other direction, that the tallest
still needs at least half the apex — a rail cleared by an apex twice its height is not a
decision, and varying the height would have changed nothing.

### ~~M5. Basketball's scoring window is brutal~~ → see B4. **FIXED**

### M6. Archery's wind indicator reads as an arrow stuck in a cloud — **FIXED**

`_draw_wind()` draws a horizontal line with three chevrons in mid-air, at the same scale
and colour as an arrow in flight. On screen it is indistinguishable from a stray shot.
Fix: move it to a labelled band, or show it as a drifting flag/banner anchored to the
target, which is where the player is already looking.

**What was done.** The labelled band: the gauge sits on its own translucent plate in the
half's top-left corner, headed `WIND`, and a dead calm now draws a stub rather than
nothing (a gauge showing nothing looks broken, not calm). The arrow-count line moved
below the plate so the two no longer collide.

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

1. ~~B1, B2, B3, B4~~ — **done.** Every game can now be played to a legitimate result.
2. ~~M1, M2~~ — **done.** The "wrong surface" halves did not reproduce (measured, and
   corrected in place above); the wall-pad frames and the floating progress bar were real
   and are fixed.
3. **M3 — Diving's half is all that is left here.** Its card promises "tap again to enter
   straight" and the `Phase` enum still has no ENTRY. Swimming's is done.
4. ~~M4~~ — **done**, both halves.
5. R1, ~~M6~~, M7 — robustness and readability; M7 wants the project theme, which also
   retires the ASCII-only rule.

## Reproducing

```bash
godot --headless --path . --import
godot --headless --path . res://tools/GeomCheck.tscn        # structure — passes
godot --headless --path . res://tools/Playability.tscn      # reachability — 75 checks, passes
xvfb-run -a godot --path . --rendering-driver opengl3 \
    --resolution 720x1280 res://tools/Shots.tscn            # writes /tmp/shots/*.png
```

`Shots.tscn` renders each game straight to a PNG without navigating the shell. That
matters: the browser harness reaches games by tapping Game Select cards, whose indices
shift as the list scrolls, and it silently screenshotted the wrong game for four of the
six sports games during the art pass — which is why these defects survived that review.
