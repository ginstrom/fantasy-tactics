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


## Step 2 of docs/plans/2026-08-18-core-loop-and-engagement: passive Shop
## income tiers (see game_session.gd's _shop_income_per_turn()).
func test_loads_shop_income_tiers_from_the_real_config_file() -> void:
	assert_eq(GameConfig.get_int("shop", "level_1_income", -1), 2)
	assert_eq(GameConfig.get_int("shop", "level_2_income", -1), 5)
	assert_eq(GameConfig.get_int("shop", "level_3_income", -1), 10)


## Step 3 of docs/plans/2026-08-18-core-loop-and-engagement: Guild Hall's
## three-tier deployment/roster/offer caps (see game_session.gd's
## get_max_party_size()/get_roster_cap()/get_recruitment_offer_cap()).
func test_loads_guild_hall_tier_caps_from_the_real_config_file() -> void:
	assert_eq(GameConfig.get_int("guild_hall", "level_1_party_cap", -1), 3)
	assert_eq(GameConfig.get_int("guild_hall", "level_2_party_cap", -1), 4)
	assert_eq(GameConfig.get_int("guild_hall", "level_3_party_cap", -1), 5)
	assert_eq(GameConfig.get_int("guild_hall", "max_level", -1), 3)
	assert_eq(GameConfig.get_int("guild_hall", "level_3_upgrade_cost", -1), 100)
	assert_eq(GameConfig.get_int("guild_hall", "level_1_roster_cap", -1), 10)
	assert_eq(GameConfig.get_int("guild_hall", "level_2_roster_cap", -1), 15)
	assert_eq(GameConfig.get_int("guild_hall", "level_3_roster_cap", -1), 20)
	assert_eq(GameConfig.get_int("guild_hall", "level_2_offer_cap", -1), 8)
	assert_eq(GameConfig.get_int("guild_hall", "level_3_offer_cap", -1), 10)


## Step 3 of docs/plans/2026-08-18-core-loop-and-engagement: Shop tier 2/3
## upgrade costs (see game_session.gd's upgrade_shop()).
func test_loads_shop_upgrade_costs_from_the_real_config_file() -> void:
	assert_eq(GameConfig.get_int("shop", "level_2_upgrade_cost", -1), 150)
	assert_eq(GameConfig.get_int("shop", "level_3_upgrade_cost", -1), 300)


## Step 3 of docs/plans/2026-08-18-core-loop-and-engagement: Temple build
## cost (see game_session.gd's can_build_temple()/build_temple()).
func test_loads_temple_build_cost_from_the_real_config_file() -> void:
	assert_eq(GameConfig.get_int("temple", "build_cost", -1), 100)


## Step 1 of docs/plans/2026-08-21-stage-2-party-readiness: the locked Stage
## 2 perk-effect magnitudes (see docs/designs/class-system.md's "Stage 2
## locked perk set").
func test_loads_stage_2_perk_magnitudes_from_the_real_config_file() -> void:
	assert_eq(GameConfig.get_int("progression", "perk_tree_size", -1), 2)
	assert_eq(GameConfig.get_int("progression", "warrior_juggernaut_hp_percent", -1), 15)
	assert_eq(GameConfig.get_int("progression", "warrior_bulwark_guard", -1), 10)
	assert_eq(GameConfig.get_int("progression", "scout_quickdraw_action_points", -1), 1)
	assert_eq(GameConfig.get_int("progression", "scout_keen_eyes_intel_range_bonus", -1), 1)
	assert_eq(GameConfig.get_int("progression", "cleric_meditation_spell_range_bonus", -1), 1)
	assert_eq(GameConfig.get_int("progression", "cleric_devout_hp_percent", -1), 10)


## Step 1 of docs/plans/2026-08-21-stage-2-party-readiness: durable Cleric MP
## and capped HP/MP natural recovery, split by mode, plus the Temple HP bonus
## (see docs/designs/campaign-loop.md's natural-recovery paragraph). Replaces
## the flat, Temple-blind encamped_rate.
func test_loads_stage_2_recovery_rates_from_the_real_config_file() -> void:
	assert_eq(GameConfig.get_int("healing", "moving_rate", -1), 1)
	assert_eq(GameConfig.get_int("healing", "resting_rate", -1), 2)
	assert_eq(GameConfig.get_int("healing", "encamped_rate", -1), 3)
	assert_eq(GameConfig.get_int("healing", "moving_mp_rate", -1), 2)
	assert_eq(GameConfig.get_int("healing", "resting_mp_rate", -1), 4)
	assert_eq(GameConfig.get_int("healing", "encamped_mp_rate", -1), 6)
	assert_eq(GameConfig.get_int("healing", "temple_hp_bonus_per_tier", -1), 1)


## Step 1 of docs/plans/2026-08-21-stage-2-party-readiness: durable Cleric max
## MP and the details-view "Heal party member" MP cost/HP range (see
## docs/designs/campaign-loop.md's Healer paragraph).
func test_loads_stage_2_cleric_config_from_the_real_config_file() -> void:
	assert_eq(GameConfig.get_int("cleric", "mp_max", -1), 3)
	assert_eq(GameConfig.get_int("cleric", "details_heal_mp_cost", -1), 1)
	assert_eq(GameConfig.get_int("cleric", "details_heal_min", -1), 2)
	assert_eq(GameConfig.get_int("cleric", "details_heal_max", -1), 8)


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
