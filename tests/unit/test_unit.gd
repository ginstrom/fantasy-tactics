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
