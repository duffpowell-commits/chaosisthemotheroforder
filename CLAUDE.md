# Chaos Is the Mother of Order

Grim Godot 4.5 strategy-RPG about organizing a revolution against a modern
police state. Owner: Duff. Read this first; it is the handoff between sessions.

## Where things stand
- Design: `docs/design.md` (locked decisions + open questions).
- Current work: the vertical slice, `docs/slice-spec.md`. Progress: `tasks/todo.md`.
- Done: M1 rules + simulator, M2 map/planner/report, M3 dialogue runner + Teodor,
  M4 tactical core, **M5 Signal Box mission** (plan the op in week 2+ and it plays
  the mission; the result finishes the week).
- **Jam target:** 2026 Jam on itch, submit by Dec 28. Plan, fixes and scope cuts:
  `docs/jam-slice-spec.md` (J1–J5; M6 becomes J2).
- Next: **J1** readability (unit rings, rim light, lighter grain on the tactical
  map) + web export spike (web needs the Compatibility renderer), then M6 as J2.
- Fallback art: `scripts/sprite_bake.gd` bakes rigs into 8-direction sprites;
  `tools/compose_sprites.py` makes review sheets (`docs/renders/sprites/`).
  Decision gate Dec 6.

## First thing next session
- Ask Duff how the Signal Box played on his phone, and whether 3 vs 4 guards
  should stay brutal (bot: aired 48% quiet, usually nobody gets home) or ease off.
  Numbers: `tasks/todo.md` M5 review.
- Saves: a mission isn't saved mid-fight. Quitting during it rewinds to the
  autosave from before the week was planned. Decide in M6 if that's OK.

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
- Run -> mission -> run hook: `godot --headless --path . --script tools/mission_flow_check.gd`
- Tactical renders: `xvfb-run -a godot --path . --rendering-driver opengl3 res://scenes/tactical.tscn -- --capture-tactical`
  (`--capture-mission` for the Signal Box). Fresh clone: run `godot --headless --path . --import` first.
- UI screenshots: `xvfb-run -a godot --path . --rendering-driver opengl3 -- --shots`
- Portraits: `xvfb-run -a godot --path . --rendering-driver opengl3 res://scenes/render_test.tscn -- --portraits`
- Sprite bake: `xvfb-run -a godot --path . --rendering-driver opengl3 res://scenes/sprite_bake.tscn -- --out /tmp/bake`
  then `python3 tools/compose_sprites.py /tmp/bake docs/renders/sprites`
- In the cloud sandbox Godot isn't installed: download the 4.5-stable Linux zip
  from github.com/godotengine/godot/releases with curl (not `gh`).

## House rules
- Duff works phone-only (Godot Android editor). No desktop-only tools. GDScript only.
- **Push after every chunk of work and merge to `main` at the end of every
  milestone.** Unmerged side branches got lost once; never again.
- One milestone per session. Long sessions with many inline images crash the app.
- Save renders to `docs/renders/`, don't paste them all into chat.
- Visual decisions need real engine renders shown to Duff, not sketches.
- Tactical numbers Duff set: 2 HP (hit = 1), 4 tiles per AP (spec said 5).
- Android export (M6): add `*.dlg` to the export include filter or the dialogue won't ship.
