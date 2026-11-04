# Chaos Is the Mother of Order — Design Doc

> Living document. Every locked decision lives here. Open questions at the bottom.

## Pitch

A grounded, grim strategy-RPG about organizing a revolution against a corrupt
modern police state — and then trying to govern without becoming the thing you
overthrew. The theme in one line: **the tools that win a revolution (secrecy,
central command, propaganda) are the same tools that build the next tyranny.**

## Locked decisions

| Area | Decision |
|---|---|
| Engine | Godot 4 |
| Setting | Fictional, present-day country. Current tech: phones, drones, social media, facial recognition |
| Tone | Grounded and grim. Death is permanent; compromises are moral, not cosmetic |
| Cast | Humans (anthropomorphic animals rejected: undercuts grim tone, costs more art, doesn't reduce "manual" risk) |
| Length | ~20 hours per run, built for replay via branching |
| Combat | Turn-based grid tactics: FFT (height, facing, jobs) × XCOM (cover, hit %, permadeath) |
| Squad | 6 per mission. Large recruitable cast (Suikoden-style) |
| Intel | Fuzzy information with certainty levels (rumor / likely / confirmed) |
| Endings | Multiple, graded by success/failure and choices |
| License | All rights reserved |

## Design pillars

1. **Defections win revolutions.** Turning police, soldiers, and officials beats killing them. Main win path.
2. **Violence is available, tempting, and costly.** Every armed act feeds regime propaganda, scares off moderates, and costs Legitimacy.
3. **Nonviolence is dangerous, not passive.** Protests, extractions, and broadcast hijacks are tense set pieces with real risk.
4. **The regime is relentless.** Escalating crackdowns, ticking clocks, informants. No turtling.
5. **Winning is not the end.** Act 3 asks whether you rebuilt the wheel.

## Accuracy guardrail

Organizing, legitimacy, propaganda, logistics, and consequences are simulated
in depth. Weapons, sabotage, and evasion techniques stay abstract (a "Sabotage"
action, not a procedure). The game shows *why* and *at what cost*, never *how*.

## The world

- **Country:** a former democracy that slid into authoritarianism through
  "temporary" emergency powers, captured courts, and a security state that
  outgrew its leash.
- **Main map:** one capital city, ~12 districts. The countryside is supply lines
  (food, smuggling routes).
- **Outside world:** other cities act as foreign powers, each with its own
  agenda: aid with strings, sanctions on the regime, arms deals, quiet support
  for whichever side looks like winning. A diaspora sends cash and amplifies
  your media. **Late game: the revolution can spread** to other cities, which
  can become allies, rivals, or a new front.

## The protagonist (you)

- Fully customizable appearance, detailed enough to build yourself.
- Customizable backstory, **defined by loss** the player relates to: a denied
  healthcare claim that killed someone you loved, a loan default that took the
  house, a market crash that erased your savings, a family member disappeared
  by police, a job lost to a crony contract.
- Backstory affects which allies trust you at the start and opens unique dialogue.
- Skill tree split between **Voice** (persuasion, rallying, speeches) and
  **Hand** (tactics, sabotage, combat).
- **Capture or death ends your game**, but you still get an ending: the
  movement continues without you, shaped by what you built. **Martyrdom is
  an option, never the default.**

## Allies

- Large recruitable cast across factions (dockworkers' union, students,
  disgraced police captain, smugglers, a nervous minister, clergy, hackers,
  medics, journalists).
- How you recruit someone (favor, blackmail, shared enemy, principle) sets their loyalty profile.
- **Allies can betray you, and you can betray allies.**
- **Permadeath.** Fallen allies can become martyrs depending on their
  contribution and public standing; a martyr boosts sentiment, and the regime
  will try to smear them.

## Resources

| Resource | Used for | Comes from |
|---|---|---|
| Cash | bribes, weapons, safehouses | donors, smuggling, diaspora |
| Supplies | food and medicine for districts and people | farms, aid, depot raids |
| Parts | gear upgrades and research | scrapyards, engineers, theft |
| People | operatives, protest turnout | recruitment, sentiment |
| Legitimacy (soft) | allies, foreign support, defections | how *clean* you win |

## Strategic layer

- Weekly turns.
- Each district tracks regime control, sentiment, and **Heat** (how hard the
  regime hunts you there).
- The regime has a finite **Attention** budget. **Diversions** (riots, fake
  intel, decoy cells, leaks) pull its attention away from your real operation.
- **District conversion:** Hostile → Wary → Sympathetic → Ready.
  - You prep a district through aid, evidence of regime crimes, local allies, and broadcast hijacks.
  - **Taking a district before it's Ready makes you an occupier**: an
    insurgency against you, propaganda ammo for the regime, and the district
    stays cold.

## Propaganda war

- Both sides run media campaigns: state TV, news tickers, phone feeds, leaked video.
- The regime uses false flags and deepfakes of you.
- You choose: **verify** evidence (slow, credible) or **fabricate** it (fast, and devastating if exposed).

## Tactical combat

- Squad of 6, grid tactics with height, facing, cover, and hit chance.
- **Noise meter:** loud actions raise the alarm; at the cap, reinforcements arrive.
- **Enemies can surrender or defect mid-mission.**
- Mission types: rescues, extractions, broadcast hijacks, sabotage, protests
  (defend the crowd, spot the provocateur), and assassinations (rare, costly).

## Act structure

1. **Act 1 — The Cell.** You decide everything. Small, hunted, desperate.
2. **Act 2 — The Coalition.** Factions demand seats. Foreign powers circle. The
   regime escalates. Your choices about violence and secrecy start compounding.
3. **Act 3 — The Republic (full playable act).** You draft a constitution
   article by article: economy, wealth distribution, courts, press, term
   limits, amnesty, and how power is split between the center and the
   districts. The economic system **emerges** from those choices (market,
   cooperative, social-democratic, or something new); it is never picked
   from a menu.

### The wheel: circle or break?

**Corruption** is a hidden, creeping meter in Act 3, fed by what you did to
win: secrecy, emergency powers you never gave back, purges, fabricated
propaganda, a personality cult around you.

You break the wheel by **giving power away**: an independent press that can
attack you, courts that can overrule you, term limits that push you out,
district autonomy that slows you down, truth commissions that expose your own
side's crimes. Each check costs control and comfort right when the new state
is fragile. The regime's remnants exploit every weakness.

- Hoard power → stable, efficient, and the wheel turns: you become the new regime.
- Give it away too fast → the republic collapses into chaos or a counter-coup.
- The good ending is the narrow path between, earned across all three acts.

The final scene: years later, a kid in a liberated district — is there a
poster of your face on the wall, or not?

## Dialogue

- **Conversation:** short, Hemingway/journalism style. Subtext over exposition.
  People in a police state talk around things.
- **Speeches:** longer, rhetorical set pieces. The player picks **topics and
  framing** (grief, anger, hope, unity, a specific grievance), and the crowd's
  makeup decides what lands.
- Choices express **intent and tone**, not "agree/disagree."
- Characters remember everything, including your lies.
- Authored in a branching format (Ink or Dialogic in Godot — TBD).

## Art direction (pending style board)

- Low-poly 3D seen from an isometric camera; mood carried by lighting.
- Regime districts: desaturated blue-gray, sodium lights, searchlights,
  drones, rain, wet asphalt, empty streets.
- Liberated districts: warm color grade, crowds, markets, murals over regime posters.
- Map-wide color grade driven by district control %.
- Diegetic propaganda UI (TV broadcasts, tickers, phone feeds).
- Painted character portraits for dialogue.

## Open questions

- [ ] Visual references (games, films, photographers)
- [ ] Music direction: ambient/tense vs. soundtrack with protest songs
- [ ] Platform: PC only, or Steam Deck / console later
- [ ] Dialogue tool: Ink vs. Dialogic
- [ ] Country, city, and regime names
