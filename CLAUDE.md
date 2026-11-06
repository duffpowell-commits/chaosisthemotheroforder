# Chaos Is the Mother of Order

Grim Godot 4.5 strategy-RPG about organizing a revolution against a modern
police state. Owner: Duff. Read this first; it is the handoff between sessions.

## Where things stand
- Design: `docs/design.md` (locked decisions + open questions).
- Current work: the vertical slice, `docs/slice-spec.md`. Progress: `tasks/todo.md`.
- Done: M1 rules + simulator, M2 map/planner/report, M3 dialogue runner + Teodor,
  M4 tactical core (skirmish from the title's Skirmish button).
- Next: **M5 Signal Box mission** (noise, Sneak/Subdue/Overwatch/Interact, Persuade +
  defection, broadcast, reinforcements, permadeath) feeding results back into the run.

## Layout
- `scripts/sim/` pure game rules (`RunState`, `Rules`, `Policies`). No scenes.
- `scripts/dialogue/` dialogue runner (`dialogue.gd`, format in its header) and
  `story.gd` (which scene plays when). Scripts live in `dialogue/*.dlg`.
- `scripts/ui/game.gd` the playable slice UI, built in code. `text.gd` player text.
- `scripts/render_test.gd` the Rail Yards street (`-- --capture`, `--portraits`).
- `scripts/tactics/battle.gd` pure tactical rules + AI. `tactical.gd` the scene
  (extends render_test.gd; 2D grid overlay so the grade doesn't grey it out).
- `tests/run_tests.gd` headless tests. `tools/simulate.gd` balance simulator.

## Commands
- Tests (run before every push): `godot --headless --path . --script tests/run_tests.gd`
- Balance: `godot --headless --path . --script tools/simulate.gd`
- Skirmish balance: `godot --headless --path . --script tools/skirmish_sim.gd`
- Tactical renders: `xvfb-run -a godot --path . --rendering-driver opengl3 res://scenes/tactical.tscn -- --capture-tactical`
- UI screenshots: `xvfb-run -a godot --path . --rendering-driver opengl3 -- --shots`
- Portraits: `xvfb-run -a godot --path . --rendering-driver opengl3 res://scenes/render_test.tscn -- --portraits`
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
