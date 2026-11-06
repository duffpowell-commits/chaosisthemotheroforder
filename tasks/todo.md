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
- [ ] M5 Signal Box mission: noise, Persuade/defection, broadcast
  Done when: mission outcomes feed back into the run.
  Pre-fix from the M4 renders: bottom HUD covered the squad's start row
  (Mara/Kesh drawn behind the panel). Reframe the camera above the HUD.
  Plan (pure rules first, then the scene, then the run hook):
  - [ ] `battle.gd` mission mode (skirmish untouched): signal box tile, noise 0-10
        (Shoot +3, Subdue +1; noise wakes patrols within 3 tiles per point),
        alarm at 10 -> 3 reinforcements from the north 2 turns later.
  - [ ] Abilities: Sneak (2 AP, one 4-tile move, hard to spot), Subdue (adjacent,
        non-lethal), Overwatch (reaction shot on a guard moving in sight),
        Upload (adjacent to the box, 2 separate turns; airing trips the alarm),
        Stabilize (adjacent downed squadmate), Leave (south edge), Persuade
        (You only, Wavering guard within 3: 40% + 10% x Legitimacy).
  - [ ] Permadeath: downed squadmate dies after 2 of your turns unless stabilized.
  - [ ] `Rules`: split resolve into begin (pay + diversions) / finish; mission
        params (guards 4 + Depot attention - 2 if diversion to the Dorms, squad,
        Legitimacy); apply the result (aired, kills, defections, dead, hurt).
        No mission result = old auto-resolve, so the run simulator still works.
  - [ ] Scene: noise + upload meters, action column, Wavering tag, extract row.
  - [ ] Run hook: a planned Signal Box op plays the mission, then the week resolves.
  - [ ] Tests + `tools/mission_sim.gd` (quiet and loud policies both win and lose).
  - [ ] Renders `docs/renders/mission_*.png`; merge; CLAUDE.md handoff.
- [ ] M6 Endings, saves, Android pass (5 clean runs on Duff's phone)

## Review
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
