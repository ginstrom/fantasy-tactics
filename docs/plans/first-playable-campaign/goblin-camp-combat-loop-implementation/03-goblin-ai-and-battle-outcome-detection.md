# Step 03: Goblin AI

## Milestone

`battle_controller.gd` gains `run_enemy_turn()`: called once, synchronously,
with `active_side` already `Side.ENEMY`, it moves every living enemy toward
the nearest living player unit (breaking distance ties by stable reading
order), attacks when adjacent, and returns a fully-resolved, ordered list of
step dictionaries describing what happened. Every rule (movement legality,
occupancy, hit resolution) is the same code path `try_move_selected_unit()`
and `try_attack_selected_unit()` already use, so the AI cannot bypass the
turn rules from step 02. No timers or waiting are involved — the whole
decision and its effects happen in one call, which is what makes it testable
without real delays. Win/loss detection (`is_battle_won()` /
`is_battle_lost()`) already exists from step 02; step 04 is what calls it.

## Setup

```bash
git status --short
git checkout main && git pull --ff-only
git checkout -b feat/goblin-ai
```

## Files

- Modify: `scripts/battle/battle_controller.gd`
- Modify: `tests/unit/test_battle_controller.gd`

## Red/green implementation

### 1. Write failing tests

Add to `tests/unit/test_battle_controller.gd`. Every test must set
`controller.active_side = BattleControllerScript.Side.ENEMY` first, matching
the real flow where `end_turn()` already flipped control before
`run_enemy_turn()` is called:

```gdscript
func test_run_enemy_turn_moves_the_goblin_toward_the_nearest_player_unit() -> void:
	var controller := _make_controller(6, 6)
	var goblin = UnitScript.new(Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 1)
	var player_unit = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 1)
	controller.units = [goblin, player_unit]
	controller.active_side = BattleControllerScript.Side.ENEMY

	var steps: Array = controller.run_enemy_turn()

	assert_eq(steps.size(), 1)
	assert_eq(steps[0].type, "move")
	assert_eq(
		goblin.grid_position,
		Vector2i(4, 3),
		"Of the four adjacent tiles, (4,3) and (3,4) tie for closest to (1,1); reading order picks the smaller y"
	)


func test_run_enemy_turn_attacks_without_moving_when_already_adjacent() -> void:
	var controller := _make_controller(6, 6)
	var goblin = UnitScript.new(
		Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 3, 1, 0.3, "Short Sword"
	)
	var player_unit = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 0.6, "Sword"
	)
	controller.units = [goblin, player_unit]
	controller.active_side = BattleControllerScript.Side.ENEMY
	controller.hit_roll = func() -> float: return 0.0

	var steps: Array = controller.run_enemy_turn()

	assert_eq(steps.size(), 1)
	assert_eq(steps[0].type, "attack")
	assert_true(steps[0].hit)
	assert_eq(steps[0].damage, 1)
	assert_eq(player_unit.health, 2)
	assert_eq(goblin.grid_position, Vector2i(1, 2), "An already-adjacent goblin should not move")


func test_run_enemy_turn_moves_then_attacks_when_movement_closes_the_gap() -> void:
	var controller := _make_controller(6, 6)
	var goblin = UnitScript.new(
		Vector2i(3, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 3, 1, 0.3, "Short Sword"
	)
	var player_unit = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 0.6, "Sword"
	)
	controller.units = [goblin, player_unit]
	controller.active_side = BattleControllerScript.Side.ENEMY
	controller.hit_roll = func() -> float: return 0.0

	var steps: Array = controller.run_enemy_turn()

	assert_eq(steps.size(), 2)
	assert_eq(steps[0].type, "move")
	assert_eq(goblin.grid_position, Vector2i(2, 1))
	assert_eq(steps[1].type, "attack")
	assert_eq(player_unit.health, 2)


func test_run_enemy_turn_breaks_target_ties_using_reading_order() -> void:
	var controller := _make_controller(6, 6)
	var goblin = UnitScript.new(Vector2i(3, 3), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 1)
	var player_a = UnitScript.new(Vector2i(0, 3), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 1)
	var player_b = UnitScript.new(Vector2i(3, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 1)
	controller.units = [goblin, player_a, player_b]
	controller.active_side = BattleControllerScript.Side.ENEMY

	controller.run_enemy_turn()

	assert_eq(
		goblin.grid_position,
		Vector2i(3, 2),
		"Both player units are 3 tiles away; reading order (top-to-bottom) must pick player_b at (3, 0)"
	)


func test_run_enemy_turn_returns_no_steps_when_no_living_player_units_remain() -> void:
	var controller := _make_controller(6, 6)
	var goblin = UnitScript.new(Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [goblin]
	controller.active_side = BattleControllerScript.Side.ENEMY

	var steps: Array = controller.run_enemy_turn()

	assert_eq(steps, [])
	assert_eq(goblin.grid_position, Vector2i(4, 4))
```

Run:

```bash
make test
```

Expected: FAIL — `run_enemy_turn()` does not exist yet.

### 2. Implement the deterministic goblin policy

Add to `scripts/battle/battle_controller.gd`, reusing
`try_move_selected_unit()` and `try_attack_selected_unit()` from step 02 so
the AI is bound by the exact same legality and hit-resolution rules as the
player:

```gdscript
const ENEMY_STEP_MOVE := "move"
const ENEMY_STEP_ATTACK := "attack"


func run_enemy_turn() -> Array:
	var steps: Array = []
	for unit in units.duplicate():
		if not unit.is_alive() or unit.side != Side.ENEMY:
			continue
		steps.append_array(_take_enemy_unit_actions(unit))
	selected_unit = null
	return steps


func _take_enemy_unit_actions(unit) -> Array:
	var steps: Array = []
	var target = _nearest_living_unit(unit.grid_position, Side.PLAYER)
	if target == null:
		return steps

	selected_unit = unit

	if not target.grid_position in grid.get_adjacent(unit.grid_position):
		var destination := _best_move_toward(unit, target.grid_position)
		var from := unit.grid_position
		if destination != from and try_move_selected_unit(destination):
			steps.append({"type": ENEMY_STEP_MOVE, "unit": unit, "from": from, "to": destination})

	if not unit.has_acted and target.is_alive() and target.grid_position in grid.get_adjacent(unit.grid_position):
		if try_attack_selected_unit(target.grid_position):
			steps.append(last_attack_result)

	return steps


func _nearest_living_unit(from_pos: Vector2i, side: int):
	var nearest = null
	var nearest_distance := -1
	for unit in units:
		if unit.side != side or not unit.is_alive():
			continue
		var distance := _grid_distance(from_pos, unit.grid_position)
		if (
			nearest == null
			or distance < nearest_distance
			or (distance == nearest_distance and _reading_order_is_earlier(unit.grid_position, nearest.grid_position))
		):
			nearest = unit
			nearest_distance = distance
	return nearest


func _best_move_toward(unit, target_pos: Vector2i) -> Vector2i:
	var best := unit.grid_position
	var best_distance := _grid_distance(unit.grid_position, target_pos)
	var has_candidate := false
	for candidate in get_legal_moves(unit):
		var candidate_distance := _grid_distance(candidate, target_pos)
		if (
			not has_candidate
			or candidate_distance < best_distance
			or (candidate_distance == best_distance and _reading_order_is_earlier(candidate, best))
		):
			best = candidate
			best_distance = candidate_distance
			has_candidate = true
	return best


func _grid_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


func _reading_order_is_earlier(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x
```

`_take_enemy_unit_actions()` reuses the same `last_attack_result` dictionary
`try_attack_selected_unit()` already builds in step 02 (keys `type`,
`attacker`, `defender`, `hit`, `damage`, `defeated`), so the returned step
list uses one consistent shape for both move steps (`type`, `unit`, `from`,
`to`) and attack steps, whether the attacker was the player or the goblin.
Step 04's presentation layer will consume this same shape for both.

### 3. Verify green

```bash
make test
make check
```

Expected: all GUT tests pass, including every test from steps 01–02 and the
new AI tests above.

## Commit and handoff

```bash
git add scripts/battle/battle_controller.gd tests/unit/test_battle_controller.gd
git commit -m "feat: add deterministic goblin AI turn resolution"
```

No manual check is required for this step — `run_enemy_turn()` is not wired
to anything visible yet. Ask for user approval, then:

```bash
git checkout main && git merge --ff-only feat/goblin-ai
git branch -d feat/goblin-ai
git status --short
```

Do not push.
