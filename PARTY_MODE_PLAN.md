# Face Off — Party Mode plan

Status: **proposal, not built.** This is a design + engineering plan for a
3–6 player mode on one shared phone, plus three new games built for it. Read
`FACE_OFF_PRD.md` for product context and `CLAUDE.md` for the engineering
rules this plan has to live inside.

---

## 1. What Party Mode is

Face Off today is strictly two players, phone held between them, screen split
left/right. Party Mode is a **second way to play the same app**: the phone goes
flat on a table, 3–6 people sit around it, everybody puts a thumb on their own
seat pad, and a very short game decides a loser/winner for the whole group.

It is not "the same games with more players." Every launch game is built on a
two-half opposition (paddle vs paddle, board vs board). Stretching Air Hockey to
six players would be worse than either. Party Mode gets its **own games, built
around the one thing a phone on a table can do that nothing else can: register
six fingers at once.**

Target session: pick player count once, then 30–60s rounds back to back with a
running crown tally, until people stop. Same "start in three taps" promise as
1v1 — the lobby is one screen, and the player count is remembered for the
session.

### Why it's worth building

- It is the answer to "I showed my friend, and the third person just watched."
  Right now the app has a hard ceiling of two participants; a group of five
  literally cannot all play.
- The three games below are **cheaper to build than any launch game** — no
  physics, no board state, no AI. They are countdowns and touch bookkeeping.
- One of them (Chosen One) is a genuine utility people already open their phone
  for — who pays, who goes first, split into teams. That is a real acquisition
  and retention hook the 1v1 roster doesn't have, and it is the *only* screen in
  the app someone will open when they aren't in the mood to play a game.
- It doubles as the multi-touch stress test the project has needed since Day 1.
  Six simultaneous touches is the hardest thing this codebase will ever ask of a
  device, and Chosen One is that test with a cute face on it.

### Scope decision this needs from you

PRD §13 rules out online play, AI, accounts, progression. It does **not** rule
out more local players — but §7 and `CLAUDE.md`'s "symmetry is sacred" rule both
assume exactly two halves. Party Mode keeps symmetry (every seat gets identical
area and weight) but replaces *left/right* with *around the edge*.

**This is a v1.1 feature, not a v1 one.** v1 still ships the 6 two-player games.
Do not let Party Mode delay submission — see §8.

---

## 2. The three games

All three: 3–6 players, one shared screen, no reading required, explainable in
three lines, cartoon-styled to match the existing look.

### Game 1 — **Chosen One** (the utility helper)

> Everyone hold a finger on the screen.
> When the circles lock in, one gets picked.
> The Chosen One does the thing.

Everyone presses and holds anywhere on the screen. A coloured ring blooms under
each finger with a stubby cartoon face. A 3-second countdown ticks (rings pulse,
audio ramps), then the picker fires: rings shrink away one by one with a
drumroll until one is left, and it explodes into confetti with a crown.

Three modes, chosen by a small segmented control on the lobby (this is what
turns it from a bit into a utility):

| Mode | Output | Use |
|---|---|---|
| **Pick one** | One finger crowned | Who pays, who's it, who goes first |
| **Split teams** | Fingers dyed into 2 (or 3) colours | Teams for anything |
| **Order** | Fingers numbered 1..N in sequence | Turn order, queue |

Design notes:
- **This is the only game with no seats.** Ownership is per-touch, not per-seat —
  a finger anywhere on screen is a participant. That is deliberate: it means it
  works with any number of people with zero setup, which is what makes it usable
  as a utility. It also means it needs no player-count lobby step at all.
- The pick must be **provably fair and visibly fair**. Uniform random over active
  touches, seeded from the system RNG, decided at the moment the countdown ends
  (never earlier — no "it already knew"), and the elimination animation is
  cosmetic replay of a decision already made. Never bias toward the last finger
  down, which is the failure mode of every knock-off of this.
- Lifting a finger before the lock-in removes you (with a sad little "poof"), so
  chickening out is a mechanic rather than a bug.
- Minimum 2 fingers to fire; below that it just waits with a "need one more"
  prompt.
- Duration: ~6 seconds. It is the fastest thing in the app and should be the
  first tile on the Party screen.

Why it goes first: smallest build, biggest reach, and it is the hardware test.

### Game 2 — **Snap!** (reaction, elimination)

> Hold your pad. Wait for the flash.
> Lift the moment it goes green.
> Lift early and you're out.

Every seat gets a pad. All players hold. The screen runs a random 2–6s wait with
**fake-outs** (a yellow near-flash, a wobble, a fake countdown "3… 2… …") and
then goes green. First to lift wins the round; anyone who lifts during a fake-out
is out for the round with a comedy buzzer.

- Best-of-5 rounds, crown per round win, most crowns takes the match.
- Handles ties by margin: reaction times are captured in ms, ties beyond ~8ms are
  vanishingly unlikely, but a genuine tie awards both.
- A player who never lifts is timed out at 2s after the flash and placed last.
- Reads correctly at any N with zero rebalancing — a 6-player round is exactly a
  2-player round with more pads.
- Duration: ~25s for five rounds. This is the "one more" game.

The interesting engineering bit is that it is the only game in the app whose
correctness depends on **input latency**, not physics. It should timestamp on the
`InputEventScreenTouch` itself, never on a `_process` frame boundary, or a 60fps
frame quantises every result to 16ms buckets and the winner becomes arbitrary.

### Game 3 — **Bomb Pass** (chaos, elimination)

> The bomb lands on someone. Tap to fling it away.
> It picks a new victim at random.
> Holding it when the fuse ends = out. Last one standing wins.

A cartoon bomb with a burning fuse sits on one seat's pad, that seat's area
glowing red and shaking. That player taps their pad to fling it — it arcs across
the screen to a random *other* live seat, with a satisfying whoosh and squash on
landing. The fuse burns 20–35 seconds (randomised, hidden — nobody can count it
down). When it blows, whoever is holding it is eliminated in a puff of soot, and
a new bomb spawns among the survivors after a 1.5s beat.

- Last player alive wins. With 6 players that is 5 explosions, ~60–90s total —
  the longest thing in the app, and the only one worth being that long because
  eliminated players are still watching and yelling.
- Anti-degenerate rule (same spirit as Tap Race's mash rule): a **0.35s hold
  minimum** before you can fling, so you can't pre-mash your pad and bounce the
  bomb off instantly on arrival. The hold is drawn as a tiny fuse-shrink so the
  rule is visible, not just felt.
- Eliminated seats go grey and stop receiving the bomb, but their pad still
  responds with a "you're out!" wobble so a dead player poking the screen gets
  feedback instead of nothing.
- Only game of the three needing per-seat geometry and an arc animation, so it
  builds last.

### Games deliberately *not* proposed

- **Simon/colour-memory for N** — memory games punish the group, not the loser;
  everyone waits while one person recalls. Bad party shape.
- **Anything requiring reading a prompt** (trivia, "never have I ever") — off-brand
  for a wordless, language-free, zero-localisation app (PRD §13 rules out
  more than one language, and text-based party games can't honour that).
- **Tug-of-war / mash race for N** — it's Tap Race with more lanes, and on a
  6" screen six lanes are unreadable.

---

## 3. Seating — the geometry problem

The whole codebase assumes `mid_x()` splits the world in two. Party Mode needs
N seats around the edge of a table-flat phone, each with its own rect **and its
own facing angle**, so a player sitting at the top of the phone sees their pad's
art the right way up from where they are.

Proposed layouts (landscape, phone flat, players around it):

```
 3 players            4 players            6 players
┌──────────┐        ┌─────┬────┐         ┌────┬────┬────┐
│    P3    │        │ P3  │ P4 │         │ P4 │ P5 │ P6 │
├────┬─────┤        ├─────┼────┤         ├────┼────┼────┤
│ P1 │ P2  │        │ P1  │ P2 │         │ P1 │ P2 │ P3 │
└────┴─────┘        └─────┴────┘         └────┴────┴────┘
   (5 players = 6-layout with one seat left empty and the
    remaining five rebalanced to equal width)
```

Rules that fall out of this, and must hold:

- **Equal area, always.** The "symmetry is sacred" rule generalises to "every
  seat gets the same number of pixels." A 5-player layout rebalances widths; it
  never leaves one player a smaller pad than another.
- Seats on the top row are rotated 180°; nobody plays upside-down art.
- Every seat rect comes from `Seat.gd` derived from `Field.rect()`. **The
  hardcoded-1280 bug (GAME_AUDIT C1) is exactly the bug that will happen again
  here if seat rects are computed anywhere else.** One source of truth, same as
  `Field`.
- Chosen One ignores all of this, per §2.

---

## 4. Engineering plan

### 4.1 New autoloads / shared code

| File | Responsibility |
|---|---|
| `autoload/Seat.gd` | Seat geometry: `rects(count)`, `rect_for(seat)`, `facing(seat)`, `center(seat)`, `seat_at(pos)`. Derived from `Field.rect()`, recomputed on resize. Single source of truth for party layout. |
| `autoload/PartyManager.gd` | Player count, per-seat alive/eliminated state, crown tally across a party session, round sequencing. Session-scoped only — nothing persisted, matching the existing `head_to_head` rule. |

### 4.2 `InputManager` changes — the risky one

Today ownership is `1 if x < Field.mid_x() else 2`, with a shared-board override.
Party Mode needs a third ownership model. Extend, don't rewrite:

```gdscript
## Seat mode: ownership is decided at touch-begin by which seat rect the touch
## started in, and never changes. 0 = no seat (touch ignored by seat games).
func set_seat_mode(seat_count: int) -> void

## Free mode: every touch is its own participant, identified by touch index
## rather than by player. Used by Chosen One only.
func set_free_touch_mode(enabled: bool) -> void
```

The existing `player: int` signal argument becomes "player or seat index"
(1..6), which is source-compatible with every current game since they only ever
see 1 and 2. `MatchHost` already resets `configure_zones([])` and
`set_shared_board_turn(0)` before each match — **it must reset seat/free mode
there too**, or a party game's input model leaks into the next 1v1 match. That
leak is the single most likely regression this feature introduces into shipped
code, and it is a one-line prevention.

Free-touch mode needs one genuinely new thing: signals carrying the **touch
index**, since Chosen One tracks fingers, not players. Add
`touch_began/moved/ended(index, position)` alongside the existing player
signals rather than overloading them.

### 4.3 Contract: `PartyGame extends MiniGame`

`MiniGame`'s `match_ended(winner, score_p1, score_p2)` cannot express "P4 won,
P2 came second, P5 and P1 tied for last." Rather than break the contract every
existing game and the whole shell depends on:

```gdscript
extends MiniGame
class_name PartyGame

var min_players: int = 3
var max_players: int = 6
var supports_free_touch: bool = false   # Chosen One sets this true

## Ordered placements, best first. [[4], [2], [1, 5]] = P4 won, P2 second,
## P1 and P5 tied third.
signal party_ended(placements: Array)
```

`PartyGame.end_party(placements)` emits `party_ended` **and** emits
`match_ended` with a degraded 2-player view (winner = first placement, scores 0)
so any shell code that only knows `MiniGame` still behaves. That keeps the
"shell never contains game-specific logic" rule intact — the shell branches on
*contract type*, not on `game_id`.

### 4.4 Shell

- `shell/main_menu` — a second button under PLAY: **PARTY**. (ASCII only, per the
  glyph rule — no emoji, no `▶`.)
- `shell/party_lobby/PartyLobby.tscn` — player-count picker (3–6, big tappable
  numbers), the party game tiles, and the Chosen One mode selector. One screen.
- `shell/match_host` — takes a `party_mode` flag: skips the midline, builds a
  seat-crown HUD instead of two score pills, resets seat/free input mode. All
  the countdown/pause/exit/ad plumbing is reused as-is.
- `shell/party_results/PartyResults.tscn` — podium with the crown tally and a
  PLAY AGAIN that returns to the lobby with the player count preserved.
- `RulesCard` works unchanged (it is already generic and metadata-driven).

### 4.5 Palette / accessibility

Six players need six colours and — per the standing rule that colour is never
the sole differentiator — **six shape markers**. P1 coral and P2 teal stay
exactly as they are; four more get added with a distinct shape each:

| Seat | Colour | Marker |
|---|---|---|
| P1 | `#FF5A5F` coral (existing) | circle |
| P2 | `#22B8CF` teal (existing) | square |
| P3 | `#FFC857` sunshine (existing accent) | triangle |
| P4 | `#4ECB8D` mint (existing success) | star |
| P5 | `#A78BFA` grape (new) | hexagon |
| P6 | `#F98B3C` tangerine (new) | diamond |

Colours 3–6 are pulled from the palette already in `Palette.gd` where possible
so the app doesn't grow a second, looser colour language. Check all six against
each other for deuteranopia/protanopia before locking — six-way distinctness is
much harder than two-way, and coral/tangerine and mint/teal are the two pairs
most likely to fail.

### 4.6 Audio

Every SFX already has a P1/P2 `pitch_scale` variant at playback time, so
`play_sfx(event, player)` extends to six pitches with no new files. New events
needed: `fuse_burn` (looping), `explode`, `whoosh`, `drumroll`, `crown`,
`false_start`. Same stdlib `wave` synthesis approach that produced the current
set — see the Audio pass notes in `CLAUDE.md`.

Party Mode does **not** relax the "no music during matches" rule.

### 4.7 Ads

One party session (a lobby → several rounds → podium) counts as **one** completed
match for `AdManager`'s frequency cap, and the interstitial slot is
podium-entry only — never between rounds. Rounds are 25 seconds; an ad every
25 seconds would be indefensible, and the existing cap ("1 per 3 matches, never
within 90s") would not on its own prevent it if each round counted as a match.
This is a real change to `AdManager`'s call sites, not just a policy note.

---

## 5. Build order

Sequenced so the riskiest unknown resolves first and each step ships something
playable.

**Phase 0 — Prove six fingers work (half a day, blocking everything else)**
Extend the existing web-export + CDP harness (the one in `/tmp/pt`, per
`CLAUDE.md`) to dispatch 6 simultaneous touch points, and confirm
`InputManager.get_active_touch_count()` reports 6 and each is tracked
independently. Then the same on a real phone browser with real hands.
**If a target device caps below 6 touches, the max player count changes and
every layout above changes with it.** Do not build seats before knowing this
number. Budget Android hardware historically ranges from 2 to 10 points, and
the browser adds its own ceiling.

**Phase 1 — Chosen One (1 day)**
Free-touch mode in `InputManager` + the game + a minimal Party entry on the
main menu. Ships on its own as a standalone utility even if nothing else lands.
No seats, no `PartyManager`, no lobby needed — it is deliberately the piece with
the fewest dependencies.

**Phase 2 — Seats + Snap! (1 day)**
`Seat.gd`, `PartyManager`, `PartyGame` contract, seat mode in `InputManager`,
party lobby, party results, and Snap! as the first seat-based game. This is the
phase that proves the whole party framework.

**Phase 3 — Bomb Pass (1 day)**
Pure content on top of Phase 2's framework, plus the arc animation and fuse
system. If the schedule slips, **cut Bomb Pass, not the polish** — same rule as
the launch roster.

**Phase 4 — Polish (half a day)**
Seat rotation for top-row pads, six-colour accessibility check, the new SFX,
crown/podium juice, and a run of the full audit checklist from `GAME_AUDIT.md`
against every seat count from 3 to 6.

Total: ~4 days, contingent on Phase 0.

---

## 6. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Device caps simultaneous touches below 6 | Critical — the mode's premise | Phase 0, before any other work. Fall back to a 4-player max if needed; the layouts already support it. |
| Seat/free input mode leaks into a 1v1 match | High — breaks shipped games | `MatchHost` resets all input modes before every match, party or not. Add a regression check to the playtest harness. |
| Six-way colour distinctness fails accessibility | Medium | Shape markers are mandatory, not decorative. Verify with a simulator before locking the palette. |
| Party rounds trigger ads too often | High — store risk, and it's a children's-audience app | Session-level ad accounting (§4.7), decided before the games are built, not after. |
| Party Mode delays v1 submission | High | It is v1.1. v1 ships the 6 two-player games and the Day 5 work that is still open. |
| Six players fighting over a 6" screen | Medium | Equal-area seats, high-contrast per-seat borders, and a hard 6 cap. Playtest at 6 before committing to 6. |

---

## 7. Success criteria

- A group of 5 can go from cold app open to a finished Chosen One pick in under
  10 seconds without anyone reading instructions.
- Six simultaneous touches tracked independently on real hardware, verified by
  checking the thing input moves (six rings appearing), not a downstream score.
  (The lesson from `GAME_AUDIT.md` applies here as much as anywhere.)
- A party session averages 3+ rounds before the group leaves — if people play
  once and stop, the round loop is wrong, not the games.
- No regression in any of the 6 launch games' input handling.

---

## 8. Open decisions

- [ ] Max player count — pending Phase 0's hardware answer (6 assumed here)
- [ ] Does Chosen One live on the main menu as its own top-level entry, given
      it is a utility rather than a game? (Recommendation: yes — it is the
      cheapest reason for someone to open the app.)
- [ ] Bomb Pass fuse length: fixed-random per bomb, or shortening each round to
      accelerate the endgame
- [ ] Whether Party Mode ships free or is bundled with Remove Ads (PRD's
      monetisation is a single non-consumable; a second SKU would be a change
      to §8's stated model and probably not worth it)
