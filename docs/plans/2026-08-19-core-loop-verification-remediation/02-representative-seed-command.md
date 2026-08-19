# Step 2: Representative-Seed Campaign Simulation Command

**Branch:** `fix/campaign-sim-representative-seeds`  
**Depends on:** Step 1 merged  
**Milestone:** `make campaign-sim` runs and labels an explicit representative seed set; numeric sweeps are opt-in and labelled samples.

## Setup

Read `docs/dev/README.md` and `docs/dev/testing.md`, then confirm Step 1 is merged before creating the regular branch:

```bash
git status --short --branch
git checkout main && git pull
git checkout -b fix/campaign-sim-representative-seeds
make check
```

Preserve unrelated generated `.uid` files and the pre-existing `project.godot` edit; stage only files named in this step.

## Files

- Modify: `scripts/tools/campaign_sim.gd` or a small shared constants script under `scripts/tools/`
- Modify: `scripts/tools/campaign_sim_main.gd`
- Modify: `scripts/tools/campaign_sim_metrics.gd`
- Modify: `Makefile`
- Modify: `tests/unit/test_campaign_sim.gd`
- Create: `tests/unit/test_campaign_sim_main.gd`
- Modify: `docs/dev/running-the-game.md`

## TDD tasks

### Task 1: Make the seed list a single source of truth

1. Move the ordered representative list `[4, 9, 10, 12, 14]` from test-local state into a production-owned immutable constant shared by simulation, CLI, and tests.
2. Add a failing test that default CLI resolution returns exactly that list and tests consume that same constant rather than a copy.
3. Run the focused test. Expected: failure because the CLI has only `--seed` and `--runs`.
4. Implement `--seeds=4,9,10,12,14`, validating non-empty positive integers. Omitted seeds default to the shared representative list. Keep `--seed`/ `--runs` as explicit sweep mode only; reject mixed modes.
5. Re-run focused tests. Expected: pass.

### Task 2: Make persisted and printed evidence self-describing

1. Add failing tests for report metadata and text:
   - Representative mode names its exact list and says `Representative seeds: 5/5 victories`, not an unqualified universal claim.
   - Sweep mode identifies its contiguous range and calls its percentage `Sample victory rate`.
   - JSON includes `mode`, `seeds`, and `failed_seeds`.
2. Run focused simulation tests. Expected: failure because records are anonymous and summary prints `Victories: … (…%)`.
3. Pass explicit mode/seed metadata from `campaign_sim_main.gd` into metrics without changing per-seed outcome semantics.
4. Re-run focused tests. Expected: pass.

### Task 3: Split Make targets and document semantics

1. Add a failing Makefile/command contract that `make campaign-sim` passes the representative list. Define `campaign-sim-sweep` for `CAMPAIGN_SEED` and `CAMPAIGN_RUNS`.
2. Implement target/help text and document exact commands, output labels, and the no-universal-claim rule in `docs/dev/running-the-game.md`.
3. Run:

   ```bash
   make campaign-sim
   CAMPAIGN_SEED=1 CAMPAIGN_RUNS=10 make campaign-sim-sweep
   ```

   Expected: first runs exactly 4, 9, 10, 12, 14; second visibly labels a sample range and reports failed seeds if present.

### Task 4: Verify, sign off, commit, merge

1. Run `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_campaign_sim.gd -gexit`, `make check`, `make campaign-sim`, `git diff --check`, and `godot --headless --path . --editor --quit`.
2. Manual check: run both targets and verify label/seed semantics.
3. Stage only this step's files; check staged diff; commit:

   ```bash
   git add Makefile scripts/tools/campaign_sim.gd scripts/tools/campaign_sim_main.gd scripts/tools/campaign_sim_metrics.gd tests/unit/test_campaign_sim.gd tests/unit/test_campaign_sim_main.gd docs/dev/running-the-game.md
   git diff --cached --check
   git commit -m "fix(sim): run documented representative campaign seeds"
   ```

4. After user sign-off, merge locally and delete only this branch:

   ```bash
   git checkout main
   git merge fix/campaign-sim-representative-seeds
   git branch -d fix/campaign-sim-representative-seeds
   ```
