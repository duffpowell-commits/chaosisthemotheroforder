# Chaos Is the Mother of Order

> **PAUSED (Nov 7, Duff's call):** Lethemoor is the active game now (own repo). Don't start J2 here
> unless Duff says Chaos is back on. See `QUEUE.md`.

Grim Godot 4.5 strategy-RPG about organizing a revolution against a modern
police state. Owner: Duff. Read this first; it is the handoff between sessions.

## Where things stand
- Design: `docs/design.md` (pillars, "XCOM meets Advance Wars" combat feel, open questions).
- Look: `docs/style-guide.md` (palette, readability rules). Check renders against it.
- Current work: the vertical slice, `docs/slice-spec.md`. Progress: `tasks/todo.md`.
- `QUEUE.md`: this is the one active game; parked ideas (Lethemoor, Echo Company) live there. Don't build them here.
- Done: M1 rules + simulator, M2 map/planner/report, M3 dialogue runner + Teodor,
  M4 tactical core, **M5 Signal Box mission** (plan the op in week 2+ and it plays
  the mission; the result finishes the week), **J1 readability + web spike** (Nov 6),
  **J1.5 diversion tools** (Nov 7).
- **Jam target:** 2026 Jam on itch, submit by Dec 28. Plan, fixes and scope cuts:
  `docs/jam-slice-spec.md` (J1–J5; M6 becomes J2).
- J1 shipped: team rings + name/HP tags drawn in 2D above the grade (the grade drains
  3D colour to 7%, so team colour can't live in 3D), tags de-stack when units bunch,
  cool fresnel rim on units only (`shaders/unit_rim.gdshader`), grain/crush turned down
  on the tactical map (`grain_mul`/`crush_mul`), threat on tap (`Battle.threat`: move
  zone + his hit % on each of ours; tap away to dismiss), Shoot preview ("downs him /
  wounds him · +3 noise"; greyed Shoot says why), threat drawn in map red (not accent
  orange), bunched tags collapse to initial + hearts with a team-coloured leader line,
  and the camera follows the fight (`_frame_camera`: zooms in up to 0.66x but only if
  every nearby unit fits between the HUD bars, else home framing).
  **Web build works** in Chrome (Compatibility, no-threads template): `export_presets.cfg`.
- **J1.5 shipped (Nov 7):** smoke, lights out (junction box, west wall), fake radio
  call (You at the box), defector flashbang. Press a tool = preview (area, white outline
  on guards hit, noise, chance), then Confirm. Balanced to **Duff's target: the squad
  gets out 60-70% of runs** (Nov 7). One extra depot guard in the east yard
  (`EXTRA_GUARDS`, `GUARD_ROUTES[4]`): 3 v 4 quiet gets out 64%, airs 83%, close 83%.
  `--capture-tools` renders each tool (`docs/renders/tools_*.png`).
- Next: **J2 = M6** (endings, saves incl. mid-fight, Android pass).
- J1.5 review leftovers: tool results scroll out of the 2-line log (banner, J3); 5th guard
  always on vs only once a tool is used (Duff); defector still named "Guard N", ✦ unexplained.
- **End of every milestone:** run autoplay, the tension numbers, and an independent
  design review (fresh agent, pillars + style guide + renders). Jam spec §5b.
- Fallback art: `scripts/sprite_bake.gd` bakes rigs into 8-direction sprites;
  `tools/compose_sprites.py` makes review sheets (`docs/renders/sprites/`).
  Decision gate Dec 10.

## First thing next session
- **Web test build: https://chaos-mother-of-order.netlify.app** (Netlify site
  `chaos-mother-of-order`, id 3c710a52-dcc9-4f1a-9f24-003c3ad2c09c, live URL public,
  previews behind team login). Redeploy: export, add `build/web/netlify.toml`
  (`publish = "."`, empty command), then the Netlify connector's deploy-site with that
  site id gives an `npx @netlify/mcp` command to run in `build/web`. Netlify's free-tier
  badge covers part of End turn (theirs, injected; itch won't have it).
  Duff: open it on the phone. Does it load, and is it 30 fps?
  **Netlify credits ran out (Nov 7)**: the 4th deploy was "skipped due to account credit
  usage exceeded" (3 uploads of the 130 MB build used the free allowance). The live site
  has J1.5 but NOT the survival retune (5th guard still in the NE corner there). Don't
  redeploy to Netlify until the credits reset or Duff upgrades; shrink the build first
  (J5 item) and/or move testing to an itch draft page.
- Web build is 90 MB pck + 38 MB wasm. Shrink it before J5 (1K textures on the rigs and
  Polyhaven props, drop unused assets). Phones on data will hate 128 MB.
- J1 design review leftovers for Duff / J1.5: move range is blue and so are regime rings
  (style guide sets both; change move to teal/white?). Both sides are pale mannequins, so
  faction rests on the ring (darker regime body tint?). Nits: grain still visible on the
  floor, "ALARM: 3 more in 1" and the guard "?" are cryptic, no down/subdued marker on
  bodies, no render of the enemy turn mid-animation.
- **Difficulty target (Duff, Nov 7): survival 60-70%** = share of runs where someone gets
  out ("nobody out" 30-40% in `mission_sim`). Careful: "nobody out" is the inverse; a
  63% wipe rate was misread as the target once. Guard count settled by that target.
- Retarget fix (Nov 6): the silhouette fix is now ON for all four rigs. Without it
  every Mixamo clip bent the forearms inward (arms looked crossed). Side effect:
  portraits re-rendered with the head tipped slightly up. Ask Duff if they're OK.
- **Art direction (Duff, Nov 11): HD-2D.** Hand-made sprites in the 3D streets replace the
  mannequin rigs (they read as pale blobs under the grade; the baked pixel fallback was muddy,
  no faces). Keep the 3D world and street grade. Share the sprite pipeline with Lethemoor.
  Supersedes the old "fall back to pixel" call and the Dec 10 gate. Design only while paused.
- **Sprite size test (Nov 11):** Canva art of Duff at 64/96/128 px on the Signal Box map,
  1080p (`-- --capture-sprite-sizes`, run with `--resolution 1920x1080`; sources in
  `docs/renders/sprites/size_test/`). Renders: `sprite_size_overlay.png`, `sprite_size_world.png`,
  `sprite_size_closeup.png`. Findings: a body is ~110 px on screen at home zoom, ~165 zoomed;
  64 px = face is a smear; 96 reads; 128 is ~1:1 and pays off when the camera zooms. Under the
  street grade sprites go grey and get hidden by walls: draw them in 2D above the grade (like the
  rings) and handle wall occlusion. Known test bug: the in-world sprites sit ~0.4 m north of
  their ring. Canva's connector only returns a 200 px preview; get the full 1024x1536 file
  from Canva for real art.
- **Duff's call (Nov 11): 128 px sprites, cutout animation.** One Canva drawing per character
  per facing (front 3/4, back 3/4; mirror for the other two), cut into parts (head, torso,
  upper/lower arms, legs) and animated in Godot (Skeleton2D / Polygon2D or plain node
  transforms). No hand-drawn frame cycles. Draw above the grade; solve wall occlusion.
- **R1 cutout rig shipped (Nov 11):** You is a cutout now (`scripts/tactics/cutout_rig.gd`,
  art `assets/characters/duff_front.png`, 47x128 from the Canva preview). Body/arm/leg Polygon2D
  meshes skinned to a Skeleton2D; poses in code: idle, walk (while the 3D node moves), shoot
  (from `_flash`, faces the target; pistol is a code-drawn polygon because Canva's safety filter
  won't draw guns), hit (hp drops), down (stays). The 3D node stays for tweens/tags/rings; its
  meshes are hidden. Drawn in `rig_root` (grid layer, between rings and `top_overlay` tags).
  Occlusion: `_occluder_hulls` (FULL 2.5 m, BOX 2.2, HALF 0.95, tiles nearer the camera) clip
  the rig via `clip_children`; a team-colour silhouette rig shows only on those hulls (its clip
  parent must always draw something or Godot won't clip at all). `-- --capture-rig` renders
  poses + occlusion (`rig_poses.png`, `rig_behind_container.png`); autoplay passes
  (`autoplay_cutout.gif`). Other squad members and guards are still 3D mannequins.
  Design review fixes (same day): parts overlap one cell at the joints (no seams), downed body
  lies shrunk on its own tile, bigger pistol + 0.16 s flash, walk facing uses screen x, wall
  outlines built once per frame and filtered by screen rect, meshes cached per texture.
  Review leftovers: 3D mannequins nearer the camera don't hide the cutout (depth sort once all
  units are cutouts); "down" can't be undone (fine until revives exist); no shot tracer; bake
  meshes offline before using 1024 px art. Only the front 3/4 drawing exists (facing = flip);
  viewport is a 1280x720 canvas, so screen coords x1.5 at 1080p.
  **Next for the art (when Chaos is active):** back-3/4 drawing, cutouts for Mara/Kesh/Teodor
  and the guards (needs Canva art per character; full-res via a Canva design + export, which
  needs Duff's OK to save), seam fix.
- **Duff's calls (Nov 13, design review):** the **Ledger** (every shortcut becomes the new
  government's toolkit in the ending; visible stamps on the weekly report), the **helmet rule**
  (movement faces, regime visors, defectors unmask) and the **locked AI prompt templates**
  (sprites, portraits, woodcut). Written into `docs/design.md` ("The Ledger") and
  `docs/style-guide.md` (§6, §9). Docs only; build them in J2/J3 when Chaos unpauses.
  Review doc: https://claude.ai/artifact/RhQ9RR5c2SFYzpTxzVwFYM
- **Grok art merged (Nov 15)** from `art/rail-yards-slice`: sprites (A-pose fronts/backs + 128 px `display/`), cold/warm portraits, woodcut UI/stamps/icons, stills, endings, itch cover/banner. Notes + known issues: `docs/art-notes.md`. Review verdict: woodcut set and portraits are ship-quality; sprites usable as cutout sources but dark (test under the grade, movement red is only a bandana); painted stills/backdrops/endings are muddy and the weakest set (redo before use, except the kid's wall). Source masters are excluded from export.
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
  (`--capture-mission` for the Signal Box, `--capture-tools` for the four diversion tools). Fresh clone: run `godot --headless --path . --import` first.
- UI screenshots: `xvfb-run -a godot --path . --rendering-driver opengl3 -- --shots`
- Portraits: `xvfb-run -a godot --path . --rendering-driver opengl3 res://scenes/render_test.tscn -- --portraits`
- Autoplay (watch a whole mission, ~6 min in the sandbox):
  `xvfb-run -a godot --path . --rendering-driver opengl3 res://scenes/tactical.tscn -- --autoplay [--loud] --out /tmp/autoplay`
  then `python3 tools/make_gif.py /tmp/autoplay docs/renders/autoplay_quiet.gif`. Exits 1 if it stalls.
  Run it after any change to the tactical scene and look at the frames before pushing.
- Web export: `godot --headless --path . --export-release "Web" build/web/index.html`
  (templates: 4.5-stable `web_nothreads_release.zip` into
  `~/.local/share/godot/export_templates/4.5.stable/`). Local check: serve `build/web`
  and drive Chrome with playwright (`--use-angle=swiftshader`); see J1 notes in todo.md.
  Web gives Godot no system fonts: symbols come from `assets/fonts/symbols_dejavu.ttf`
  (autoload `scripts/fonts.gd`). Game files must not live in `docs/` (excluded from export).
- CI: `.github/workflows/tests.yml` parses every script and runs the tests + flow check on
  pushes to `main` and on PRs (not plain branch pushes or docs/*.md-only changes: saves Actions
  minutes, the repo is private). Open a PR to get CI on a branch. Check the result with `gh run list -L 3` before calling a milestone done.
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
- **Up to three milestones per session** (Duff's trial from Nov 6; it was one). Long
  sessions with many inline images crashed the app before, so: merge to `main` and
  update this handoff after EACH milestone (a crash then loses nothing), keep images
  in `docs/renders/` not chat, and stop early if the session gets sluggish.
- Save renders to `docs/renders/`, don't paste them all into chat.
- Visual decisions need real engine renders shown to Duff, not sketches.
- Tactical numbers Duff set: 2 HP (hit = 1), 4 tiles per AP (spec said 5).
- Android export (M6): add `*.dlg` to the export include filter or the dialogue won't ship.
