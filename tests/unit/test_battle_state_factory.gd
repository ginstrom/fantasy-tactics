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


## Cover terrain (Stage 5 D2, decision-ledger.md's "Terrain representation/
## distribution" row): hand-authored per encounter, hydrated onto the built
## Grid's own cover_tiles exactly as declared -- see grid.gd's own doc
## comment on why no procedural distribution exists anywhere in this
## pipeline.
func test_build_hydrates_authored_cover_tiles_onto_the_grid() -> void:
	var scenario := _normalized({
		"scenario_id": "covered_board",
		"board": {
			"cover": [
				{"position": {"x": 2, "y": 2}, "tier": "low"},
				{"position": {"x": 4, "y": 4}, "tier": "high"},
			],
		},
		"player": {"template_id": "warrior", "count": 1},
		"enemy": {"template_id": "goblin", "count": 1},
	})

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)

	assert_eq(controller.grid.get_cover(Vector2i(2, 2)), "low")
	assert_eq(controller.grid.get_cover(Vector2i(4, 4)), "high")
	assert_eq(controller.grid.get_cover(Vector2i(0, 0)), "")


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
	# Step 5's explicit shared tactical profile fields must hydrate
	# identically through this scene-free factory route -- see
	# BattleController._ready()'s matching assertions in
	# test_battle_controller.gd for the live-battle route.
	assert_eq(hero.melee, GameSession.CLASS_DEFINITIONS.warrior.base_stats.melee)
	assert_eq(hero.missile, GameSession.CLASS_DEFINITIONS.warrior.base_stats.missile)
	assert_eq(hero.guard, hero.defense)
	assert_eq(hero.spellcasting, 0, "Warrior has no spellcasting skill")
	assert_eq(hero.magic_resistance, 0)


func test_build_derives_the_enemy_units_stats_from_gamesessions_named_template() -> void:
	var controller: Node2D = BattleStateFactory.build(_one_v_one_scenario(), 1)
	autofree(controller)

	var grunt = controller.get_unit_at(Vector2i(5, 5))

	assert_eq(grunt.max_health, GameSession.GOBLIN_ENEMY_STATS.max_health)
	assert_eq(grunt.damage_min, GameSession.GOBLIN_ENEMY_STATS.damage_min)
	assert_eq(grunt.damage_max, GameSession.GOBLIN_ENEMY_STATS.damage_max)
	assert_eq(
		grunt.hit_chance,
		minf(GameSession.GOBLIN_ENEMY_STATS.melee / GameSession.ATTACK_TO_HIT_CHANCE_DIVISOR, GameSession.EFFECTIVE_HIT_CHANCE_CAP),
	)
	assert_eq(grunt.kill_xp, GameSession.GOBLIN_ENEMY_STATS.kill_xp)
	# Step 5's explicit shared tactical profile fields (docs/plans/2026-08-21-
	# stage-2-party-readiness/05-shared-tactical-profile-migration.md) must
	# hydrate identically through this scene-free factory route -- see
	# BattleController._ready()'s matching assertions in
	# test_battle_controller.gd for the live-battle route.
	assert_eq(grunt.melee, GameSession.GOBLIN_ENEMY_STATS.melee)
	assert_eq(grunt.missile, GameSession.GOBLIN_ENEMY_STATS.missile)
	assert_eq(grunt.guard, GameSession.GOBLIN_ENEMY_STATS.guard)
	assert_eq(grunt.spellcasting, GameSession.GOBLIN_ENEMY_STATS.spellcasting)
	assert_eq(grunt.magic_resistance, GameSession.GOBLIN_ENEMY_STATS.magic_resistance)


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


## --- Mage spells/MP hydration (Stage 5 D3) --------------------------------
## Mirrors the Cleric coverage immediately above -- KNOWN_PLAYER_TEMPLATES
## now includes "mage" (see scenario_contract.gd), and CLASS_DEFINITIONS.mage
## is read through the exact same generic hydration path, no Mage-specific
## code needed in battle_state_factory.gd's _build_player_unit() itself.

func test_build_hydrates_mage_spells_and_mp_from_the_class_definition() -> void:
	var scenario := _normalized({
		"scenario_id": "mage_hydration",
		"player": {"units": [{"id": "spellcaster", "template_id": "mage", "position": {"x": 0, "y": 0}}]},
		"enemy": {"template_id": "goblin", "count": 1},
	})

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)

	var mage = controller.get_unit_at(Vector2i(0, 0))
	var mage_def: Dictionary = GameSession.CLASS_DEFINITIONS.mage

	assert_eq(mage.spells, mage_def.spells)
	assert_eq(mage.mp_max, int(mage_def.mp_max))
	assert_eq(mage.mp_max, 3)
	assert_eq(mage.mp_remaining, mage.mp_max)
	assert_eq(mage.max_health, mage_def.base_stats.max_health)
	assert_eq(mage.spellcasting, mage_def.base_stats.spellcasting)


func test_build_hydrates_a_mages_mp_from_an_explicit_scenario_value() -> void:
	var scenario := _normalized({
		"scenario_id": "mage_explicit_mp",
		"player": {"units": [{"id": "spellcaster", "template_id": "mage", "position": {"x": 0, "y": 0}, "mp_current": 1}]},
		"enemy": {"template_id": "goblin", "count": 1},
	})

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)

	var mage = controller.get_unit_at(Vector2i(0, 0))
	assert_eq(mage.mp_max, 3)
	assert_eq(mage.mp_remaining, 1, "An explicit scenario mp_current must hydrate the built unit, not the class's full mp_max")


## Correctness fix this step made: a class whose skills_def omits a skill
## entirely (Mage has no "melee"/"guard"/"might" entry -- class-system.md's
## mage row reads them as n/a) must never grow that stat per level -- a
## level-2+ scenario Mage's melee/guard/might must equal the flat base_stats
## value, not base + a stray +1/level from a fallback default. Missile and
## Spellcasting (Mage's two real skills) DO grow, at their own tiers'
## min_gain, exactly like Cleric's growable skills already do.
func test_build_grows_only_a_level_2_mages_missile_and_spellcasting_never_melee_guard_or_might() -> void:
	var level_1_scenario := _normalized({
		"scenario_id": "mage_level_1",
		"player": {"units": [{"id": "spellcaster", "template_id": "mage", "position": {"x": 0, "y": 0}, "level": 1}]},
		"enemy": {"template_id": "goblin", "count": 1},
	})
	var level_2_scenario := _normalized({
		"scenario_id": "mage_level_2",
		"player": {"units": [{"id": "spellcaster", "template_id": "mage", "position": {"x": 0, "y": 0}, "level": 2}]},
		"enemy": {"template_id": "goblin", "count": 1},
	})

	var level_1_controller: Node2D = BattleStateFactory.build(level_1_scenario, 1)
	var level_2_controller: Node2D = BattleStateFactory.build(level_2_scenario, 1)
	autofree(level_1_controller)
	autofree(level_2_controller)

	var level_1_mage = level_1_controller.get_unit_at(Vector2i(0, 0))
	var level_2_mage = level_2_controller.get_unit_at(Vector2i(0, 0))
	var mage_def: Dictionary = GameSession.CLASS_DEFINITIONS.mage

	assert_eq(
		level_2_mage.missile, level_1_mage.missile + int(mage_def.skills.missile.min_gain),
		"missile is Mage's own low-tier skill -- must grow by min_gain per level"
	)
	assert_eq(
		level_2_mage.spellcasting, level_1_mage.spellcasting + int(mage_def.skills.spellcasting.min_gain),
		"spellcasting is Mage's own med-tier skill -- must grow by min_gain per level"
	)
	assert_eq(level_2_mage.melee, level_1_mage.melee, "melee is n/a for Mage -- must never grow")
	assert_eq(level_2_mage.guard, level_1_mage.guard, "guard is n/a for Mage -- must never grow")
	assert_eq(level_2_mage.might, level_1_mage.might, "might is n/a for Mage -- must never grow")


## --- Deterministic Mage Sleep scenario (Stage 5 D3 task 6) -----------------
## Proves the Mage's intended success case AND the counter (resisted) case
## both replay byte-identically for a fixed seed, built entirely through the
## production ScenarioContract/BattleStateFactory path (never a simulator-
## only parallel model) -- mirrors the real orc_outpost encounter's own
## Mage spellcasting (20)/Orc magic_resistance (50) values, giving the
## documented 30% resist chance (see EXPEDITIONS.orc_outpost's own doc
## comment). Seeds 1 and 13 were selected by probing sleep_resist_roll's
## first draw (a fresh controller's very first randf() call, since nothing
## else consumes the shared rng before a test's own try_cast_spell() call)
## against that exact 30% threshold, not cherry-picked from a live run --
## seed 1 draws ~0.33 (>= 30% -- succeeds), seed 13 draws ~0.06 (< 30% --
## resisted).
func _mage_vs_resistant_orc_scenario() -> Dictionary:
	return _normalized({
		"scenario_id": "mage_sleep_vs_resistant_orc",
		"player": {"units": [{"id": "spellcaster", "template_id": "mage", "position": {"x": 0, "y": 0}}]},
		"enemy": {"units": [
			{"id": "resistant_orc", "template_id": "orc", "position": {"x": 1, "y": 0}, "modifiers": {"magic_resistance": 50}},
		]},
	})


func test_seeded_sleep_scenario_succeeds_against_the_counter_enemy_on_seed_1() -> void:
	var controller: Node2D = BattleStateFactory.build(_mage_vs_resistant_orc_scenario(), 1)
	autofree(controller)
	var mage = controller.get_unit_at(Vector2i(0, 0))
	var orc = controller.get_unit_at(Vector2i(1, 0))
	controller.selected_unit = mage
	assert_eq(orc.magic_resistance, 50, "Precondition: the scenario's counter enemy carries the documented magic_resistance")
	assert_eq(mage.spellcasting, 20, "Precondition: the scenario's Mage carries the documented base spellcasting")

	assert_true(controller.try_cast_spell("sleep", orc.grid_position))

	assert_false(
		controller.last_attack_result.resisted,
		"Seed 1's first sleep_resist_roll draw (~0.33) sits above the 30% resist chance"
	)
	assert_true(controller.has_status(orc, "sleeping"))
	assert_eq(mage.mp_remaining, 2)


func test_seeded_sleep_scenario_is_resisted_by_the_counter_enemy_on_seed_13() -> void:
	var controller: Node2D = BattleStateFactory.build(_mage_vs_resistant_orc_scenario(), 13)
	autofree(controller)
	var mage = controller.get_unit_at(Vector2i(0, 0))
	var orc = controller.get_unit_at(Vector2i(1, 0))
	controller.selected_unit = mage

	assert_true(controller.try_cast_spell("sleep", orc.grid_position))

	assert_true(
		controller.last_attack_result.resisted,
		"Seed 13's first sleep_resist_roll draw (~0.06) sits below the 30% resist chance"
	)
	assert_false(controller.has_status(orc, "sleeping"))
	assert_eq(mage.mp_remaining, 2, "A resisted cast still spends its MP")


## Regression: a same-seed factory build must reproduce identical spell/
## resource outcomes -- CampaignSim's own "100% reproducible from sim_seed
## alone" contract, extended to Sleep's own new stochastic check.
func test_same_seed_sleep_scenario_reproduces_identical_outcomes() -> void:
	var controller_a: Node2D = BattleStateFactory.build(_mage_vs_resistant_orc_scenario(), 13)
	var controller_b: Node2D = BattleStateFactory.build(_mage_vs_resistant_orc_scenario(), 13)
	autofree(controller_a)
	autofree(controller_b)
	controller_a.selected_unit = controller_a.get_unit_at(Vector2i(0, 0))
	controller_b.selected_unit = controller_b.get_unit_at(Vector2i(0, 0))

	controller_a.try_cast_spell("sleep", Vector2i(1, 0))
	controller_b.try_cast_spell("sleep", Vector2i(1, 0))

	assert_eq(controller_a.last_attack_result.resisted, controller_b.last_attack_result.resisted)
	assert_eq(
		controller_a.get_unit_at(Vector2i(0, 0)).mp_remaining, controller_b.get_unit_at(Vector2i(0, 0)).mp_remaining
	)


## --- Deterministic Knight scenarios (Stage 5 D4 task 5) --------------------
## Proves Shield Bash's off-balance application and Chain Blow's bonus second
## strike both replay byte-identically for a fixed seed, built entirely
## through the production ScenarioContract/BattleStateFactory path. The
## favorable scenario clusters two Kobolds adjacent to the Knight (mirrors
## the real ruined_fortress encounter's own clustered Kobold swarm, see
## EXPEDITIONS.ruined_fortress) so Chain Blow has a second target to strike;
## the countered scenario fields a single, solitary Kobold (mirrors the real
## goblin_camp encounter's own solitary enemy, see EXPEDITIONS.goblin_camp)
## so Chain Blow -- present on the Knight either way -- never finds one.
## Kobold's 0 Guard/25 melee keeps both to-hit rolls favorable without
## inventing new stats.

func _knight_vs_clustered_kobolds_scenario() -> Dictionary:
	return _normalized({
		"scenario_id": "knight_shield_bash_and_chain_blow_favorable",
		"player": {
			"units": [
				{
					"id": "knight", "template_id": "warrior", "position": {"x": 0, "y": 0}, "level": 6,
					"specialization": "knight",
					"perks": [
						GameSession.WARRIOR_JUGGERNAUT_PERK_ID, GameSession.WARRIOR_BULWARK_PERK_ID,
						GameSession.KNIGHT_SHIELD_BASH_PERK_ID, GameSession.KNIGHT_CHAIN_BLOW_PERK_ID,
					],
				},
			],
		},
		"enemy": {"units": [
			{"id": "kobold_primary", "template_id": "kobold", "position": {"x": 1, "y": 0}},
			{"id": "kobold_second", "template_id": "kobold", "position": {"x": 1, "y": 1}},
		]},
	})


func _knight_vs_solitary_kobold_scenario() -> Dictionary:
	return _normalized({
		"scenario_id": "knight_chain_blow_countered_by_a_solitary_enemy",
		"player": {
			"units": [
				{
					"id": "knight", "template_id": "warrior", "position": {"x": 0, "y": 0}, "level": 6,
					"specialization": "knight",
					"perks": [
						GameSession.WARRIOR_JUGGERNAUT_PERK_ID, GameSession.WARRIOR_BULWARK_PERK_ID,
						GameSession.KNIGHT_SHIELD_BASH_PERK_ID, GameSession.KNIGHT_CHAIN_BLOW_PERK_ID,
					],
				},
			],
		},
		"enemy": {"units": [
			{"id": "kobold_solo", "template_id": "kobold", "position": {"x": 1, "y": 0}},
		]},
	})


func test_seeded_shield_bash_lands_and_chain_blow_strikes_the_adjacent_kobold_on_seed_1() -> void:
	var controller: Node2D = BattleStateFactory.build(_knight_vs_clustered_kobolds_scenario(), 1)
	autofree(controller)
	var knight = controller.get_unit_at(Vector2i(0, 0))
	var primary = controller.get_unit_at(Vector2i(1, 0))
	var second = controller.get_unit_at(Vector2i(1, 1))
	controller.selected_unit = knight

	assert_true(controller.try_shield_bash_selected_unit(primary.grid_position))

	assert_true(controller.last_attack_result.hit, "Seed 1's roll lands the primary Shield Bash hit")
	assert_true(primary.off_balance_pending, "A landed Shield Bash hit must off-balance the primary target")
	assert_false(controller.last_chain_blow_result.is_empty(), "Chain Blow must find the adjacent second Kobold")
	assert_eq(controller.last_chain_blow_result.defender, second)
	assert_true(controller.last_chain_blow_result.hit, "Seed 1's roll also lands the Chain Blow strike")
	assert_true(knight.chain_blow_used_this_round)


## Regression: a same-seed factory build must reproduce identical outcomes
## for both Shield Bash's off-balance application and Chain Blow's bonus
## strike -- CampaignSim's own "100% reproducible from sim_seed alone"
## contract, extended to Stage 5 D4's two new stochastic checks.
func test_same_seed_knight_scenario_reproduces_identical_outcomes() -> void:
	var controller_a: Node2D = BattleStateFactory.build(_knight_vs_clustered_kobolds_scenario(), 1)
	var controller_b: Node2D = BattleStateFactory.build(_knight_vs_clustered_kobolds_scenario(), 1)
	autofree(controller_a)
	autofree(controller_b)
	controller_a.selected_unit = controller_a.get_unit_at(Vector2i(0, 0))
	controller_b.selected_unit = controller_b.get_unit_at(Vector2i(0, 0))

	controller_a.try_shield_bash_selected_unit(Vector2i(1, 0))
	controller_b.try_shield_bash_selected_unit(Vector2i(1, 0))

	assert_eq(controller_a.last_attack_result.hit, controller_b.last_attack_result.hit)
	assert_eq(controller_a.last_chain_blow_result.hit, controller_b.last_chain_blow_result.hit)
	assert_eq(controller_a.last_chain_blow_result.damage, controller_b.last_chain_blow_result.damage)


## The countered case: Chain Blow is present on the Knight but a solitary
## enemy composition denies it a second target -- Shield Bash still applies
## normally (the counter is specific to Chain Blow's adjacency requirement,
## not Shield Bash), demonstrating why a party facing scattered/solitary
## enemies gets less value from Chain Blow than from a composition that
## clusters enemies together.
func test_seeded_chain_blow_finds_no_second_target_against_a_solitary_kobold_on_seed_1() -> void:
	var controller: Node2D = BattleStateFactory.build(_knight_vs_solitary_kobold_scenario(), 1)
	autofree(controller)
	var knight = controller.get_unit_at(Vector2i(0, 0))
	var solo = controller.get_unit_at(Vector2i(1, 0))
	controller.selected_unit = knight

	assert_true(controller.try_shield_bash_selected_unit(solo.grid_position))

	assert_true(controller.last_attack_result.hit, "Seed 1's roll still lands the primary Shield Bash hit")
	assert_true(solo.off_balance_pending, "Shield Bash's off-balance is unaffected by Chain Blow's own counter")
	assert_true(
		controller.last_chain_blow_result.is_empty(),
		"A solitary enemy composition denies Chain Blow a second target even though the Knight owns the perk"
	)
	assert_false(
		knight.chain_blow_used_this_round,
		"Chain Blow's once-per-round flag is only spent when it actually finds a second target"
	)


## --- Deterministic Archer scenarios (Stage 5 D4 task 5) --------------------
## Proves Called Shot's Guard-bypass and Lock On's same-target/last-round
## to-hit bonus both replay byte-identically for a fixed seed, and that each
## specifically flips a stubbed outcome (miss <-> hit), built entirely
## through the production ScenarioContract/BattleStateFactory path -- mirrors
## the Knight section above's "favorable / countered" pairing exactly, one
## pair per shipped ability. All four fixtures reuse the Warrior/Archer's own
## level-6 melee (75% hit_chance, unchanged from Knight's own fixtures) and
## Kobold's 0 base Guard/25 melee, adding only a "guard" modifier where a
## fixture specifically needs a defended target -- no new stats invented.

func _archer_vs_guarded_kobold_scenario(defender_guard: int) -> Dictionary:
	return _normalized({
		"scenario_id": "archer_called_shot_guard_probe",
		"player": {
			"units": [
				{
					"id": "archer", "template_id": "warrior", "position": {"x": 0, "y": 0}, "level": 6,
					"specialization": "archer",
					"perks": [
						GameSession.WARRIOR_JUGGERNAUT_PERK_ID, GameSession.WARRIOR_BULWARK_PERK_ID,
						GameSession.ARCHER_LOCK_ON_PERK_ID, GameSession.ARCHER_CALLED_SHOT_PERK_ID,
					],
				},
			],
		},
		"enemy": {"units": [
			{"id": "kobold", "template_id": "kobold", "position": {"x": 1, "y": 0}, "modifiers": {"guard": defender_guard}},
		]},
	})


func _archer_vs_one_kobold_scenario() -> Dictionary:
	return _normalized({
		"scenario_id": "archer_lock_on_favorable",
		"player": {
			"units": [
				{
					"id": "archer", "template_id": "warrior", "position": {"x": 0, "y": 0}, "level": 6,
					"specialization": "archer",
					"perks": [
						GameSession.WARRIOR_JUGGERNAUT_PERK_ID, GameSession.WARRIOR_BULWARK_PERK_ID,
						GameSession.ARCHER_LOCK_ON_PERK_ID, GameSession.ARCHER_CALLED_SHOT_PERK_ID,
					],
				},
			],
		},
		"enemy": {"units": [{"id": "kobold", "template_id": "kobold", "position": {"x": 1, "y": 0}}]},
	})


func _archer_vs_two_kobolds_scenario() -> Dictionary:
	return _normalized({
		"scenario_id": "archer_lock_on_countered_by_switching_targets",
		"player": {
			"units": [
				{
					"id": "archer", "template_id": "warrior", "position": {"x": 0, "y": 0}, "level": 6,
					"specialization": "archer",
					"perks": [
						GameSession.WARRIOR_JUGGERNAUT_PERK_ID, GameSession.WARRIOR_BULWARK_PERK_ID,
						GameSession.ARCHER_LOCK_ON_PERK_ID, GameSession.ARCHER_CALLED_SHOT_PERK_ID,
					],
				},
			],
		},
		"enemy": {"units": [
			{"id": "kobold_a", "template_id": "kobold", "position": {"x": 1, "y": 0}},
			{"id": "kobold_b", "template_id": "kobold", "position": {"x": 0, "y": 1}},
		]},
	})


## Favorable: a 40-Guard Kobold (a "modifiers" override, not a new monster --
## mirrors D3's own "hand-authored per encounter" precedent for a one-off
## stat variant) reduces a plain attack to a 35% effective hit chance (75%
## melee - 40 Guard); Called Shot ignores that Guard entirely and nets 75% -
## the flat 10% penalty = 65% instead. Seed 3's roll lands specifically
## inside that [35%, 65%) band -- a plain attack misses, Called Shot hits the
## exact same roll.
func test_seeded_called_shot_ignores_guard_and_flips_a_miss_to_a_hit_on_seed_3() -> void:
	var plain_controller: Node2D = BattleStateFactory.build(_archer_vs_guarded_kobold_scenario(40), 3)
	autofree(plain_controller)
	var plain_archer = plain_controller.get_unit_at(Vector2i(0, 0))
	var plain_kobold = plain_controller.get_unit_at(Vector2i(1, 0))
	plain_controller.selected_unit = plain_archer
	assert_true(plain_controller.try_attack_selected_unit(plain_kobold.grid_position))
	assert_false(plain_controller.last_attack_result.hit, "Seed 3's roll misses a plain attack against 40 Guard (35% effective hit chance)")

	var controller: Node2D = BattleStateFactory.build(_archer_vs_guarded_kobold_scenario(40), 3)
	autofree(controller)
	var archer = controller.get_unit_at(Vector2i(0, 0))
	var kobold = controller.get_unit_at(Vector2i(1, 0))
	controller.selected_unit = archer

	assert_true(controller.try_called_shot_selected_unit(kobold.grid_position))

	assert_eq(controller.last_attack_result.effective_defense, 0, "Called Shot ignores the defender's 40 Guard entirely")
	assert_true(controller.last_attack_result.called_shot)
	assert_true(controller.last_attack_result.hit, "Seed 3's exact same roll now hits once Guard is bypassed (65% effective hit chance)")


## Regression: a same-seed factory build must reproduce identical Called Shot
## outcomes -- CampaignSim's own "100% reproducible from sim_seed alone"
## contract, extended to Stage 5 D4's Archer branch.
func test_same_seed_called_shot_scenario_reproduces_identical_outcomes() -> void:
	var controller_a: Node2D = BattleStateFactory.build(_archer_vs_guarded_kobold_scenario(40), 3)
	var controller_b: Node2D = BattleStateFactory.build(_archer_vs_guarded_kobold_scenario(40), 3)
	autofree(controller_a)
	autofree(controller_b)
	controller_a.selected_unit = controller_a.get_unit_at(Vector2i(0, 0))
	controller_b.selected_unit = controller_b.get_unit_at(Vector2i(0, 0))

	controller_a.try_called_shot_selected_unit(Vector2i(1, 0))
	controller_b.try_called_shot_selected_unit(Vector2i(1, 0))

	assert_eq(controller_a.last_attack_result.hit, controller_b.last_attack_result.hit)
	assert_eq(controller_a.last_attack_result.damage, controller_b.last_attack_result.damage)


## The countered case: against a defenseless (0 Guard) Kobold, Called Shot's
## flat -10% penalty has nothing to offset -- a plain attack (75% effective
## hit chance) is strictly better than Called Shot (65%, since there is no
## Guard left to ignore). Seed 2's roll lands specifically inside that
## [65%, 75%) band -- a plain attack lands, Called Shot (the same roll)
## misses, demonstrating why Called Shot is a situational choice, not a
## strictly-dominant one.
func test_seeded_called_shot_is_worse_than_a_plain_attack_against_an_undefended_kobold_on_seed_2() -> void:
	var plain_controller: Node2D = BattleStateFactory.build(_archer_vs_guarded_kobold_scenario(0), 2)
	autofree(plain_controller)
	var plain_archer = plain_controller.get_unit_at(Vector2i(0, 0))
	var plain_kobold = plain_controller.get_unit_at(Vector2i(1, 0))
	plain_controller.selected_unit = plain_archer
	assert_true(plain_controller.try_attack_selected_unit(plain_kobold.grid_position))
	assert_true(plain_controller.last_attack_result.hit, "Seed 2's roll lands a plain attack against an undefended Kobold (75% effective hit chance)")

	var controller: Node2D = BattleStateFactory.build(_archer_vs_guarded_kobold_scenario(0), 2)
	autofree(controller)
	var archer = controller.get_unit_at(Vector2i(0, 0))
	var kobold = controller.get_unit_at(Vector2i(1, 0))
	controller.selected_unit = archer

	assert_true(controller.try_called_shot_selected_unit(kobold.grid_position))

	assert_true(controller.last_attack_result.called_shot)
	assert_false(
		controller.last_attack_result.hit,
		"Seed 2's exact same roll misses once Called Shot's flat 10% penalty applies with no Guard to offset it"
	)


## Favorable: the Archer attacks the same solitary Kobold on Round 1 and
## Round 2. Round 1 (seed 43's roll, deliberately a miss -- only the tracking
## matters here) stamps Unit.last_attacked_target/last_attacked_round; Round
## 2 reads that state, sees the same target on the immediately preceding
## Round, and applies Lock On's +10% -- flipping seed 43's Round-2 roll from
## a miss (75% base) to a hit (85% with the bonus).
func test_seeded_lock_on_applies_against_the_same_target_and_flips_a_miss_to_a_hit_on_seed_43() -> void:
	var controller: Node2D = BattleStateFactory.build(_archer_vs_one_kobold_scenario(), 43)
	autofree(controller)
	var archer = controller.get_unit_at(Vector2i(0, 0))
	var kobold = controller.get_unit_at(Vector2i(1, 0))
	controller.selected_unit = archer

	assert_true(controller.try_attack_selected_unit(kobold.grid_position))
	assert_eq(controller.current_round, 1)

	controller.end_turn()  # PLAYER -> ENEMY
	controller.end_turn()  # ENEMY -> PLAYER: Round 2 begins
	controller.selected_unit = archer
	archer.action_points_remaining = archer.max_action_points

	assert_true(controller.try_attack_selected_unit(kobold.grid_position))

	assert_true(controller.last_attack_result.lock_on_applied)
	assert_true(controller.last_attack_result.hit, "Seed 43's Round-2 roll hits once Lock On's +10% applies (85% effective hit chance)")


## Regression: a same-seed factory build must reproduce identical Lock On
## outcomes across both attacks -- same "100% reproducible from sim_seed
## alone" contract as the Called Shot regression test above.
func test_same_seed_lock_on_scenario_reproduces_identical_outcomes() -> void:
	var controller_a: Node2D = BattleStateFactory.build(_archer_vs_one_kobold_scenario(), 43)
	var controller_b: Node2D = BattleStateFactory.build(_archer_vs_one_kobold_scenario(), 43)
	autofree(controller_a)
	autofree(controller_b)
	for controller in [controller_a, controller_b]:
		controller.selected_unit = controller.get_unit_at(Vector2i(0, 0))
		controller.try_attack_selected_unit(Vector2i(1, 0))
		controller.end_turn()
		controller.end_turn()
		controller.selected_unit = controller.get_unit_at(Vector2i(0, 0))
		controller.get_unit_at(Vector2i(0, 0)).action_points_remaining = controller.get_unit_at(Vector2i(0, 0)).max_action_points
		controller.try_attack_selected_unit(Vector2i(1, 0))

	assert_eq(controller_a.last_attack_result.hit, controller_b.last_attack_result.hit)
	assert_eq(controller_a.last_attack_result.lock_on_applied, controller_b.last_attack_result.lock_on_applied)
	assert_eq(controller_a.last_attack_result.damage, controller_b.last_attack_result.damage)


## The countered case: two Kobolds are fielded instead of one -- the Archer
## attacks kobold_a on Round 1 and kobold_b (a DIFFERENT target) on Round 2.
## Lock On is present on the Archer either way (same perk list as the
## favorable fixture above), but the same seed 43 Round-2 roll that hits once
## Lock On applies (the favorable fixture) misses here, since kobold_b was
## never attacked on the immediately preceding Round -- demonstrating why
## switching targets forfeits Lock On's bonus.
func test_seeded_lock_on_grants_no_bonus_when_round_2_targets_a_different_kobold_on_seed_43() -> void:
	var controller: Node2D = BattleStateFactory.build(_archer_vs_two_kobolds_scenario(), 43)
	autofree(controller)
	var archer = controller.get_unit_at(Vector2i(0, 0))
	var kobold_a = controller.get_unit_at(Vector2i(1, 0))
	var kobold_b = controller.get_unit_at(Vector2i(0, 1))
	controller.selected_unit = archer

	assert_true(controller.try_attack_selected_unit(kobold_a.grid_position))

	controller.end_turn()
	controller.end_turn()
	controller.selected_unit = archer
	archer.action_points_remaining = archer.max_action_points

	assert_true(controller.try_attack_selected_unit(kobold_b.grid_position))

	assert_false(
		controller.last_attack_result.lock_on_applied,
		"kobold_b was never attacked on the immediately preceding Round -- a solitary-target composition denies Lock On the same way a solitary enemy denies Chain Blow"
	)
	assert_false(controller.last_attack_result.hit, "The same seed 43 roll that hits WITH Lock On's bonus (the favorable fixture) misses here without it")


## --- Deterministic Battle Mage scenarios (Stage 5 D4 task 5) ---------------
## Proves Fire Bolt's damage/resist-halving and Temporary Guard's Guard bonus
## both replay byte-identically for a fixed seed, built entirely through the
## production ScenarioContract/BattleStateFactory path. Fire Bolt reuses the
## exact same counter enemy/seeds as Mage's own Sleep fixture above (Orc,
## magic_resistance 50, spellcasting 20 -> the documented 30% resist chance,
## seeds 1/13 probed the same way) -- no new monster family, per D3's own
## "hand-authored per encounter" precedent D4 explicitly reuses.

func _battle_mage_vs_resistant_orc_scenario() -> Dictionary:
	return _normalized({
		"scenario_id": "battle_mage_fire_bolt_vs_resistant_orc",
		"player": {"units": [
			{
				"id": "battle_mage", "template_id": "mage", "position": {"x": 0, "y": 0},
				"specialization": "battle_mage",
			},
		]},
		"enemy": {"units": [
			{"id": "resistant_orc", "template_id": "orc", "position": {"x": 1, "y": 0}, "modifiers": {"magic_resistance": 50}},
		]},
	})


## Favorable: Fire Bolt has no accuracy roll at all (spells "always land" per
## combat-system.md), only the resist check -- seed 1's first draw (~0.33)
## sits above the 30% resist chance, so it lands full (unhalved) damage. The
## SAME seed's plain attack (the Mage's own weak 15% melee, longsword_iron's
## default 1-8 damage) misses outright, demonstrating exactly why Fire Bolt is
## the better choice against a magic-resistant target that a melee swing
## can't reliably even connect with.
func test_seeded_fire_bolt_lands_full_damage_while_a_plain_attack_misses_on_seed_1() -> void:
	var plain_controller: Node2D = BattleStateFactory.build(_battle_mage_vs_resistant_orc_scenario(), 1)
	autofree(plain_controller)
	var plain_mage = plain_controller.get_unit_at(Vector2i(0, 0))
	var plain_orc = plain_controller.get_unit_at(Vector2i(1, 0))
	plain_controller.selected_unit = plain_mage
	assert_true(plain_controller.try_attack_selected_unit(plain_orc.grid_position))
	assert_false(plain_controller.last_attack_result.hit, "Seed 1's roll misses the Mage's own weak 15% melee against the Orc")

	var controller: Node2D = BattleStateFactory.build(_battle_mage_vs_resistant_orc_scenario(), 1)
	autofree(controller)
	var mage = controller.get_unit_at(Vector2i(0, 0))
	var orc = controller.get_unit_at(Vector2i(1, 0))
	controller.selected_unit = mage
	assert_eq(orc.magic_resistance, 50, "Precondition: the scenario's counter enemy carries the documented magic_resistance")
	assert_eq(mage.spellcasting, 20, "Precondition: the scenario's Mage carries the documented base spellcasting")

	assert_true(controller.try_cast_spell("fire_bolt", orc.grid_position))

	assert_false(controller.last_attack_result.resisted, "Seed 1's resist roll (~0.33) sits above the 30% resist chance")
	assert_eq(controller.last_attack_result.damage, 7, "Fire Bolt always lands -- no accuracy roll at all, unlike the plain attack that just missed")
	assert_eq(mage.mp_remaining, 2)


## Countered: seed 13's resist roll (~0.06) sits below the 30% resist chance,
## HALVING (not negating) Fire Bolt's damage -- but the SAME seed's plain
## attack both lands AND deals more raw damage than the halved Fire Bolt,
## demonstrating decision-ledger.md's own example: against a magic-resistant
## enemy, a plain attack can outright beat a halved Fire Bolt.
func test_seeded_fire_bolt_is_halved_while_a_plain_attack_deals_more_damage_on_seed_13() -> void:
	var plain_controller: Node2D = BattleStateFactory.build(_battle_mage_vs_resistant_orc_scenario(), 13)
	autofree(plain_controller)
	var plain_mage = plain_controller.get_unit_at(Vector2i(0, 0))
	var plain_orc = plain_controller.get_unit_at(Vector2i(1, 0))
	plain_controller.selected_unit = plain_mage
	assert_true(plain_controller.try_attack_selected_unit(plain_orc.grid_position))
	assert_true(plain_controller.last_attack_result.hit, "Seed 13's roll lands the Mage's own weak melee attack (15% effective hit chance)")
	assert_eq(plain_controller.last_attack_result.damage, 7)

	var controller: Node2D = BattleStateFactory.build(_battle_mage_vs_resistant_orc_scenario(), 13)
	autofree(controller)
	var mage = controller.get_unit_at(Vector2i(0, 0))
	var orc = controller.get_unit_at(Vector2i(1, 0))
	controller.selected_unit = mage

	assert_true(controller.try_cast_spell("fire_bolt", orc.grid_position))

	assert_true(controller.last_attack_result.resisted, "Seed 13's resist roll (~0.06) sits below the 30% resist chance")
	assert_eq(controller.last_attack_result.damage, 1, "2 raw damage halved by the resist roll -- strictly less than the plain attack's 7 on this same seed")
	assert_eq(mage.mp_remaining, 2, "A resisted cast still spends its MP")


## Regression: a same-seed factory build must reproduce identical Fire Bolt
## outcomes -- CampaignSim's own "100% reproducible from sim_seed alone"
## contract, extended to Stage 5 D4's Battle Mage branch.
func test_same_seed_fire_bolt_scenario_reproduces_identical_outcomes() -> void:
	var controller_a: Node2D = BattleStateFactory.build(_battle_mage_vs_resistant_orc_scenario(), 13)
	var controller_b: Node2D = BattleStateFactory.build(_battle_mage_vs_resistant_orc_scenario(), 13)
	autofree(controller_a)
	autofree(controller_b)
	controller_a.selected_unit = controller_a.get_unit_at(Vector2i(0, 0))
	controller_b.selected_unit = controller_b.get_unit_at(Vector2i(0, 0))

	controller_a.try_cast_spell("fire_bolt", Vector2i(1, 0))
	controller_b.try_cast_spell("fire_bolt", Vector2i(1, 0))

	assert_eq(controller_a.last_attack_result.resisted, controller_b.last_attack_result.resisted)
	assert_eq(controller_a.last_attack_result.damage, controller_b.last_attack_result.damage)
	assert_eq(
		controller_a.get_unit_at(Vector2i(0, 0)).mp_remaining, controller_b.get_unit_at(Vector2i(0, 0)).mp_remaining
	)


## --- Deterministic Temporary Guard scenarios (Stage 5 D4 task 5) -----------
## Kobold's 0 base Guard/25 melee (same fixture stats Knight/Archer's own
## sections above already established) keeps both fixtures free of any newly
## invented monster stat.

func _battle_mage_vs_kobold_scenario() -> Dictionary:
	return _normalized({
		"scenario_id": "battle_mage_temporary_guard_vs_kobold",
		"player": {"units": [
			{
				"id": "battle_mage", "template_id": "mage", "position": {"x": 0, "y": 0},
				"specialization": "battle_mage", "perks": [GameSession.BATTLE_MAGE_TEMPORARY_GUARD_PERK_ID],
			},
		]},
		"enemy": {"units": [{"id": "kobold", "template_id": "kobold", "position": {"x": 1, "y": 0}}]},
	})


## A "modifiers" Guard override on the Battle Mage (mirrors Archer's own
## _archer_vs_guarded_kobold_scenario() precedent, just on the player side
## instead of the enemy) -- not a new monster, an authored one-off stat
## variant for this fixture only.
func _battle_mage_vs_kobold_scenario_with_extra_guard(extra_guard: int) -> Dictionary:
	return _normalized({
		"scenario_id": "battle_mage_temporary_guard_already_floored",
		"player": {"units": [
			{
				"id": "battle_mage", "template_id": "mage", "position": {"x": 0, "y": 0},
				"specialization": "battle_mage", "perks": [GameSession.BATTLE_MAGE_TEMPORARY_GUARD_PERK_ID],
				"modifiers": {"guard": extra_guard},
			},
		]},
		"enemy": {"units": [{"id": "kobold", "template_id": "kobold", "position": {"x": 1, "y": 0}}]},
	})


## Favorable: seed 39's first draw (~0.09) sits inside the flip band a flat
## +10 Guard opens against a Kobold's 25% melee -- 15% effective hit chance
## (10 Guard from the Mage's default leather armor) without Temporary Guard,
## 5% (the floor) with it active.
func test_seeded_temporary_guard_flips_an_attack_from_hit_to_miss_on_seed_39() -> void:
	var plain_controller: Node2D = BattleStateFactory.build(_battle_mage_vs_kobold_scenario(), 39)
	autofree(plain_controller)
	var plain_mage = plain_controller.get_unit_at(Vector2i(0, 0))
	var plain_kobold = plain_controller.get_unit_at(Vector2i(1, 0))
	plain_controller.selected_unit = plain_kobold
	plain_controller.active_side = BattleControllerScript.Side.ENEMY
	assert_true(plain_controller.try_attack_selected_unit(plain_mage.grid_position))
	assert_true(plain_controller.last_attack_result.hit, "Without Temporary Guard, seed 39's roll (~0.09) beats the Kobold's 15% effective hit chance")

	var controller: Node2D = BattleStateFactory.build(_battle_mage_vs_kobold_scenario(), 39)
	autofree(controller)
	var mage = controller.get_unit_at(Vector2i(0, 0))
	var kobold = controller.get_unit_at(Vector2i(1, 0))
	controller.selected_unit = mage
	assert_true(controller.try_temporary_guard_selected_unit())

	controller.selected_unit = kobold
	controller.active_side = BattleControllerScript.Side.ENEMY
	assert_true(controller.try_attack_selected_unit(mage.grid_position))

	assert_false(
		controller.last_attack_result.hit,
		"Temporary Guard's +10 Guard drops the Kobold to its 5% floor -- the same seed 39 roll now misses"
	)


## Countered: the Battle Mage's own Guard is already high enough (+40, a
## one-off "modifiers" override) that the Kobold's to-hit chance is already
## floored at 5% with no Temporary Guard at all -- casting it changes NOTHING
## (both effective_hit_chance values below are identical), so the 3 AP / 1 MP
## it costs buys zero additional defense this turn compared to just attacking
## with that same economy, per decision-ledger.md's own example.
func test_seeded_temporary_guard_adds_no_value_once_the_defender_is_already_floored() -> void:
	var plain_controller: Node2D = BattleStateFactory.build(_battle_mage_vs_kobold_scenario_with_extra_guard(40), 1)
	autofree(plain_controller)
	var plain_mage = plain_controller.get_unit_at(Vector2i(0, 0))
	var plain_kobold = plain_controller.get_unit_at(Vector2i(1, 0))
	plain_controller.selected_unit = plain_kobold
	plain_controller.active_side = BattleControllerScript.Side.ENEMY
	assert_true(plain_controller.try_attack_selected_unit(plain_mage.grid_position))
	assert_eq(
		plain_controller.last_attack_result.effective_hit_chance, BattleControllerScript.MIN_HIT_CHANCE,
		"The Mage's own +40 Guard modifier already floors the Kobold's to-hit chance with no Temporary Guard cast"
	)

	var controller: Node2D = BattleStateFactory.build(_battle_mage_vs_kobold_scenario_with_extra_guard(40), 1)
	autofree(controller)
	var mage = controller.get_unit_at(Vector2i(0, 0))
	var kobold = controller.get_unit_at(Vector2i(1, 0))
	controller.selected_unit = mage
	assert_true(controller.try_temporary_guard_selected_unit())

	controller.selected_unit = kobold
	controller.active_side = BattleControllerScript.Side.ENEMY
	assert_true(controller.try_attack_selected_unit(mage.grid_position))

	assert_eq(
		controller.last_attack_result.effective_hit_chance, BattleControllerScript.MIN_HIT_CHANCE,
		"Temporary Guard's own +10 Guard changes nothing once the Kobold is already floored"
	)
	assert_eq(
		plain_controller.last_attack_result.hit, controller.last_attack_result.hit,
		"Same seed, same floored hit chance either way -- Temporary Guard provably added zero defensive value this turn"
	)


## Regression: a same-seed factory build must reproduce identical Temporary
## Guard outcomes -- same "100% reproducible from sim_seed alone" contract.
func test_same_seed_temporary_guard_scenario_reproduces_identical_outcomes() -> void:
	var controller_a: Node2D = BattleStateFactory.build(_battle_mage_vs_kobold_scenario(), 39)
	var controller_b: Node2D = BattleStateFactory.build(_battle_mage_vs_kobold_scenario(), 39)
	autofree(controller_a)
	autofree(controller_b)
	for controller in [controller_a, controller_b]:
		var mage = controller.get_unit_at(Vector2i(0, 0))
		var kobold = controller.get_unit_at(Vector2i(1, 0))
		controller.selected_unit = mage
		controller.try_temporary_guard_selected_unit()
		controller.selected_unit = kobold
		controller.active_side = BattleControllerScript.Side.ENEMY
		controller.try_attack_selected_unit(mage.grid_position)

	assert_eq(controller_a.last_attack_result.hit, controller_b.last_attack_result.hit)
	assert_eq(controller_a.last_attack_result.effective_hit_chance, controller_b.last_attack_result.effective_hit_chance)


func test_build_leaves_a_non_spell_class_at_zero_mp_and_empty_spells() -> void:
	var controller: Node2D = BattleStateFactory.build(_one_v_one_scenario(), 1)
	autofree(controller)

	var hero = controller.get_unit_at(Vector2i(0, 0))

	assert_eq(hero.spells, [])
	assert_eq(hero.mp_max, 0)
	assert_eq(hero.mp_remaining, 0)


## --- Class-owned perks (docs/plans/2026-08-21-stage-2-party-readiness/
## final-review fix wave's Fix 1) --------------------------------------------
## Before this fix, a scenario-built unit's perks had zero mechanical effect
## (only the live BattleController._ready() route consulted GameSession's
## get_effective_max_health()/get_effective_defense()/get_effective_action_
## points()), so make campaign-sim's balance evidence silently modeled a
## build where 4 of 6 Stage 2 perks (all but Meditation/Keen Eyes, which
## affect spell/scout range rather than battle stats) were inert. These
## tests prove the scenario contract's own explicit "perks" field (never
## ambient GameSession.get_adventurer(...).progression.perks state) now
## drives the exact same math get_effective_max_health()/get_effective_
## defense()/get_effective_action_points() apply on the live route.

func test_build_applies_warrior_juggernauts_max_health_percent_bonus() -> void:
	var scenario := _normalized({
		"scenario_id": "juggernaut",
		"player": {
			"units": [
				{
					"id": "hero", "template_id": "warrior", "position": {"x": 0, "y": 0}, "level": 1,
					"perks": [GameSession.WARRIOR_JUGGERNAUT_PERK_ID],
				},
			],
		},
		"enemy": {"template_id": "goblin", "count": 1},
	})
	var base_max_health := int(GameSession.CLASS_DEFINITIONS.warrior.base_stats.vitality)

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)

	var hero = controller.get_unit_at(Vector2i(0, 0))
	var expected := base_max_health + int(round(base_max_health * GameSession.WARRIOR_JUGGERNAUT_HP_PERCENT / 100.0))
	assert_eq(hero.max_health, expected, "warrior_juggernaut must raise the scenario-built unit's max_health by its configured percent")
	assert_gt(hero.max_health, base_max_health, "The perk must actually change the built unit's stats, not just be recorded")


func test_build_omits_a_perks_bonus_when_the_scenario_names_no_perks() -> void:
	var controller: Node2D = BattleStateFactory.build(_one_v_one_scenario(), 1)
	autofree(controller)

	var hero = controller.get_unit_at(Vector2i(0, 0))
	var base_max_health := int(GameSession.CLASS_DEFINITIONS.warrior.base_stats.vitality)
	assert_eq(hero.max_health, base_max_health, "No perks field must leave max_health at its unmodified baseline")


func test_build_applies_warrior_bulwarks_flat_guard_bonus() -> void:
	var scenario := _normalized({
		"scenario_id": "bulwark",
		"player": {
			"units": [
				{
					"id": "hero", "template_id": "warrior", "weapon_id": "longsword_iron", "armor_id": "leather_armor",
					"position": {"x": 0, "y": 0}, "level": 1, "perks": [GameSession.WARRIOR_BULWARK_PERK_ID],
				},
			],
		},
		"enemy": {"template_id": "goblin", "count": 1},
	})
	var armor_defense := int(GameSession.ARMORS.leather_armor.defense)

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)

	var hero = controller.get_unit_at(Vector2i(0, 0))
	assert_eq(
		hero.defense, armor_defense + GameSession.WARRIOR_BULWARK_GUARD,
		"warrior_bulwark must add its configured flat Guard bonus on top of armor defense"
	)
	assert_eq(hero.guard, hero.defense, "The shared tactical Guard field must track the perk-inclusive defense exactly")


## Stage 5 D4: Unit.perks is what gates Shield Bash/Chain Blow in
## BattleController (see its own _unit_has_perk()) -- mirrors mp_current's/
## perks-bonus' own "explicit scenario field, never ambient GameSession
## state" precedent immediately above.
func test_build_hydrates_a_units_perks_list_including_specialization_perks() -> void:
	var scenario := _normalized({
		"scenario_id": "knight_perks_hydration",
		"player": {
			"units": [
				{
					"id": "hero", "template_id": "warrior", "position": {"x": 0, "y": 0}, "specialization": "knight",
					"perks": [GameSession.WARRIOR_BULWARK_PERK_ID, GameSession.KNIGHT_SHIELD_BASH_PERK_ID],
				},
			],
		},
		"enemy": {"template_id": "goblin", "count": 1},
	})

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)

	var hero = controller.get_unit_at(Vector2i(0, 0))
	assert_eq(hero.perks, [GameSession.WARRIOR_BULWARK_PERK_ID, GameSession.KNIGHT_SHIELD_BASH_PERK_ID])


func test_build_applies_scout_quickdraws_flat_action_point_bonus() -> void:
	var scenario := _normalized({
		"scenario_id": "quickdraw",
		"player": {
			"units": [
				{
					"id": "hero", "template_id": "scout", "position": {"x": 0, "y": 0}, "level": 1,
					"perks": [GameSession.SCOUT_QUICKDRAW_PERK_ID],
				},
			],
		},
		"enemy": {"template_id": "goblin", "count": 1},
	})

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)

	var hero = controller.get_unit_at(Vector2i(0, 0))
	assert_eq(
		hero.action_points_remaining, BattleControllerScript.BASE_ACTION_POINTS + GameSession.SCOUT_QUICKDRAW_ACTION_POINTS,
		"scout_quickdraw must add its configured flat AP bonus on top of the battle baseline"
	)


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
	assert_eq(grunt.damage_min, GameSession.GOBLIN_ENEMY_STATS.damage_min + 1)
	assert_eq(grunt.damage_max, GameSession.GOBLIN_ENEMY_STATS.damage_max + 1)


## Step 5's explicit shared tactical profile fields (melee/missile/guard/
## might/spellcasting/magic_resistance) are real modifier deltas on an enemy
## template, exactly like a player's -- see _build_player_unit()'s "attack"/
## "melee"/"missile" handling and the corresponding
## test_build_applies_explicit_player_modifiers_on_top_of_the_baseline test.
func test_build_applies_explicit_enemy_shared_profile_modifiers_on_top_of_the_baseline() -> void:
	var scenario := _normalized({
		"scenario_id": "modified_enemy_profile",
		"player": {"template_id": "warrior", "count": 1},
		"enemy": {
			"units": [
				{
					"id": "grunt", "template_id": "goblin", "position": {"x": 5, "y": 5},
					"modifiers": {"melee": 10, "guard": 15, "might": 2, "spellcasting": 3, "magic_resistance": 4},
				},
			],
		},
	})

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)
	var grunt = controller.get_unit_at(Vector2i(5, 5))

	assert_eq(grunt.melee, GameSession.GOBLIN_ENEMY_STATS.melee + 10)
	assert_eq(grunt.guard, GameSession.GOBLIN_ENEMY_STATS.guard + 15)
	assert_eq(grunt.defense, grunt.guard, "The legacy defense field and the new guard field must always agree")
	assert_eq(grunt.might, 2)
	assert_eq(grunt.spellcasting, 3)
	assert_eq(grunt.magic_resistance, 4)
	assert_eq(
		grunt.hit_chance,
		minf(
			(GameSession.GOBLIN_ENEMY_STATS.melee + 10) / GameSession.ATTACK_TO_HIT_CHANCE_DIVISOR,
			GameSession.EFFECTIVE_HIT_CHANCE_CAP,
		),
	)


## Fix-review finding 1 (docs/plans/2026-08-21-stage-2-party-readiness/
## 05-shared-tactical-profile-migration.md's task-1-report.md fix report): a
## "melee" modifier against a still-legacy template (ORC_BRUISER_ENEMY_STATS,
## authored with a flat hit_chance 0.5 and no melee/missile/attack_max_range
## keys, so it is a melee, not ranged, template) must adjust its *real*
## hit_chance-derived accuracy (50 + 10 = 60), not replace it with the bare
## modifier value (0 + 10 = 10) -- get_enemy_profile_melee() seeds the merge
## from hit_chance * 100 for exactly this reason. The resolved hit_chance
## itself must reflect the same base + modifier arithmetic, proving this
## isn't just a display-field fix.
func test_build_applies_a_melee_modifier_to_a_legacy_template_on_top_of_its_real_accuracy() -> void:
	var scenario := _normalized({
		"scenario_id": "legacy_melee_modifier",
		"player": {"template_id": "warrior", "count": 1},
		"enemy": {
			"units": [
				{"id": "grunt", "template_id": "orc_bruiser", "position": {"x": 5, "y": 5}, "modifiers": {"melee": 10}},
			],
		},
	})

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)
	var grunt = controller.get_unit_at(Vector2i(5, 5))

	assert_eq(GameSession.ORC_BRUISER_ENEMY_STATS.hit_chance, 0.5, "Guard against this fixture drifting silently")
	assert_eq(grunt.melee, 60, "50 (hit_chance-derived) + 10 (modifier), not 0 + 10")
	assert_eq(
		grunt.hit_chance, minf(0.6, GameSession.EFFECTIVE_HIT_CHANCE_CAP),
		"The resolved hit chance itself -- not just the display field -- must be base 0.5 + modifier 0.10 = 0.6"
	)


## Fix-review finding 2: a still-legacy template's melee/missile display
## fields must show its real, hit_chance-derived accuracy even with no
## modifier applied at all -- not a misleading 0 -- and this must never
## change the resolved hit_chance itself, which keeps coming from the exact
## same legacy hit_chance read as before this fix (GOBLIN_ARCHER_ENEMY_STATS
## is ranged -- attack_max_range 3 -- so this also proves the derivation
## doesn't accidentally depend on the ranged/melee split).
func test_build_derives_melee_and_missile_display_fields_for_an_unmodified_legacy_template() -> void:
	var scenario := _normalized({
		"scenario_id": "legacy_unmodified_display",
		"player": {"template_id": "warrior", "count": 1},
		"enemy": {"units": [{"id": "grunt", "template_id": "goblin_archer", "position": {"x": 5, "y": 5}}]},
	})

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)
	var grunt = controller.get_unit_at(Vector2i(5, 5))

	assert_eq(GameSession.GOBLIN_ARCHER_ENEMY_STATS.hit_chance, 0.4, "Guard against this fixture drifting silently")
	assert_eq(grunt.melee, 40, "0.4 hit_chance derived to a melee display value, not a misleading 0")
	assert_eq(grunt.missile, 40, "0.4 hit_chance derived to a missile display value, not a misleading 0")
	assert_eq(grunt.hit_chance, 0.4, "Unmodified: hit_chance itself must stay exactly the legacy value")


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


## Stage 5 D2 tactical primitives (docs/plans/2026-08-23-stage-5-strategic-
## roster-expansion/03-tactical-depth-primitives.md): Dodge/Parry are new
## stochastic checks that must be seeded from the same per-iteration
## RandomNumberGenerator as hit_roll/crit_roll/damage_roll -- never falling
## back to Godot's global, unseeded randf() -- or a deterministic scenario
## fielding either mechanic would stop reproducing byte-identically.
func test_build_seeds_dodge_roll_and_parry_roll_deterministically_from_the_iteration_seed() -> void:
	var scenario := _one_v_one_scenario()

	var controller_a: Node2D = BattleStateFactory.build(scenario, 12345)
	var controller_b: Node2D = BattleStateFactory.build(scenario, 12345)
	autofree(controller_a)
	autofree(controller_b)

	for _i in 5:
		assert_eq(controller_a.dodge_roll.call(), controller_b.dodge_roll.call())
	for _i in 5:
		assert_eq(controller_a.parry_roll.call(), controller_b.parry_roll.call())


## Sleep's magic-resistance roll (Stage 5 D3) is a new stochastic check --
## the same requirement as Dodge/Parry above: it must be seeded from the same
## per-iteration RandomNumberGenerator, never Godot's global unseeded randf(),
## or a deterministic scenario fielding a Mage's Sleep would stop reproducing
## byte-identically.
func test_build_seeds_sleep_resist_roll_deterministically_from_the_iteration_seed() -> void:
	var scenario := _one_v_one_scenario()

	var controller_a: Node2D = BattleStateFactory.build(scenario, 12345)
	var controller_b: Node2D = BattleStateFactory.build(scenario, 12345)
	autofree(controller_a)
	autofree(controller_b)

	for _i in 5:
		assert_eq(controller_a.sleep_resist_roll.call(), controller_b.sleep_resist_roll.call())


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
