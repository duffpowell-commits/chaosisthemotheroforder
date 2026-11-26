# The studio mascot in every game (Duff's rule, Nov 26, 2026)

For any coding AI (Claude, Grok, Codex, ChatGPT...) or person working on a 3 Eyed Fox Studios game.

## The rule
- The studio mascot, the **three-eyed fox**, appears in **every** game.
- It is a **cameo, not a pal**: no companion, no sidekick, no follower, no helper the player keeps.
- It shows up as a **small event that matters but never ruins a run**: it costs or nudges something
  the player notices (a turn, a moment, a bit of noise, a dropped item), never a death, a lost save,
  a failed level or anything the player can't recover from.
- Rare: at most once a run or once a night/level, so it stays a surprise.
- **Duff approves the fox art on a tappable card before anything is built.** Use the studio look
  (distressed gold, tattoo-inspired, three eyes, the ear jewelry; godot-game-starter docs/MARKETING.md "Brand"), make
  it in Foxboard Forge first, then show him. No fox art ships without his yes.
- The example Duff gave (Rush): on a quiet service a fox gets loose in the kitchen and costs a turn.

## Exceptions (Duff's calls)
- **Hunter:** the fox is the **main character's pet**, not a cameo (Duff, Nov 26).
- **DuffQuest:** besides its cameo, the fox also joins the overworld animals, with the raccoons.

## How to build one
1. Write the game's cameo idea (one line) in this file's "This game" section and the handoff log.
2. Get the fox art approved by Duff on a card (see above).
3. Build it with a TUNE slider for its odds/cost and an autoplay PASS line, like any feature.
4. Log it in the handoff (CLAUDE.md "Where things stand" + the handoff log).

## This game: Chaos Is the Mother of Order
- **Built (Nov 26, Duff: "make the mascot graffiti on the wall", kept the art on a card):** the three-eyed fox is
  spray-painted on the south face of a container block in the Signal Box yard.
  - Rare: `Battle.FOX_CHANCE` (35%) of fights, on one of `Battle.FOX_WALLS`. A player's first ever fight always has it
    (mid-yard wall, `FOX_FIRST_WALL` in tactical.gd) so they meet it once.
  - Event: the first time one of yours walks up to it, the log says "Someone sprayed a three-eyed fox on the container"
    and a one-time tip reads "Somebody in this yard is on your side." Flavour only: no dice, sight or noise change, so
    quiet survival stays 66% (its own RNG; rule test `test_fox_cameo`).
  - Art: Foxboard Forge job `chaos-fox-graffiti-r2-20261126` take 1 (seed 1295374655), cut out of the wall into
    `assets/props/fox_graffiti.png` (alpha, drawn on a quad by `_build_fox`). Render: `docs/renders/fox/`
    (`res://scenes/tactical.tscn -- --capture-fox`).
- Old idea (not built): a fox knocks over a bin for a noise pulse. Could come later as a second cameo if Duff wants one.
