extends GutTest

const GameConfigScript := preload("res://scripts/autoload/game_config.gd")


func test_loads_int_values_from_the_real_config_file() -> void:
	assert_eq(GameConfig.get_int("guild_hall", "upgrade_cost", -1), 50)
	assert_eq(GameConfig.get_int("population", "encounter_vacancy_turns", -1), 15)


func test_loads_float_values_from_the_real_config_file() -> void:
	assert_eq(GameConfig.get_float("combat", "effective_hit_chance_cap", -1.0), 0.95)


func test_missing_key_returns_the_provided_default() -> void:
	assert_eq(GameConfig.get_int("guild_hall", "no_such_key", 999), 999)


func test_missing_section_returns_the_provided_default() -> void:
	assert_eq(GameConfig.get_int("no_such_section", "upgrade_cost", 999), 999)


func test_malformed_json_falls_back_to_defaults() -> void:
	var config = GameConfigScript.new()
	autofree(config)

	var parsed: Dictionary = config._parse_or_default("{not valid json")

	assert_eq(parsed, GameConfigScript.DEFAULTS)


func test_valid_json_text_is_parsed_as_is() -> void:
	var config = GameConfigScript.new()
	autofree(config)

	var parsed: Dictionary = config._parse_or_default('{"combat": {"base_attack": 99}}')

	assert_eq(parsed, {"combat": {"base_attack": 99.0}})
