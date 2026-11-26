@AGENTS.md

# Chaos Is the Mother of Order

> **ACTIVE again (Nov 25, Duff: "lets get all six in order"):** working the 7-item standards list
> (APK, guardrails, 3D cast, phone UI, QoL, sound/feel, perf/size). Duff wants it step by step:
> one step, then his OK on a card, before the next.

Grim Godot 4.7.2 strategy-RPG about organizing a revolution against a modern
police state. Owner: Duff. Read this first; it is the handoff between sessions.
Commands, standing rules and guards (push guard, fresh-eyes, rule lock): AGENTS.md (imported above).

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
- **Nov 25: real 3D cast** (standards audit item 3; Duff: "lets get all six in order"): Meshy models
  on one shared 24-bone skeleton replace the mannequins and the HD-2D cutouts in the fight
  (`USE_CUTOUTS := false` in tactical.gd; the cutout code stays). You = a new Chaos Duff in revolution gear
  (olive work jacket, red armband; Duff's pick Nov 25) from his upload via Meshy image edits, hands painted
  from the DuffQuest masters (project files chaos-art/duff-new/, README there; 67 credits); Mara, Kesh, Teodor made from Grok's A-pose fronts/backs; the guard is
  the old CPU model re-textured from guard_front.png. 9 shared clips (idle, walk, run, shoot, hit,
  death, crouch_walk, injured_walk, sneak) in `assets/characters/meshy/clips/*.res`, made by
  `tools/extract_meshy_clips.gd` from GLBs kept in project files `chaos-art/meshy/clips_src/`.
  `_meshy_person` (render_test.gd) builds a body; `_update_bodies` (tactical.gd) picks its clip.
  Readability: matte materials + slight glow, a warm side key light on units only (`UNIT_LAYER`,
  `UNIT_KEY`, `UNIT_KEY_YAW`), tactical grade keeps 60% colour (`GRADE_SAT`), tile fills thin under bodies,
  camera frames the selected unit + allies within 3 + guards within 4 (`FRAME_*_RANGE`, zoom to 0.5x). Spent 166 Meshy
  credits (balance 2,113). Renders: `docs/renders/cast/`. The street scene still uses MakeHuman crowds.
- **Nov 25: phone-first UI** (standards item 4): title opens on **Fight now** (straight into the Signal
  Box, `_fight_now` in game.gd), buttons 72 px / text >= 20 px (`MIN_TEXT`), HUD buttons 64 px and wrap,
  first-move coach hint "Tap a blue tile" (`_build_coach`, seen flag in `user://coach.cfg`).
  Action picker is a **ledger page** (Duff picked "All six"): woodcut icon per action (128 px `icons/display/`),
  effect chips from `Text.ACTION_CARDS` (green good, red heat + flame, cost tag by the title), red
  "WEEK N · ORDERS" stamp, RISK / PLANNED / NO CASH stamps, Teodor beats as a full-width card with his face,
  Cancel in the header, "more below" hint when a late week scrolls. Then **desk dossier** (Duff's pick): dark desk +
  torn stained sheet, index cards (manila for Teodor) tilted up to 2° with paper clips, icons cut round
  (`shaders/ui_round_icon`), inked stamps (`shaders/ui_ink_stamp`); textures made free by `tools/gen_dossier.py`
  into `assets/ui/dossier/`. "More stylish" pass: label-maker tape chips, case-file header (operative photo
  taped on, typed file line, CONFIDENTIAL), clips / masking tape / staples by action, Teodor as a taped photo. Typewriter font Special Elite (Apache 2.0,
  `assets/fonts/`). `_pick_action` / `_action_tile` / `_chip` / `_stamp` / `_ledger_box` in game.gd.
  **Dossier look everywhere** (Duff's pick after the IGN review): district = zone cards + Teodor tag left,
  assignments + surveillance street photo right; report = Continuity News 24 TV woodcut + Unbroken Radio phone
  woodcut (`_framed`); dialogue = painted portrait polaroid (`_portrait_for`: warm/cold by liberation, mood by
  heat/Teodor state) + transcript card with the last lines faded; title/ending use `_ink_button`. Helpers:
  `_page`, `_typed`, `_paper_panel`, `_paper_button`, `_ink_button`, `_street_photo`.
  Then **graffiti + worn** (Duff: "too boring", "more worn ... often carried"): Forge graffiti wall
  (`assets/ui/dossier/wall.png`, Foxboard job `chaos-graffiti-wall-20261125` take 0) behind a crooked stack of 3 sheets
  (`_wall_and_sheets`); `gen_dossier.py` wear pass: folds, creases, dog-ears, thumb grime; cards tilt up to 3.5° and scatter.
- **Nov 25: QoL** (standards item 5, step by step with Duff's OK). Step 1: phone lifecycle. Leaving the app
  saves the run + the half-made plan (`user://plan.save`, kept only for its week; `_save_plan` / `_load_plan`);
  back closes the picker, then leaves to the title, then quits (`quit_on_go_back=false`, `_go_back`). The fight
  pauses behind a menu on back / focus-out (`_set_paused` in tactical.gd).
  Check: `tools/qol_check.gd` -> `QOL PASS` (in CI). Render `docs/renders/ui/7_paused.png`.
  Step 2: **settings** (`scripts/settings.gd` autoload, `user://settings.cfg`; `scripts/ui/settings_sheet.gd`, a manila
  card from the title's SETTINGS button and the fight's pause menu): music + SFX (buses in `default_bus_layout.tres`,
  ready for item 6), brightness (gamma pass), TEXT SIZE NORMAL/LARGE/HUGE (`_fs` in game.gd / render_test.gd scales
  `_label`, `_button`, HUD labels; the top bar stays fixed), GRAPHICS LOW (`apply_graphics`: no shadows/glow/probe,
  rain 500, 3D at 75%). Scripts reach Settings through the root node (`--script` runs don't register autoload names).
  Renders `docs/renders/ui/8_settings.png`, `9_district_huge_text.png`, `8b_pick_huge_text.png` (action cards grow + chips wrap at HUGE).
  Back closes the top sheet first (`SettingsSheet.close_open`); settings.cfg values are type-checked and clamped on load.
  Step 3: **REPORT A BUG** (`scripts/ui/bug_report.gd`, from the settings sheet, so from the title and the fight's pause
  menu): a typed note, then SEND (prefilled GitHub issue, label bug) or COPY (clipboard). The report adds version, build,
  phone, screen, fps, settings and the scene's `bug_state()` (game.gd: screen/week/heat/cash...; tactical.gd: turn, side,
  noise, upload, every unit's hp + tile). Render `docs/renders/ui/10_bug_report.png`. The version shows on the title, the
  settings card and the bug card.
  Step 4: **mid-fight save** (`scripts/fight_save.gd`, `user://fight.save`, store_var): a run's Signal Box fight saves as it
  starts, at the start of each of your turns, on focus-out (immediately, not deferred), on pause and on "Save and quit to
  title". `Battle.to_dict/from_dict` copy every script var + the RNG seed/state, so the regime plays on identically (rule test
  `test_mission_save_round_trip`). The title shows CONTINUE FIGHT; `_continue_run` resumes when the save matches the run's
  seed + week (stale ones are deleted). `_return_to_run` (run fights only) and New run clear it. Fight now is never saved. The pause menu also has "Quit and replan the
  week" (Duff's pick Nov 26, `_replan_week`): drops the fight save, so Continue replays the week from planning; render `12_pause_replan.png`. Renders
  `11_title_continue_fight.png`, `11_fight_resumed.png`. QoL (item 5) is done; next is item 6 (sound/feel).
- **Nov 26: sound, step 1** (standards item 6, Duff: "Start sound"): real CC0 recordings (OpenGameArt; logged in
  `assets/audio/SOURCES.md`, a rule test checks every .ogg has a row) cut and levelled by `tools/real_audio.py`
  (ffmpeg + numpy; loudness per clip in its `LOUD` table, yard slap baked in because web has no bus effects).
  Autoload `Audio` (`scripts/audio.gd`): `Sfx.fx/music/bed` static helpers (preload it; `--script` runs don't
  register autoload names), takes `name_0..N` picked at random, every BaseButton clicks on press. Fight: cold music +
  rain bed, pistol (ours) / rifle (theirs), grunt on a hit, boots per tile (quieter sneaking, theirs on their turn),
  alarm once when it trips, smoke/flash/lights/radio/upload, typewriter key on End turn. Desk: EmptyCity bed,
  paper on each new screen. Check: `tools/sound_check.gd` -> `SOUND PASS` (in CI). Merged PR #23.
- **Nov 26: feel, step 2** (item 6, Duff: "Ship + do step 2"): `scripts/tactics/feel.gd` (tactical.gd's `feel`): camera
  shake (trauma² on `cam.h_offset/v_offset`, so it never fights the framing tweens), hit-stop (`Engine.time_scale` 0.05
  for 60 ms, 140 ms when someone goes down; real-time timer, reset on exit), phone buzz (`Input.vibrate_handheld`),
  muzzle smoke (CPUParticles3D), flashbang white-out, lights-out dip to black, three red edge beats when the alarm trips
  (canvas layer 2, under the HUD, ~2 beats a second). Losing one of ours lands hardest. Settings: SHAKE (shake + screen flashes) and BUZZ,
  both on by default. Checked in `tools/sound_check.gd`. Renders `docs/renders/feel/` (effects shown at peak: the
  sandbox runs ~600 ms a frame, so a timed capture misses them). Merged PR #24; item 6 done.
- **Nov 26: perf/size, step 1** (item 7, Duff: "Ship + start item 7"): the dev APK was 242 MB, 205 MB of it textures
  imported lossless. `tools/texture_policy.py` sets lossy WebP by folder (body maps capped 1024 px; Duff's colour map
  keeps 2048 for the tattoos); CI runs `--check` and a rule test fails on a lossless body/portrait/UI texture. Unused art
  is out of both exports (assets/art, full-size woodcut icons, posters/stamps, 2D cutout sprites except the `display/`
  ones the code loads, painted backdrops). Shipped assets ~40 MB (est. APK ~70 MB). Before/after: `docs/renders/perf/`
  (no visible change). Settings got FPS (counter top-left, green 55+, amber 30+, red under). **New art: run
  `python3 tools/texture_policy.py` before committing**; new folders need a POLICY row. The export excludes `civilian_*`, `operative_*`, `kesh/*`, `teodor/*` whole, `display/` copies too (nothing loads them yet): a new cutout for one of them must narrow that pattern or it won't ship.
- **Nov 26: web size + play stats, step 2** (item 7, Duff: "Ship + do step 2"): the web build was 90 MB pck + 38 MB wasm;
  now 43 MB pck + 39.5 MB wasm (~51 MB gzipped on the wire). The animation sources (`assets/characters/meshy/clips_src/`,
  15 MB) are out of both exports; the game only loads the extracted `clips/*.res`. Renders of the web build in headless
  Chromium: `docs/renders/perf/web_title.png`, `web_fight.png` (cast poses fine). **Play stats**: autoload `Stats`
  (`scripts/stats.gd`, from the starter's Telemetry): `user://events.jsonl` (last 500) logs session_start, run_start,
  week_done, fight_start/fight_end (aired, got out, dead, turns, noise), run_end (ending), crash_suspected, and `left`
  with the screen the player was on (where people quit). Nothing leaves the phone (no collector yet); the summary rides
  on REPORT A BUG (`stats:` line). Call `PlayStats.log_event` (preload; `--script` runs don't register autoload names).
  Checked in `tools/qol_check.gd` and rule test `test_play_stats_summary`.
- **Nov 26: loud-play fix** (mock IGN: the loud Signal Box route aired ~1%; Duff: "Ship + do the loud-play fix"). The sim
  showed 3 v 4 loud is a squad-size wall (3 operatives vs 5 guards, all down by turn 4): range falloff, slower or smaller
  reinforcements barely moved it and pushed quiet survival to ~89%. Built: **caught off guard** (`Battle.CAUGHT_OFF_GUARD`):
  your opening shot startles every patrolling guard (`Unit.startled`); each spends his next regime turn diving for cover
  (`_dive_for_cover`), no return fire. Subdues, shouts and other noise don't count. Shoot button warns in red when a shot goes
  loud and you're outnumbered ("GOES LOUD · 3 vs 5", `Battle.goes_loud`). Sim (300 runs): quiet 3 v 4 nobody out 34%
  (survival 66%, in Duff's 60-70%), loud 5 v 4 airs 60% (was 49%), loud 3 v 4 still ~0% (warned). Rule test
  `test_opening_shot_catches_guards_off_guard`. Render `docs/renders/loud/1_goes_loud_warning.png`.
- **Nov 25: phone APK** (standards audit item 1, Duff tapped "1 + 2 now"): Android preset, CI
  `.github/workflows/build.yml` (replaces tests.yml) builds a signed APK on every PR and push to main;
  on main `chaosisthemotheroforder.apk` + `version.json` go to Releases -> `dev`. In-app updates
  (`scripts/updater.gd` autoload, never offers during the Tactical scene), version on the title
  (`scripts/config.gd`). Signing: the keystone via `signing/unlock.sh` (fetched from the starter);
  until Duff adds the `KEYSTONE_PASS` secret here, CI signs with a throwaway key and warns.
  Off-phone updater check render: `docs/renders/updater_offer.png`.
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
- QoL (pause, back, saves): `godot --headless --path . --script tools/qol_check.gd` -> `QOL PASS`
- Sound (each event plays its clip): `godot --headless --path . --script tools/sound_check.gd` -> `SOUND PASS`
  Rebuild the clips: `python3 tools/real_audio.py` (downloads CC0 sources to `~/.cache/chaos_audio`).
- Tactical renders: `xvfb-run -a godot --path . --rendering-driver opengl3 res://scenes/tactical.tscn -- --capture-tactical`
  (`--capture-mission` for the Signal Box, `--capture-tools` for the four diversion tools). Fresh clone: run `godot --headless --path . --import` first.
- UI screenshots: `xvfb-run -a godot --path . --rendering-driver opengl3 -- --shots`
- Portraits: `xvfb-run -a godot --path . --rendering-driver opengl3 res://scenes/render_test.tscn -- --portraits`
- Autoplay (watch a whole mission, ~6 min in the sandbox):
  `xvfb-run -a godot --path . --rendering-driver opengl3 res://scenes/tactical.tscn -- --autoplay [--loud] --out /tmp/autoplay`
  then `python3 tools/make_gif.py /tmp/autoplay docs/renders/autoplay_quiet.gif`. Exits 1 if it stalls.
  Run it after any change to the tactical scene and look at the frames before pushing.
- Web export: `godot --headless --path . --export-release "Web" build/web/index.html`
  (templates: 4.7.2-stable `web_nothreads_release.zip` into
  `~/.local/share/godot/export_templates/4.7.2.stable/`). Local check: serve `build/web`
  and drive Chrome with playwright (`--use-angle=swiftshader`); see J1 notes in todo.md.
  Web gives Godot no system fonts: symbols come from `assets/fonts/symbols_dejavu.ttf`
  (autoload `scripts/fonts.gd`). Game files must not live in `docs/` (excluded from export).
- CI: `.github/workflows/build.yml` parses every script, runs the tests + flow check and builds
  the Android APK on pushes to `main` and on PRs (not plain branch pushes or docs/*.md-only changes:
  saves Actions minutes, the repo is private). Main publishes the APK to the `dev` release. Open a PR to get CI on a branch. Check the result with `gh run list -L 3` before calling a milestone done.
- Sprite bake: `xvfb-run -a godot --path . --rendering-driver opengl3 res://scenes/sprite_bake.tscn -- --out /tmp/bake`
  then `python3 tools/compose_sprites.py /tmp/bake docs/renders/sprites`
- In the cloud sandbox Godot isn't installed: download the 4.7.2-stable Linux zip
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
- Android signing (M6): use the keystone, the shared key for every Duff game except Lethemoor. Copy
  `signing/unlock.sh` + the signing step from godot-game-starter's build.yml; add the `KEYSTONE_PASS` secret
  (godot-game-starter docs/SIGNING.md). Never make a new key, never use Lethemoor's.
