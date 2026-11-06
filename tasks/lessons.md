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
