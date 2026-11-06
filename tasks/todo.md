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
- [ ] M4 Tactical core: grid, AP, move, cover, shoot, basic AI
  Done when: a skirmish on the street map is winnable and losable.
  Plan (same split as M1/M2: pure rules first, scene second):
  - [ ] `scripts/tactics/battle.gd`: pure data. 14x14 grid, tiles (floor,
        half cover, full cover, high ground), units (side, pos, AP, HP).
  - [ ] Rules: 2 AP/unit, Move 1 AP = 5 tiles (BFS, blocked by cover/units),
        Shoot 1 AP, hit 65% / half -20 / full -40 / high +10 / flank +20,
        clamp 5-95. Cover read per direction; flanked = no cover from that side.
  - [ ] Line of sight: grid raycast, full cover blocks, half doesn't.
  - [ ] AI: patrol fixed route -> alerted (sees you / you shoot) -> move to
        best covered tile in range and shoot -> retreat at 1 HP.
  - [ ] Skirmish layout from the Rail Yards street: containers = full,
        crates = half, gantry = high ground. 3 of ours vs 4 guards.
  - [ ] Tests: hit-chance table, LOS, BFS move range, flank, AI states,
        seeded skirmish deterministic.
  - [ ] `tools/skirmish_sim.gd`: 500 seeded skirmishes, dumb player policy.
        Pass = both wins and losses occur (target win rate 35-65%).
  - [ ] Scene: 3D street + grid overlay, tap unit / tap tile, Shoot button
        shows hit %, AP pips, end turn. Touch targets >= 48 px.
  - [ ] Renders to `docs/renders/tactical_*.png`; Duff judges them.
  - [ ] Merge to main, update CLAUDE.md handoff.
  Deferred to M5 (spec §9): Sneak, Subdue, Overwatch, Interact, Persuade,
  noise meter, reinforcements, stabilize/permadeath.
- [ ] M5 Signal Box mission: noise, Persuade/defection, broadcast
- [ ] M6 Endings, saves, Android pass (5 clean runs on Duff's phone)

## Review
- **M3 (Nov 6):** custom runner reads `dialogue/teodor.dlg` (lines, narration,
  conditional choices, jumps, `set`). Teodor's choice now happens in the scene,
  not on a card. All three paths reachable in tests; betrayal, found-out and
  confession beats fire. Rules untouched, so balance is unchanged.
  Open: portraits are a first pass (Kesh uses the riot-police base mesh);
  Duff to judge them. The confession is still a dice roll (50% + 10%/Legitimacy).
