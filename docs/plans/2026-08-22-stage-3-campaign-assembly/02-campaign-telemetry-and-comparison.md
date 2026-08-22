# Step 2 — Campaign Telemetry and Comparison

**Branch:** `feat/stage-3-campaign-telemetry`

**Depends on:** Step 1 merged

**Milestone:** A deterministic full-campaign run emits structured, comparable evidence for every objective and outcome without reimplementing gameplay.

## Files

- Modify: `scripts/tools/campaign_sim.gd`
- Modify: `scripts/tools/campaign_sim_metrics.gd`
- Modify: `scripts/tools/campaign_sim_main.gd`
- Modify: `tests/unit/test_campaign_sim.gd`
- Modify: `tests/unit/test_campaign_sim_main.gd`
- Modify: `docs/dev/running-the-game.md` if CLI output/retention has a persistent new workflow

## Red/green tasks

1. Add a failing `CampaignSim` test for one representative run asserting an ordered per-objective record: objective ID, attempt outcome, world-turn interval, party losses, HP/MP recovery observed, gold/resources before and after, upgrades, party composition, and level summary. Keep existing top-level telemetry compatible until callers migrate.
2. Run the focused test with `-gunit_test_name` and confirm it fails because the record is absent, not because a UI or global RNG path is used.
3. Add the smallest record-only hooks at existing public transition points (`_run_encampment_phase`, travel, `_fight_objective`, return). Build battle state only through `ScenarioContract`/`BattleStateFactory`; seed every new random draw from the run RNG.
4. Add failing aggregate/JSON/summary tests requiring the exact seed list, failed-seed details, per-objective summary ranges, and an explicit representative-versus-sweep mode label. Implement those fields in `CampaignSimMetrics` and CLI output; do not label a sweep a guarantee.
5. Run focused checks:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_campaign_sim.gd -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_campaign_sim_main.gd -gexit
   make campaign-sim
   ```

   Expected: byte-identical records for a repeated seed and one labelled report for the documented representative seed list.

## Manual check

Inspect one saved terminal/JSON report. It must let a reviewer identify a setback, recovery interval, objective reached, upgrade timing, and final outcome without reading simulator source.

## Commit and local merge

After user signoff, commit only the listed files as `feat(campaign): record full-arc simulation evidence`, merge locally to `main`, and delete `feat/stage-3-campaign-telemetry`. Do not push or open a PR.
