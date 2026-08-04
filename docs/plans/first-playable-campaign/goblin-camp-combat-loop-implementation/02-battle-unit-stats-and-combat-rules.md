# Step 02: Battle Unit Stats and Combat Rules

## Milestone

`unit.gd` carries health and attack stats. `battle_controller.gd` (the
`Grid` node) spawns exactly one Warrior (3 HP, move 3, Sword, 2 dmg, 60% hit)
and one Goblin (3 HP, move 3, Short Sword, 1 dmg, 30% hit) on the existing
6×6 board. A selected unit can move once and attack once per turn in either
order, through an injectable roll source so hit and miss are both provable
under test. A defeated unit is removed from `units` and can no longer act or
be targeted. `is_battle_won()` and `is_battle_lost()` report the two
outcomes that step 04 will route through the campaign.

## Setup

```bash
git status --short
git checkout main && git pull --ff-only
git checkout -b feat/battle-combat-rules
```

## Files

- Modify: `scripts/battle/unit.gd`
- Modify: `scripts/battle/battle_controller.gd`
- Modify: `tests/unit/test_battle_controller.gd`

## Red/green implementation

### 1. Write failing tests

Add these to `tests/unit/test_battle_controller.gd`, alongside the existing
movement tests (which must keep passing unchanged — they rely on the
2-argument and 4-argument `Unit.new()` calls staying valid):

```gdscript
func test_ready_spawns_the_documented_warrior_and_goblin() -> void:
	var controller: Node2D = BattleControllerScript.new()
	add_child_autofree(controller)

	assert_eq(controller.units.size(), 2)
	var warrior = controller.get_unit_at(Vector2i(1, 1))
	var goblin = controller.get_unit_at(Vector2i(4, 4))
	assert_not_null(warrior, "Warrior should spawn at (1, 1)")
	assert_not_null(goblin, "Goblin should spawn at (4, 4)")
	assert_eq(warrior.side, BattleControllerScript.Side.PLAYER)
	assert_eq(warrior.max_health, 3)
	assert_eq(warrior.move_range, 3)
	assert_eq(warrior.attack_damage, 2)
	assert_eq(warrior.hit_chance, 0.6)
	assert_eq(goblin.side, BattleControllerScript.Side.ENEMY)
	assert_eq(goblin.max_health, 3)
	assert_eq(goblin.move_range, 3)
	assert_eq(goblin.attack_damage, 1)
	assert_eq(goblin.hit_chance, 0.3)


func test_attack_hits_and_deals_damage_when_the_roll_is_below_hit_chance() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 0.6, "Sword"
	)
	var defender = UnitScript.new(
		Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 3, 1, 0.3, "Short Sword"
	)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_true(attacked)
	assert_eq(defender.health, 1, "A hit applies the attacker's fixed damage")
	assert_true(attacker.has_acted)


func test_attack_misses_and_deals_no_damage_when_the_roll_is_at_or_above_hit_chance() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 0.6, "Sword"
	)
	var defender = UnitScript.new(
		Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 3, 1, 0.3, "Short Sword"
	)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.99

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_true(attacked)
	assert_eq(defender.health, 3, "A miss must not change the defender's health")


func test_attack_defeats_and_removes_the_target_when_health_reaches_zero() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 0.6, "Sword"
	)
	var defender = UnitScript.new(
		Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 1, 1, 0.3, "Short Sword"
	)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0

	controller.try_attack_selected_unit(defender.grid_position)

	assert_false(defender.is_alive())
	assert_eq(controller.units, [attacker], "A defeated unit is removed from the board")
	assert_null(controller.get_unit_at(defender.grid_position))


func test_attack_is_rejected_against_a_non_adjacent_target() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var defender = UnitScript.new(Vector2i(5, 5), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_false(attacked)
	assert_eq(defender.health, defender.max_health)


func test_attack_is_rejected_a_second_time_in_the_same_turn() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 5)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.try_attack_selected_unit(defender.grid_position)
	controller.selected_unit = attacker

	var attacked_again: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_false(attacked_again, "A unit that already attacked this turn cannot attack again")


func test_attack_is_rejected_for_a_unit_on_the_inactive_side() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.ENEMY, 3)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.active_side = BattleControllerScript.Side.PLAYER

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_false(attacked)


func test_unit_can_move_then_attack_in_the_same_turn() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var defender = UnitScript.new(Vector2i(2, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker

	var moved: bool = controller.try_move_selected_unit(Vector2i(2, 1))
	controller.selected_unit = attacker
	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_true(moved)
	assert_true(attacked)


func test_unit_can_attack_then_move_in_the_same_turn() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)
	controller.selected_unit = attacker
	var moved: bool = controller.try_move_selected_unit(Vector2i(2, 1))

	assert_true(attacked, "Attacking first must still be legal")
	assert_true(moved, "Moving after attacking must still be legal — order does not matter")


func test_end_turn_resets_has_acted_for_the_newly_active_side() -> void:
	var controller := _make_controller(6, 6)
	var player_unit = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var enemy_unit = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [player_unit, enemy_unit]
	controller.active_side = BattleControllerScript.Side.PLAYER
	controller.selected_unit = player_unit
	controller.try_attack_selected_unit(enemy_unit.grid_position)

	controller.end_turn()
	controller.end_turn()

	assert_false(player_unit.has_acted, "The player's unit regains its attack on its next turn")


func test_is_battle_won_when_no_living_enemies_remain() -> void:
	var controller := _make_controller(6, 6)
	var player_unit = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [player_unit]

	assert_true(controller.is_battle_won())
	assert_false(controller.is_battle_lost())


func test_is_battle_lost_when_no_living_player_units_remain() -> void:
	var controller := _make_controller(6, 6)
	var enemy_unit = UnitScript.new(Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [enemy_unit]

	assert_true(controller.is_battle_lost())
	assert_false(controller.is_battle_won())
```

Run:

```bash
make test
```

Expected: FAIL — `Unit.new()` does not yet accept the extra stat arguments,
and `battle_controller.gd` has no `hit_roll`, `try_attack_selected_unit()`,
`is_battle_won()`, or `is_battle_lost()`.

### 2. Extend `Unit` with health and attack stats

Replace `scripts/battle/unit.gd` in full:

```gdscript
extends RefCounted

var grid_position: Vector2i
var color: Color
var side: int
var move_range: int
var has_moved: bool = false
var has_acted: bool = false
var max_health: int
var health: int
var attack_damage: int
var hit_chance: float
var attack_name: String


func _init(
	p_grid_position: Vector2i,
	p_color: Color,
	p_side: int = 0,
	p_move_range: int = 1,
	p_max_health: int = 3,
	p_attack_damage: int = 1,
	p_hit_chance: float = 1.0,
	p_attack_name: String = "Attack"
) -> void:
	grid_position = p_grid_position
	color = p_color
	side = p_side
	move_range = p_move_range
	max_health = p_max_health
	health = p_max_health
	attack_damage = p_attack_damage
	hit_chance = p_hit_chance
	attack_name = p_attack_name


func is_alive() -> bool:
	return health > 0


func take_damage(amount: int) -> void:
	health = max(0, health - amount)
```

The four new trailing parameters all have defaults, so every existing
`Unit.new(position, color)` and `Unit.new(position, color, side, move_range)`
call site keeps working unchanged.

### 3. Add stats, attacks, and outcome checks to `battle_controller.gd`

Add stat constants near the existing `UNIT_MOVE_RANGE` constant:

```gdscript
const WARRIOR_START := Vector2i(1, 1)
const WARRIOR_COLOR := Color(0.3, 0.5, 0.9)
const WARRIOR_MAX_HEALTH := 3
const WARRIOR_ATTACK_DAMAGE := 2
const WARRIOR_HIT_CHANCE := 0.6
const WARRIOR_ATTACK_NAME := "Sword"

const GOBLIN_START := Vector2i(4, 4)
const GOBLIN_COLOR := Color(0.9, 0.4, 0.3)
const GOBLIN_MAX_HEALTH := 3
const GOBLIN_ATTACK_DAMAGE := 1
const GOBLIN_HIT_CHANCE := 0.3
const GOBLIN_ATTACK_NAME := "Short Sword"
```

Add a member so tests can force a deterministic roll, and a place to read
the last attack's outcome:

```gdscript
var hit_roll: Callable = func() -> float: return randf()
var last_attack_result: Dictionary = {}
```

Update `_ready()` to spawn the documented units:

```gdscript
func _ready() -> void:
	grid = GridScript.new(GRID_WIDTH, GRID_HEIGHT)
	units = [
		UnitScript.new(
			WARRIOR_START, WARRIOR_COLOR, Side.PLAYER, UNIT_MOVE_RANGE,
			WARRIOR_MAX_HEALTH, WARRIOR_ATTACK_DAMAGE, WARRIOR_HIT_CHANCE, WARRIOR_ATTACK_NAME
		),
		UnitScript.new(
			GOBLIN_START, GOBLIN_COLOR, Side.ENEMY, UNIT_MOVE_RANGE,
			GOBLIN_MAX_HEALTH, GOBLIN_ATTACK_DAMAGE, GOBLIN_HIT_CHANCE, GOBLIN_ATTACK_NAME
		),
	]
	_draw_tiles()
	_draw_units()
	_update_highlights()
```

Add the attack action next to `try_move_selected_unit()`:

```gdscript
func try_attack_selected_unit(target_pos: Vector2i) -> bool:
	if selected_unit == null or not selected_unit.is_alive():
		return false
	if selected_unit.side != active_side:
		return false
	if selected_unit.has_acted:
		return false
	if not target_pos in grid.get_adjacent(selected_unit.grid_position):
		return false

	var target = get_unit_at(target_pos)
	if target == null or target.side == selected_unit.side or not target.is_alive():
		return false

	selected_unit.has_acted = true
	var hit: bool = hit_roll.call() < selected_unit.hit_chance
	var damage: int = selected_unit.attack_damage if hit else 0
	if hit:
		target.take_damage(damage)
	var defeated: bool = hit and not target.is_alive()
	if defeated:
		units.erase(target)

	last_attack_result = {
		"type": "attack",
		"attacker": selected_unit,
		"defender": target,
		"hit": hit,
		"damage": damage,
		"defeated": defeated,
	}
	return true
```

Have a successful move clear any stale attack result, so a later
presentation layer never reports an attack that isn't current:

```gdscript
func try_move_selected_unit(target: Vector2i) -> bool:
	if selected_unit == null:
		return false
	if selected_unit.side != active_side:
		return false
	if not target in get_legal_moves(selected_unit):
		return false

	selected_unit.grid_position = target
	selected_unit.has_moved = true
	last_attack_result = {}
	return true
```

Reset `has_acted` alongside `has_moved` in `end_turn()`:

```gdscript
func end_turn() -> void:
	active_side = Side.ENEMY if active_side == Side.PLAYER else Side.PLAYER
	for unit in units:
		if unit.side == active_side:
			unit.has_moved = false
			unit.has_acted = false
	_select_unit(null)
```

Add the outcome checks:

```gdscript
func is_battle_won() -> bool:
	for unit in units:
		if unit.side == Side.ENEMY and unit.is_alive():
			return false
	return true


func is_battle_lost() -> bool:
	for unit in units:
		if unit.side == Side.PLAYER and unit.is_alive():
			return false
	return true
```

Finally, let a click on a living enemy attack instead of being ignored, and
only clear the selection once the selected unit has spent both actions or
been defeated. Replace `_handle_tile_click()`:

```gdscript
func _handle_tile_click(tile_pos: Vector2i) -> void:
	var clicked_unit = get_unit_at(tile_pos)

	if clicked_unit != null and clicked_unit.side == active_side:
		_select_unit(clicked_unit)
		return

	if clicked_unit != null and selected_unit != null and clicked_unit.side != active_side:
		if try_attack_selected_unit(tile_pos):
			_draw_units()
			_select_unit_after_action()
		return

	if clicked_unit == null and try_move_selected_unit(tile_pos):
		_draw_units()
		_select_unit_after_action()


func _select_unit_after_action() -> void:
	if selected_unit == null or not selected_unit.is_alive():
		_select_unit(null)
		return
	if selected_unit.has_moved and selected_unit.has_acted:
		_select_unit(null)
		return
	_select_unit(selected_unit)
```

### 4. Verify green

```bash
make test
make check
```

Expected: all GUT tests pass, including every pre-existing movement test in
`test_battle_controller.gd` and the new attack/outcome tests above.

## Commit and handoff

```bash
git add scripts/battle/unit.gd scripts/battle/battle_controller.gd tests/unit/test_battle_controller.gd
git commit -m "feat: add unit stats, attacks, and outcome checks to the battle controller"
```

No manual check is required for this step (nothing new is wired to the HUD
yet). Ask for user approval, then:

```bash
git checkout main && git merge --ff-only feat/battle-combat-rules
git branch -d feat/battle-combat-rules
git status --short
```

Do not push.
