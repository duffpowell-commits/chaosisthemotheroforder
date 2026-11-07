# Diversion Tools Spec (milestone J1.5)

> Duff, Nov 6: "the game is set on diversionary tactics and I want realism."
> Give the squad ways to move the guards' eyes, then rebalance so the Signal
> Box is exactly as hard as it is now.

## 1. Picks (Duff's)

| Tool | Who has it | One-line effect |
|---|---|---|
| **Smoke flare** | squad kit, 1 per mission | blinds a 3×3 area for 2 turns |
| **Lights out** | the map (junction box) | one zone goes dark for 3 turns |
| **Fake radio call** | You, next to the signal box | sends 1–2 guards away for 2 turns, or backfires |
| **Flashbang** | a guard who defects brings 1 | stuns guards next to the blast for 1 turn, very loud |

**Not picked:** the thrown noisemaker.

**Realism guardrail (design.md):** tools are abstract game actions. The game
shows what they do and what they cost, never how to make or use the real thing.
Flashbangs are regime gear: the movement only gets one when a guard defects
with his kit.

## 2. Rules

All numbers are constants at the top of `battle.gd`, so the simulator can tune them.

### 2.1 Smoke flare
- **Action:** `Smoke`, 1 AP. Target any tile within 5 that the thrower can see.
- **Area:** that tile plus its 8 neighbours (3×3).
- **Duration:** 2 regime turns.
- **Effect:** blocks line of sight into, out of and through the area.
  Spotting through it is impossible. Shots at a unit standing in smoke take −30.
- **Cost:** +2 noise. Every guard who can see the cloud goes to ALERT.
- **Charges:** 1 per mission (`SMOKE_CHARGES`).

### 2.2 Lights out
- **Map:** a junction box tile (new tile type `JUNCTION`) on the yard wall,
  away from the signal box. It feeds the depot floodlight.
- **Action:** `Interact`, 1 AP, standing next to the box. Once per mission.
- **Effect:** for 3 turns, the floodlit zone (the box's half of the yard)
  goes dark. Guards in or looking into the dark zone only spot units within
  `HIDDEN_SIGHT` (2), sneaking or not.
- **Cost:** +1 noise. The nearest patrolling guard walks to the junction box
  to check it, which is a threat you have to plan around.
- **Visual:** the floodlight cuts out; the zone's lights dim on the map.

### 2.3 Fake radio call
- **Action:** `Radio`, 1 AP, **You** only, standing next to the signal box.
  One attempt per mission. It competes with the upload for You's AP.
- **Chance:** `30 + 10 × Legitimacy`, capped at 85%. The preview shows it.
- **Success:** the 2 nearest guards who are not yet on full alarm head for the
  far edge for 2 regime turns. They don't spot or shoot while busy, then
  come back on alert.
- **Failure:** they know someone's on their channel. +3 noise and every guard
  goes to ALERT.

### 2.4 Flashbang (defector only)
- **When a guard defects** (Persuade), he joins with 1 flashbang. Only he can
  throw it.
- **Action:** `Flash`, 1 AP, target within 4 tiles that he can see.
- **Effect:** every regime unit within 1 tile of the blast (3×3) is stunned:
  it loses its next turn.
- **Cost:** +4 noise. That almost always trips the alarm.

## 3. Screen (the Advance Wars rule: no hidden math)
- Each tool gets a button in the right-hand action column, shown only when it can
  be used. The number of charges left shows on the button.
- **Before you commit**, the preview shows:
  - the affected tiles (smoke and flash: 3×3; lights: the zone),
  - outlines on the guards it will affect,
  - the noise cost,
  - the chance (radio).
- Smoke shows as a grey cloud on the grid; the dark zone tints the tiles.
  Busy and stunned guards get a status tag over their head.

## 4. Simulator and bot
- Add the tools to the quiet and loud bots in `tools/mission_sim.gd`:
  - **Lights out** early if the box is on the way.
  - **Radio** when You is next to the box, before the upload, if guards are
    within 6 tiles.
  - **Smoke** on the run home when a guard can see a squad member.
  - **Flash** when 2+ guards are bunched within reach of the defector.

## 5. Balance target: same difficulty as now
The tools make the mission easier, so the game gets harder somewhere else
until these numbers are back (300 runs, `-- 300 focus`, quiet bot):

| Case | Aired | Nobody out | Close calls |
|---|---|---|---|
| Squad 3 v 4 guards | 40–50% | 60–70% | 40–70% |
| Squad 5 v 4 guards | 90–97% | under 10% | — |

Knobs to try, in this order:
1. Drop the broadcast freeze (`BROADCAST_STUN` 1 → 0) if smoke now covers the run home.
2. Guards search smarter after a disturbance: they check the source, then sweep
   toward the nearest unit they last saw.
3. A fifth guard.

Record which knobs moved and the before/after numbers in `tasks/todo.md`.

## 6. Tests (in `tests/run_tests.gd`)
- Smoke blocks line of sight through it, −30 to hit into it, lasts 2 regime turns, 1 charge.
- Lights out: dark-zone sight drops to 2; the nearest guard walks toward the box.
- Radio: success makes 2 guards busy for 2 turns; failure adds +3 noise and
  alerts everyone; only You, only next to the box, once.
- Flashbang: only a defector, stuns guards within 1 tile for 1 turn, +4 noise.
- The run → mission → run flow check still passes.

## 7. Done when
- All four tools work in the real scene. Autoplay shows the bot using each of
  them, saved as `docs/renders/autoplay_tools.gif`.
- The balance numbers sit inside §5's targets.
- The independent design review ran (CLAUDE.md, end of milestone).
- If time runs short, cut in this order: the radio call, then the flashbang.
