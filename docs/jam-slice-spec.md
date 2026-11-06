# Jam Slice Spec: "The Rail Yards" for the 2026 Jam

> Ship the vertical slice (`docs/slice-spec.md`) as a jam entry by the end
> of the year. Same game, smaller promises, playable in a phone browser.

## 1. The target

- **Jam:** "2026 Jam" on itch.io (itch.io/jam/2026-jam). Rule: the game is
  made during 2026. This repo started November 2026, so it qualifies.
- **Deadline:** submissions close Dec 31, 2026. **Our deadline is Dec 28.**
  The last three days are buffer, not build time.
- **What ships:** one full run of the Rail Yards. Six weeks, Teodor, the
  diversion, the Signal Box mission, five endings. 30–45 minutes.
- **Where it runs:** in the browser on itch (the main build), plus an
  Android APK download as a backup.

## 2. Done means

1. A stranger can finish a run on a phone browser with no help.
2. The tactical map reads at a glance: whose unit is whose, where cover is,
   what a tap will do.
3. All five endings are reachable. No soft-locks in 5 full runs.
4. 30 fps or better on Duff's phone, in the browser and the APK.
5. The itch page is up: screenshots, a GIF, controls, a content warning and
   the AI disclosure.

## 3. Fixes (the look and the risks)

### 3.1 Faces: design around them, don't fight them
- **Camera stays high and pulled back** on the tactical map. At that
  distance a unit is a silhouette, a pose and a color. Nobody reads faces.
- **Faceless gear is the style.** The regime wears helmets and visors. The
  movement wears bandanas, caps and respirators. Simple meshes on the head
  bone, the same way `scripts/sprite_bake.gd` already does it. No custom
  faces, no new character models.
- **Faces live in the portraits.** Teodor, Mara and Kesh get their
  personality from dialogue portraits and writing. The 3D bodies only have
  to move well.

### 3.2 Tactical readability (seen in `docs/renders/mission_start.png`)
- **Units hiding under the HUD:** fixed in M5 (camera reframed, actions
  moved to a right-hand column).
- **Units are tiny and dark.** Guards are hard to pick out from crates and
  barrels. Fix: a colored ring under every unit (red for
  the movement, cold blue for the regime) and a light rim light on units
  only.
- **The grade eats the board.** Keep the Frontline grade, but turn the grain
  and crush down on the tactical map so the grid and cover stay readable.
- **Units glide.** Use the Mixamo clips already in `assets/animations`:
  walk while moving, `rifle_aim` to shoot, `death_front` when downed, plus a
  simple rifle prop on the hand bone.

### 3.3 The web build (the biggest technical risk)
- Godot's web export only runs the **Compatibility** renderer. The project
  uses **Mobile**. Test the web build in week 1, not week 7.
- Good sign: every render so far runs on the OpenGL (Compatibility) driver,
  so the Frontline grade shader already works there.
- Keep the download small: compress the Polyhaven textures, and drop any
  asset the slice doesn't show.
- Add `*.dlg` to the export include filter, or the dialogue won't ship.

### 3.4 Fallback: baked sprites, if 3D drags
- **The pipeline exists.** `scripts/sprite_bake.gd` renders each rigged
  character from 8 directions with any Mixamo clip, and
  `tools/compose_sprites.py` turns the frames into sheets and GIFs. Review
  shots: `docs/renders/sprites/`.
- **Two looks to pick from:** smooth pre-rendered (late-90s isometric) or
  hard-edged pixel (28 colors with an outline).
- **The street stays 3D.** Only the units become flat sprites that face the
  camera.
- **Decision gate: Dec 6.** Switch the units to sprites if either is true:
  - animated 3D units still look wrong after the animation pass, or
  - the tactical map runs under 30 fps on Duff's phone.

## 4. Scope cuts for the jam

M5 shipped the whole Signal Box mission (noise, Sneak, Subdue, Overwatch,
upload, Persuade and defection, reinforcements, permadeath). Nothing there
gets cut. Open question from M5: is 3–4 guards too brutal? The bot airs the
footage 48% of the time playing quiet, and usually nobody gets home. Duff
plays it and decides in J1.

Cut or simplify:
- **The Raid** at Heat 7: stays a scripted arrest (the spec's own fallback).
- **Radio jammer, facing rules, ironman mode:** cut. Autosave stays.
- **Dramatic camera swoops:** cut. A short pan to the acting unit is enough.
- **Mid-mission saves:** none. Quitting mid-fight rewinds to the week's autosave.

Rule for the whole schedule: **if a milestone runs over, cut features, not
quality.**

## 5. Schedule

One milestone per session (house rule). Each ends merged to `main` with
renders in `docs/renders/`.

| Dates | Milestone | Done when |
|---|---|---|
| Done | M5 Signal Box mission | Mission outcomes feed back into the run |
| Nov 9–15 | **J1: readability + web spike** | §3.2 fixes in; a web build runs in Duff's phone browser; guard count decided |
| Nov 16–29 | **J2: endings, saves, Android pass** (M6) | Five endings reachable; 5 clean runs on the phone |
| Nov 30–Dec 6 | **J3: animation pass + fallback gate** | Units walk, aim and fall; the Dec 6 call is made |
| Dec 7–20 | **J4: playtests + polish** | 2 outside playtesters finish a run; their worst problems fixed |
| Dec 21–27 | **J5: itch page + upload** | Page live as a draft; build tested from itch on the phone |
| Dec 28 | **Submit** | Entry shows on the jam page |

## 6. The itch page

- Title, a one-line hook, 4–5 screenshots, one GIF of a tactical turn.
- Controls (tap unit, tap tile, buttons), and expected run length.
- **Content warning:** political violence, police brutality, death (the
  game is Rated M by design).
- **AI disclosure:** fill in itch's generative-AI field. Code and writing
  are made with Claude. Characters are MakeHuman (CC0), animations are
  Mixamo, environment assets are Polyhaven (CC0).
- Credits for every outside asset.
