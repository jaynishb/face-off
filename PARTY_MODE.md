# Party Mode — group play proposal

**Status:** proposal / not implemented. Nothing in this file has been built.
**Companion to:** `FACE_OFF_PRD.md` (v1 scope) and `CLAUDE.md` (dev manual).

v1 is deliberately two people on one phone. This document is the case for the next
axis of growth — *the whole room on one phone* — split into the utility layer that
makes a group session work, the engine changes it needs, and the game ideas that
only become possible once it exists.

---

## 1. Why this, and why it doesn't break the product

The v1 positioning is "no wifi, one phone, two players." The group version is the
same story with a bigger occasion: **one phone, the whole room, still no wifi.**
Everything that makes Face Off good — zero setup, no account, instant rematch —
gets *more* valuable as the group gets bigger, because the alternative (everyone
installs an app, joins a lobby, one person has no signal) fails harder with 6
people than with 2.

It also stays inside PRD §13's out-of-scope list. §13 rules out online multiplayer,
AI opponents, accounts, leaderboards, cloud save, and progression systems. Local
group play on the one shared device is none of those. **The one rule §13 imposes on
this proposal: the party scoreboard is session-scoped, cleared on app close, exactly
like `GameManager.session_head_to_head` is today.** No persistent profiles, no
lifetime stats, no unlock ladder. A party scoreboard that survives the party is a
progression system wearing a hat.

---

## 2. The key insight: there are two group models, and only one of them is expensive

Almost all the value is in the cheap one.

### Model A — Hot seat ("2 play, everyone watches")
6–12 people in the room, two of them holding the phone at any moment. The app's job
is to manage *who plays next and who is winning overall*. It is pure shell work:
roster, format, standings, hand-off. **It requires zero changes to any of the six
existing games** — every one of them becomes party content the day the shell lands.

This is the highest return-on-effort item in this entire document.

### Model B — Same-screen simultaneous (3–4 players around one phone)
Phone flat on a table, players on its edges, all touching at once. This needs an
N-seat input model, N-seat layout, N-seat scoring, rotated per-seat UI, and new
games designed for it. It is real engineering, and it's constrained by physics:
**a 6" phone gives four people about 7cm of edge each.** Drag controls stop working
(you cannot drag along an axis that's sideways to you), so 4-player games have to be
tap-only with well-separated targets. That single constraint decides the game list
in §5.

**Recommendation: ship Model A first as a free update, then Model B.** Model A can be
built and shipped without touching `MiniGame`, `InputManager`, or a single game
scene. Model B pays for itself only after the party framing already exists.

---

## 3. The utility layer — what "party mode" actually is

This is the part the app is missing. Not more games — a *host*.

### 3.1 Roster
Add 2–12 players before a session. Each gets a colour **and a shape marker** (the
existing accessibility rule: never colour alone). Naming must not require a keyboard
— tap to cycle through friendly presets ("Fox", "Bolt", "Pickle") with an optional
keyboard entry, because the Parent persona's five-year-old cannot type and the Pair
persona is in a bar. Roster is session-scoped; optionally remember the *last* roster
so "same crew as last time" is one tap.

### 3.2 Formats
- **Free play** — today's behaviour, now with real names on the results screen.
- **King of the Hill** — winner stays on, next challenger steps up, streak counter
  on screen. This is the classic arcade format, it needs no bracket UI, it handles
  any number of players including someone joining mid-session, and it maps perfectly
  onto a phone being physically handed sideways. **Build this one first.**
- **Round robin** — everyone plays everyone once, points table. Best at 3–5 players;
  at 8 players it's 28 matches and the party is over before it resolves. Cap it.
- **Knockout bracket** — single elimination with automatic byes, drawn as a real
  bracket. The most "tournament night" feeling, the most UI work.
- **Teams** — two sides, members alternate. Makes a 4-thumb phone feel like a
  6-person game.

### 3.3 Game spinner / party pack
Each round, the app picks the next game — random from a chosen pool, no repeats
until the pool is exhausted, with a visible spin animation. This removes the single
most common friction in a group: arguing about what to play. It also surfaces games
people would never have picked from a grid.

### 3.4 Session scoreboard
Cumulative points across games and matches, with a podium at the end and an explicit
"New Party" reset. Points per match win, not per goal, so a Ping Pong 7–0 and a
Tic-Tac-Toe 3–1 are worth the same and the games stay interchangeable.

### 3.5 Pass-the-phone card
Between matches, a full-screen hand-off card: both names, both colours, both shapes,
and a **READY tap required from each side** before the countdown starts. This solves
a real failure the current flow has even at two players — the rematch button starts
the match instantly, and the person who wasn't holding the phone loses the first two
seconds. It also gives the ad system a clean, honest boundary (see §6).

### 3.6 Handicap / fair play
Optional, off by default: shorten the leader's target score, or give the trailing
player a slightly larger paddle. Aimed squarely at the Parent persona — a 7-year-old
against a 30-year-old is not a game, and today the app has no answer for that. Keep
it explicit and visible on screen; a hidden handicap is a betrayal, a visible one is
a courtesy.

### 3.7 Referee tools (games with no game)
Cheap to build, disproportionately useful, and a genuine re-engagement hook — these
are the reason someone opens the app when nobody wants to play anything:

- **Coin flip / dice / spinner** — who goes first, who buys the round.
- **Team randomiser** — split the roster into balanced teams.
- **"Who's it?" chooser** — everyone puts a finger on the screen, the app counts
  down and picks one. This is the universal party primitive *and* it is the single
  best live demonstration and stress test of `InputManager`'s simultaneous
  multi-touch, which is this project's stated #1 product risk. It doubles as the
  capability probe in §7.
- **Turn timer / countdown** for whatever physical game the room is actually playing.

---

## 4. What the engine needs (Model B)

Keyed to the files as they exist today. Everything here is a two-player assumption
baked into a name or a signature, which is fine at 2 and blocks at 4.

| Today | Needs to become | Notes |
|---|---|---|
| `MiniGame.match_ended(winner, score_p1, score_p2)` | `match_ended(winner, scores: Array)` | The hard blocker. Six games and the shell touch it. Generalise now while there are six — this only gets more expensive per game added. |
| `Field.half_center(player)`, `Field.mid_x()` | `Field.seat_rect(seat, seat_count)`, `Field.seat_center(...)` | `mid_x()` stays for 2-seat games. Layouts: 2 = left/right; 3 = three columns or two-plus-bottom; 4 = quadrants or four edges. The Field-is-the-single-source-of-truth rule from `GAME_AUDIT.md` matters *more* here, not less. |
| `InputManager._player_for_position` compares against `Field.mid_x()` | Hit-test seat rects from `Field` | Touch-begin ownership rule is unchanged and still correct. `set_shared_board_turn()` is unchanged. |
| `Palette.PLAYER_1/PLAYER_2`, `for_player()` | Four seat colours + four shape markers | Proposed: P1 coral (circle), P2 teal (square), P3 amber (triangle), P4 violet (diamond). Do **not** reuse `SUCCESS` mint or `ACCENT` yellow verbatim — they already mean something. Shapes are mandatory, per the existing accessibility rule. |
| `GameManager.session_head_to_head` as `{p1_wins, p2_wins}` | A new `PartyManager` autoload owning roster, format, standings | `GameManager` stays about scene loading and the registry. Party state is a separate concern and shouldn't grow inside it. |
| `MatchHost` score bar: two pills | N pills, sized from seat count | Same for the win banner and results screen. |
| `GAME_REGISTRY` entries | Add `min_seats`, `max_seats`, `seat_layout` | So `GameSelect` filters by party size **as data**, not by the shell branching on `game_id` — the contract rule in `CLAUDE.md` still holds. |

**Orientation.** Landscape lock stays. But a player sitting on the far edge reads
everything upside down, so seat-local UI (score pill, turn banner, ready button) must
be rotated to face its seat, and rules cards for 4-player games must be carried by
the diagram, not the text. This is a good forcing function — the PRD already caps
rules at three lines.

---

## 5. Game ideas

### 5.1 The free tier: the six games you already have
Under King of the Hill or a bracket, all six existing games become group content with
no game code written. Stated plainly because it's easy to skip past: **the first
party update needs no new games at all.**

### 5.2 Four-player simultaneous — ranked by cost-to-value

**1. Sumo Rumble** *(cheapest real 4-player game available)*
Sumo Blob with four blobs on the shrinking platform, last one standing wins. The
physics, the dash, the squash-and-stretch, the elimination handling, and the
shrinking-platform resolution timer all already exist in `games/sumo_blob`. It needs
four seats and four tap zones, not a new game. Elimination order gives free
4th/3rd/2nd/1st placings for the scoreboard.

**2. Reaction Royale ("Don't Be Last")**
Screen holds… holds… flashes GO after a random delay. Last player to tap loses a
life; tapping early also loses a life; three lives each. No physics, no art, no
board. Scales from 2 to as many seats as fit around the phone. It is the purest
possible elimination drama and — importantly — it is a *deliberate* maximum-load
test of simultaneous multi-touch, the risk area this project has never fully cleared
on native hardware.

**3. Colour Flood 4**
The PRD's post-launch #10, generalised. Shared grid, four paints spreading from four
corners, most territory after 20 seconds wins. Shared-board input model (already
built for Tic-Tac-Toe / Connect Four), naturally N-player, and the PRD already calls
it the best-looking game of the set. Highest ceiling of anything here.

**4. Hot Potato, four-way**
PRD's post-launch #8 with the bomb bouncing between four quadrants instead of two
halves. Whoever's quadrant it's in when the fuse blows is out; play continues with
the survivors. Elimination scales for free.

**5. Tug of War (2v2)**
Two teams, two players per side, alternate-tapping to pull the rope. Reuses Tap
Race's already-solved anti-mashing alternation rule. This is the flagship for team
mode: it is the game that makes four thumbs on a small phone feel intentional rather
than cramped.

**6. Crown Grab**
A crown appears at a random point on the shared screen. Hold it to bank time; most
banked time after 30 seconds wins. Four fingers physically fighting over the same
pixel — chaotic, funny, and the best short video clip in the whole app.

**7. Colour Call (Simon-like)**
A sequence of coloured flashes; each player must tap when *their* colour comes up and
not when it doesn't. Misses and false taps eliminate. Tiny to build, and the only
memory/attention game in the roster — good pacing contrast, same role Tower Topple
plays in the PRD's list.

### 5.3 Beyond four — the crowd games

These break the "two players, split screen" model entirely and scale to a whole room.
They are a different product shape, and should be a clearly separate section in the
UI, not mixed into the head-to-head grid.

**8. Charades / pass-the-phone prompt game**
Phone held to the forehead or passed round, prompt on screen, room shouts clues,
timer runs. Scales to 12 people, needs no multi-touch at all, and is the only idea
here that works when everyone is standing up. Content is a word list — cheap to build,
but it *is* content that needs writing and age-appropriate curation, unlike everything
else in this app.

**9. Trivia buzzer**
The phone is only the buzzer array: four corner buttons, first tap locks out the
rest. Questions come from the room or a bundled deck. Reuses the four-corner seat
layout from §4 exactly.

**10. Impostor / odd-one-out word round** — *listed with a warning.*
Pass the phone, everyone reads a secret word, one player's is different, then the
room discusses. Genuinely great with 5+ people, but a round lasts several minutes of
talking, which is a direct violation of PRD §3's "a match is 20–60 seconds" and of
the whole positioning. If it ships, it ships knowingly as a different thing in a
different menu — not as game #11 in the grid.

---

## 6. Ads and monetisation under party mode

The existing rules in `CLAUDE.md` (interstitial only between match end and results,
max 1 per 3 matches, never within 90s, none in the first 3 matches ever) were written
for a two-player session where matches are naturally spaced by a hand-off. A bracket
runs matches back to back and will hit the frequency cap constantly.

Two adjustments, both tightening rather than loosening:
- **Count rounds, not matches.** In a tournament format, the cap counts completed
  *rounds*, so a five-match bracket round is one ad opportunity, not five.
- **The pass-the-phone card is the only party ad slot.** It is already a deliberate
  pause where nobody is mid-game, which is exactly the honest place for it. Never
  between a knockout semi-final and its final.

Party mode is also the strongest Remove Ads pitch the app will ever have — the person
who has 6 friends round is the person most annoyed by an interstitial — without
adding a second IAP, which stays out of scope.

---

## 7. Risks

1. **Simultaneous multi-touch at 4 points on cheap hardware.** This project's #1
   stated risk is still unresolved on native (`CLAUDE.md`: web-build two-finger
   verification exists, native does not). Budget Android panels vary in how many
   simultaneous points they track reliably, and some report ghost points under load.
   **Mitigation:** probe it. The "Who's it?" chooser from §3.7 is a genuine feature
   *and* a first-run capability test — if the device never reports more than two
   simultaneous touches, hide the 4-player games rather than shipping a game that
   silently doesn't work. Do this before building any Model B game, exactly as Day 1
   should have been cleared before Day 2.
2. **Physical ergonomics.** Four adults around a 6" phone is genuinely cramped. This
   is the first real argument for revisiting the "no tablet layout" decision in §13 —
   not for v1, but party mode is what makes a tablet layout worth money.
3. **Format length.** Round robin at 8 players is 28 matches. Cap formats by roster
   size and default to King of the Hill, which never has this problem.
4. **Session length creep.** Group mode must add length by *stacking* 30-second
   matches, never by lengthening a match. The 20–60s rule is the product.
5. **Age rating.** Forfeit/dare decks and prompt word lists are the two features here
   that can move the rating. Both are optional content; if either ships, it ships
   with a kid-safe default list and the rating decision made first — which is already
   an open item in PRD §14.

---

## 8. Suggested phasing

**P1 — Party shell (no game code touched).** `PartyManager` autoload, roster, King of
the Hill, session scoreboard, pass-the-phone card, game spinner. Ships as a free
update; all six existing games instantly support 2–12 players hot-seat. Store listing
gains "2–12 players" without a single new game.

**P2 — N-seat contract + two 4-player games.** Generalise `MiniGame` scores, `Field`
seats, `InputManager` seat rects, `Palette` seat colours/shapes. Land Sumo Rumble
(reuses existing physics) and Reaction Royale (near-zero content) — two genuine
simultaneous 4-player games for roughly the cost of one.

**P3 — Depth.** Colour Flood 4, Hot Potato four-way, Tug of War 2v2, bracket UI,
referee tools, handicaps.

**Cut order if time runs short:** bracket UI before King of the Hill, round robin
before either, crowd games (§5.3) before anything in §5.2. A group of people with one
phone needs a host and a queue far more than it needs a bracket diagram.
