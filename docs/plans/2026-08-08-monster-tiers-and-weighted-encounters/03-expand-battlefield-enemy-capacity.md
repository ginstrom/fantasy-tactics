# Step 3: Expand battlefield enemy capacity to 8

**Depends on:** nothing from Step 2 directly — this is independent
infrastructure, but comes after it in sequence per index.md.

**Produces:** `BattleController.ENEMY_START_POSITIONS` grows from 3 to 8
entries, and `_ready()`'s `mini(enemy_count, ENEMY_START_POSITIONS.size())`
cap stops silently dropping enemies beyond the third. Today, an expedition
whose resolved `enemy.count` is greater than 3 (impossible until Step 4, but
this step must land first so Step 4 doesn't introduce a site nothing can
actually field) only ever spawns 3 units.

## Setup

```bash
git checkout main && git pull
git checkout -b expand-battlefield-enemy-capacity
```

## Steps

- [ ] **Step 1: Write the failing tests (RED)**

  Add to `tests/unit/test_battle_controller.gd` (near the other `_ready()`
  tests, e.g. after `test_ready_builds_one_goblin_when_the_goblin_camp_is_selected`):

  ```gdscript
  func test_enemy_start_positions_supports_up_to_eight_enemies() -> void:
  	assert_eq(BattleControllerScript.ENEMY_START_POSITIONS.size(), 8)


  func test_ready_fields_up_to_eight_enemies_when_the_encounter_has_that_many() -> void:
  	GameSession.reset()
  	var enemy_stats: Dictionary = GameSession.GOBLIN_ENEMY_STATS.duplicate(true)
  	enemy_stats["count"] = 8
  	GameSession.active_encounters.append({
  		"id": "capacity_test",
  		"template_id": GameSession.GOBLIN_CAMP_ID,
  		"position": Vector2i(2, 2),
  		"name_key": "expedition.goblin_camp.name",
  		"danger_key": "expedition.danger.low",
  		"difficulty": 1,
  		"kill_xp": 5,
  		"clear_xp": 10,
  		"enemy": enemy_stats,
  	})
  	GameSession.selected_encounter = "capacity_test"
  	var battlefield: Node2D = BattlefieldScene.instantiate()
  	add_child_autofree(battlefield)
  	var controller: Node2D = battlefield.grid

  	var enemy_units: Array = []
  	for unit in controller.units:
  		if unit.side == BattleControllerScript.Side.ENEMY:
  			enemy_units.append(unit)
  	assert_eq(enemy_units.size(), 8, "All eight enemy start positions should be usable")

  	var seen_positions: Array[Vector2i] = []
  	for unit in enemy_units:
  		assert_true(controller.grid.is_in_bounds(unit.grid_position), "Every enemy start position must be on the board")
  		assert_false(seen_positions.has(unit.grid_position), "No two enemies should share a start tile")
  		seen_positions.append(unit.grid_position)
  ```

  Check the top of `tests/unit/test_battle_controller.gd` for how
  `BattlefieldScene` is already preloaded in this file (other tests in it
  already use `BattlefieldScene.instantiate()`); reuse that same constant
  rather than adding a second preload.

- [ ] **Step 2: Run it and confirm it fails**

  Run: `make test`
  Expected: FAIL — `test_enemy_start_positions_supports_up_to_eight_enemies`
  fails because the array currently has 3 entries; the fielding test fails
  because only 3 of the 8 requested enemies spawn.

- [ ] **Step 3: Expand the position list (GREEN)**

  Edit `scripts/battle/battle_controller.gd` — the grid is already 6x6
  (`GRID_WIDTH`/`GRID_HEIGHT` = 6, valid coordinates 0-5).
  `PLAYER_START_POSITIONS` only ever occupies `(0,0)-(2,1)`, so an 8-tile
  block in the opposite corner has no overlap risk. Replace
  `ENEMY_START_POSITIONS` (around line 41-43):

  ```gdscript
  const ENEMY_START_POSITIONS: Array[Vector2i] = [
  	Vector2i(5, 5), Vector2i(4, 5), Vector2i(5, 4), Vector2i(3, 5),
  	Vector2i(4, 4), Vector2i(5, 3), Vector2i(3, 4), Vector2i(4, 3),
  ]
  ```

  No other code change is needed: `_ready()`'s existing `for index in
  mini(enemy_count, ENEMY_START_POSITIONS.size())` loop (around line 84)
  already scales to however many positions the array holds.

- [ ] **Step 4: Run the full suite and confirm everything passes**

  Run: `make check`
  Expected: PASS, with zero failures.

- [ ] **Step 5: Manual verification**

  Run `make play`, open the F9 debug menu, and use "Orc Outpost Battle" a
  few times (retry until you see the two-Goblin roll, if needed) — confirm
  both Goblins still spawn at distinct, sensible tiles in the bottom-right
  of the board, with no visual overlap. This step doesn't yet have a way to
  reach 8 enemies through real play (that's Step 6's debug scenario) — the
  automated test above is the primary verification for the 8-enemy case.

- [ ] **Step 6: Commit**

  ```bash
  git add scripts/battle/battle_controller.gd tests/unit/test_battle_controller.gd
  git commit -m "feat: expand battlefield enemy capacity from 3 to 8"
  ```

## Merge back to main

Get the user's signoff on Step 5, then:

```bash
git checkout main
git merge expand-battlefield-enemy-capacity
git branch -d expand-battlefield-enemy-capacity
```
