# Task 03: `Unit` carries a damage range plus defense/resistance instead of a fixed damage int

## Objective

Change the battle-layer `Unit` value object from a single `attack_damage`
int to a `(damage_min, damage_max)` range plus `defense`/`resistance`
fields, so Task 04 has somewhere to put the weapon roll and armor
mitigation.

## Files

- Modify: `scripts/battle/unit.gd`
- Test: `tests/unit/test_unit.gd` (create if it does not already exist —
  check first with `ls tests/unit/test_unit.gd`; if it exists, add to it
  instead of overwriting)

## Produces

`Unit._init(p_grid_position: Vector2i, p_color: Color, p_side: int = 0,
p_move_range: int = 1, p_max_health: int = 3, p_damage_min: int = 1,
p_damage_max: int = 1, p_hit_chance: float = 1.0, p_attack_name: String =
"Attack", p_adventurer_id: String = "", p_defense: int = 0, p_resistance:
int = 0)`, with matching new fields `damage_min: int`, `damage_max: int`,
`defense: int`, `resistance: int`. The `attack_damage: int` field is
removed.

## Steps

1. **Write the failing test.** Create/append to `tests/unit/test_unit.gd`:

   ```gdscript
   extends GutTest

   const UnitScript := preload("res://scripts/battle/unit.gd")


   func test_unit_stores_a_damage_range_and_defense_and_resistance() -> void:
   	var unit = UnitScript.new(
   		Vector2i(1, 1), Color.CORNFLOWER_BLUE, 0, 3, 5, 2, 8, 0.6, "Longsword", "warrior_001", 10, 10
   	)

   	assert_eq(unit.damage_min, 2)
   	assert_eq(unit.damage_max, 8)
   	assert_eq(unit.defense, 10)
   	assert_eq(unit.resistance, 10)


   func test_unit_defense_and_resistance_default_to_zero() -> void:
   	var unit = UnitScript.new(Vector2i(0, 0), Color.INDIAN_RED)

   	assert_eq(unit.defense, 0)
   	assert_eq(unit.resistance, 0)
   ```

   (If `tests/unit/test_unit.gd` already exists with other tests, append
   these two functions to it rather than replacing the file.)

2. **Run the test to verify it fails.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_unit.gd -gexit
   ```

   Expected: FAIL — `Invalid access to property or key 'damage_min'` (the
   field does not exist; the 6th positional argument is still read as a
   single `attack_damage`).

3. **Rewrite `scripts/battle/unit.gd`.** Replace the whole file:

   ```gdscript
   extends RefCounted

   var grid_position: Vector2i
   var color: Color
   var side: int
   var move_range: int
   var moves_remaining: int
   var has_acted: bool = false
   var max_health: int
   var health: int
   var damage_min: int
   var damage_max: int
   var hit_chance: float
   var attack_name: String
   # Empty for a unit with no backing adventurer record (e.g. every enemy).
   # Lets Battlefield match a leveled-up adventurer id (from
   # GameSession.award_party_xp()) back to the on-field unit whose health it
   # must refresh immediately.
   var adventurer_id: String
   # Percent-point armor stats (see GameSession.get_effective_defense/
   # get_effective_resistance). 0 for every unarmored unit — currently every
   # enemy, since enemies are not migrated onto the weapon/armor system (see
   # this plan's Phase A architecture note).
   var defense: int
   var resistance: int


   func _init(
   	p_grid_position: Vector2i,
   	p_color: Color,
   	p_side: int = 0,
   	p_move_range: int = 1,
   	p_max_health: int = 3,
   	p_damage_min: int = 1,
   	p_damage_max: int = 1,
   	p_hit_chance: float = 1.0,
   	p_attack_name: String = "Attack",
   	p_adventurer_id: String = "",
   	p_defense: int = 0,
   	p_resistance: int = 0
   ) -> void:
   	grid_position = p_grid_position
   	color = p_color
   	side = p_side
   	move_range = p_move_range
   	moves_remaining = p_move_range
   	max_health = p_max_health
   	health = p_max_health
   	damage_min = p_damage_min
   	damage_max = p_damage_max
   	hit_chance = p_hit_chance
   	attack_name = p_attack_name
   	adventurer_id = p_adventurer_id
   	defense = p_defense
   	resistance = p_resistance


   func is_alive() -> bool:
   	return health > 0


   func take_damage(amount: int) -> void:
   	health = max(0, health - amount)
   ```

4. **Run the test to verify it passes.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_unit.gd -gexit
   ```

   Expected: PASS. Do **not** chase the unrelated failures this step
   introduces in `test_battle_controller.gd`/`test_debug_menu.gd`/
   `test_game_manager.gd` — every existing `UnitScript.new(...)` call that
   still passes a single positional damage value now silently reads it as
   `p_damage_min` and leaves `p_damage_max` at its default of `1`. That is
   expected at this point in the plan and is fixed by Task 04.

5. **Commit** only this task's files:

   ```bash
   git add scripts/battle/unit.gd tests/unit/test_unit.gd
   git commit -m "feat: give Unit a damage range and defense/resistance instead of a fixed damage int"
   ```

## Milestone

`Unit` stores a damage range and armor stats and both new tests pass in
isolation; the rest of the suite is expected to be red until Task 04 fixes
every call site — that is a known, temporary intermediate state, not a
regression to debug.
