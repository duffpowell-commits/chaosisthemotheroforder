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
- [ ] M5 Signal Box mission: noise, Persuade/defection, broadcast
- [ ] M6 Endings, saves, Android pass (5 clean runs on Duff's phone)

## Review
- **M3 (Nov 6):** custom runner reads `dialogue/teodor.dlg` (lines, narration,
  conditional choices, jumps, `set`). Teodor's choice now happens in the scene,
  not on a card. All three paths reachable in tests; betrayal, found-out and
  confession beats fire. Rules untouched, so balance is unchanged.
  Open: portraits are a first pass (Kesh uses the riot-police base mesh);
  Duff to judge them. The confession is still a dice roll (50% + 10%/Legitimacy).
