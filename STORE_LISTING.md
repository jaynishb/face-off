# Face Off — Store Listing

Source of truth for Google Play / App Store listing copy. Pulled and
expanded from `FACE_OFF_PRD.md` §10 — keep both in sync if either changes.

## Title

`Face Off — 2 Player Offline Games`

(53 characters — fits Google Play's 30-char short title too if truncated to
`Face Off`, with the rest as subtitle where the store allows it.)

## Short description (Google Play — max 80 chars)

`Two players, one phone, no wifi. Six fast head-to-head games.`

## Subtitle (App Store — max 30 chars)

`2-Player Offline Games`

## Keywords / ASO targets

`2 player games`, `offline games`, `games without wifi`, `two player games
one phone`, `same screen multiplayer`, `2 player offline`, `no internet
games`, `couples games`, `games for kids offline`, `split screen games`

## Long description

```
NO WIFI? NO PROBLEM.

Face Off is six fast, funny head-to-head games you play on ONE phone —
no wifi, no accounts, no login, no second device. Just hand over the
phone and go.

HOW IT WORKS
Every game splits the screen in two. Player 1 controls the left side,
Player 2 controls the right. Every match takes 20-60 seconds. Rematch
with one tap.

THE GAMES
🏒 Air Hockey — drag your paddle, hit the puck, first to 5 wins
🏓 Ping Pong — the classic, first to 7 wins
⭕❌ Tic-Tac-Toe — best of 5 rounds, resolves fast
🏎 Tap Race — tap your two buttons as fast as you can
🔴🟡 Connect Four — four in a row, any direction
🟠🔵 Sumo Blob — dash and knock them off the shrinking platform

PERFECT FOR
- Car rides, flights, restaurants, waiting rooms
- Killing five minutes with a friend, partner, or sibling
- Parents who want the kids occupied without handing over data or ads
  aimed at them

NO CATCH
- No login, no account, no cloud save
- No data collection, nothing sent anywhere except (optionally) ad
  requests — see our privacy policy
- No ads for your first 3 matches, ever, and never mid-match
- One-time Remove Ads purchase if you want the app ad-free for good

Two players. One phone. Zero setup. Face Off.
```

## Screenshot plan (in order)

1. Air Hockey mid-match with two hands visible on the phone — sells the concept in one image
2. Big text overlay: "NO WIFI NEEDED"
3. Game select screen showing the full roster
4. Sumo Blob mid-collision (the personality shot)
5. Two kids playing in the back of a car
6. Two adults playing at a table
7. Big text overlay: "ONE PHONE. TWO PLAYERS. ZERO SETUP."

**Status: not produced.** All 7 require either real device screenshots (after
the art/audio polish pass, PRD Day 4) or staged photography with real
people — neither is possible from this environment. Placeholder/procedural
`_draw()` graphics are not representative enough to submit as store
screenshots.

## Category / rating

- Category: Games → Family / Casual (confirm exact taxonomy per store)
- Content rating: general audience, no violence/language — should clear the
  lowest content-rating tier on both stores. Confirm the target age rating
  decision in `FACE_OFF_PRD.md` §14 before submission — it changes required
  ad SDK configuration (see `PRIVACY_POLICY.md`).

## Still open before this can actually be submitted

- Final app name check (Play Store / App Store / domain availability) — PRD §14
- Real screenshots and a 30s preview video (needs the art/audio pass + a device)
- App icon / feature graphic in store-required resolutions (currently only
  a placeholder `icon.svg` exists, sized for in-engine use, not store submission)
- Signed `.aab` (Android) and iOS archive — needs the Godot editor, export
  templates, and signing keys, none of which exist in this environment
