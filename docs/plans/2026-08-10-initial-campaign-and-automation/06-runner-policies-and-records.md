# Step 6: Run Seeded Policies and Record Every Iteration

## Milestone

The runner drives legal public battle actions for named policies, classifies every run, and emits reproducible JSONL without campaign/UI effects.

## Setup and files

Work after Step 5. Read `battle_bot.gd`, enemy-turn methods in `battle_controller.gd`, and the simulator section of `docs/dev/running-the-game.md`.

- Create: `scripts/tools/battle_scenarios/policy.gd`, `greedy_player_policy.gd`, `current_enemy_policy.gd`, `seeded_random.gd`, `scenario_runner.gd`
- Create: `tests/unit/test_scenario_runner.gd`
- Modify: `tests/unit/test_battle_bot.gd`
- Modify: `scripts/battle/battle_controller.gd` and its test only if a minimal shared public extraction is required.

## Red

Use a tiny fixed case to assert same scenario/seed produces matching records except `elapsed_ms`; seeds are derived/stored per iteration; greedy adapter matches `BattleBot`; enemy adapter invokes shipped rules rather than copied logic; cap yields `stalemate`; illegal policy intent yields `error` with machine-readable reason; and neither is silently counted as a loss.

Assert records include contract/runner/engine versions, normalized case, config fingerprint, policies, outcome, rounds, attempts/rejections, damage, kills, survivors/health, seeds, and raw-record metadata. Assert runner never calls `DebugScenarios`, `GameManager`, or reward settlement. Run focused runner tests; expected: FAIL because runner/policies are absent.

## Green

Implement policy interface using immutable legal-state view plus supplied RNG stream. Validate/apply intents using factory/controller public movement, attack, and turn behavior. Adapt existing `BattleBot` and current enemy AI; only extract a tested common helper when direct adaptation cannot preserve shipped behavior. Use deterministic RNG for both hit/damage. Convert setup/policy faults into one `error` record and write a caller-provided fresh JSONL file—never append.

Run focused runner/bot/controller tests, `make check`, editor scan, and `git diff --check`.

## Commit and handoff

```bash
git add scripts/tools/battle_scenarios tests/unit/test_scenario_runner.gd tests/unit/test_battle_bot.gd
git commit -m "feat: run seeded battle policies"
```

Add controller files only if changed. Do not merge before Step 8 user signoff.
