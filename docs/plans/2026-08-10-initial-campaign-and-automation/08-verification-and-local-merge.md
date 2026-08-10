# Step 8: Verify Both Milestones and Merge Only After Signoff

## Milestone

Automated contracts, editor loading, campaign manual play, and representative runner output provide evidence for a safe local merge.

## Setup

Work on the relevant branch with prior steps committed. Preserve unrelated files and read `docs/dev/running-the-game.md`.

## Automated verification

```bash
godot --version
make check
godot --headless --path . --editor --quit
git diff --check
git status --short
```

Expected: Godot 4.7.1, GUT `All tests passed`, editor/whitespace success, and only intended work.

For automation, run the same baseline scenario twice with same seed/iterations and compare normalized records excluding only `elapsed_ms`. Case IDs, seeds, outcomes, metrics, and aggregates must match; directories must differ and neither run overwrites another.

## Manual campaign verification for user signoff

Run `make play` and ask the user to perform/observe:

1. New campaign through guide, party, deployment, route, battle, return, and one improvement—without F9.
2. Every guide message is concise, dismissible, and does not block input.
3. Save at Encampment; quit/relaunch/Continue; verify roster, party, stores/equipment, gold/buildings, turn, encounters/vacancies, and dismissals.
4. Win, retain carried World Map reward, save/relaunch/Continue, then return home; confirm one bank only.
5. Enter battle and confirm Save is unavailable/clear; lose once and confirm return home without clearing the site.
6. Manually play baseline, favourable, and adverse runner cases; record qualitative/report discrepancies for a separate balance/AI task, not a value change here.

Record route, save boundary, outcome, report path, case IDs, and explicit user approval. A failed check reopens its owning step; never delete tests/records to bypass it.

## Documentation, commit, and local merge

Update `docs/plans/first-playable-campaign/game-design.md` only for shipped save/onboarding/runner behavior and `docs/dev/running-the-game.md` only for commands actually verified. Commit separately:

```bash
git add docs/plans/first-playable-campaign/game-design.md docs/dev/running-the-game.md
git commit -m "docs: record campaign readiness verification"
```

After explicit user signoff, merge locally:

```bash
git checkout main
git merge feature/initial-campaign-readiness
git branch -d feature/initial-campaign-readiness
```

Then, after runner signoff:

```bash
git checkout main
git merge feature/battle-scenario-runner
git branch -d feature/battle-scenario-runner
```

Do not push or open a PR unless asked.

## Completion check

`main` contains independently verified campaign-readiness and automation milestones, generated experiments stay out of Git, and the user has approved manual evidence.
