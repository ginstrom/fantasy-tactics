# Task 04: `BattleController` rolls weapon damage and applies defense/resistance

## Objective

Make `BattleController` field player units with the equipped weapon's
damage range and equipped armor's defense/resistance (Task 02's getters),
roll damage from that range through an injectable callable, and apply
defense to the hit-chance check and resistance to the damage dealt. This is
the task that turns Task 03's now-broken call sites green again.

## Files

- Modify: `scripts/battle/battle_controller.gd`
- Test: `tests/unit/test_battle_controller.gd`, `tests/unit/test_debug_menu.gd`,
  `tests/unit/test_game_manager.gd`

## Depends on

Task 02 (`GameSession.get_effective_weapon_damage_range`,
`get_effective_weapon_name`, `get_effective_defense`,
`get_effective_resistance`), Task 03 (`Unit`'s new constructor shape).

## Produces

`BattleController.damage_roll: Callable` (signature `func(min_value: int,
max_value: int) -> int`, default `randi_range`), `BattleController.
MIN_HIT_CHANCE: float = 0.05`. `try_attack_selected_unit()`'s resolved
damage is now `round(damage_roll.call(attacker.damage_min,
attacker.damage_max) * (1.0 - target.resistance / 100.0))`, and the roll
against which `hit_roll.call()` is compared is
`maxf(attacker.hit_chance - target.defense / 100.0, MIN_HIT_CHANCE)` instead
of the raw `attacker.hit_chance`.

## Steps

1. **Write the new failing tests.** Add to `tests/unit/test_battle_controller.gd`:

   ```gdscript
   func test_attack_damage_is_rolled_between_the_attackers_min_and_max() -> void:
   	var controller := _make_controller(6, 6)
   	var attacker = UnitScript.new(
   		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 8, 0.6, "Longsword"
   	)
   	var defender = UnitScript.new(
   		Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 20, 1, 1, 0.3, "Short Sword"
   	)
   	controller.units = [attacker, defender]
   	controller.selected_unit = attacker
   	controller.hit_roll = func() -> float: return 0.0
   	controller.damage_roll = func(min_value: int, max_value: int) -> int:
   		assert_eq(min_value, 2)
   		assert_eq(max_value, 8)
   		return 5

   	controller.try_attack_selected_unit(defender.grid_position)

   	assert_eq(defender.health, 15, "A rolled damage of 5 with no resistance should apply in full")


   func test_attack_applies_the_defenders_resistance_rounded_to_the_nearest_integer() -> void:
   	var controller := _make_controller(6, 6)
   	var attacker = UnitScript.new(
   		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 10, 10, 0.6, "Longsword"
   	)
   	var defender = UnitScript.new(
   		Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 20, 1, 1, 0.3, "Short Sword", "", 0, 10
   	)
   	controller.units = [attacker, defender]
   	controller.selected_unit = attacker
   	controller.hit_roll = func() -> float: return 0.0
   	controller.damage_roll = func(_min_value: int, _max_value: int) -> int: return 10

   	controller.try_attack_selected_unit(defender.grid_position)

   	assert_eq(defender.health, 11, "10% resistance turns 10 damage into 9 (round(10 * 0.9) = 9)")


   func test_attack_hit_chance_is_reduced_by_the_defenders_defense_but_floors_at_the_minimum() -> void:
   	var controller := _make_controller(6, 6)
   	var attacker = UnitScript.new(
   		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.3, "Dagger"
   	)
   	var defender = UnitScript.new(
   		Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 20, 1, 1, 0.3, "Short Sword", "", 0, 0
   	)
   	defender.defense = 50
   	controller.units = [attacker, defender]
   	controller.selected_unit = attacker
   	var observed_threshold := 0.0
   	controller.hit_roll = func() -> float:
   		observed_threshold = 0.04
   		return observed_threshold

   	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

   	assert_true(attacked)
   	assert_eq(defender.health, 20, "0.3 hit chance minus 50 defense floors at 0.05; a 0.04 roll must still miss")
   ```

2. **Run the tests to verify they fail.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd -gunit_test_name=attack_damage_is_rolled -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd -gunit_test_name=attack_applies_the_defenders_resistance -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd -gunit_test_name=attack_hit_chance_is_reduced -gexit
   ```

   Expected: FAIL — `Invalid access to property or key 'damage_roll'`,
   and/or wrong `defender.health` values (the current code still uses
   `selected_unit.attack_damage` and the raw `hit_chance` with no
   defense/resistance term).

3. **Implement in `scripts/battle/battle_controller.gd`.** Remove the
   `WARRIOR_ATTACK_DAMAGE` and `WARRIOR_ATTACK_NAME` consts (lines 45-49):

   ```gdscript
   const WARRIOR_ATTACK_DAMAGE := 2
   const WARRIOR_ATTACK_NAME := "Sword"
   ```

   Add next to `const UNIT_MOVE_RANGE := 3`:

   ```gdscript
   const MIN_HIT_CHANCE := 0.05
   ```

   Add next to `var hit_roll: Callable = func() -> float: return randf()`:

   ```gdscript
   var damage_roll: Callable = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
   ```

   Replace the player-unit construction loop inside `_ready()`:

   ```gdscript
   	for index in mini(_player_adventurer_ids.size(), PLAYER_START_POSITIONS.size()):
   		var adventurer_id: String = _player_adventurer_ids[index]
   		units.append(UnitScript.new(
   			PLAYER_START_POSITIONS[index], PLAYER_COLORS[index % PLAYER_COLORS.size()], Side.PLAYER,
   			GameSession.get_effective_move_range(adventurer_id),
   			GameSession.get_effective_max_health(adventurer_id),
   			WARRIOR_ATTACK_DAMAGE,
   			GameSession.get_effective_hit_chance(adventurer_id),
   			WARRIOR_ATTACK_NAME,
   			adventurer_id
   		))
   ```

   with:

   ```gdscript
   	for index in mini(_player_adventurer_ids.size(), PLAYER_START_POSITIONS.size()):
   		var adventurer_id: String = _player_adventurer_ids[index]
   		var damage_range: Vector2i = GameSession.get_effective_weapon_damage_range(adventurer_id)
   		units.append(UnitScript.new(
   			PLAYER_START_POSITIONS[index], PLAYER_COLORS[index % PLAYER_COLORS.size()], Side.PLAYER,
   			GameSession.get_effective_move_range(adventurer_id),
   			GameSession.get_effective_max_health(adventurer_id),
   			damage_range.x,
   			damage_range.y,
   			GameSession.get_effective_hit_chance(adventurer_id),
   			GameSession.get_effective_weapon_name(adventurer_id),
   			adventurer_id,
   			GameSession.get_effective_defense(adventurer_id),
   			GameSession.get_effective_resistance(adventurer_id)
   		))
   ```

   Replace the enemy-unit construction loop:

   ```gdscript
   	for index in mini(enemy_count, ENEMY_START_POSITIONS.size()):
   		units.append(UnitScript.new(
   			ENEMY_START_POSITIONS[index], ENEMY_COLOR, Side.ENEMY, UNIT_MOVE_RANGE,
   			enemy_stats.max_health, enemy_stats.attack_damage, enemy_stats.hit_chance,
   			tr(enemy_stats.attack_name_key)
   		))
   ```

   with (min == max preserves each enemy's existing fixed damage exactly):

   ```gdscript
   	for index in mini(enemy_count, ENEMY_START_POSITIONS.size()):
   		units.append(UnitScript.new(
   			ENEMY_START_POSITIONS[index], ENEMY_COLOR, Side.ENEMY, UNIT_MOVE_RANGE,
   			enemy_stats.max_health, enemy_stats.attack_damage, enemy_stats.attack_damage, enemy_stats.hit_chance,
   			tr(enemy_stats.attack_name_key)
   		))
   ```

   Replace `try_attack_selected_unit()`'s damage-resolution body:

   ```gdscript
   	selected_unit.has_acted = true
   	var hit: bool = hit_roll.call() < selected_unit.hit_chance
   	var damage: int = selected_unit.attack_damage if hit else 0
   	if hit:
   		target.take_damage(damage)
   ```

   with:

   ```gdscript
   	selected_unit.has_acted = true
   	var effective_hit_chance: float = maxf(selected_unit.hit_chance - target.defense / 100.0, MIN_HIT_CHANCE)
   	var hit: bool = hit_roll.call() < effective_hit_chance
   	var damage: int = 0
   	if hit:
   		var raw_damage: int = damage_roll.call(selected_unit.damage_min, selected_unit.damage_max)
   		damage = int(round(raw_damage * (1.0 - target.resistance / 100.0)))
   		target.take_damage(damage)
   ```

   In `apply_super_power()`, replace:

   ```gdscript
   			unit.attack_damage = SUPER_POWER_ATTACK_DAMAGE
   ```

   with:

   ```gdscript
   			unit.damage_min = SUPER_POWER_ATTACK_DAMAGE
   			unit.damage_max = SUPER_POWER_ATTACK_DAMAGE
   ```

4. **Run the three new tests to verify they pass.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd -gunit_test_name=attack_damage_is_rolled -gexit
   ```

   Expected: PASS (and the other two new tests).

5. **Update every existing `UnitScript.new()` call that passes a fixed
   damage value.** The rest of `test_battle_controller.gd` still fails to
   compile/run correctly because every pre-existing `UnitScript.new(...)`
   call that passes a 6th positional argument (the old single
   `attack_damage`) now has that value read as `p_damage_min`, silently
   leaving `p_damage_max` at its default of `1` — this breaks
   damage-dependent assertions instead of erroring loudly, so it must be
   fixed even though the test runner won't point at every line for you.

   **Mechanical rule:** every `UnitScript.new(pos, color, side, move_range,
   max_health, N, hit_chance, ...)` call becomes `UnitScript.new(pos, color,
   side, move_range, max_health, N, N, hit_chance, ...)` — duplicate the
   single damage value `N` into two consecutive arguments (`damage_min`,
   `damage_max`), leaving every other argument (including trailing
   `attack_name`/`adventurer_id`) in place.

   Two worked examples from the file:

   ```gdscript
   # Before (line 391):
   var attacker = UnitScript.new(
   	Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 0.6, "Sword"
   )
   # After:
   var attacker = UnitScript.new(
   	Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword"
   )
   ```

   ```gdscript
   # Before (line 786):
   var warrior = UnitScript.new(
   	Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 0.6, "Sword", "warrior_001"
   )
   # After:
   var warrior = UnitScript.new(
   	Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_001"
   )
   ```

   Apply this same substitution at every other line in
   `tests/unit/test_battle_controller.gd` with a call of this shape: **160,
   163, 186, 189, 393, 409, 412, 427, 430, 567, 570, 589, 592, 654, 657, 702,
   705, 799, 815, 836, 839, 857, 924** (in addition to 391 and 786 shown
   above). Use `grep -n "UnitScript.new" tests/unit/test_battle_controller.gd`
   to confirm you've found every call with a damage argument — a call with
   only 4 positional arguments (just `move_range`) needs no change.

   Then fix the two assertions that read the removed `attack_damage` field
   directly:

   ```gdscript
   # test_ready_spawns_the_full_party_and_the_encounters_full_enemy_count (around line 254):
   	assert_eq(warrior.attack_damage, 2)
   # becomes (default Warrior equipment is an Iron Longsword, 1-8):
   	assert_eq(warrior.damage_min, 1)
   	assert_eq(warrior.damage_max, 8)
   ```

   ```gdscript
   # test_apply_super_power_maxes_out_player_units_only (around line 665):
   	assert_eq(warrior.attack_damage, BattleControllerScript.SUPER_POWER_ATTACK_DAMAGE)
   	...
   	assert_eq(goblin.attack_damage, 1, "Super Power must not affect enemy units")
   # becomes:
   	assert_eq(warrior.damage_min, BattleControllerScript.SUPER_POWER_ATTACK_DAMAGE)
   	assert_eq(warrior.damage_max, BattleControllerScript.SUPER_POWER_ATTACK_DAMAGE)
   	...
   	assert_eq(goblin.damage_min, 1, "Super Power must not affect enemy units")
   	assert_eq(goblin.damage_max, 1, "Super Power must not affect enemy units")
   ```

6. **Fix the two other files that assert on `attack_damage` after Super
   Power.** In `tests/unit/test_debug_menu.gd` (around line 66) and
   `tests/unit/test_game_manager.gd` (around line 182), replace:

   ```gdscript
   	assert_eq(warrior.attack_damage, 100)
   ```

   with:

   ```gdscript
   	assert_eq(warrior.damage_min, 100)
   	assert_eq(warrior.damage_max, 100)
   ```

7. **Run the full suite.**

   ```bash
   make test
   ```

   Expected: `---- All tests passed! ----`, exit code 0. If any test still
   fails, it will name the exact file/assertion — re-check that assertion
   against the mechanical rule in step 5 (a missed call site is the most
   likely cause).

8. **Commit** only this task's files:

   ```bash
   git add scripts/battle/battle_controller.gd tests/unit/test_battle_controller.gd tests/unit/test_debug_menu.gd tests/unit/test_game_manager.gd
   git commit -m "feat: roll player attack damage from the equipped weapon and apply armor defense/resistance"
   ```

## Milestone

A player unit's attack rolls damage between its equipped weapon's min and
max, a defender's resistance shaves that roll down (rounded to the nearest
integer), a defender's defense lowers the attacker's effective hit chance
down to a 5% floor, and `make test` is fully green — Task 03's temporary red
state is now resolved everywhere.
