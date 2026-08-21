extends GutTest
## Covers scripts/tools/battle_scenarios/battle_state_factory.gd: builds a
## bare, un-scened BattleController (grid, units, positions, sides, and
## seeded RNG callables) from one normalized, validated concrete scenario
## case -- the same "construct via script, never via the scene" pattern
## test_battle_controller.gd's _make_controller() and test_battle_bot.gd
## already use. See docs/plans/2026-08-10-initial-campaign-and-automation/
## 05-battle-scenario-contract.md.

const BattleStateFactory := preload("res://scripts/tools/battle_scenarios/battle_state_factory.gd")
const ScenarioContract := preload("res://scripts/tools/battle_scenarios/scenario_contract.gd")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const BattleBot := preload("res://scripts/tools/battle_bot.gd")


func before_each() -> void:
	GameSession.reset()


func _normalized(raw: Dictionary) -> Dictionary:
	return ScenarioContract.normalize(raw)


func _one_v_one_scenario() -> Dictionary:
	return _normalized({
		"scenario_id": "one_v_one",
		"player": {"units": [{"id": "hero", "template_id": "warrior", "position": {"x": 0, "y": 0}}]},
		"enemy": {"units": [{"id": "grunt", "template_id": "goblin", "position": {"x": 5, "y": 5}}]},
	})


## --- Grid, units, positions, sides -------------------------------------------

func test_build_creates_a_grid_sized_to_the_scenarios_board() -> void:
	var scenario := _normalized({
		"scenario_id": "sized_board",
		"board": {"width": 4, "height": 8},
		"player": {"template_id": "warrior", "count": 1},
		"enemy": {"template_id": "goblin", "count": 1},
	})

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)

	assert_eq(controller.grid.width, 4)
	assert_eq(controller.grid.height, 8)


func test_build_fields_one_unit_per_declared_side_unit_at_its_declared_position() -> void:
	var controller: Node2D = BattleStateFactory.build(_one_v_one_scenario(), 1)
	autofree(controller)

	assert_eq(controller.units.size(), 2)
	var hero = controller.get_unit_at(Vector2i(0, 0))
	var grunt = controller.get_unit_at(Vector2i(5, 5))
	assert_not_null(hero)
	assert_not_null(grunt)
	assert_eq(hero.side, BattleControllerScript.Side.PLAYER)
	assert_eq(grunt.side, BattleControllerScript.Side.ENEMY)


func test_build_selects_the_first_living_player_unit_and_starts_on_the_player_side() -> void:
	var controller: Node2D = BattleStateFactory.build(_one_v_one_scenario(), 1)
	autofree(controller)

	assert_eq(controller.active_side, BattleControllerScript.Side.PLAYER)
	assert_not_null(controller.selected_unit)
	assert_eq(controller.selected_unit.side, BattleControllerScript.Side.PLAYER)


## --- facing: scene-free defaults mirror production, overrides are honored ---

func test_build_hydrates_default_facing_matching_production_side_defaults() -> void:
	var controller: Node2D = BattleStateFactory.build(_one_v_one_scenario(), 1)
	autofree(controller)

	var hero = controller.get_unit_at(Vector2i(0, 0))
	var grunt = controller.get_unit_at(Vector2i(5, 5))
	assert_eq(hero.facing, Vector2i.RIGHT, "A scene-free player unit must start facing right, matching production")
	assert_eq(grunt.facing, Vector2i.LEFT, "A scene-free enemy unit must start facing left, matching production")


func test_build_honors_an_explicit_scenario_facing_override() -> void:
	var scenario := _normalized({
		"scenario_id": "facing_override",
		"player": {"units": [{"id": "hero", "template_id": "warrior", "position": {"x": 0, "y": 0}, "facing": "down"}]},
		"enemy": {"units": [{"id": "grunt", "template_id": "goblin", "position": {"x": 5, "y": 5}, "facing": "up"}]},
	})

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)

	assert_eq(controller.get_unit_at(Vector2i(0, 0)).facing, Vector2i.DOWN)
	assert_eq(controller.get_unit_at(Vector2i(5, 5)).facing, Vector2i.UP)


## --- end_turn() round-start reselection ---------------------------------------
## BattleController.end_turn() re-selects the first living player unit via
## its own _first_living_player_unit(), which walks _player_adventurer_ids
## rather than `units` directly (see battle_controller.gd). A factory-built
## controller must populate that field, or every end_turn() back to the
## player side would silently leave selected_unit null -- exactly the gap
## test_battle_controller.gd's own _make_controller()-based tests guard
## against by assigning _player_adventurer_ids by hand (see
## test_end_turn_selects_the_first_living_player_unit_when_a_new_round_starts
## there).

func _two_player_scenario() -> Dictionary:
	return _normalized({
		"scenario_id": "two_player",
		"player": {
			"units": [
				{"id": "hero_1", "template_id": "warrior", "position": {"x": 0, "y": 0}},
				{"id": "hero_2", "template_id": "warrior", "position": {"x": 1, "y": 0}},
			],
		},
		"enemy": {"units": [{"id": "grunt", "template_id": "goblin", "position": {"x": 5, "y": 5}}]},
	})


func test_end_turn_reselects_the_first_living_player_unit_when_control_returns_to_the_player() -> void:
	var controller: Node2D = BattleStateFactory.build(_two_player_scenario(), 1)
	autofree(controller)
	# Simulate the round-start selection having moved on, the way a real
	# turn would leave it once the second unit has acted.
	controller.selected_unit = controller.get_unit_at(Vector2i(1, 0))

	controller.end_turn()  # PLAYER -> ENEMY
	assert_null(controller.selected_unit, "Handing control to the enemy does not select one of its units")

	controller.end_turn()  # ENEMY -> PLAYER

	assert_eq(controller.active_side, BattleControllerScript.Side.PLAYER)
	assert_not_null(
		controller.selected_unit,
		"A factory-built controller must reselect a player unit at round start, not silently leave it null",
	)
	assert_eq(controller.selected_unit, controller.get_unit_at(Vector2i(0, 0)), "hero_1 was declared first")


func test_end_turn_skips_a_defeated_party_member_when_reselecting_at_round_start() -> void:
	var controller: Node2D = BattleStateFactory.build(_two_player_scenario(), 1)
	autofree(controller)
	controller.get_unit_at(Vector2i(0, 0)).health = 0

	controller.end_turn()  # PLAYER -> ENEMY
	controller.end_turn()  # ENEMY -> PLAYER

	assert_eq(
		controller.selected_unit,
		controller.get_unit_at(Vector2i(1, 0)),
		"A defeated party member cannot be the round-start selection",
	)


## --- Ranged weapon attack range hydration (Step 4 of docs/plans/2026-08-21-
## stage-2-party-readiness/04-scout-ranged-and-tier-two-pattern.md) ----------
## A live battle hydrates a player unit's attack_min_range/attack_max_range
## from its equipped weapon (see battle_controller.gd's own _ready(), which
## reads GameSession.get_effective_weapon_attack_range()) -- but until this
## fix, _build_player_unit() below never read a scenario unit's weapon_id for
## range at all, silently leaving every scenario-built player unit at
## unit.gd's melee-only 1/1 default even when the scenario declared a bow.
## Mirrors GameSession.get_effective_weapon_attack_range()'s own min_range/
## max_range floor logic exactly, so a scenario-built unit's range always
## agrees with what the same weapon_id would hydrate to in a real battle.

func test_build_hydrates_a_shortbows_attack_range_onto_the_scenario_player_unit() -> void:
	var scenario := _normalized({
		"scenario_id": "shortbow_hydration",
		"player": {"units": [{"id": "scout", "template_id": "scout", "weapon_id": "shortbow_iron", "position": {"x": 0, "y": 0}}]},
		"enemy": {"template_id": "goblin", "count": 1},
	})

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)

	var scout = controller.get_unit_at(Vector2i(0, 0))
	var shortbow: Dictionary = GameSession.WEAPONS.shortbow_iron
	assert_eq(scout.attack_min_range, shortbow.min_range)
	assert_eq(scout.attack_max_range, shortbow.max_range, "A scenario-built Scout must not be stuck at the melee-only 1-tile default")


func test_build_hydrates_a_longbows_longer_attack_range_than_a_shortbows() -> void:
	var scenario := _normalized({
		"scenario_id": "longbow_hydration",
		"player": {"units": [{"id": "scout", "template_id": "scout", "weapon_id": "longbow_iron", "position": {"x": 0, "y": 0}}]},
		"enemy": {"template_id": "goblin", "count": 1},
	})

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)

	var scout = controller.get_unit_at(Vector2i(0, 0))
	var longbow: Dictionary = GameSession.WEAPONS.longbow_iron
	assert_eq(scout.attack_min_range, longbow.min_range)
	assert_eq(scout.attack_max_range, longbow.max_range)
	assert_gt(longbow.max_range, GameSession.WEAPONS.shortbow_iron.max_range, "Longbow must genuinely outrange shortbow for this to be a meaningful hydration proof")


func test_build_hydrates_a_melee_weapons_default_one_tile_attack_range() -> void:
	# The default warrior/longsword_iron template must keep its existing
	# melee-only 1/1 range -- this hydration fix must not change behavior for
	# every scenario test written before it existed.
	var controller: Node2D = BattleStateFactory.build(_one_v_one_scenario(), 1)
	autofree(controller)

	var hero = controller.get_unit_at(Vector2i(0, 0))
	assert_eq(hero.attack_min_range, 1)
	assert_eq(hero.attack_max_range, 1)


## --- Stats read from GameSession's read-only balance constants ---------------

func test_build_derives_the_player_units_stats_from_gamesessions_baseline_and_default_gear() -> void:
	var controller: Node2D = BattleStateFactory.build(_one_v_one_scenario(), 1)
	autofree(controller)

	var hero = controller.get_unit_at(Vector2i(0, 0))
	var weapon: Dictionary = GameSession.WEAPONS[GameSession.DEFAULT_WEAPON_ID]
	var armor: Dictionary = GameSession.ARMORS[GameSession.DEFAULT_ARMOR_ID]

	assert_eq(hero.max_health, GameSession.CLASS_DEFINITIONS.warrior.base_stats.max_health)
	assert_eq(hero.max_action_points, BattleControllerScript.BASE_ACTION_POINTS)
	assert_eq(hero.damage_min, weapon.damage_min)
	assert_eq(hero.damage_max, weapon.damage_max)
	assert_eq(hero.defense, armor.defense)
	assert_eq(hero.resistance, armor.resistance)
	assert_eq(
		hero.hit_chance,
		minf(GameSession.CLASS_DEFINITIONS.warrior.base_stats.melee / GameSession.ATTACK_TO_HIT_CHANCE_DIVISOR, GameSession.EFFECTIVE_HIT_CHANCE_CAP),
	)


func test_build_derives_the_enemy_units_stats_from_gamesessions_named_template() -> void:
	var controller: Node2D = BattleStateFactory.build(_one_v_one_scenario(), 1)
	autofree(controller)

	var grunt = controller.get_unit_at(Vector2i(5, 5))

	assert_eq(grunt.max_health, GameSession.GOBLIN_ENEMY_STATS.max_health)
	assert_eq(grunt.damage_min, GameSession.GOBLIN_ENEMY_STATS.attack_damage)
	assert_eq(grunt.damage_max, GameSession.GOBLIN_ENEMY_STATS.attack_damage)
	assert_eq(grunt.hit_chance, GameSession.GOBLIN_ENEMY_STATS.hit_chance)
	assert_eq(grunt.kill_xp, GameSession.GOBLIN_ENEMY_STATS.kill_xp)


func test_build_applies_a_higher_level_players_max_health_bonus() -> void:
	var scenario := _normalized({
		"scenario_id": "leveled",
		"player": {"units": [{"id": "hero", "template_id": "warrior", "level": 3, "position": {"x": 0, "y": 0}}]},
		"enemy": {"template_id": "goblin", "count": 1},
	})

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)

	var hero = controller.get_unit_at(Vector2i(0, 0))
	assert_eq(hero.max_health, 30)


## --- Cleric spells/MP hydration -----------------------------------------------
## Mirrors battle_controller.gd's own runtime hydration (see that file's
## _build_player_units()-equivalent code, ~lines 245-255): a class whose
## GameSession.CLASS_DEFINITIONS entry declares "spells" gets those spells
## and its class's mp_max/mp_remaining; a non-spell class (warrior/scout)
## keeps the field defaults declared in unit.gd (spells == [], mp_max == 0,
## mp_remaining == 0).

func test_build_hydrates_cleric_spells_and_mp_from_the_class_definition() -> void:
	var scenario := _normalized({
		"scenario_id": "cleric_hydration",
		"player": {"units": [{"id": "healer", "template_id": "cleric", "position": {"x": 0, "y": 0}}]},
		"enemy": {"template_id": "goblin", "count": 1},
	})

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)

	var healer = controller.get_unit_at(Vector2i(0, 0))
	var cleric_def: Dictionary = GameSession.CLASS_DEFINITIONS.cleric

	assert_eq(healer.spells, cleric_def.spells)
	assert_eq(healer.mp_max, int(cleric_def.mp_max))
	assert_eq(healer.mp_max, 3)
	assert_eq(healer.mp_remaining, healer.mp_max)
	assert_eq(healer.max_health, cleric_def.base_stats.max_health)


## Explicit optional MP field (scenario_contract.gd's own doc comment on
## "mp_current" -- deterministic scenarios never rely on ambient GameSession
## session state): an explicit scenario mp_current hydrates the built unit at
## that value instead of always-full, exercising the same durable-not-always-
## full rule production battle start now follows (see BattleController.
## _ready()) without touching any adventurer record.
func test_build_hydrates_a_clerics_mp_from_an_explicit_scenario_value() -> void:
	var scenario := _normalized({
		"scenario_id": "cleric_explicit_mp",
		"player": {"units": [{"id": "healer", "template_id": "cleric", "position": {"x": 0, "y": 0}, "mp_current": 1}]},
		"enemy": {"template_id": "goblin", "count": 1},
	})

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)

	var healer = controller.get_unit_at(Vector2i(0, 0))
	assert_eq(healer.mp_max, 3)
	assert_eq(healer.mp_remaining, 1, "An explicit scenario mp_current must hydrate the built unit, not the class's full mp_max")


func test_build_leaves_a_non_spell_class_at_zero_mp_and_empty_spells() -> void:
	var controller: Node2D = BattleStateFactory.build(_one_v_one_scenario(), 1)
	autofree(controller)

	var hero = controller.get_unit_at(Vector2i(0, 0))

	assert_eq(hero.spells, [])
	assert_eq(hero.mp_max, 0)
	assert_eq(hero.mp_remaining, 0)


## --- Explicit modifiers affect only the constructed unit ---------------------

func test_build_applies_explicit_player_modifiers_on_top_of_the_baseline() -> void:
	var scenario := _normalized({
		"scenario_id": "modified",
		"player": {
			"units": [
				{
					"id": "hero", "template_id": "warrior", "position": {"x": 0, "y": 0},
					"modifiers": {"max_health": 5, "damage_min": 2, "damage_max": 3, "defense": 4, "resistance": 6},
				},
			],
		},
		"enemy": {"template_id": "goblin", "count": 1},
	})
	var weapon: Dictionary = GameSession.WEAPONS[GameSession.DEFAULT_WEAPON_ID]
	var armor: Dictionary = GameSession.ARMORS[GameSession.DEFAULT_ARMOR_ID]

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)
	var hero = controller.get_unit_at(Vector2i(0, 0))

	assert_eq(hero.max_health, GameSession.CLASS_DEFINITIONS.warrior.base_stats.max_health + 5)
	assert_eq(hero.damage_min, weapon.damage_min + 2)
	assert_eq(hero.damage_max, weapon.damage_max + 3)
	assert_eq(hero.defense, armor.defense + 4)
	assert_eq(hero.resistance, armor.resistance + 6)


func test_build_applies_explicit_enemy_modifiers_on_top_of_the_baseline() -> void:
	var scenario := _normalized({
		"scenario_id": "modified_enemy",
		"player": {"template_id": "warrior", "count": 1},
		"enemy": {
			"units": [
				{
					"id": "grunt", "template_id": "goblin", "position": {"x": 5, "y": 5},
					"modifiers": {"max_health": 10, "damage_min": 1, "damage_max": 1},
				},
			],
		},
	})

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)
	var grunt = controller.get_unit_at(Vector2i(5, 5))

	assert_eq(grunt.max_health, GameSession.GOBLIN_ENEMY_STATS.max_health + 10)
	assert_eq(grunt.damage_min, GameSession.GOBLIN_ENEMY_STATS.attack_damage + 1)
	assert_eq(grunt.damage_max, GameSession.GOBLIN_ENEMY_STATS.attack_damage + 1)


func test_build_never_mutates_gamesession_or_gameconfig_state() -> void:
	var scenario := _normalized({
		"scenario_id": "no_side_effects",
		"player": {
			"units": [
				{
					"id": "hero", "template_id": "warrior", "position": {"x": 0, "y": 0},
					"modifiers": {"max_health": 999, "damage_min": 999},
				},
			],
		},
		"enemy": {"template_id": "goblin", "count": 1},
	})
	var adventurers_before: Array = GameSession.adventurers.duplicate(true)
	var base_max_health_before: int = GameSession.CLASS_DEFINITIONS.warrior.base_stats.max_health
	var weapons_before: Dictionary = GameSession.WEAPONS.duplicate(true)

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)

	assert_eq(GameSession.adventurers, adventurers_before)
	assert_eq(GameSession.CLASS_DEFINITIONS.warrior.base_stats.max_health, base_max_health_before)
	assert_eq(GameSession.WEAPONS, weapons_before)
	assert_eq(GameSession.selected_encounter, "")
	assert_false(controller.is_inside_tree(), "BattleStateFactory must never add the controller to the scene tree")


## --- Injected, seeded RNG callables -------------------------------------------

func test_build_seeds_hit_roll_and_damage_roll_deterministically_from_the_iteration_seed() -> void:
	var scenario := _one_v_one_scenario()

	var controller_a: Node2D = BattleStateFactory.build(scenario, 12345)
	var controller_b: Node2D = BattleStateFactory.build(scenario, 12345)
	autofree(controller_a)
	autofree(controller_b)

	for _i in 5:
		assert_eq(controller_a.hit_roll.call(), controller_b.hit_roll.call())
	for _i in 5:
		assert_eq(controller_a.damage_roll.call(1, 100), controller_b.damage_roll.call(1, 100))


## Step 2 of docs/plans/2026-08-18-critical-hits-and-flanking: crit_roll must
## be seeded from the same per-iteration RandomNumberGenerator as hit_roll/
## damage_roll (see battle_controller.gd's own default `randf()` -- never
## global randomness during scenario execution, so re-running the same case
## with the same iteration seed reproduces the same critical-hit outcomes.
func test_build_seeds_crit_roll_deterministically_from_the_iteration_seed() -> void:
	var scenario := _one_v_one_scenario()

	var controller_a: Node2D = BattleStateFactory.build(scenario, 12345)
	var controller_b: Node2D = BattleStateFactory.build(scenario, 12345)
	autofree(controller_a)
	autofree(controller_b)

	for _i in 5:
		assert_eq(controller_a.crit_roll.call(), controller_b.crit_roll.call())


## Heal (see battle_controller.gd's try_cast_spell()) rolls its healing
## amount via controller.healing_roll, which must be seeded from the same
## per-iteration RandomNumberGenerator as hit_roll/crit_roll/damage_roll --
## otherwise a Cleric's Heal amount (and any Heal-vs-Bless priority decision
## a wounded ally's resulting health crosses) would draw from Godot's global,
## unseeded RNG, breaking CampaignSim's "100% reproducible from sim_seed
## alone" contract for any run that fields a Cleric.
func test_build_seeds_healing_roll_deterministically_from_the_iteration_seed() -> void:
	var scenario := _one_v_one_scenario()

	var controller_a: Node2D = BattleStateFactory.build(scenario, 12345)
	var controller_b: Node2D = BattleStateFactory.build(scenario, 12345)
	autofree(controller_a)
	autofree(controller_b)

	for _i in 5:
		assert_eq(controller_a.healing_roll.call(2, 8), controller_b.healing_roll.call(2, 8))


func test_build_seeds_hit_roll_differently_for_different_iteration_seeds() -> void:
	var scenario := _one_v_one_scenario()

	var controller_a: Node2D = BattleStateFactory.build(scenario, 1)
	var controller_b: Node2D = BattleStateFactory.build(scenario, 2)
	autofree(controller_a)
	autofree(controller_b)

	var rolls_a: Array = []
	var rolls_b: Array = []
	for _i in 10:
		rolls_a.append(controller_a.hit_roll.call())
		rolls_b.append(controller_b.hit_roll.call())
	assert_ne(rolls_a, rolls_b, "Different iteration seeds should (overwhelmingly likely) diverge over 10 rolls")


## --- Exposes the public action surface used by BattleBot/enemy turns --------

func test_battle_bot_can_drive_a_factory_built_controllers_player_turn() -> void:
	var controller: Node2D = BattleStateFactory.build(_one_v_one_scenario(), 1)
	autofree(controller)

	var steps: Array = BattleBot.take_player_turn(controller)

	assert_eq(steps.size(), 1)
	assert_eq(steps[0].type, "move", "The hero starts 10 tiles from the goblin, so its only legal action is to move closer")


func test_run_enemy_turn_drives_a_factory_built_controllers_enemy_side() -> void:
	var controller: Node2D = BattleStateFactory.build(_one_v_one_scenario(), 1)
	autofree(controller)
	controller.active_side = BattleControllerScript.Side.ENEMY

	var steps: Array = controller.run_enemy_turn()

	assert_eq(steps.size(), 1)
	assert_eq(steps[0].type, "move")


func test_try_move_and_try_attack_work_directly_on_a_factory_built_controller() -> void:
	var scenario := _normalized({
		"scenario_id": "adjacent",
		"player": {"units": [{"id": "hero", "template_id": "warrior", "position": {"x": 1, "y": 1}}]},
		"enemy": {"units": [{"id": "grunt", "template_id": "goblin", "position": {"x": 1, "y": 2}}]},
	})
	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)
	var hero = controller.get_unit_at(Vector2i(1, 1))
	controller.selected_unit = hero
	controller.hit_roll = func() -> float: return 0.0

	var attacked: bool = controller.try_attack_selected_unit(Vector2i(1, 2))

	assert_true(attacked)


## --- Step 5: authored campaign ladder fixtures ------------------------------
## (docs/plans/2026-08-18-core-loop-and-engagement/
## 05-authored-encounters-and-final-boss.md's task-list item 1: one
## ScenarioContract fixture per tier, both pre-boss nodes, and the Ogre,
## each hydrated through BattleStateFactory with its own recorded seed.)

const CAMPAIGN_SCENARIOS_PATH := "res://config/campaign_scenarios.json"


func _load_campaign_scenarios() -> Array:
	var file := FileAccess.open(CAMPAIGN_SCENARIOS_PATH, FileAccess.READ)
	assert_not_null(file, "%s must exist" % CAMPAIGN_SCENARIOS_PATH)
	var json := JSON.new()
	assert_eq(json.parse(file.get_as_text()), OK, "%s must be valid JSON" % CAMPAIGN_SCENARIOS_PATH)
	assert_true(json.data is Dictionary and (json.data as Dictionary).get("scenarios") is Array)
	return (json.data as Dictionary).scenarios


## Every fixture covers a distinct authored node id -- one per tier (using
## that tier's first node as the representative), both pre-boss nodes, and
## the Ogre -- six in total.
func test_campaign_scenarios_fixture_covers_one_node_per_tier_both_preboss_nodes_and_the_ogre() -> void:
	var scenarios := _load_campaign_scenarios()
	var objective_ids: Array = []
	for entry in scenarios:
		objective_ids.append(String(entry.objective_id))

	assert_eq(objective_ids.size(), 6)
	for expected_id in [
		"obj_tier1_1_goblin_outpost", "obj_tier2_1_orc_outpost", "obj_tier3_1_hobgoblin_command",
		"obj_preboss_1_borderlands_vanguard", "obj_preboss_2_borderlands_stronghold", "obj_boss_borderlands_ogre",
	]:
		assert_true(objective_ids.has(expected_id), "campaign_scenarios.json must cover %s" % expected_id)


## Every fixture normalizes/validates cleanly and hydrates through
## BattleStateFactory.build() into a controller fielding exactly the
## fixture's own declared unit counts; each fixture's own recorded seed
## (GameSession.CAMPAIGN_OBJECTIVES id + ScenarioContract.derive_iteration_
## seed()) reproduces identically on every call, proving the fixture is a
## reproducible, deterministic regression scenario rather than a one-off.
func test_every_campaign_scenario_fixture_hydrates_through_battle_state_factory() -> void:
	for entry in _load_campaign_scenarios():
		var raw_contract: Dictionary = entry.contract
		var scenario := ScenarioContract.normalize(raw_contract)
		var errors := ScenarioContract.validate(scenario)
		assert_eq(errors, [] as Array[String], "%s's fixture must validate cleanly" % entry.objective_id)

		var root_seed: int = scenario.randomness.root_seed
		var seed_a := ScenarioContract.derive_iteration_seed(root_seed, scenario.scenario_id, 0)
		var seed_b := ScenarioContract.derive_iteration_seed(root_seed, scenario.scenario_id, 0)
		assert_eq(seed_a, seed_b, "%s's derived iteration seed must be deterministic" % entry.objective_id)

		var controller: Node2D = BattleStateFactory.build(scenario, seed_a)
		autofree(controller)

		var expected_player_count: int = scenario.player.units.size()
		var expected_enemy_count: int = scenario.enemy.units.size()
		var player_units := 0
		var enemy_units := 0
		for unit in controller.units:
			if unit.side == BattleControllerScript.Side.PLAYER:
				player_units += 1
			else:
				enemy_units += 1
		assert_eq(player_units, expected_player_count, "%s should field its declared player count" % entry.objective_id)
		assert_eq(enemy_units, expected_enemy_count, "%s should field its declared enemy count" % entry.objective_id)
		assert_true(controller.is_battle_won() or enemy_units > 0)


## The Ogre fixture specifically must hydrate with the boss's real tuned
## stats -- proof the JSON fixture actually names the "ogre" template rather
## than a placeholder.
func test_ogre_campaign_scenario_fixture_hydrates_the_tuned_ogre_stats() -> void:
	for entry in _load_campaign_scenarios():
		if String(entry.objective_id) != "obj_boss_borderlands_ogre":
			continue
		var scenario := ScenarioContract.normalize(entry.contract)
		var controller: Node2D = BattleStateFactory.build(scenario, 1)
		autofree(controller)

		var ogre = null
		for unit in controller.units:
			if unit.side == BattleControllerScript.Side.ENEMY:
				ogre = unit
		assert_not_null(ogre)
		assert_eq(ogre.max_health, GameSession.OGRE_ENEMY_STATS.max_health)
		assert_eq(ogre.defense, GameSession.OGRE_ENEMY_STATS.defense)
		assert_eq(ogre.resistance, GameSession.OGRE_ENEMY_STATS.resistance)
		return
	fail_test("obj_boss_borderlands_ogre fixture not found")
