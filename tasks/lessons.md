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
- (Nov 6) A GDScript parse error doesn't crash a scene launched with xvfb; Godot just sits
  there forever. Always run with `timeout`, and CI parses every script first.
- (Nov 6) MPFB rigs need the retarget silhouette fix ON, or every Mixamo clip bends the
  forearms inward. Check arms in a render after touching `tools/setup_retarget.py`.
- (Nov 6) Two sessions on one repo collided on `main`. One session per repo; fetch first.
- (Nov 6) Scripted edits that cut a file by "from function X to marker Y" swallow whatever
  sits between. J1 lost `_pips`/`_face` that way; `test_scripts_compile` caught it. Replace
  exact old text, never a range.
- (Nov 7) Say difficulty numbers the way the player feels them ("squad gets out 64%"),
  not as the sim's failure stat ("nobody out 36%"). Reporting the inverse got a whole
  rebalance tuned to the wrong end.
- (Nov 6) Moving the camera can undo an old HUD fix. Check the edge rows in renders after
  any camera change; the fit check in `_frame_camera` exists for this.
