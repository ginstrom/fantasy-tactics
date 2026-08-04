# Step 01: Debug Scenario State

## Milestone

`DebugScenarios` exposes a six-item named catalogue. Applying a scenario resets
the campaign and creates only valid party/deployment state; GUT tests prove the
setup without loading a scene.

## Setup

The completed first playable loop, including the goblin-camp battle and its
victory/defeat outcome routes, must be merged into `main`.

```bash
git status --short
git checkout main && git pull --ff-only
git checkout -b feat/debug-scenarios
```

## Files

- Create: `scripts/debug/debug_scenarios.gd`
- Create: `scripts/debug/debug_scenarios.gd.uid`
- Create: `tests/unit/test_debug_scenarios.gd`

## Red/green implementation

### 1. Write failing tests

Preload `DebugScenarios`; reset `GameSession` in each test. Test state only:

```gdscript
func test_party_ready_creates_a_staffed_undeployed_party() -> void:
	assert_true(DebugScenarios.apply("party_ready"))
	assert_false(GameSession.has_deployed_party())
	assert_eq(GameSession.get_selected_party().member_ids, ["warrior_001"])

func test_world_map_creates_a_deployed_party_away_from_settlement() -> void:
	assert_true(DebugScenarios.apply("world_map"))
	assert_true(GameSession.has_deployed_party())
	assert_eq(GameSession.get_deployed_party_position(), Vector2i(1, 0))

func test_unknown_scenario_fails_after_reset_without_creating_a_party() -> void:
	assert_false(DebugScenarios.apply("unknown"))
	assert_eq(GameSession.parties, [])
```

Also test `goblin_camp` creates a Warrior-staffed deployed party at `(4, 4)`,
and `scenario_ids()` returns exactly the six IDs in the index in display order.
The scenario helper does not call `GameSession.enter_encounter()`; that remains
the responsibility of `GameManager.enter_battle()` when it routes the scenario.

```bash
make test
```

Expected: FAIL because `DebugScenarios` does not exist.

### 2. Write minimal implementation

Create a `RefCounted` `class_name DebugScenarios` with
`WORLD_MAP_POSITION := Vector2i(1, 0)` and
`GOBLIN_CAMP_POSITION := Vector2i(4, 4)`. Implement `scenario_ids()` as
an ordered constant duplicate.

`apply(scenario_id)` must call `GameSession.start_new_game()` first.
`new_campaign`, `encampment`, and `party_manager` then return `true`;
`party_ready` calls `_create_staffed_party()`; `world_map` and
`goblin_camp` call `_deploy_at(position)`; unknown IDs return `false`.

`_create_staffed_party()` must use only `GameSession.create_party()` and
`GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)`.
`_deploy_at()` uses that helper, `depart_selected_party()`, then
`set_deployed_party_position(position)`, returning `false` on any failure. Do
not construct party dictionaries, write `GameSession.parties`, or route scenes.

In the same branch, add `GameSession.GOBLIN_CAMP_ID := "goblin_camp"` as the
shared campaign encounter identity. Replace the literal in
`scripts/world/world_map.gd` and `scripts/tools/screenshot_tour.gd`; the map
continues to own its `ENCOUNTER_POSITION`, while `GameSession` owns the
campaign-state identifier. Update affected unit tests to use the shared
constant where that improves the assertion.

### 3. Verify green

```bash
make test
make check
rg -n 'GameSession\\.parties\\s*=|GameSession\\.adventurers\\s*=' scripts tests
```

Expected: all GUT tests pass; no production matches outside `game_session.gd`.

## Commit and handoff

```bash
git add scripts/autoload/game_session.gd scripts/debug/debug_scenarios.gd scripts/debug/debug_scenarios.gd.uid scripts/tools/screenshot_tour.gd scripts/world/world_map.gd tests/unit/test_debug_scenarios.gd tests/unit/test_game_session.gd tests/unit/test_world_map.gd
git commit -m "feat: add campaign debug scenarios"
```

No manual check is required. Ask for user approval, then:

```bash
git checkout main && git merge --ff-only feat/debug-scenarios
git branch -d feat/debug-scenarios
git status --short
```

Do not push.
