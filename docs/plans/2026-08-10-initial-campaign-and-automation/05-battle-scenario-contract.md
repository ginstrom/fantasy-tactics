# Step 5: Define Validated, Expanded Battle Scenarios

## Milestone

Declarative scenario data expands deterministically into validated concrete cases without scenes, debug scenarios, or campaign rewards.

## Setup and files

Start only after campaign readiness has merged locally:

```bash
git checkout main && git pull
git checkout -b feature/battle-scenario-runner
```

Read `scripts/tools/battle_sim.gd`, `scripts/tools/battle_bot.gd`, `scripts/battle/battle_controller.gd`, and `tests/unit/test_battle_controller.gd`.

- Create: `scripts/tools/battle_scenarios/scenario_contract.gd`, `scenario_expander.gd`, `battle_state_factory.gd`
- Create: `tests/unit/test_scenario_contract.gd`, `test_scenario_expander.gd`, `test_battle_state_factory.gd`

## Red

Specify `contract_version`, `scenario_id`, `board`, `player`, `enemy`, `rules`, `policies`, `randomness`, and `labels`. Prove single-case normalization, sorted named-axis expansion to stable case IDs, reproducible derived iteration seeds, and pre-construction failure for duplicate IDs, invalid limits, unknown template/policy, overlap/out-of-bounds positions, and unsupported counts. Explicit modifiers must affect constructed units only, never `GameConfig`/campaign state.

Run focused contract/expander tests; expected: FAIL because the types are absent.

## Green

Implement pure normalization/validation and deterministic matrix expansion. `BattleStateFactory` builds only grid, units, stats, positions, sides, and injected RNG callables. It reads existing template/equipment definitions through explicit read-only helpers, never `GameSession.selected_encounter`. It exposes the public action surface used by `BattleBot` and enemy turns. Do not modify `battle_sim` yet.

Run focused tests, `make check`, editor scan, and `git diff --check`.

## Commit and handoff

```bash
git add scripts/tools/battle_scenarios tests/unit/test_scenario_contract.gd tests/unit/test_scenario_expander.gd tests/unit/test_battle_state_factory.gd
git commit -m "feat: define deterministic battle scenarios"
```

Completion: all executable cases are normalized/validated before construction. Do not merge until Step 8 user signoff.
