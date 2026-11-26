# White Flag: surrender + prisoners (notes, not built)

Duff, Nov 25, 2026: fold this into Chaos instead of a new game. **Notes only.** Nothing is
built; it waits its turn behind the standards list (items 1-7). It fleshes out the
existing design line "Enemies can surrender or defect mid-mission" (design.md) and
pillar 1, "Defections win revolutions."

## Why
Players keep asking for it. From r/gamingsuggestions (Nov 2026): "Fps where enemies
genuinely surrender" and "Suggest me a game with a strong moral dilemma that is player
resolved." Chaos already wants both, and the Ledger is the right place for the choice.

## The idea
- **Nobody fights to the death by default.** Guards have nerve. Losing a partner, getting
  flanked, getting flashbanged, lights out, the broadcast airing: each one drains it.
  At zero a guard **breaks**: he runs or he surrenders (hands up, drops his weapon).
- **You win by breaking nerve, not by clearing the map.** That fits the no-kill diversion
  tools (smoke, lights out, fake radio, flashbang) and gives them a second job.
- **Show it the Advance Wars way:** a nerve pip row on each guard, plus the preview line
  ("Shoot: wounds him · his partner breaks"). No hidden math.

## Every prisoner is a choice (and a Ledger stamp)
| Choice | Why it tempts | Cost now | What it becomes after you win |
|---|---|---|---|
| Feed + hold | Clean; raises the defection lean of guards who hear about it | Rations/cash each week | Prisoners get tried, not purged |
| Interrogate | Intel: patrols, the next op's guard count | His side hardens (their nerve starts higher) | Your security service runs "enhanced questioning" |
| Recruit | A new operative (unmasks: helmet rule) | He might be a plant (intel certainty decides the odds) | Ex-police in your ranks: order or infiltration |
| Let him go | Reputation spreads; future guards surrender sooner | He can come back armed | Amnesty becomes policy |
| Execute | Fast, no upkeep, no risk | **Every guard after this fights to the last man** (no surrenders for 3 weeks) | Purges; their families are the next resistance (ties to "Killing guards") |

- Tune it so the dirty options win missions ~10-20% more often (the Ledger rule).
- A recruit who defects takes his helmet off on screen: the one camera beat (Helmets).

## Duff's answers (Nov 26, 2026, tapped on cards)
- **Where prisoners live: a holding slot in the weekly plan** that eats cash, so holding them
  competes with ops. (Not in the first build step; that one shows prisoners as a report row.)
- **Surrender is its own stat.** The 60-70% survival target stays "someone in the squad got out";
  surrenders are counted separately so old sim numbers stay comparable.
- **Execution penalty lasts 3 weeks**: no surrenders for 3 weeks after an execution, then nerve works again.
- **First build step: break in the Signal Box + a report row.** Guards there get nerve and can run or
  surrender; prisoners show as one row on the weekly report. Checked with `mission_sim`.

## Where it would touch the code (when it's built)
- `scripts/tactics/battle.gd`: nerve per guard, break check after each event, AI for running/surrendered.
- `scripts/tactics/tactical.gd`: nerve pips, hands-up pose (Meshy clip needed), preview text.
- `scripts/sim/` + `scripts/ui/game.gd`: prisoner choices on the report, Ledger stamps, ending lines.
- `tools/mission_sim.gd`: re-check the survival target and tension numbers.
