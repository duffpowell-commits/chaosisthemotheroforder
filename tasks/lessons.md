# Lessons

_Patterns learned from corrections. Reviewed at the start of each session._

- **Visual decisions need real renders, not code sketches.** Style board 01
  (canvas-drawn shapes) read as "childish" and sank every direction with it.
  For look-and-feel choices, show actual engine output with real assets.
- **Check platform before recommending tools.** Recommended VRoid Studio
  (desktop only) before knowing what device the user has. Ask first.
- **Merge to main every milestone.** A whole session's work sat on an
  unmerged branch; when that session stopped loading, the next session only
  saw `main` and wrongly reported the game as lost. Merge, and keep CLAUDE.md
  current so any session can pick up cold.
- **Keep sessions small.** A long session full of inline renders force-closes
  the mobile app. One milestone per session; renders go to files.
- **Check that you can see renders before you judge them.** A plugin hook
  (ClaudeTokenSAP) blocked image reads in the M4 session, so the renders went
  to Duff unchecked. Try one Read on a render early; if it's blocked, say so
  and name the plugin from the error.
- **A script that fails to compile can still print "all passed".** The test
  runner counted tests as passed when their script failed to parse (errors
  showed as "Nil" calls). `test_scripts_compile` now loads every game script;
  still read the output for SCRIPT ERROR, not just the last line.
- **Check the bot before tuning the game.** The first mission sim said the
  Signal Box was nearly unwinnable; traces showed the bot walking into patrol
  lines and stalling. Trace a couple of seeded runs before changing numbers.
