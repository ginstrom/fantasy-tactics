# Step 3: Side-Effect-Free Debug Launch

## Objective

Route a successfully applied debug scenario to its declared screen without changing the configured campaign state. The normal campaign routes retain their reward and encounter semantics.

## Setup

```bash
git checkout main && git pull
git checkout -b feat/debug-scenario-launch
```

Read `scripts/autoload/game_manager.gd`, especially `go_to_encampment()`, `go_to_world_map()`, and `enter_battle()`, plus `tests/unit/test_game_manager.gd`.

## Red / green work

1. Add failing `test_game_manager.gd` tests for each permitted `launch.scene`: settlement, Encampment, Party Manager, World Map, Stores, and Battlefield.
2. Seed fixtures containing non-zero `pending_reward`, `battle_reward`, and a selected encounter. Assert every debug launch leaves the exported snapshot unchanged after routing; in particular, World Map must not merge battle loot and Encampment must not deposit pending reward.
3. Add failure tests for unknown scenario IDs, unrecognized launch scenes, unavailable debug builds, and battlefield fixtures without a selected encounter. Each returns a meaningful `Error` and changes neither scene nor session.
4. Run the focused test and confirm red.
5. In `GameManager`, add a narrowly scoped debug-only dispatcher that validates the loaded manifest and changes directly to the corresponding scene after `DebugScenarios.apply()` succeeds. Reuse normal route validation only where it has no state transition; do not call `go_to_encampment()`, `go_to_world_map()`, or `enter_battle()` for debug launch.
6. Keep the supported launch list explicit. Do not expose detail routes such as Assign Equipment until the manifest supplies and validates their required stable context IDs; `go_to_assign_equipment()` requires an item ID.
7. Rerun the focused tests and `make check`.

## Constraints

The dispatcher owns navigation only. `GameSession` remains the sole owner of snapshot state; `DebugScenarios` remains the manifest/application adapter. Battlefield fixtures use the selected encounter and current standard battle construction only. Custom squads and custom positions are deferred to an adapter built on `ScenarioContract`, not a `GameSession.debug_battle_override` field.

## Milestone and manual check

Use `make play`, press F9, and run `Stocked Stores`, `World Map`, and `Goblin Camp`. Confirm each requested screen opens and that returning to inspect the configured reward buckets shows no bank/merge caused by launch.

## Handoff

After user sign-off, run `godot --headless --path . --editor --quit` and `git diff --check`, commit `feat: route debug scenarios without campaign side effects`, merge `feat/debug-scenario-launch` locally into `main`, and delete the branch. Do not push.
