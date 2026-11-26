# Chaos log

Design decisions and idea intake, newest first. Build progress lives in `tasks/todo.md`
and the CLAUDE.md handoff; this is the why behind them.

## 2026-11-26: the fox on the wall (studio mascot cameo)
- **Duff:** "For chaos, we'll make the mascot graffiti on the wall." First Forge take (red ring for a third eye) he sent
  back; he kept the redo with a real red third eye (dark mask, no earrings; earrings too small to read in-game anyway).
- **Built:** the fox is sprayed on a container in 35% of Signal Box fights, always in a player's first. Walking up to it
  logs a line and a one-time tip ("Somebody in this yard is on your side"). Flavour only, so the 60-70% target is untouched.
- **Why not the bin-noise idea:** Duff picked graffiti; a gameplay nudge can be added later if he wants one.

## 2026-11-26: the 8.5 pass (first-timer review 5.5, veteran 6.0)
- **Duff's rule:** before more rounds get built, plan to an 8.5 first-time-player review, OK it once, build it in one
  pass. He tapped "Build all 7", then said to skip the mock reviews and just build the fixes.
- **Built:** mission brief + Goal button + UPLOAD HERE / EXIT markers; fair stealth (`FIRST_CONTACT`: a guard on
  patrol when the regime turn began holds fire that turn, and the log says who he saw, how far and why;
  `_can_target`: no shots at a sneaking unit a guard can't see, alerted guards within `SEARCH_SIGHT` 4); the enemy turn
  plays one guard at a time with a "Regime turn" card; ♥♡ hearts; cover bars on the move range; one-time tips;
  Persuade shown out of range; Support meter on zone cards; Listen shows regime eyes the week after; dossier-style
  zone picker; Leave asks before abandoning the downed; bug sweep.
- **Balance:** first contact for every fresh guard pushed quiet 3 v 4 nobody-out 34% -> 17% (too easy). Guards that
  come running to a shout don't get the grace (only the spotter does): back to 34% (survival 66%, in target).

## 2026-11-26: White Flag step 1 built
- **Proposal** (prototype, 300 sims a case): nerve 3, drains from hits, partners down, flashbangs, the broadcast.
  With lights out draining too, quiet 3 v 4 survival went 66% -> 87% (lights out darkens the half of the yard nearly
  every guard stands in, so it drained them all at once). Without it survival stayed 66%.
- **Duff's call:** "Build it (lights don't drain)".
- **Result:** quiet 3 v 4 nobody out 34% (unchanged, in the 60-70% target), loud 5 v 4 airs 62% (was 60%).
  The sim bots don't play for nerve, so they break ~0.3 guards a fight; a player stacking flash + hit sees more.

## 2026-11-26: White Flag, Duff's four answers
- Standards list (items 1-7) finished: PR #14 merged, so White Flag's turn came up.
- **Prisoners:** a holding slot in the weekly plan that eats cash (later step).
- **Surrender:** its own stat; the 60-70% survival target stays "someone got out".
- **Execution:** no surrenders for 3 weeks, not the whole run (dirty options must stay tempting).
- **First build:** nerve + break (run/surrender) in the Signal Box only, prisoners as one report row.
  Duff OKs the proposal before any code (step by step).

## 2026-11-25: White Flag folded into Chaos (notes only)
- **Where it came from:** Duff asked for a scan of social media for game requests to start
  another game. Requests found on r/gamingsuggestions (Nov 2026): "Fps where enemies genuinely
  surrender", "Suggest me a game with a strong moral dilemma that is player resolved", a
  Fallout 4-style settlement builder "but good", and "Games where you run a shop and mostly stand around".
  These are single posts. They're signals, not market data.
- **Killed:** a wasteland pawn shop/settlement game. That lane is crowded on Steam (Doomsday
  Dealer, Outpost Simulator, Wasteland Shop Simulator and an Early Access last-shop-in-town game).
- **Pitched:** White Flag, a tactics game where nobody fights to the death. Nerve breaks, guards
  surrender, and every prisoner is a moral choice.
- **Duff's call:** don't start a sixth game repo. Fold it into Chaos, because it already says "enemies
  can surrender or defect" and pillar 1 is "Defections win revolutions". Then: "Let's just
  make notes." Nothing gets built now; it goes after the 7-item standards list.
- **Written:** `docs/white-flag-notes.md` (nerve/break rules, five prisoner choices as Ledger
  stamps, open questions, code touch points), a pointer in `docs/design.md`, a parked line in `QUEUE.md`.
- **Open for Duff:** the four questions at the bottom of the notes.
