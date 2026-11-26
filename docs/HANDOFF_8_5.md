# Handoff: Chaos 8.5 pass (paused Nov 26, 2026)

For any coding AI picking this up. Duff paused Chaos on Nov 26 (~7:12 AM CT) to save usage.
**Don't resume until Duff says so.** Read AGENTS.md and CLAUDE.md first (rules, guards, commands).

## Where things stand
- On main and live: everything through PR #31 (White Flag step 1, iPhone web link).
  Web: https://duffpowell-commits.github.io/chaosisthemotheroforder/ (v0.1.55, Pages from `gh-pages`,
  published by CI's `web` job on every push to main). APK: Releases -> `dev`.
- This branch: `claude/chaos-8-5` (WIP, no PR yet, NOT merged). Started from main 2c5f551.
- Latest reviews (Nov 26): first-timer 5.5/10, veteran IGN-style 6.0/10. Full first-timer review is in
  Duff's project files (chaos-reviews/first_timer_2026-11-26.md); its top 5 are below.
- Duff's standing bar: a first-time-player review of **8.5** before more rounds get built. He OK'd the
  7-item "8.5 plan" below ("Build all 7"), to be built in ONE pass, then a fresh first-timer replay.

## The 8.5 plan (Duff OK'd all 7) and status on this branch
1. Mission brief + goal markers: a card before every Signal Box fight (incl. Fight now): "Hold the box
   2 turns to air the footage, then get out at the south edge". Markers on the upload tile and exit row
   before it's aired too; tapping the Upload counter reopens the brief. **Not started.**
2. Fair stealth. **Built, balance NOT done** (scripts/tactics/battle.gd):
   - `FIRST_CONTACT`: guards on patrol when the regime turn began (`fresh`) hold fire that turn
     (log "X takes aim but holds fire").
   - `_can_target`: a guard can't aim at a hidden (sneaking) unit unless a patrol could spot it or an
     alerted guard is within `SEARCH_SIGHT` with line of sight.
   - `_spotted_by` logs who saw whom and why ("Guard 2 spots Mara (5 tiles, in the open) and shouts")
     and un-hides everyone that guard sees.
   - **Problem:** mission_sim 300 focus, quiet 3 v 4 "nobody out" went 34% -> 17% (target 30-40%, i.e.
     survival 60-70%). SEARCH_SIGHT 4 or 6 doesn't move it; EXTRA_GUARDS 2 overshoots (93%). Next try:
     faster reinforcements (REINFORCE_DELAY), guards' MISSION_SIGHT, or FIRST_CONTACT only for the
     spotter (not guards alerted by his shout). Keep the fairness rules; tune with visible levers.
3. Readable enemy turn: today `_on_end_turn` (tactical.gd) tweens every guard at once in 0.5 s and
   flashes all shots back to back. Make it one guard at a time (~0.45 s each), shots spaced out, then a
   "Regime turn" summary panel of this turn's log lines (skip under --autoplay). Log: 6+ lines or a LOG
   button. Hearts as "♥♡" (`_pips` -> filled + empty up to Battle.MAX_HP). **Not started.**
4. Cover markers: on reachable tiles, a short bar on each edge facing a HALF (thin) / FULL or BOX
   (thick) neighbour (draw in `_draw_overlay`). **Not started.**
5. First-time tips (once each, saved in user://coach.cfg like `_build_coach`): "?" = on patrol, hasn't
   seen you; "Wavering" = close to switching sides, get within 3 and Persuade; ALARM = N riot police in
   N turns; nerve pips ◆. Show Persuade on a tapped wavering guard even out of range, disabled with
   "get within 3". **Not started.**
6. Campaign polish. **Done on this branch** (scripts/ui/game.gd, scripts/sim/rules.gd, scripts/ui/text.gd):
   zone card shows Support ▮▮▯ N/100 (exact when Confirmed, ~ when Likely, ? when Rumor) and Ready at 61;
   "Sentiment" renamed "Support" in job text; a Likely zone (the week after Listen) now shows Regime eyes;
   the zone/choice popup uses the dossier sheet + card buttons. Still to do: Leave asks before abandoning
   downed allies (tactical.gd `_on_leave`), and Fight now's result button says "Back to title"
   (`_show_result`: `mission_meta.has("state")` = a run).
7. Bug sweep. Done: log said "You fires" (`_verb`). To do: coach "Tap a blue tile" also goes away on any
   action/End turn; no "+3 noise" in the Shoot label once the alarm is on; reframe the camera ~0.3 s after
   start (units started under the bottom bar on web); clamp tags inside the screen (a "Wavering" tag was
   clipped at the right edge); smoke/flash valid tiles at alpha ~0.22 (`_tool_tiles`, now 0.10).

Then: tools/test.sh (TESTS PASS), autoplay after tactical changes, renders to docs/renders/, a draft PR,
the fresh-eyes review (docs/FRESH_EYES.md), merge when green, then a fresh first-timer review on the web
build (play blind, like a new player) and report the score against 8.5.

## After the 8.5 pass (design to plan with Duff, nothing built)
Second mission/map (the veteran's biggest ask), White Flag's holding slot + five prisoner choices
(docs/white-flag-notes.md), Ledger stamps, endings.

## Gotchas
- Commit and push in separate calls; the push guard wants `tools/test.sh` to pass on the exact tree.
- mission_sim: `godot --headless --path . --script tools/mission_sim.gd -- 300 focus` (~4 min).
- `--script` runs don't register autoloads; preload instead.
- A first-timer review in headless Chromium runs ~1 FPS; judge readability, not speed.
