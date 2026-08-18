extends GutTest

const GameConfigScript := preload("res://scripts/autoload/game_config.gd")


func test_loads_int_values_from_the_real_config_file() -> void:
	assert_eq(GameConfig.get_int("guild_hall", "upgrade_cost", -1), 50)
	assert_eq(GameConfig.get_int("population", "encounter_vacancy_turns", -1), 15)


func test_loads_float_values_from_the_real_config_file() -> void:
	assert_eq(GameConfig.get_float("combat", "effective_hit_chance_cap", -1.0), 0.95)


## Step 2 of docs/plans/2026-08-18-critical-hits-and-flanking: critical hit
## balance constants (see battle_controller.gd's try_attack_selected_unit()).
func test_loads_critical_hit_config_values_from_the_real_config_file() -> void:
	assert_eq(GameConfig.get_float("combat", "base_critical_chance", -1.0), 0.05)
	assert_eq(GameConfig.get_float("combat", "critical_damage_multiplier", -1.0), 1.5)
	assert_eq(GameConfig.get_int("combat", "critical_resistance_reduction", -1), 20)


## Step 3 of docs/plans/2026-08-18-critical-hits-and-flanking: flanking
## balance constants (see battle_controller.gd's get_flank_type()/
## try_attack_selected_unit()).
func test_loads_flanking_config_values_from_the_real_config_file() -> void:
	assert_eq(GameConfig.get_int("combat", "side_flank_guard_penalty", -1), 20)
	assert_eq(GameConfig.get_float("combat", "side_flank_crit_bonus", -1.0), 0.20)
	assert_eq(GameConfig.get_int("combat", "rear_flank_guard_penalty", -1), 50)
	assert_eq(GameConfig.get_float("combat", "rear_flank_crit_bonus", -1.0), 0.50)


func test_missing_key_returns_the_provided_default() -> void:
	assert_eq(GameConfig.get_int("guild_hall", "no_such_key", 999), 999)


func test_missing_section_returns_the_provided_default() -> void:
	assert_eq(GameConfig.get_int("no_such_section", "upgrade_cost", 999), 999)


func test_malformed_json_falls_back_to_defaults() -> void:
	var config = GameConfigScript.new()
	autofree(config)

	var parsed: Dictionary = config._parse_or_default("{not valid json")

	assert_eq(parsed, GameConfigScript.DEFAULTS)
	assert_push_error("is not valid JSON, using built-in defaults")


func test_valid_json_text_is_parsed_as_is() -> void:
	var config = GameConfigScript.new()
	autofree(config)

	var parsed: Dictionary = config._parse_or_default('{"combat": {"base_move_range": 5}}')

	assert_eq(parsed, {"combat": {"base_move_range": 5.0}})


## DEFAULTS is documented as mirroring config/game_config.json exactly, and it
## is the fallback the whole "a bad config never crashes the game" guarantee
## rests on — but nothing else compares the two, so they can drift silently.
## JSON has no integer type, so every number comes back as a float and is
## compared numerically rather than by Variant type.
func test_defaults_mirror_the_shipped_config_file_exactly() -> void:
	var file := FileAccess.open(GameConfigScript.CONFIG_PATH, FileAccess.READ)
	assert_not_null(file, "The shipped config file must exist and be readable")
	var json := JSON.new()
	assert_eq(json.parse(file.get_as_text()), OK, "The shipped config file must be valid JSON")
	var parsed: Dictionary = json.data

	assert_eq(
		parsed.keys(),
		GameConfigScript.DEFAULTS.keys(),
		"The shipped file and DEFAULTS must declare exactly the same sections"
	)
	for section in GameConfigScript.DEFAULTS:
		var expected: Dictionary = GameConfigScript.DEFAULTS[section]
		var actual: Dictionary = parsed.get(section, {})
		assert_eq(
			actual.keys(),
			expected.keys(),
			"Section '%s' must declare exactly the same keys in DEFAULTS and the shipped file" % section
		)
		for key in expected:
			assert_almost_eq(
				float(actual.get(key, INF)),
				float(expected[key]),
				0.0001,
				"%s.%s must have the same value in DEFAULTS and the shipped file" % [section, key]
			)
