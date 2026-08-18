extends GutTest
## Covers scripts/tools/battle_scenarios/scenario_contract.gd: pure
## normalize()/validate()/derive_iteration_seed() over declarative,
## JSON-safe scenario Dictionaries. See docs/plans/2026-08-10-initial-
## campaign-and-automation/05-battle-scenario-contract.md.

const ScenarioContract := preload("res://scripts/tools/battle_scenarios/scenario_contract.gd")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")


func before_each() -> void:
	GameSession.reset()


func _minimal_raw_scenario() -> Dictionary:
	return {
		"scenario_id": "warrior_vs_goblin",
		"player": {"template_id": "warrior", "count": 1},
		"enemy": {"template_id": "goblin", "count": 1},
	}


## --- normalize(): single-case normalization ---------------------------------

func test_normalize_fills_every_default_for_a_sparse_scenario() -> void:
	var scenario := ScenarioContract.normalize(_minimal_raw_scenario())

	assert_eq(scenario.contract_version, ScenarioContract.CONTRACT_VERSION)
	assert_eq(scenario.scenario_id, "warrior_vs_goblin")
	assert_eq(scenario.board.width, ScenarioContract.DEFAULT_BOARD_WIDTH)
	assert_eq(scenario.board.height, ScenarioContract.DEFAULT_BOARD_HEIGHT)
	assert_eq(scenario.board.blocked, [])
	assert_eq(scenario.rules.round_limit, ScenarioContract.DEFAULT_ROUND_LIMIT)
	assert_eq(scenario.rules.victory_condition, ScenarioContract.DEFAULT_VICTORY_CONDITION)
	assert_eq(scenario.policies.player, ScenarioContract.DEFAULT_PLAYER_POLICY)
	assert_eq(scenario.policies.enemy, ScenarioContract.DEFAULT_ENEMY_POLICY)
	assert_eq(scenario.policies.config, {})
	assert_eq(scenario.randomness.root_seed, 0)
	assert_eq(scenario.randomness.iterations, 1)
	assert_eq(scenario.labels, [])


func test_normalize_expands_player_shorthand_into_explicit_positioned_units() -> void:
	var raw := _minimal_raw_scenario()
	raw.player.count = 2

	var scenario := ScenarioContract.normalize(raw)

	assert_eq(scenario.player.units.size(), 2)
	assert_eq(scenario.player.units[0].id, "player_1")
	assert_eq(scenario.player.units[1].id, "player_2")
	assert_eq(scenario.player.units[0].template_id, "warrior")
	assert_eq(scenario.player.units[0].weapon_id, GameSession.DEFAULT_WEAPON_ID)
	assert_eq(scenario.player.units[0].armor_id, GameSession.DEFAULT_ARMOR_ID)
	assert_eq(scenario.player.units[0].level, 1)
	assert_eq(
		scenario.player.units[0].position,
		ScenarioContract.position_to_dict(BattleControllerScript.PLAYER_START_POSITIONS[0]),
	)
	assert_eq(
		scenario.player.units[1].position,
		ScenarioContract.position_to_dict(BattleControllerScript.PLAYER_START_POSITIONS[1]),
	)
	assert_ne(scenario.player.units[0].position, scenario.player.units[1].position)


func test_normalize_expands_enemy_shorthand_into_explicit_positioned_units() -> void:
	var raw := _minimal_raw_scenario()
	raw.enemy.count = 3

	var scenario := ScenarioContract.normalize(raw)

	assert_eq(scenario.enemy.units.size(), 3)
	var ids: Array = []
	for unit in scenario.enemy.units:
		ids.append(unit.id)
		assert_eq(unit.template_id, "goblin")
	assert_eq(ids, ["enemy_1", "enemy_2", "enemy_3"])


func test_normalize_preserves_explicit_unit_fields_over_shorthand_defaults() -> void:
	var raw := {
		"scenario_id": "explicit_units",
		"player": {
			"units": [
				{
					"id": "hero",
					"template_id": "warrior",
					"weapon_id": "dagger_iron",
					"armor_id": "chainmail_armor",
					"level": 3,
					"position": {"x": 2, "y": 2},
					"modifiers": {"max_health": 5},
				},
			],
		},
		"enemy": {"template_id": "goblin", "count": 1},
	}

	var scenario := ScenarioContract.normalize(raw)
	var unit: Dictionary = scenario.player.units[0]

	assert_eq(unit.id, "hero")
	assert_eq(unit.weapon_id, "dagger_iron")
	assert_eq(unit.armor_id, "chainmail_armor")
	assert_eq(unit.level, 3)
	assert_eq(unit.position, {"x": 2, "y": 2})
	assert_eq(unit.modifiers, {"max_health": 5})


## --- facing: normalized defaults mirror production side defaults -----------

func test_normalize_defaults_facing_to_the_sides_production_default() -> void:
	var scenario := ScenarioContract.normalize(_minimal_raw_scenario())

	assert_eq(scenario.player.units[0].facing, "right")
	assert_eq(scenario.enemy.units[0].facing, "left")


func test_normalize_preserves_an_explicit_unit_facing() -> void:
	var raw := {
		"scenario_id": "explicit_facing",
		"player": {"units": [{"id": "hero", "template_id": "warrior", "position": {"x": 0, "y": 0}, "facing": "down"}]},
		"enemy": {"template_id": "goblin", "count": 1},
	}

	var scenario := ScenarioContract.normalize(raw)

	assert_eq(scenario.player.units[0].facing, "down")


func test_validate_rejects_an_invalid_facing() -> void:
	var raw := {
		"scenario_id": "invalid_facing",
		"player": {
			"units": [{"id": "hero", "template_id": "warrior", "position": {"x": 0, "y": 0}, "facing": "sideways"}],
		},
		"enemy": {"template_id": "goblin", "count": 1},
	}

	var scenario := ScenarioContract.normalize(raw)
	var errors := ScenarioContract.validate(scenario)

	assert_true(_has_error_with_prefix(errors, "invalid_facing"), "Expected an invalid_facing error, got: %s" % [errors])


func test_normalize_does_not_mutate_its_input() -> void:
	var raw := _minimal_raw_scenario()
	var raw_copy := raw.duplicate(true)

	ScenarioContract.normalize(raw)

	assert_eq(raw, raw_copy, "normalize() must be a pure read of its argument")


func test_normalize_is_idempotent() -> void:
	var once := ScenarioContract.normalize(_minimal_raw_scenario())
	var twice := ScenarioContract.normalize(once)

	assert_eq(once, twice, "Normalizing an already-normalized scenario must return the same data")


## --- validate(): pre-construction failures ----------------------------------

func test_validate_accepts_a_normalized_minimal_scenario() -> void:
	var scenario := ScenarioContract.normalize(_minimal_raw_scenario())

	var errors := ScenarioContract.validate(scenario)

	assert_eq(errors, [], "A minimal, normalized scenario should have no validation errors")


func test_validate_rejects_an_unsupported_contract_version() -> void:
	var raw := _minimal_raw_scenario()
	raw.contract_version = 999

	var scenario := ScenarioContract.normalize(raw)
	var errors := ScenarioContract.validate(scenario)

	assert_true(_has_error_with_prefix(errors, "unsupported_version"), "Expected an unsupported_version error, got: %s" % [errors])


func test_validate_rejects_duplicate_unit_ids_across_sides() -> void:
	var raw := {
		"scenario_id": "duplicate_ids",
		"player": {"units": [{"id": "same_id", "template_id": "warrior", "position": {"x": 0, "y": 0}}]},
		"enemy": {"units": [{"id": "same_id", "template_id": "goblin", "position": {"x": 5, "y": 5}}]},
	}

	var scenario := ScenarioContract.normalize(raw)
	var errors := ScenarioContract.validate(scenario)

	assert_true(_has_error_with_prefix(errors, "duplicate_id"), "Expected a duplicate_id error, got: %s" % [errors])


func test_validate_rejects_a_non_positive_round_limit() -> void:
	var raw := _minimal_raw_scenario()
	raw.rules = {"round_limit": 0}

	var scenario := ScenarioContract.normalize(raw)
	var errors := ScenarioContract.validate(scenario)

	assert_true(_has_error_with_prefix(errors, "invalid_limit"), "Expected an invalid_limit error, got: %s" % [errors])


func test_validate_rejects_non_positive_iterations() -> void:
	var raw := _minimal_raw_scenario()
	raw.randomness = {"iterations": 0}

	var scenario := ScenarioContract.normalize(raw)
	var errors := ScenarioContract.validate(scenario)

	assert_true(_has_error_with_prefix(errors, "invalid_limit"), "Expected an invalid_limit error, got: %s" % [errors])


func test_validate_rejects_an_unknown_player_template() -> void:
	var raw := _minimal_raw_scenario()
	raw.player = {"template_id": "not_a_real_template", "count": 1}

	var scenario := ScenarioContract.normalize(raw)
	var errors := ScenarioContract.validate(scenario)

	assert_true(_has_error_with_prefix(errors, "unknown_template"), "Expected an unknown_template error, got: %s" % [errors])


func test_validate_rejects_an_unknown_enemy_template() -> void:
	var raw := _minimal_raw_scenario()
	raw.enemy = {"template_id": "dragon", "count": 1}

	var scenario := ScenarioContract.normalize(raw)
	var errors := ScenarioContract.validate(scenario)

	assert_true(_has_error_with_prefix(errors, "unknown_template"), "Expected an unknown_template error, got: %s" % [errors])


func test_validate_rejects_an_unknown_weapon_id() -> void:
	var raw := _minimal_raw_scenario()
	raw.player = {"template_id": "warrior", "count": 1, "weapon_id": "not_a_real_weapon"}

	var scenario := ScenarioContract.normalize(raw)
	var errors := ScenarioContract.validate(scenario)

	assert_true(_has_error_with_prefix(errors, "unknown_template"), "Expected an unknown_template error, got: %s" % [errors])


func test_validate_rejects_an_unknown_policy() -> void:
	var raw := _minimal_raw_scenario()
	raw.policies = {"player": "not_a_real_policy"}

	var scenario := ScenarioContract.normalize(raw)
	var errors := ScenarioContract.validate(scenario)

	assert_true(_has_error_with_prefix(errors, "unknown_policy"), "Expected an unknown_policy error, got: %s" % [errors])


func test_validate_rejects_overlapping_positions() -> void:
	var raw := {
		"scenario_id": "overlap",
		"player": {"units": [{"id": "p1", "template_id": "warrior", "position": {"x": 2, "y": 2}}]},
		"enemy": {"units": [{"id": "e1", "template_id": "goblin", "position": {"x": 2, "y": 2}}]},
	}

	var scenario := ScenarioContract.normalize(raw)
	var errors := ScenarioContract.validate(scenario)

	assert_true(_has_error_with_prefix(errors, "position_overlap"), "Expected a position_overlap error, got: %s" % [errors])


func test_validate_rejects_an_out_of_bounds_position() -> void:
	var raw := {
		"scenario_id": "out_of_bounds",
		"board": {"width": 6, "height": 6},
		"player": {"units": [{"id": "p1", "template_id": "warrior", "position": {"x": 99, "y": 0}}]},
		"enemy": {"template_id": "goblin", "count": 1},
	}

	var scenario := ScenarioContract.normalize(raw)
	var errors := ScenarioContract.validate(scenario)

	assert_true(_has_error_with_prefix(errors, "out_of_bounds"), "Expected an out_of_bounds error, got: %s" % [errors])


func test_validate_rejects_a_non_positive_board_dimension() -> void:
	var raw := _minimal_raw_scenario()
	raw.board = {"width": 0, "height": 6}

	var scenario := ScenarioContract.normalize(raw)
	var errors := ScenarioContract.validate(scenario)

	assert_true(_has_error_with_prefix(errors, "invalid_limit"), "Expected an invalid_limit error, got: %s" % [errors])


func test_validate_rejects_an_unsupported_victory_condition() -> void:
	var raw := _minimal_raw_scenario()
	raw.rules = {"victory_condition": "not_a_real_condition"}

	var scenario := ScenarioContract.normalize(raw)
	var errors := ScenarioContract.validate(scenario)

	assert_true(_has_error_with_prefix(errors, "unsupported_rule"), "Expected an unsupported_rule error, got: %s" % [errors])


func test_validate_rejects_an_unsupported_enemy_count() -> void:
	var raw := _minimal_raw_scenario()
	raw.enemy = {"template_id": "goblin", "count": 999}

	var scenario := ScenarioContract.normalize(raw)
	var errors := ScenarioContract.validate(scenario)

	assert_true(_has_error_with_prefix(errors, "unsupported_count"), "Expected an unsupported_count error, got: %s" % [errors])


func test_validate_rejects_an_unsupported_player_count() -> void:
	var raw := _minimal_raw_scenario()
	raw.player = {"template_id": "warrior", "count": 999}

	var scenario := ScenarioContract.normalize(raw)
	var errors := ScenarioContract.validate(scenario)

	assert_true(_has_error_with_prefix(errors, "unsupported_count"), "Expected an unsupported_count error, got: %s" % [errors])


## --- derive_iteration_seed(): reproducibility --------------------------------

func test_derive_iteration_seed_is_deterministic_for_identical_inputs() -> void:
	var first := ScenarioContract.derive_iteration_seed(42, "case_a", 0)
	var second := ScenarioContract.derive_iteration_seed(42, "case_a", 0)

	assert_eq(first, second)


func test_derive_iteration_seed_differs_across_iteration_index() -> void:
	var seed_0 := ScenarioContract.derive_iteration_seed(42, "case_a", 0)
	var seed_1 := ScenarioContract.derive_iteration_seed(42, "case_a", 1)

	assert_ne(seed_0, seed_1)


func test_derive_iteration_seed_differs_across_case_id() -> void:
	var seed_a := ScenarioContract.derive_iteration_seed(42, "case_a", 0)
	var seed_b := ScenarioContract.derive_iteration_seed(42, "case_b", 0)

	assert_ne(seed_a, seed_b)


## --- Guard rails: mirrored engine constants stay in sync --------------------

func test_max_player_units_mirrors_battle_controllers_start_positions() -> void:
	assert_eq(
		ScenarioContract.MAX_PLAYER_UNITS,
		BattleControllerScript.PLAYER_START_POSITIONS.size(),
		"ScenarioContract's max player-unit count must track BattleController's real capacity",
	)


func test_max_enemy_units_mirrors_battle_controllers_start_positions() -> void:
	assert_eq(
		ScenarioContract.MAX_ENEMY_UNITS,
		BattleControllerScript.ENEMY_START_POSITIONS.size(),
		"ScenarioContract's max enemy-unit count must track BattleController's real capacity",
	)


func test_default_board_dimensions_mirror_battle_controller() -> void:
	assert_eq(ScenarioContract.DEFAULT_BOARD_WIDTH, BattleControllerScript.GRID_WIDTH)
	assert_eq(ScenarioContract.DEFAULT_BOARD_HEIGHT, BattleControllerScript.GRID_HEIGHT)


## --- Modifiers never touch global/campaign state ----------------------------

func test_normalize_and_validate_never_touch_gamesession_campaign_state() -> void:
	var raw := _minimal_raw_scenario()
	raw.player = {
		"template_id": "warrior", "count": 1,
		"modifiers": {"attack": 999, "max_health": 999, "defense": 999},
	}
	var adventurers_before: Array = GameSession.adventurers.duplicate(true)
	var base_melee_before: int = GameSession.CLASS_DEFINITIONS.warrior.base_stats.melee

	var scenario := ScenarioContract.normalize(raw)
	ScenarioContract.validate(scenario)

	assert_eq(GameSession.adventurers, adventurers_before, "Modifiers must never touch GameSession.adventurers")
	assert_eq(GameSession.CLASS_DEFINITIONS.warrior.base_stats.melee, base_melee_before, "Modifiers must never touch GameSession's balance constants")
	assert_eq(GameSession.selected_encounter, "", "The contract must never touch GameSession.selected_encounter")


func _has_error_with_prefix(errors: Array, prefix: String) -> bool:
	for error in errors:
		if String(error).begins_with(prefix):
			return true
	return false
