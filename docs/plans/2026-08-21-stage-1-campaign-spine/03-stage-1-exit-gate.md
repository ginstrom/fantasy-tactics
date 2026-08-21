# Step 3 — Stage 1 Exit Gate

**Branch:** `test/stage-1-campaign-spine-exit-gate`
**Depends on:** Step 2 merged
**Milestone:** One focused automated journey and documented manual evidence prove every Stage 1 exit-gate transition without weakening the representative-seed campaign proof.

## Files

- Create: `tests/unit/test_stage_1_campaign_spine.gd`
- Modify: `tests/unit/test_campaign_sim.gd` only if a missing assertion prevents the documented representative run from proving current-objective progression
- Modify: `docs/dev/testing.md` only if the focused command needs a durable developer-doc entry

## Setup

```bash
git checkout main && git pull
git checkout -b test/stage-1-campaign-spine-exit-gate
make check
```

Proceed only after Step 2 is merged locally and the user has signed off on its
manual check. Use this normal branch in the shared checkout; do not create a
worktree.

## Design

This is an integration proof, not a second campaign simulator. The new GUT test drives public `GameSession`/`GameManager` contracts and uses a real scene only where signal wiring matters. Battle construction and full-arc evidence remain the existing `CampaignSim` → `ScenarioContract` → `BattleStateFactory` route. The test must not assert an arbitrary seed sweep or claim universal balance proof.

## Red/green tasks

1. Write `test_stage_1_campaign_spine.gd` with isolated `before_each` reset/routing cleanup. Add the failing fresh-save journey:
   - start a new game and verify the first objective and its unlocked authored node;
   - exercise pre-battle Withdraw with a deterministic harmless roll, then prove the objective remains available;
   - enter and complete the first objective through the established battle/completion path, then assert exactly the next node unlocks;
   - force a wipe/zero-gold/no-party aftermath using public APIs, advance recovery turns, recruit/form a legal party, and assert completed objectives/upgrades persist;
   - export/import the resulting state and assert objective, roster, position, and reward buckets remain unchanged.
2. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_stage_1_campaign_spine.gd -gexit
   ```

   Expected: fail until any missing cross-boundary behavior is repaired; do not change production code without first recording the failing assertion.
3. Implement only a demonstrated fix, re-run the focused test, then execute:

   ```bash
   make campaign-sim
   make check
   godot --headless --path . --editor --quit
   git diff --check
   ```

   Archive the terminal output with the implementation handoff (or attach it to the commit/PR description if one is later requested). `make campaign-sim-sweep` may be run for exploration but must be labelled an arbitrary sample.

## Manual exit-gate signoff

Run `make play` from a fresh game and complete this sequence: form party → read first objective in Encampment/World Map → Withdraw and return → enter/clear the first objective → see next objective → deliberately use Battle Retreat in a separate battle → use the available recovery/recruitment flow → save, relaunch, and load. Confirm every state is understandable and no route soft-locks. Capture screenshots only if a UI regression needs review.

## Commit and local merge

After user signoff:

```bash
git add tests/unit/test_stage_1_campaign_spine.gd tests/unit/test_campaign_sim.gd docs/dev/testing.md
git diff --cached --check
git commit -m "test(campaign): add stage one spine exit gate"
git checkout main
git merge test/stage-1-campaign-spine-exit-gate
git branch -d test/stage-1-campaign-spine-exit-gate
```

Omit unchanged optional files from `git add`. Do not push or open a PR.
