# Step 7: Expose the Runner and Produce a Small Baseline Suite

## Milestone

Developers can run selected scenarios into a unique directory, inspect aggregate evidence tied to raw records, and compare completed reports without implicit reruns.

## Setup and files

Work after Step 6. Read `scripts/tools/battle_sim_main.gd`, `Makefile`, and `docs/dev/running-the-game.md`. Never commit generated JSONL/report artifacts.

- Create: `scripts/tools/battle_scenarios/scenario_runner_main.gd`, `report_aggregator.gd`, `report_compare.gd`
- Create: `scenarios/battle/baseline-party-viability.json`, `baseline-count-pressure.json`, `baseline-offense.json`, `baseline-defense.json`, `baseline-policy-comparison.json`
- Create: `tests/unit/test_report_aggregator.gd`, `tests/unit/test_scenario_runner_main.gd`
- Modify: `Makefile`, `docs/dev/running-the-game.md`, and `.gitignore` only if needed.

## Red

Test CLI parsing for `--scenario`, `--seed`, `--iterations`, `--axis=name=value`, `--output-dir`, and `--format=json|table`; reject malformed input before output. With fixture records, test runs/wins/losses/stalemates/errors, win rate plus sample count, mean/percentile rounds, mean damage, survivor/health distributions, grouping by scenario/policy, raw-record path, and command/config metadata.

Assert output directories use unique timestamp-seed plus collision suffix. Assert report comparison only reads two completed reports and never invokes the runner. Run focused tests; expected: FAIL because entry/report code is absent.

## Green

Add `make scenario` accepting `SCENARIO`, `SEED`, `ITERATIONS`, and `OUTPUT_DIR`. Default to a unique `user://battle-scenarios/` directory containing `records.jsonl`, `report.json`, and optional table. Fingerprint exact `config/game_config.json` text in records/reports. Retain append-only `make simulate` as the scene-driven smoke client; document the different purposes.

Add the design’s small matrices: 1–4 Warriors versus Goblin/Orc; 1–8 enemy count pressure; attack/weapon variants; defense/resistance variants; baseline versus experimental policy. Definitions state inputs only, never target win rates or balance conclusions.

```bash
make scenario SCENARIO=scenarios/battle/baseline-party-viability.json SEED=20260810 ITERATIONS=20
```

Expected: a unique output directory and 20 records per concrete case. Then run focused tests, `make check`, editor scan, and `git diff --check`.

## Commit and handoff

```bash
git add scripts/tools/battle_scenarios scenarios/battle Makefile docs/dev/running-the-game.md
git commit -m "feat: report reproducible battle scenarios"
```

Add test files and `.gitignore` when changed; never stage generated output. Do not merge before Step 8 user signoff.
