# AGENT.md — Operating rules for coding agents on Face Off

This file is the checklist/guardrail layer. `CLAUDE.md` has the architecture and stack reference; `FACE_OFF_PRD.md` has the full product spec. Read this before making changes, especially before adding a new game or touching the shell/autoloads.

## Non-negotiables (do not break these while implementing anything)

1. **Landscape only.** Never add a portrait layout, orientation-change handling, or responsive breakpoints for portrait. If a scene "would also work" in portrait, that's not a reason to support it.
2. **No network calls** anywhere except the ad SDK. No analytics SDK, no backend, no cloud save, no login. If a task seems to require one of these, stop and flag it — it's almost certainly out of scope (PRD §13).
3. **Symmetry.** Any change to one player's control zone, UI weight, color treatment, or screen real estate must be mirrored for the other player in the same change.
4. **The MiniGame contract is the only interface between shell and games.** Never have shell code (`MainMenu`, `GameSelect`, `Results`, `GameManager`) branch on a specific `game_id`. Never have a game reach into shell scenes directly. If you need shell↔game communication that the contract doesn't cover, extend the contract itself, don't bypass it.
5. **All player input goes through `InputManager`.** Never read `Input`/`InputEvent` touch data directly inside a game script. Zone definitions are data (a Dictionary/Resource passed into `setup()`), not new code paths in `InputManager`.
6. **Ad placement rules are fixed**, not a product decision an agent can revisit: interstitial only between match-end and results, never mid-match/launch/rules-card, ≤1 per 3 matches, ≥90s apart, zero ads in the user's first 3 matches ever. Any AdManager change must preserve these invariants — write/keep tests or at least manual verification notes for the frequency cap logic.
7. **No mid-match interruptions of any kind** — no popups, no notifications, no forced pauses other than the player-initiated pause button.
8. **Color coding is fixed**: P1 = coral `#FF5A5F`, P2 = teal `#22B8CF`. Never rely on color alone to distinguish players in a new UI element — always add a shape/icon marker too.

## Before adding a new game

1. Confirm it's in the roster (PRD §5) — 6 launch games, 4 post-launch. Don't invent new games unless explicitly asked.
2. Create `/games/<game_id>/` with its own scene(s) and script(s) implementing `MiniGame`.
3. Populate `rules_text` (max 3 lines) and `rules_icon`/diagram — if you can't get the rules under 3 lines, say so rather than shipping a paragraph.
4. Register the game with exactly one line in the game registry (wherever `GameManager` enumerates games) — no other shell file should need edits.
5. Route all input through `InputManager` zone config, not new input-handling code.
6. Verify: playable start-to-finish (countdown → match → `match_ended` signal fires with correct winner/scores → results screen), performs at the 30fps floor, both player sides are visually/functionally symmetric.

## Before touching `InputManager`

This is the highest-blast-radius file in the codebase — every game depends on it.
- Multi-touch (both players touching simultaneously, independently) must keep working. This cannot be verified in the editor alone; note in your summary that real-hardware verification is still needed if you can't do it yourself.
- Touch-to-player assignment is decided once, at touch-begin, by screen half, and must not change mid-drag even if the finger crosses the midline.
- Keep the debug overlay functional — it's the tool used to catch regressions here.

## Monetization/IAP changes

- Never add a second IAP product, subscription, or skin-pack purchase at v1 — only the single non-consumable "Remove Ads". Skins/game-packs are explicitly v1.2+ (PRD §8.3) and out of scope now.
- Never block gameplay behind a purchase or rewarded-ad prompt. Rewarded video is opt-in only ("watch an ad to unlock a skin") and must never gate a game.

## When a task is ambiguous or seems out of scope

Check PRD §13 (Out of Scope for v1) and PRD §3 (Core Design Principles) first. If a request conflicts with a non-negotiable above or with explicit out-of-scope items (online multiplayer, AI opponent, accounts, leaderboards, cloud save, portrait/tablet layouts, progression systems), implement the smallest in-scope version of what's actually needed and flag the conflict rather than silently building the out-of-scope version.

## Definition of done for any change

- Builds/runs in the Godot editor without errors.
- Doesn't regress the shell's generic handling of games (no new `game_id` branches leaking into shell code).
- Respects the performance floor (playable at 30fps) for anything touching a game loop or physics.
- Respects the visual system (palette, fonts, motion/easing rules) in `CLAUDE.md` for anything touching UI.
- If it's a new game: matches the "readable in one sentence" rule end to end, from rules card to actual mechanic.
