# Vertical Slice Spec: "The Rail Yards"

> The first playable piece of the game. One district, one ally, one diversion,
> one tactical mission, five endings. If this isn't fun, we fix the design
> before building anything bigger.

Working names (from naming set A, not yet locked): country **Caldera**,
capital **Port Varga**, regime **the Continuity Government**, movement
**the Unbroken**.

## 1. Goal and success criteria

The slice exists to answer one question: **is the core loop tense, and do
choices matter?**

It passes when all of these are true:

1. **Two runs feel different.** Two playthroughs with different choices
   reach different endings and play out differently along the way.
2. **Length:** a run takes 30–45 minutes.
3. **Pressure:** in playtests, the player feels the regime closing in by
   week 4. No run where you can sit safely and grind.
4. **Violence tempts and costs.** Players reach for force at least once in
   a run and can name what it cost them.
5. **Runs on your phone** at 30 fps or better on the tactical map, with no
   crashes or soft-locks in 5 full runs.

## 2. The run at a glance

- **Six weeks** (turns). If you haven't won by the end of week 6, the
  regime consolidates and the window closes.
- **District 7, the Rail Yards**, split into two zones:
  - **Zone A, the Dormitories:** where people live. Sentiment lives here.
  - **Zone B, the Freight Depot:** cargo, the dock union, the signal box.
- **Start:** sentiment *Wary* (25), regime control 90%, Heat 1.
- **Each week:**
  1. **Plan:** assign up to 3 actions, one operative each.
  2. **Resolve:** outcomes roll, then the regime responds.
  3. **Report:** a state TV bulletin and a pirate-radio counterpoint
     summarise the week (the propaganda layer, Woodcut style).
  4. **Story beat:** an occasional dialogue scene.

## 3. Resources (slice version)

| Resource | Start | Gained by | Spent on |
|---|---|---|---|
| Cash | 3 | Scavenge, Teodor's cut | Expose, diversion, bribes |
| Supplies | 3 | Scavenge, depot raids | Aid runs |
| People | 2 operatives (plus you) | Recruit | Actions, squad slots |
| Parts | 0 | Scavenge | One gear upgrade (radio jammer) |
| Legitimacy | 0 | Clean wins, verified evidence | Unlocks defections and the strike |

## 4. Weekly actions

Each action takes one operative for the week and adds Heat.

| Action | Cost | Effect | Heat |
|---|---|---|---|
| **Aid run** | 2 Supplies | Sentiment +8 in the chosen zone | +1 |
| **Expose** (leaflets, wall posters) | 1 Cash | Sentiment +6, Legitimacy +1 | +2 |
| **Recruit** | none | +1 operative (+2 if sentiment is Sympathetic or better) | +1 |
| **Scavenge** | none | +1 Parts or +1 Cash or +2 Supplies (random, 15% chance of a run-in) | +1 |
| **Listen** | none | Raises intel certainty (see §6) | 0 |
| **Lay low** | none | Heat −2 | 0 |
| **See Teodor** | none | Advances the ally storyline (§7) | 0 |
| **Diversion** | 1 People, 1 Cash | See §8 | +1 (+2 if it fails) |

**District states, by sentiment:** Hostile 0–15 · Wary 16–35 ·
Sympathetic 36–60 · Ready 61+.

## 5. The regime (it has to be relentless)

- **Attention:** each week the regime puts 3 points of Attention across the
  two zones. Every point of Attention on a zone cuts action success there
  by 15% and adds a guard to any mission there.
- **Heat thresholds** (district-wide):
  - **3:** patrols. Each action has a 10% chance to fail outright.
  - **5:** checkpoint raids. Lose 1 random resource each week.
  - **7:** targeted raid. Next week opens with the defensive mission
    *The Raid* (stretch goal; see §12). If it's cut, a scripted event
    arrests one operative.
  - **9:** you're found. The capture ending fires, unless you're
    mid-mission.
- **Escalation clock:** Heat rises +1 on its own every week from week 3,
  no matter what you do. That keeps the pressure on.

## 6. Fuzzy intel

The player never sees exact numbers for the regime. Every reading comes with
a certainty level:

- **Rumor:** only a range ("Sympathetic or Wary").
- **Likely:** one state, with a 20% chance it's off by one.
- **Confirmed:** exact.

**Listen** and Teodor's dock network raise certainty. Regime Attention is
always shown as a Rumor unless you Listen in that zone.

## 7. The ally: Teodor, the dock foreman

Teodor runs the night shift at the Freight Depot. His brother is in Kell
Prison for printing a newsletter. There are three ways to get him on side:

| Path | How | Loyalty | What it unlocks | The catch |
|---|---|---|---|---|
| **Trust** | Two aid runs in the Depot zone, then the honest conversation | High | **The strike:** Depot sentiment +20, regime Attention −1 for 2 weeks | Slow: ready by week 3 at the earliest |
| **Leverage** | Listen in the Depot zone until you learn he skims cargo for smugglers, then blackmail him | Low | He joins immediately and fights in the mission | At Heat 7 or more, a 50% chance he tips off the regime before the finale |
| **The lie** | Promise to get his brother out of Kell | High, for now | Fast trust, strike unlocked | In week 5 he learns there is no rescue plan. Loyalty crashes, unless you confess first (Voice check) |

He's written in the short, Hemingway-style voice from the style board. The
existing dock scene (style board) is his first scene.

## 8. The diversion: the Signal Fire

Stage a fake leak and a small protest at whichever zone you are **not**
operating in.

- **On success** (base 70%, −10% per Heat level above 3): 2 Attention moves
  to the decoy zone this week.
- **On failure:** Heat +2 and one operative is arrested (gone for 2 weeks).
- **On the mission:** a successful diversion on mission week removes 2
  guards from the tactical map.

This is the slice's key strategic lesson: **you win by moving the regime's
eyes, not by outgunning it.**

## 9. The tactical mission: the Signal Box

The signal box in the Freight Depot is wired into the district's public
screens. **Objective:** take it, broadcast the real footage of the
dormitory raid, and get out.

- **Map:** about 14×14 tiles, built from the render-test street plus the
  Depot yard. Containers give full cover, crates half cover, and the
  gantry is high ground.
- **Your squad:** up to 6: you, Teodor (if recruited) and operatives.
- **Enemies:** 4 patrol guards, +1 per Attention point on the Depot,
  −2 if the diversion worked. 3 reinforcements arrive if the alarm trips.
  One guard is marked **Wavering**.

**Turn rules:**
- **2 action points** per unit. Movement range is 5 tiles per point.
- **Hit chance:** 65% base. Half cover −20%, full cover −40%. High ground
  +10%. Flanking a target's cover +20%. Clamped to 5–95%.
- **Abilities:**

| Ability | Cost | Effect | Noise |
|---|---|---|---|
| Move | 1 AP | Normal move | +0 |
| Sneak | 2 AP for one move | Silent | none |
| Shoot | 1 AP | Lethal | +3 |
| Subdue | 1 AP, adjacent | Non-lethal takedown | +1 |
| Overwatch | 1 AP | Reaction shot | — |
| Interact | 1 AP | Signal box, doors | — |
| **Persuade** (you only, Voice) | 1 AP | On a Wavering guard within 3 tiles: 40% + 10% × Legitimacy chance they defect | — |

- **Noise meter:** 0–10. At 10, the alarm sounds and reinforcements arrive
  in 2 turns.
- **Holding the box:** 2 turns of Interact (the broadcast uploads), then
  extract from the map edge.
- **Defectors** join your squad for the rest of the mission.
- **Permadeath:** a downed operative dies unless a squadmate stabilizes them
  within 2 turns. Stabilized operatives sit out 2 weeks.

**Outcomes:**

| Result | Effect |
|---|---|
| Broadcast airs | Sentiment +15 in both zones |
| No kills | Legitimacy +2 |
| Each kill | Legitimacy −1, Heat +1 |
| Each defection | Legitimacy +1 (and it seeds the defection theme) |

**Enemy AI** (simple, readable):
- Patrol along fixed routes until they spot you or hear noise.
- Once alerted, move to cover and shoot.
- At low health they retreat toward reinforcements.

**Build notes (M5):** spotting a squad member makes the guard shout (+2
noise, wakes guards within 6 tiles) rather than alerting everyone; gunfire
still alerts everyone. Airing the footage alerts every guard but doesn't sound
the alarm by itself. The squad is you plus everyone free that week (max 6).
Sentiment +20 (not 15) on airing, matching the tuned auto-resolve. Guards cap at
8. Quiet vs loud is chosen in the mission, not on the plan card.

## 10. Endings (five)

| Ending | How you get it |
|---|---|
| **The district turns** | Sentiment Ready in both zones, the broadcast aired, Legitimacy 3 or more |
| **The yards go silent** | The Teodor strike plus the broadcast. A worker-led takeover |
| **Occupiers** | You take the district while sentiment is below Ready, or with 3+ kills. You hold it, but it stays cold. The regime TV gets its footage. |
| **Captured** | Heat hits 9. The movement carries on without you, shaped by what you built |
| **The window closes** | Week 6 ends without a win |

Each ending gets a short epilogue, a state TV bulletin and a pirate-radio
reply. **The district's color grade reflects the result:** full color,
partial, or still gray.

## 11. Screens (phone-first)

All touch targets are at least 48 px. Nothing depends on hovering.

1. **District map:** a top-down woodcut-style map of the two zones
   (propaganda layer D). Shows sentiment with its certainty and an
   Attention estimate.
2. **Week planner:** action cards dragged onto operatives, with live cost
   and Heat preview.
3. **Weekly report:** the state TV bulletin, then the pirate-radio reply.
4. **Dialogue:** a character render as the portrait, the lines, and the
   choices.
5. **Tactical map:** the 3D street with the Frontline grade, a grid overlay,
   action buttons, the noise meter and hit chances.
6. **Ending:** the epilogue, the regraded street, and stats.

## 12. Technical plan

- **Engine:** Godot 4.5, Mobile renderer, all game code in GDScript (the
  Android editor can't run C#).
- **Game state is pure data** (`RunState` resource) and separate from the
  scenes. That makes it testable headless and saveable.
- **Dialogue:** a small custom runner reading plain-text script files
  (speaker, line, choices, conditions, effects). I'd skip Ink, which needs
  C# in Godot, and Dialogic, which is heavy for this. Revisit if the
  writing outgrows it.
- **Saves:** autosave at the start of every week, plus an optional
  ironman mode with a single slot.
- **Balance testing:** a headless simulator (`tools/simulate.gd`) plays
  1,000 runs each with three automated players: random, careful
  (non-violent) and violent. **Targets** (revised after the first runs;
  random play *should* mostly fail, so the old "no ending above 50% for
  random" target was wrong):
  - Careful player wins 35–60%, captured 15–35%.
  - Random player captured 10–30%, almost never wins.
  - Violent player reaches "Occupiers" fastest: violence has to tempt.

  **First tuned results (M1):** careful wins 42% and is captured 31%;
  random is captured 26%; violent ends as Occupiers 71% by week 3.6. The
  strike ending is rare (0.5%) because the careful bot rarely lines up the
  strike before the rally; revisit when a human plays it.
- **Tests:** headless unit tests for hit chance, noise, Heat thresholds,
  sentiment states and ending conditions, run before every push.

**Stretch (only if the core lands early):** *The Raid* defensive mission at
Heat 7, a radio-jammer upgrade that uses Parts, and facing rules.

**Out of scope for the slice:** more districts, the governing act, the
corruption meter, foreign powers, the full character creator, real
riot-gear models, music, and localization.

## 13. Build order

Each milestone ends with something you can run on your phone.

| # | Milestone | Done when |
|---|---|---|
| M1 | **Run state and week loop**, headless | Simulator runs 1,000 games; unit tests pass |
| M2 | **District map, planner and report** | Plays a full 6-week run, text-and-cards only |
| M3 | **Dialogue runner and Teodor's three paths** | All three paths reachable; loyalty consequences fire |
| M4 | **Tactical core:** grid, AP, move, cover, shoot, basic AI | A skirmish on the street map is winnable and losable |
| M5 | **The Signal Box mission:** noise, Persuade, defection, broadcast | Mission outcomes feed back into the run |
| M6 | **Endings, saves, Android pass** | Five endings reachable; 5 clean runs on your phone |

## 14. Open questions for Duff

1. Lock naming set A, or pick different names?
2. Is six weeks the right length, or do you want it tighter or looser?
3. Should the lie path's confession be a dice roll (Voice check) or a pure
   story choice?
4. Is the custom dialogue runner OK? It keeps the project phone-editable.
