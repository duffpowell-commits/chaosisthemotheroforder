# Handoff: Chaos 8.5 pass (Nov 26, 2026)

For any coding AI picking this up. Read AGENTS.md and CLAUDE.md first (rules, guards, commands).
Duff paused Chaos briefly, then said to build all the fixes with no mock reviews.

## Studio mascot (Duff, Nov 26)
- **The three-eyed fox is in every game as a rare cameo, not a pal**: a small event
  that matters but never ruins a run. Duff OKs the fox art on a card before it's built. Rule + this game's idea: `docs/MASCOT.md`.

## Where things stand
- Live: web https://duffpowell-commits.github.io/chaosisthemotheroforder/ (Pages from `gh-pages`, published by CI's
  `web` job on every push to main). APK: Releases -> `dev`.
- Checked 2026-11-26 20:00 UTC: main `3073806`, **build 62 live** (`version.json` on the `dev` release).
  On main: the 8.5 pass (PR #32), the iPhone web load fix (#33), the mascot rule (#34), the fox graffiti cameo (#35).
  Nothing is mid-build. Open PRs: only #9 (Nov 16 "Beauty test", Grok sprites on the Mobile renderer: old, not
  current work; leave it for Duff to close).
- White Flag: step 1 is live; every further step needs Duff's OK first (he asked for step by step). Keep quiet
  survival at 60-70% in `tools/mission_sim.gd`.
- Latest reviews (Nov 26, before this pass): first-timer 5.5/10, veteran 6.0/10. Duff cancelled the replay review.
- Duff's standing bar: plan to an 8.5 first-time-player review, OK it once, build it in one pass.

## What the 8.5 pass built (all 7 items Duff OK'd)
1. **Mission brief:** a card before turn 1 of every Signal Box fight (`_show_brief`, tactical.gd), a Goal button in the
   top bar that reopens it, and map markers `_draw_goal_markers` (UPLOAD HERE n/2 over the box, EXIT on the south row,
   pinned to the screen edge with an arrow when off camera).
2. **Fair stealth** (battle.gd):
   - `FIRST_CONTACT`: a guard on patrol when the regime turn began holds fire that turn ("takes aim but holds
     fire"). Guards who come running to his shout (`add_noise`) lose that grace.
   - `_can_target`: no shots at a hidden unit unless a patrol could spot it or an alerted guard is within
     `SEARCH_SIGHT` (4) in line of sight.
   - `_spotted_by` logs who, how far and why, and un-hides the units seen.
   - Test: `test_first_contact_and_hidden_targets`.
   - Balance: quiet 3 v 4 nobody out 34% (survival 66%, target 60-70%); loud 5 v 4 airs 62%.
3. **Readable enemy turn:** guards move one at a time (`ENEMY_STEP`), shots are spaced out (`ENEMY_SHOT_GAP`), then a
   "REGIME TURN" card lists the last 8 log lines (skipped under --autoplay). Hearts show lost ones: `_hearts` -> "♥♡".
4. **Cover bars:** `_draw_cover_marks` draws a bar on each edge of the move range that faces cover (thin = half, thick
   = full or the box).
5. **One-time tips:** `TIPS` / `_tips` cover ?, Wavering, ALARM and nerve ◆. Each shows once, saved in
   user://coach.cfg [tips]. Persuade shows on a tapped wavering guard even out of range, disabled with what it needs.
6. **Campaign polish** (game.gd, rules.gd, text.gd):
   - Zone cards show Support ▮▯ N/100: exact when Confirmed, ~ when Likely, ? when Rumor.
   - "Sentiment" is now "Support".
   - A Likely zone (the week after Listen) shows Regime eyes.
   - The zone/choice picker uses the dossier sheet with card buttons.
   - Leave asks before the last one out abandons the downed (`_confirm_leave`).
   - Fight now's result button says "Back to the title".
7. **Bug sweep:**
   - Log said "You fires".
   - The coach hint now also goes on any action, End turn, or a tap after turn 1.
   - No "+N noise" once the alarm is on.
   - The camera reframes 0.4 s after start (web canvas settles late).
   - Tags are clamped on screen (left, right, above the bottom bar).
   - Smoke/flash valid tiles are brighter.
- Renders: `docs/renders/8_5/` (`res://scenes/tactical.tscn -- --capture-8-5`).

## After the 8.5 pass (Nov 26)
- Web load fix for iPhone (PR #33): pack 43 MB, commit-named files.
- Mascot cameo: fox graffiti on a yard container (docs/MASCOT.md "This game").

## Known leftovers (small)
- Threat-odds % labels can sit under the bottom bar.
- A tip line can overlap guard tags at the top.
- The UPLOAD HERE marker can overlap guard tags when the box is off camera.
- Not done: a full scrollable log (the Regime turn card covers most of it).

## Next (needs Duff; design first, nothing built)
- A second mission/map (the veteran's biggest ask; likely needed to reach 8.5+).
- White Flag's holding slot and five prisoner choices (docs/white-flag-notes.md).
- Ledger stamps.
- Endings.

## How to build and test
- `tools/test.sh` must print `TESTS PASS` before any push (the push guard checks the tree).
- QoL: `xvfb-run -a godot --path . --rendering-driver opengl3 --script tools/qol_check.gd` -> `QOL PASS` (it rewrites
  docs/renders/ui/*.png; revert those unless they're meant to change). Sound: same with `tools/sound_check.gd`.
- Balance: `godot --headless --path . --script tools/mission_sim.gd -- 300 focus` (~4 min).
- Commit and push in separate calls. PRs need CI green plus a `FRESH-EYES REVIEW: PASS` review on the head commit.

## Log (newest first)
- 2026-11-26 20:00 UTC Claude: handoff refresh (no code): state checked against main, old PR #9 noted, this log added.
- 2026-11-26 Claude: fox graffiti cameo merged (#35); web pack 65 -> 43 MB (#33); 8.5 pass merged (#32).
