# Chaos Is the Mother of Order

Grim Godot 4.5 strategy-RPG about organizing a revolution against a modern
police state. Owner: Duff. Read this first; it is the handoff between sessions.

## Where things stand
- Design: `docs/design.md` (pillars, "XCOM meets Advance Wars" combat feel, open questions).
- Look: `docs/style-guide.md` (palette, readability rules). Check renders against it.
- Current work: the vertical slice, `docs/slice-spec.md`. Progress: `tasks/todo.md`.
- Done: M1 rules + simulator, M2 map/planner/report, M3 dialogue runner + Teodor,
  M4 tactical core, **M5 Signal Box mission** (plan the op in week 2+ and it plays
  the mission; the result finishes the week).
- **Jam target:** 2026 Jam on itch, submit by Dec 28. Plan, fixes and scope cuts:
  `docs/jam-slice-spec.md` (J1–J5; M6 becomes J2).
- Next: **J1** readability (unit rings, label stacking, rim light, lighter grain on
  the tactical map), Advance Wars clarity (threat on tap, full shot preview), and a
  web export spike (web needs the Compatibility renderer). Then J2 = M6 + mid-fight saves.
- **End of every milestone:** run autoplay, the tension numbers, and an independent
  design review (fresh agent, pillars + style guide + renders). Jam spec §5b.
- Fallback art: `scripts/sprite_bake.gd` bakes rigs into 8-direction sprites;
  `tools/compose_sprites.py` makes review sheets (`docs/renders/sprites/`).
  Decision gate Dec 6.

## First thing next session
- Retarget fix (Nov 6): the silhouette fix is now ON for all four rigs. Without it
  every Mixamo clip bent the forearms inward (arms looked crossed). Side effect:
  portraits re-rendered with the head tipped slightly up. Ask Duff if they're OK.
- If the jam falls back to sprites, the look is **pixel** (Duff's pick).
- Autoplay found (Nov 6, `docs/renders/autoplay_quiet.gif`): when units bunch up, their
  name/HP labels pile on top of each other and can't be read (fix in J1).
- Duff's calls (Nov 6): Signal Box slightly less brutal (done: broadcast freezes
  guards 1 turn); the fight carries on when You fall (already true); **save mid-fight:
  yes** (build it in J2 with the saves work). Combat should play like **XCOM meets
  Advance Wars** (see `docs/design.md` pillars).

## Layout
- `scripts/sim/` pure game rules (`RunState`, `Rules`, `Policies`). No scenes.
- `scripts/dialogue/` dialogue runner (`dialogue.gd`, format in its header) and
  `story.gd` (which scene plays when). Scripts live in `dialogue/*.dlg`.
- `scripts/ui/game.gd` the playable slice UI, built in code. `text.gd` player text.
- `scripts/render_test.gd` the Rail Yards street (`-- --capture`, `--portraits`).
- `scripts/tactics/battle.gd` pure tactical rules + AI, skirmish and Signal Box
  mission (`create_mission`). `tactical.gd` the scene (extends render_test.gd;
  2D grid overlay so the grade doesn't grey it out). The run hands the mission
  over through `Engine` meta `"mission"` (game.gd `_resolve` / `_after_mission`).
- `tests/run_tests.gd` headless tests. `tools/simulate.gd` balance simulator.

## Commands
- Tests (run before every push): `godot --headless --path . --script tests/run_tests.gd`
- Balance: `godot --headless --path . --script tools/simulate.gd`
- Skirmish balance: `godot --headless --path . --script tools/skirmish_sim.gd`
- Mission balance: `godot --headless --path . --script tools/mission_sim.gd -- 500`
  (`-- 300 focus` for just the 3 v 4 and 5 v 4 cases; prints tension: close %, coin-flip shots)
- Run -> mission -> run hook: `godot --headless --path . --script tools/mission_flow_check.gd`
- Tactical renders: `xvfb-run -a godot --path . --rendering-driver opengl3 res://scenes/tactical.tscn -- --capture-tactical`
  (`--capture-mission` for the Signal Box). Fresh clone: run `godot --headless --path . --import` first.
- UI screenshots: `xvfb-run -a godot --path . --rendering-driver opengl3 -- --shots`
- Portraits: `xvfb-run -a godot --path . --rendering-driver opengl3 res://scenes/render_test.tscn -- --portraits`
- Autoplay (watch a whole mission, ~6 min in the sandbox):
  `xvfb-run -a godot --path . --rendering-driver opengl3 res://scenes/tactical.tscn -- --autoplay [--loud] --out /tmp/autoplay`
  then `python3 tools/make_gif.py /tmp/autoplay docs/renders/autoplay_quiet.gif`. Exits 1 if it stalls.
  Run it after any change to the tactical scene and look at the frames before pushing.
- CI: `.github/workflows/tests.yml` parses every script and runs the tests + flow check on
  every push. Check the result with `gh run list -L 3` before calling a milestone done.
- Sprite bake: `xvfb-run -a godot --path . --rendering-driver opengl3 res://scenes/sprite_bake.tscn -- --out /tmp/bake`
  then `python3 tools/compose_sprites.py /tmp/bake docs/renders/sprites`
- In the cloud sandbox Godot isn't installed: download the 4.5-stable Linux zip
  from github.com/godotengine/godot/releases with curl (not `gh`).

## House rules
- **One Claude Code session per repo at a time.** On Nov 6 two sessions pushed to `main`
  at once and had to be untangled by hand. Work on a branch named for the milestone,
  `git fetch` before starting and before pushing, and merge at the end.
- Duff works phone-only (Godot Android editor). No desktop-only tools. GDScript only.
- **Push after every chunk of work and merge to `main` at the end of every
  milestone.** Unmerged side branches got lost once; never again.
- One milestone per session. Long sessions with many inline images crash the app.
- Save renders to `docs/renders/`, don't paste them all into chat.
- Visual decisions need real engine renders shown to Duff, not sketches.
- Tactical numbers Duff set: 2 HP (hit = 1), 4 tiles per AP (spec said 5).
- Android export (M6): add `*.dlg` to the export include filter or the dialogue won't ship.
