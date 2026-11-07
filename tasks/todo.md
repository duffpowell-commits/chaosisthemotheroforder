# TODO

## Phase 0 — Lock the vision (no code)
- [x] Core concept, tone, setting, engine, license
- [x] Systems outline (resources, districts, propaganda, combat, acts)
- [x] Style board 01 (canvas mockups): rejected as too childish; A grade + D propaganda kept
- [x] Real Godot render test: Rail Yards street, regime vs liberated (docs/renders)
- [ ] Dialogue samples: short exchange, speech with topic choices, regime broadcast
- [ ] Pick / mix a visual direction and a dialogue voice
- [x] Visual references, music direction, platforms
- [ ] Answer the remaining open questions in docs/design.md
- [ ] Name the country, city, and regime

## Phase 1 — Vertical slice spec
- [x] Spec written: docs/slice-spec.md
- [x] Open questions: defaults accepted (set A names, 6 weeks, Voice-check confession, custom dialogue runner)

## Phase 2 — Build the vertical slice (milestones from docs/slice-spec.md §13)
- [x] M1 Run state + week loop, headless simulator + unit tests (12 tests; balance tuned)
- [x] M2 District map, week planner, weekly report (playable 6-week run; autosave + continue)
- [x] M3 Dialogue runner + Teodor's three paths (20 tests; portraits rendered)
- [x] M4 Tactical core: grid, AP, move, cover, shoot, basic AI (28 tests; dumb-policy skirmish 58% won)
  Done when: a skirmish on the street map is winnable and losable.
  Plan (same split as M1/M2: pure rules first, scene second):
  - [x] `scripts/tactics/battle.gd`: pure data. 14x14 grid, tiles (floor,
        half cover, full cover, high ground), units (side, pos, AP, HP).
  - [x] Rules: 2 AP/unit, 2 HP (hit = 1, Duff's call), Move 1 AP = 4 tiles (Duff's call; spec said 5) (BFS, blocked by cover/units),
        Shoot 1 AP, hit 65% / half -20 / full -40 / high +10 / flank +20,
        clamp 5-95. Cover read per direction; flanked = no cover from that side.
  - [x] Line of sight: grid raycast, full cover blocks, half doesn't.
  - [x] AI: patrol fixed route -> alerted (sees you / you shoot) -> move to
        best covered tile in range and shoot -> retreat at 1 HP when not outnumbering you
        (always-retreat: 76% dumb-policy wins; never: 29%; this: 58%).
  - [x] Skirmish layout from the Rail Yards street: containers = full,
        crates = half, gantry = high ground. 3 of ours vs 4 guards.
  - [x] Tests: hit-chance table, LOS, BFS move range, flank, AI states,
        seeded skirmish deterministic.
  - [x] `tools/skirmish_sim.gd`: 500 seeded skirmishes, dumb player policy.
        Pass = both wins and losses occur (target win rate 35-65%).
  - [x] Scene: 3D street + grid overlay, tap unit / tap tile, Shoot button
        shows hit %, AP pips, end turn. Touch targets >= 48 px.
  - [x] Renders to `docs/renders/tactical_*.png`; Duff judges them.
  - [x] Merge to main, update CLAUDE.md handoff.
  Deferred to M5 (spec §9): Sneak, Subdue, Overwatch, Interact, Persuade,
  noise meter, reinforcements, stabilize/permadeath.
- [x] M5 Signal Box mission: noise, Persuade/defection, broadcast (43 tests; flow check passes)
  Done when: mission outcomes feed back into the run.
  - [x] Pre-fix from the M4 renders: bottom HUD covered the squad's start row.
        Camera reframed; actions moved to a right-hand column.
  - [x] `battle.gd` mission mode (skirmish untouched, still 58% won): signal box
        tile, noise 0-10 (Shoot +3, Subdue +1, a guard's shout +2; noise wakes
        patrols within 3 tiles per point), alarm at 10 -> 3 reinforcements from
        the north 2 turns later.
  - [x] Sneak, Subdue, Overwatch, Upload (2 separate turns), Stabilize, Leave,
        Persuade (You only, Wavering guard within 3: 40% + 10% x Legitimacy).
  - [x] Permadeath: downed squadmate dies after 2 of your turns unless
        stabilized; left behind = dead, carried out = 2 weeks out.
  - [x] `Rules`: begin_resolve / finish_resolve, mission_params, apply_mission.
        No result = old auto-resolve (run simulator unchanged but for 1 run in
        1000, from the new 8-guard cap).
  - [x] Scene: noise/upload/alarm meter, action column, Wavering tag, green exit row.
  - [x] Run hook: a planned Signal Box op plays the mission, then the week resolves.
  - [x] Tests + `tools/mission_sim.gd` + `tools/mission_flow_check.gd`.
  - [x] Renders `docs/renders/mission_*.png`; merge; CLAUDE.md handoff.
- [ ] M6 Endings, saves, Android pass (5 clean runs on Duff's phone)

## Phase 3 — Jam entry: 2026 Jam on itch, submit by Dec 28 (docs/jam-slice-spec.md)
- [x] Jam spec written, scope cuts set, fixes listed
- [x] Fallback sprite pipeline: scripts/sprite_bake.gd + tools/compose_sprites.py
      (review shots in docs/renders/sprites/; Duff picks a look if we fall back)
- [x] J1 readability fixes + web export spike (runs in Chrome; phone test waits on hosting); guard count call still open
- [x] J1.5 diversion tools: smoke, lights out, radio call, defector flashbang
      (docs/diversion-tools-spec.md), rebalanced to the same difficulty
- [ ] J2 (Nov 23–Dec 3) endings, saves incl. mid-fight, Android pass (= M6)
- [ ] J3 (Dec 4–10) animation pass; Dec 10 gate: 3D units or baked sprites
- [ ] J4 (Dec 11–20) outside playtests + polish
- [ ] J5 (Dec 21–27) itch page + upload; submit Dec 28

## Review
- **J1.5 (Nov 7):** all four tools in `battle.gd` (constants at the top), 4 new tests
  (50 total). Two-step use in the scene: press the tool to preview (area, white outline
  on every guard it hits, noise, chance), then Confirm; Smoke and Flash take a target
  tap in between. Smoke draws as grey puffs; lights out tints the north yard and kills
  the north lamps; guards get "stunned", "on a fake call", "watching" tags; the junction
  box is labelled on the map until used; a defector with a flashbang shows ✦.
  Renders: `docs/renders/tools_*.png`, `autoplay_tools.gif`.
  Smoke rule, clarified: no spotting into/out of/through; shots through it blocked;
  a unit on the cloud's edge is hit at -30.
  Balance (300 runs, quiet bot, focus):
  | | aired | nobody out | close | flips |
  |---|---|---|---|---|
  | 3 v 4 before tools | 45% | 65% | 56% | 4.6 |
  | 3 v 4 tools, no fix | 81% | 22% | 81% | 5.1 |
  | 3 v 4 + knob 1 (no freeze) | 81% | 23% | 81% | 2.8 |
  | 3 v 4 + 5th guard on entry row | 17% | 96% | 22% | 5.2 |
  | 3 v 4 + 5th guard by the box, freeze 1 (**shipped**) | 40% | 63% | 40% | 2.8 |
  | 5 v 4 shipped | 97% | 5% | 100% | 7.2 |
  Knobs moved: `EXTRA_GUARDS := 1`, `GUARD_ROUTES[4]` is now the NE corner by the box.
  `BROADCAST_STUN` and `DARK_TURNS` back at 1 and 3 (neither moved the numbers).
  The bot uses smoke and lights constantly, radio and flash rarely (radio needs You
  at the box before any alarm; flash needs a defector plus 2 bunched guards), so
  `--capture-tools` shows those two. Known bot flaw kept on purpose (it's the yardstick
  the target was set with): it opens fire whenever an alert guard has a line on it,
  even in the dark where that guard can't see it. A human won't. Loud play got much
  harder: 5 v 4 loud aired 92% -> 53%. Fits "diversion, not firefights", but flag it.
- **J1 (Nov 6):** team rings (red = movement, cold blue = regime, yellow = Wavering) and
  name/HP tags moved into the 2D overlay, because the Frontline grade keeps 7% of 3D
  colour on the tactical map. Tags are fixed-size and de-stack (nearest unit keeps its
  spot, others slide up, or down against the top bar, with a leader line); test
  `test_tactical_tags_never_overlap`. Fresnel rim on units only. Grain x0.35, contrast
  and vignette x0.45 on the tactical map. Threat on tap: `Battle.threat(g)` mirrors the
  guard AI (move 2 AP, or move 1 AP + shoot at 15%+); the overlay shows his move zone,
  a faint shoot zone, and his hit % on each of ours. Guards have no range limit, so the
  shoot zone covers most of the yard; the per-unit % carries the info. Shot preview:
  "Shoot 85% / wounds him · +3 noise". Camera fov 52 -> 55 so the start row clears the HUD.
  Independent review (fresh agent) found 3 blockers, all fixed: tag ladders didn't
  point at their units (now collapse + team-coloured leader line), threat was accent
  orange (now map red), and the fight drifted into the top 15% of the screen (camera
  follow with a fit check). Also: greyed Shoot says why. Logged for later: blue move
  range vs blue regime rings, same mannequin bodies both sides, text nits.
  Web spike: exports and runs in Chrome (WebGL 2, Compatibility, single-threaded). Found
  and fixed 3 web-only bugs: backdrops loaded from `docs/` (now `assets/ui/`),
  `tools/mission_sim.gd` excluded but preloaded by tactical.gd, and ♥ ● ◎ rendering as
  boxes (no system fonts in a browser; DejaVu subset fallback). Size: 90 MB pck + 38 MB
  wasm, too big for phones on data; shrink before J5. Rules unchanged, tension the same:
  3 v 4 quiet close 56%, 4.6 flips; 5 v 4 quiet close 98% (too easy, J1.5 rebalance).
- **Signal Box tuning (Nov 6, Duff: "slightly less brutal"):** the deaths came on
  the run home, after the broadcast alerts every guard, not from being spotted
  (sight range, bleed time and reinforcement size changed nothing). New rule:
  the broadcast freezes the guards for one regime turn (`BROADCAST_STUN`).
  3 v 4 quiet: nobody out 75% -> 65%, our dead 2.22 -> 1.99, aired 45% (same).
  A 2-turn freeze gave 56% / 1.81; kept at 1 for "slightly".
  Duff confirmed: the fight carries on when You go down (it already did).
  Tension metrics added to `tools/mission_sim.gd` (close %, coin-flip shots).
- **M5 (Nov 6):** the Signal Box is a played mission now. Planning the op sends
  you plus everyone free that week into the depot; the result (aired, kills,
  defections, dead, hurt) comes back and finishes the week. Departures from the
  spec, all in the spirit of it: a spotting guard shouts (+2 noise, wakes guards
  near him) instead of alerting the whole map, airing the footage alerts every
  guard but doesn't sound the alarm, and the quiet/loud plan choice is gone
  because you choose that in the mission. Balance (simple bot, 500 runs,
  Legitimacy 1): squad of 3 vs 4 guards airs it 48% quiet / 9% loud and usually
  nobody gets home; squad of 5 vs 4 airs it 96% / 92%. Recruiting and the
  diversion decide it. A human should beat the bot. Open: is 3 vs 4 too harsh?
  The M4 HUD bug is fixed and the M4 renders are re-shot.
- **M4 (Nov 6):** pure rules in `scripts/tactics/battle.gd` (grid, LOS, per-side
  cover, flanking, high ground, 2 AP / 2 HP, 4 tiles per AP) with a guard AI
  (patrol -> alert -> best covered tile + shoot -> retreat at 1 HP when not
  outnumbering you). Scene `scenes/tactical.tscn` on the Rail Yards street, launched
  from the title's Skirmish button. Grid highlights are drawn in 2D over the
  colour grade (in 3D the grade turned the blue move range grey).
  Balance: both sides on the simple AI, 500 fights: 58% won, 42% lost, 0 stalls.
  A human should beat that; M5's noise and reinforcements push back.
  Open: units glide (no walk/shoot/death clips yet); downed = tipped over.
  Duff to judge `docs/renders/tactical_*.png` and play it on the phone.
- **M3 (Nov 6):** custom runner reads `dialogue/teodor.dlg` (lines, narration,
  conditional choices, jumps, `set`). Teodor's choice now happens in the scene,
  not on a card. All three paths reachable in tests; betrayal, found-out and
  confession beats fire. Rules untouched, so balance is unchanged.
  Open: portraits are a first pass (Kesh uses the riot-police base mesh);
  Duff to judge them. The confession is still a dice roll (50% + 10%/Legitimacy).
