# AGENTS.md: the rulebook for any coding AI in Chaos (Grok, Claude, Codex, Copilot...)

Commands and standing rules for this repo. Claude Code loads it through the `@AGENTS.md` line at
the top of CLAUDE.md; CLAUDE.md keeps the handoff (where things stand). Topic rules live in
`standards/` (index: GROK_STANDARDS.md), copied unchanged from `duffpowell-commits/godot-game-starter`
(the master). Rules here win where they are more specific than `standards/`.
Why (Nov 25, 2026): Chaos had no guardrails while every other game repo did (push guard, fresh-eyes,
rule lock). Duff tapped "1 + 2 now" on the standards audit.

## First step of every session (required, once per clone)
```sh
git config core.hooksPath .githooks
```
Turns on `.githooks/pre-push` for every agent, not just Claude Code (see Guards).

## Commands
- Engine: Godot 4.7.2-stable (4.7.x only, never downgrade). Cloud sandbox: the 4.7.2-stable Linux
  zip from GitHub releases -> `/usr/local/bin/godot`. Fresh clone: `godot --headless --path . --import`.
- Tests: `tools/test.sh` -> `TESTS PASS` (runs `test_cmd` from `.claude/hooks/guard.cfg`: parse check
  `tools/check_scripts.gd`, `tests/run_tests.gd` -> `N passed, 0 failed`, and the run -> mission ->
  run flow check; records the passing tree for the push guard).
- Autoplay, balance sims, renders and the web export: CLAUDE.md "Commands".
- Push guard self-test: `tools/test_push_guard.sh` -> `PUSH GUARD PASS`. Rule lock: `tools/test_rule_lock.sh` -> `RULE LOCK PASS`.
- CI: `gh api repos/duffpowell-commits/chaosisthemotheroforder/actions/runs?per_page=3` (gh GraphQL is blocked).

Before every push: `tools/test.sh` prints `TESTS PASS`; after tactical-scene changes, run autoplay too.
Before any merge: a fresh-eyes review (docs/FRESH_EYES.md); CI keeps the PR pending until then.

## Read first
- `standards/00-core.md` always, then only the `standards/*.md` files your task touches.
- CLAUDE.md for where things stand; QUEUE.md for what to work on (Chaos is PAUSED unless Duff says so).
- docs/design.md and docs/style-guide.md before gameplay or visual work.

## Standing rules
- Duff is phone-only (Godot Android editor, GitHub app). GDScript only. No desktop steps.
- Chaos is landscape (1280x720, tactics map); the starter's portrait default doesn't apply here.
- Pure rules stay in `scripts/sim/` and `scripts/tactics/battle.gd` (no nodes, tested).
- Renderer: Mobile on Android, Compatibility on web. Visual decisions need real engine renders, saved to files.
- One session per repo. Push after every chunk; merge to main at the end of every milestone.
- Never put secrets in the repo, commits, logs or chat. Duff adds secrets himself.
- Signing: the keystone (one key for every game except Lethemoor). Never make another key.

## Guards (enforced, not just written down)
- One rule script, two triggers: `.claude/hooks/guard.py` (settings `.claude/hooks/guard.cfg`).
  Claude Code runs it before every tool call (`.claude/settings.json`); every agent runs it on
  `git push` through `.githooks/pre-push`, once `core.hooksPath` is set (above).
- It blocks: force push, direct push to main, pushing code the tests didn't pass on,
  writing/generating signing keys, committing secret files (.env, keystores, secrets.*; names only).
  The Git hook blocks any push that rewrites the remote branch, `--force-with-lease` included.
- `git push --no-verify` skips the Git hook. Don't use it; CI and the fresh-eyes gate stay the backstop.
- PRs: the `fresh-eyes` status stays pending until a fresh-context review posts
  `FRESH-EYES REVIEW: PASS` on the head commit (docs/FRESH_EYES.md). Pending is not green: don't merge.
- Rule lock (Nov 24, 2026, from godot-game-starter): a PR that changes the rules (AGENTS.md,
  GROK_STANDARDS.md, `standards/`, `.claude/`, `.githooks/`, `fresh_eyes.yml`, `rule_lock.yml`, the
  lock's own tools, or CLAUDE.md's top or a rules/guards/signing section; list in `tools/rule_lock.py`)
  gets a failing `rule-lock` status until Duff adds the `duff-ok` label.
  **Agents never add, ask a tool to add, or work around that label**; guard.py blocks Claude from it.
  Put rule changes in their own PR, say in the body what changes and why, and tell Duff it needs his tap.
