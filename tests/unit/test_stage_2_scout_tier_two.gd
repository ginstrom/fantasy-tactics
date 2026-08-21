extends GutTest
## Proving suite for Step 4 of docs/plans/2026-08-21-stage-2-party-readiness/
## 04-scout-ranged-and-tier-two-pattern.md. Unlike Steps 1-3 of this plan,
## this step is a PROVING step: the Scout's ranged attack, line-of-sight, and
## proximity reconnaissance are already shipped (docs/plans/2026-08-18-
## core-loop-and-engagement/04-cleric-class-and-scout-reconnaissance.md and
## Step 2 of this plan's scout_keen_eyes perk). This file demonstrates the
## existing public contract holds, against the existing public APIs
## (GameSession.get_party_scouting_intel()/get_effective_scout_intel_range(),
## world_map.gd's marker/hover rendering, BattleController's range/LoS rules
## via ScenarioContract/BattleStateFactory) -- it never invents a parallel
## Scout model or duplicates that logic. See docs/designs/campaign-loop.md's
## tier-gate paragraph: "tier 2 tests scouting, ranged pressure, armour/
## resistance counterplay, and potion use" -- every section below maps onto
## one clause of that sentence.
##
## Task 1 (GameSession contract) and Task 5 (the tier-two fixture) reuse the
## shared autoloaded GameSession singleton (reset in before_each), matching
## test_world_map.gd's and test_battle_state_factory.gd's own convention,
## since Task 2's real world_map.tscn scene test needs the same autoload
## instance the scene itself reads from.

const GameSessionScript := preload("res://scripts/autoload/game_session.gd")
const WorldMapScene := preload("res://scenes/world/world_map.tscn")
const WorldMapScript := preload("res://scripts/world/world_map.gd")
const BattleStateFactory := preload("res://scripts/tools/battle_scenarios/battle_state_factory.gd")
const ScenarioContract := preload("res://scripts/tools/battle_scenarios/scenario_contract.gd")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")


func before_each() -> void:
	GameSession.reset()


func _deploy_party_with_scout_at(position: Vector2i) -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var scout := GameSession.get_default_scout("scout_test", "Test Scout")
	GameSession.adventurers.append(scout)
	GameSession.assign_adventurer_to_selected_party("scout_test")
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	GameSession.set_deployed_party_position(position)


## --- Task 1: GameSession.get_party_scouting_intel() public-contract proof --
## The base 3-tile range, the perk-extended 4-tile range, and the individual
## "no Scout"/"mixed authored formation" cases are already exhaustively
## proven in test_game_session.gd (its own "Scout strategic reconnaissance"
## section, plus test_get_party_scouting_intel_reveals_composition_for_an_
## authored_objective_id_the_same_as_a_sandbox_id added alongside this step).
## This section focuses on the three clauses those existing tests don't
## already isolate: the "only location, nothing else" shape of a no-intel
## result, a live in-range-then-out-of-range transition, and the base-vs-
## perk-extended range boundary read together in one place.

func test_no_scout_and_no_range_reveals_only_the_encounters_bare_location() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	var goblin_camp: Dictionary = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID)
	GameSession.set_deployed_party_position(goblin_camp.position)

	var intel: Dictionary = GameSession.get_party_scouting_intel(
		GameSession.FIRST_PARTY_ID, GameSession.GOBLIN_CAMP_ID
	)

	assert_false(intel.has_intel, "No deployed Scout means nothing beyond the encounter's bare location is known")
	assert_eq(intel.enemy_types, [])
	assert_eq(intel.enemy_counts, [])
	assert_eq(intel.enemy_count, 0)
	assert_eq(intel.danger_tier, 0)
	# The location itself is always public -- it comes from get_expedition(),
	# independent of intel entirely, which is exactly why has_intel/danger_
	# tier/enemy_* must be the only things this gate ever withholds.
	assert_true(goblin_camp.has("position"), "The bare location remains independently knowable")


func test_a_deployed_scout_within_range_reveals_danger_and_composition_and_nothing_else() -> void:
	_deploy_party_with_scout_at(GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID).position)

	var intel: Dictionary = GameSession.get_party_scouting_intel(
		GameSession.FIRST_PARTY_ID, GameSession.GOBLIN_CAMP_ID
	)

	assert_true(intel.has_intel)
	assert_eq(intel.danger_tier, 1)
	assert_eq(intel.enemy_types, [tr("battle.enemy.goblin")])
	assert_eq(intel.enemy_counts, [1])
	assert_eq(intel.enemy_count, 1)
	# A strict key-set check, not just "no reward field happens to be unset":
	# proves the contract has no reward/gold/battlefield-placement field to
	# ever leak, at any range, rather than relying on one field's absence.
	var expected_keys: Array = ["has_intel", "enemy_types", "enemy_counts", "enemy_count", "danger_tier"]
	assert_eq(intel.keys().size(), expected_keys.size(), "Scouting intel must never grow a reward/placement field")
	for key in expected_keys:
		assert_true(intel.has(key), "Scouting intel must still carry its documented %s field" % key)


func test_moving_the_deployed_party_out_of_scouting_range_removes_the_view() -> void:
	var goblin_camp: Dictionary = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID)
	_deploy_party_with_scout_at(goblin_camp.position)
	assert_true(
		GameSession.get_party_scouting_intel(GameSession.FIRST_PARTY_ID, GameSession.GOBLIN_CAMP_ID).has_intel,
		"Setup: intel must be visible while the Scout stands on the encounter itself"
	)

	# Goblin Camp sits at (4, 4); (0, 4) is Manhattan distance 4 -- one tile
	# beyond the base 3-tile range (BASE_SCOUT_INTEL_RANGE), with no
	# scout_keen_eyes perk chosen here to extend it.
	GameSession.set_deployed_party_position(Vector2i(0, 4))

	var intel_after_moving: Dictionary = GameSession.get_party_scouting_intel(
		GameSession.FIRST_PARTY_ID, GameSession.GOBLIN_CAMP_ID
	)
	assert_false(intel_after_moving.has_intel, "Moving out of range must remove the previously-earned view")
	assert_eq(intel_after_moving.danger_tier, 0)
	assert_eq(intel_after_moving.enemy_types, [])


func test_scout_keen_eyes_extends_the_reveal_range_to_four_tiles_but_not_further() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var scout := GameSession.get_default_scout("scout_test", "Test Scout")
	GameSession.adventurers.append(scout)
	GameSession.assign_adventurer_to_selected_party("scout_test")
	# award_party_xp() splits its amount evenly across all party members (two
	# here), so 100 total XP gives each member 50 -- the level 3 threshold a
	# perk choice requires.
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 100.0)
	assert_true(GameSession.choose_perk("scout_test", GameSessionScript.SCOUT_KEEN_EYES_PERK_ID))
	assert_eq(GameSession.get_effective_scout_intel_range("scout_test"), 4, "3 base + 1 scout_keen_eyes bonus")
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)

	# Goblin Camp sits at (4, 4); distance 4 is beyond the 3-tile base range
	# but within Keen Eyes' extended 4-tile range.
	GameSession.set_deployed_party_position(Vector2i(0, 4))
	var intel_at_distance_four: Dictionary = GameSession.get_party_scouting_intel(
		GameSession.FIRST_PARTY_ID, GameSession.GOBLIN_CAMP_ID
	)
	assert_true(intel_at_distance_four.has_intel, "Keen Eyes must extend the reveal range to 4 tiles")

	# Distance 5 -- (0, 4) to (-1, 4) is out of bounds, so move along y
	# instead: (0, 4) -> (0, -1) is also out of bounds; use (4, 9)? The board
	# is unrelated to World Map bounds here (GameSession does not clamp
	# set_deployed_party_position to a specific grid), so any tile 5 away
	# works -- (4, 9) is Manhattan distance 5 from (4, 4).
	GameSession.set_deployed_party_position(Vector2i(4, 9))
	var intel_at_distance_five: Dictionary = GameSession.get_party_scouting_intel(
		GameSession.FIRST_PARTY_ID, GameSession.GOBLIN_CAMP_ID
	)
	assert_false(intel_at_distance_five.has_intel, "Keen Eyes' extended range is still a hard 4-tile gate, not unlimited")


## --- Task 2: real world_map.tscn scene test -------------------------------
## See test_world_map.gd's own test_world_map_scene_reveals_an_authored_
## tier_two_markers_star_and_composition_once_a_scout_is_in_range() and its
## out-of-range companion, added alongside this step -- those drive the real
## scene's _draw_markers()/_update_hovered_encounter() path against an
## authored tier-2 node (obj_tier2_1_orc_outpost) and assert the rendered
## marker Label/InformationPanel, not merely GameSession's return value. Kept
## in test_world_map.gd rather than duplicated here so World Map's own
## rendering suite has exactly one home, per this step's "not a second Scout
## model" instruction.


## --- Task 3: scene-free scenario tests (ScenarioContract/BattleStateFactory)
## Every random roll here is the factory's own per-iteration-seeded RNG
## (BattleStateFactory.build()'s hit_roll/crit_roll/damage_roll/healing_roll)
## -- none of these tests overrides a roll callable by hand the way the older
## direct-UnitScript battle_controller tests do, so "seeded through the
## factory" is exercised end to end, not just at the hydration layer proven
## in test_battle_state_factory.gd.

func _scenario(raw: Dictionary) -> Dictionary:
	return ScenarioContract.normalize(raw)


func test_a_shortbow_scout_can_pressure_a_distant_target_with_clear_line_of_sight() -> void:
	var scenario := _scenario({
		"scenario_id": "shortbow_clear_los",
		"board": {"width": 6, "height": 6},
		"player": {"units": [{"id": "scout", "template_id": "scout", "weapon_id": "shortbow_iron", "position": {"x": 0, "y": 0}}]},
		"enemy": {"units": [{"id": "target", "template_id": "orc_bruiser", "position": {"x": 0, "y": 5}}]},
	})
	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)
	var scout = controller.get_unit_at(Vector2i(0, 0))
	var target = controller.get_unit_at(Vector2i(0, 5))

	assert_true(
		controller.get_legal_attack_targets(scout).has(target),
		"A shortbow's 1-8 range reaches a distance-5 target with a clear line of sight"
	)


func test_a_longbow_reaches_a_target_a_shortbow_cannot() -> void:
	# Distance 10 is beyond shortbow_iron's max_range (8) but within
	# longbow_iron's (12) -- demonstrating that bow choice is itself a
	# positioning decision (docs/designs/campaign-loop.md's "ranged pressure").
	var enemy_position := {"x": 0, "y": 10}
	var shortbow_scenario := _scenario({
		"scenario_id": "shortbow_out_of_range",
		"board": {"width": 11, "height": 11},
		"player": {"units": [{"id": "scout", "template_id": "scout", "weapon_id": "shortbow_iron", "position": {"x": 0, "y": 0}}]},
		"enemy": {"units": [{"id": "target", "template_id": "orc_bruiser", "position": enemy_position}]},
	})
	var longbow_scenario := _scenario({
		"scenario_id": "longbow_in_range",
		"board": {"width": 11, "height": 11},
		"player": {"units": [{"id": "scout", "template_id": "scout", "weapon_id": "longbow_iron", "position": {"x": 0, "y": 0}}]},
		"enemy": {"units": [{"id": "target", "template_id": "orc_bruiser", "position": enemy_position}]},
	})

	var short_controller: Node2D = BattleStateFactory.build(shortbow_scenario, 1)
	autofree(short_controller)
	var long_controller: Node2D = BattleStateFactory.build(longbow_scenario, 1)
	autofree(long_controller)

	var short_scout = short_controller.get_unit_at(Vector2i(0, 0))
	var short_target = short_controller.get_unit_at(Vector2i(0, 10))
	var long_scout = long_controller.get_unit_at(Vector2i(0, 0))
	var long_target = long_controller.get_unit_at(Vector2i(0, 10))

	assert_false(
		short_controller.get_legal_attack_targets(short_scout).has(short_target),
		"A shortbow (max range 8) cannot reach a distance-10 target"
	)
	assert_true(
		long_controller.get_legal_attack_targets(long_scout).has(long_target),
		"A longbow (max range 12) reaches the same distance-10 target"
	)


func test_an_occupied_intermediate_tile_blocks_line_of_sight_to_a_target_behind_it() -> void:
	# Occupied-endpoint LoS (grid.gd's has_line_of_sight() doc comment): any
	# other living unit's own tile blocks a shot passing through it, but never
	# blocks a shot landing ON it -- a blocker standing between the scout and
	# a priority target is itself still a legal (attackable) target.
	var scenario := _scenario({
		"scenario_id": "occupied_endpoint_los",
		"board": {"width": 6, "height": 6},
		"player": {"units": [{"id": "scout", "template_id": "scout", "weapon_id": "shortbow_iron", "position": {"x": 0, "y": 0}}]},
		"enemy": {
			"units": [
				{"id": "blocker", "template_id": "orc_bruiser", "position": {"x": 0, "y": 3}},
				{"id": "priority_target", "template_id": "goblin_archer", "position": {"x": 0, "y": 5}},
			],
		},
	})
	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)
	var scout = controller.get_unit_at(Vector2i(0, 0))
	var blocker = controller.get_unit_at(Vector2i(0, 3))
	var priority_target = controller.get_unit_at(Vector2i(0, 5))

	var legal_targets: Array = controller.get_legal_attack_targets(scout)

	assert_true(legal_targets.has(blocker), "The blocker's own tile is a legal target (occupied-endpoint exception)")
	assert_false(legal_targets.has(priority_target), "A living unit standing between the scout and the target blocks the shot")


func test_scout_pressures_a_protected_enemy_from_range_while_the_warrior_holds_the_front_line() -> void:
	# Demonstrates "a Scout that can pressure a protected enemy but cannot
	# substitute for a front line": the melee-only (attack_max_range 1) Orc
	# Bruiser can strike the adjacent Warrior but can never reach the distant
	# Scout, so only the Warrior's own adjacency actually draws its retaliation
	# -- ranged pressure is not a substitute for a unit willing to hold that
	# adjacent tile.
	var scenario := _scenario({
		"scenario_id": "pressure_without_substituting_front_line",
		"board": {"width": 6, "height": 6},
		"player": {
			"units": [
				{"id": "warrior_1", "template_id": "warrior", "position": {"x": 3, "y": 4}},
				{"id": "scout_1", "template_id": "scout", "weapon_id": "shortbow_iron", "position": {"x": 0, "y": 3}},
			],
		},
		"enemy": {"units": [{"id": "bruiser", "template_id": "orc_bruiser", "position": {"x": 3, "y": 3}}]},
	})
	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)
	var warrior = controller.get_unit_at(Vector2i(3, 4))
	var scout = controller.get_unit_at(Vector2i(0, 3))
	var bruiser = controller.get_unit_at(Vector2i(3, 3))

	assert_true(
		controller.get_legal_attack_targets(scout).has(bruiser),
		"The Scout can pressure the Bruiser from range 3 with a clear line of sight"
	)
	assert_true(
		controller.get_legal_attack_targets(bruiser).has(warrior),
		"The Bruiser's melee range reaches the adjacent Warrior holding the front line"
	)
	assert_false(
		controller.get_legal_attack_targets(bruiser).has(scout),
		"The Bruiser's melee range 1 can never reach the Scout -- ranged pressure never has to hold a front-line tile"
	)


func test_a_scenario_built_ranged_attack_against_an_armored_enemy_is_fully_reproducible_from_its_iteration_seed() -> void:
	# Every roll here comes from BattleStateFactory.build()'s own per-
	# iteration RandomNumberGenerator -- no hit_roll/crit_roll/damage_roll
	# override -- proving a Scout's bow attack against an armored (defense
	# 10/resistance 15) enemy reproduces identically from the seed alone, the
	# same reproducibility contract test_battle_state_factory.gd's own seeded-
	# roll tests already prove for the raw callables individually. Iteration
	# seed 1 is pinned (not arbitrary) precisely because it deterministically
	# produces a landed hit with real (non-zero) damage for this exact
	# scenario -- without the precondition asserts below, a seed that
	# happened to roll a miss on both runs would let this test pass
	# vacuously (false == false, 0 == 0) without ever proving damage
	# computation reproduces at all.
	var scenario := _scenario({
		"scenario_id": "reproducible_ranged_attack_vs_armor",
		"board": {"width": 6, "height": 6},
		"player": {"units": [{"id": "scout", "template_id": "scout", "weapon_id": "shortbow_iron", "position": {"x": 0, "y": 0}}]},
		"enemy": {"units": [{"id": "bruiser", "template_id": "orc_bruiser", "position": {"x": 0, "y": 4}}]},
	})

	var controller_a: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller_a)
	var controller_b: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller_b)

	var attacked_a: bool = controller_a.try_attack_selected_unit(Vector2i(0, 4))
	var attacked_b: bool = controller_b.try_attack_selected_unit(Vector2i(0, 4))

	assert_true(attacked_a, "A legal ranged target must execute regardless of hit/miss")
	assert_eq(attacked_a, attacked_b)
	# Precondition: this pinned seed must land a real hit with real damage on
	# BOTH runs, or the equality assertions below could pass vacuously on two
	# misses without proving anything about damage computation.
	assert_true(controller_a.last_attack_result.get("hit", false), "Seed 1 must land a hit -- pick a different seed if this ever regresses")
	assert_gt(int(controller_a.last_attack_result.get("damage", 0)), 0, "A landed hit against this target must deal real, non-zero damage")
	assert_eq(controller_a.last_attack_result.get("hit"), controller_b.last_attack_result.get("hit"))
	assert_eq(controller_a.last_attack_result.get("damage", 0), controller_b.last_attack_result.get("damage", 0))


## --- Task 5: the tier-two fixture ------------------------------------------

## Tier-two fixture: "Scout intel -> bow positioning -> armour/resistance/
## potion preparation" (docs/designs/campaign-loop.md's tier-gate paragraph:
## "tier 2 tests scouting, ranged pressure, armour/resistance counterplay,
## and potion use"). Named for the decision chain it demonstrates, not a
## single mechanic:
##
## 1. Scout intel (GameSession.get_party_scouting_intel(), proven in Task 1
##    above and in test_game_session.gd's own authored-id test) tells the
##    player, before this battle ever starts, that obj_tier2_1_orc_outpost
##    fields an armored Orc Bruiser (defense 10/resistance 15) escorted by a
##    Goblin Archer -- this fixture's own enemy composition mirrors that node.
## 2. That intel justifies bow positioning: a Scout stands at range with a
##    clear line of sight, applying pressure the Bruiser's own melee-only
##    range (1) can never punish -- the same shape proven in isolation by
##    test_scout_pressures_a_protected_enemy_from_range_while_the_warrior_
##    holds_the_front_line above.
## 3. Armour/resistance counterplay: the Warrior wears upgraded chainmail
##    (defense 15/resistance 20) rather than the default leather (10/10) to
##    withstand the Bruiser's melee while holding that front-line tile.
## 4. Potion preparation: a carried healing potion lets the Warrior recover
##    mid-battle once the Bruiser's melee has drawn it down, rather than
##    ending the encounter early.
##
## Built entirely through ScenarioContract/BattleStateFactory -- no scene, no
## ad hoc random global state. The one GameSession call the potion leg
## requires (equip_item_from_bank(), since try_use_selected_potion() ->
## GameSession.consume_carried_potion() is keyed to a real adventurer record)
## is why the Warrior's own scenario unit id is deliberately GameSession.
## WARRIOR_ID -- the one adventurer GameSession.reset() always seeds -- rather
## than an arbitrary made-up id.
## warrior_armor_id defaults to the fixture's own prepared chainmail_armor
## (see the doc comment above); test_tier_two_fixture_demonstrates_the_
## chainmail_warriors_armour_and_resistance_actually_reduce_bruiser_damage
## below passes "leather_armor" instead to build the SAME scenario/positions/
## enemy roll sequence with only the Warrior's armor swapped, so the two
## runs are otherwise identical inputs to the seeded RNG.
func _tier_two_fixture_scenario(warrior_armor_id: String = "chainmail_armor") -> Dictionary:
	return _scenario({
		"scenario_id": "tier_two_scout_intel_to_bow_and_potion_pattern",
		"board": {"width": 6, "height": 6},
		"player": {
			"units": [
				{
					"id": GameSession.WARRIOR_ID, "template_id": "warrior",
					"weapon_id": "longsword_iron", "armor_id": warrior_armor_id,
					"position": {"x": 3, "y": 4},
				},
				{
					"id": "scout_intel_bow", "template_id": "scout",
					"weapon_id": "shortbow_iron", "armor_id": "leather_armor",
					"position": {"x": 0, "y": 3},
				},
			],
		},
		"enemy": {
			"units": [
				{"id": "bruiser", "template_id": "orc_bruiser", "position": {"x": 3, "y": 3}},
				{"id": "archer", "template_id": "goblin_archer", "position": {"x": 5, "y": 0}},
			],
		},
	})


func test_tier_two_fixture_validates_cleanly_and_hydrates_the_prepared_equipment() -> void:
	var scenario := _tier_two_fixture_scenario()
	var errors: Array[String] = ScenarioContract.validate(scenario)
	assert_eq(errors, [] as Array[String], "The tier-two fixture must validate cleanly")

	var controller: Node2D = BattleStateFactory.build(scenario, 42)
	autofree(controller)
	var warrior = controller.get_unit_at(Vector2i(3, 4))
	var scout = controller.get_unit_at(Vector2i(0, 3))

	assert_eq(warrior.defense, GameSession.ARMORS.chainmail_armor.defense, "The prepared Warrior wears upgraded chainmail, not the default leather")
	assert_eq(warrior.resistance, GameSession.ARMORS.chainmail_armor.resistance)
	assert_gt(
		GameSession.ARMORS.chainmail_armor.resistance, GameSession.ARMORS.leather_armor.resistance,
		"Chainmail must be a genuine resistance upgrade for this to demonstrate armour/resistance counterplay"
	)
	assert_eq(scout.attack_min_range, GameSession.WEAPONS.shortbow_iron.min_range)
	assert_eq(scout.attack_max_range, GameSession.WEAPONS.shortbow_iron.max_range)


func test_tier_two_fixture_demonstrates_bow_positioned_pressure_alongside_the_warriors_front_line() -> void:
	var controller: Node2D = BattleStateFactory.build(_tier_two_fixture_scenario(), 42)
	autofree(controller)
	var warrior = controller.get_unit_at(Vector2i(3, 4))
	var scout = controller.get_unit_at(Vector2i(0, 3))
	var bruiser = controller.get_unit_at(Vector2i(3, 3))

	assert_true(
		controller.get_legal_attack_targets(scout).has(bruiser),
		"The Scout's bow positioning pressures the Bruiser from range 3 with a clear line of sight"
	)
	assert_true(
		controller.get_legal_attack_targets(bruiser).has(warrior),
		"The armored Warrior, not the Scout, holds the adjacent front-line tile the Bruiser can actually strike"
	)
	assert_false(controller.get_legal_attack_targets(bruiser).has(scout))


## Finding 1 fix: the two hydration assertions in test_tier_two_fixture_
## validates_cleanly_and_hydrates_the_prepared_equipment above (defense ==
## chainmail's catalog value, chainmail's catalog resistance > leather's)
## are pure data checks -- neither would fail if armour had zero effect on
## actual combat damage. This test instead builds the fixture scenario
## TWICE at the identical seed -- once with the Warrior in the fixture's own
## chainmail_armor, once with the same Warrior in leather_armor -- and has
## the Bruiser execute the exact same attack in both runs. Same seed means
## the same hit_roll/crit_roll/damage_roll draws in both runs (see
## BattleStateFactory.build()'s per-iteration RandomNumberGenerator); only
## the target's own defense/resistance differs. No roll is ever manually
## overridden here, keeping this file's "every random roll seeded through
## the factory" property. Seed 1 is pinned because it deterministically
## lands a hit in both runs (required for a real damage comparison) --
## see the precondition asserts below.
func test_tier_two_fixture_demonstrates_the_chainmail_warriors_armour_and_resistance_actually_reduce_bruiser_damage() -> void:
	var chainmail_controller: Node2D = BattleStateFactory.build(_tier_two_fixture_scenario("chainmail_armor"), 1)
	autofree(chainmail_controller)
	var leather_controller: Node2D = BattleStateFactory.build(_tier_two_fixture_scenario("leather_armor"), 1)
	autofree(leather_controller)

	for controller in [chainmail_controller, leather_controller]:
		controller.active_side = BattleControllerScript.Side.ENEMY
		controller.selected_unit = controller.get_unit_at(Vector2i(3, 3))  # the Bruiser

	var chainmail_attacked: bool = chainmail_controller.try_attack_selected_unit(Vector2i(3, 4))
	var leather_attacked: bool = leather_controller.try_attack_selected_unit(Vector2i(3, 4))

	# Precondition: both runs must land a real hit, or comparing damage would
	# be vacuous (e.g. 0 == 0 proves nothing about armour mitigating damage).
	assert_true(chainmail_attacked and leather_attacked)
	assert_true(chainmail_controller.last_attack_result.get("hit", false), "Seed 1 must land a hit against the chainmail Warrior")
	assert_true(leather_controller.last_attack_result.get("hit", false), "Seed 1 must land a hit against the leather Warrior")
	var chainmail_damage: int = int(chainmail_controller.last_attack_result.get("damage", 0))
	var leather_damage: int = int(leather_controller.last_attack_result.get("damage", 0))
	assert_gt(chainmail_damage, 0)
	assert_gt(leather_damage, 0)

	assert_lt(
		chainmail_damage, leather_damage,
		"The chainmail-armored Warrior must take strictly less damage from the identical Bruiser attack than the leather-armored one would -- real behavioral armour/resistance counterplay, not just a hydrated stat value"
	)


func test_tier_two_fixture_lets_the_warrior_use_a_prepared_potion_after_taking_armored_bruiser_damage() -> void:
	GameSession.banked_gear = {"healing_potion": 1}
	assert_true(GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "healing_potion"))
	var controller: Node2D = BattleStateFactory.build(_tier_two_fixture_scenario(), 42)
	autofree(controller)
	var warrior = controller.get_unit_at(Vector2i(3, 4))
	# Simulate the Warrior having already taken some of the Bruiser's melee
	# damage while holding the front line -- the exact combat roll that got it
	# there is not this test's concern (see the reproducible-ranged-attack
	# test above for that proof); what matters here is that the potion action
	# itself is available and functions on a fixture-built unit/adventurer.
	warrior.health = warrior.max_health - 5
	var health_before: int = warrior.health
	controller.selected_unit = warrior

	var used: bool = controller.try_use_selected_potion("healing_potion")

	assert_true(used, "A prepared potion must be usable on the fixture-built Warrior")
	assert_true(warrior.health > health_before, "healing_potion's 1-6 min heal must always recover at least 1 HP")
	assert_lte(warrior.health, warrior.max_health, "Healing must still clamp at max health")
	assert_eq(
		GameSession.get_carried_item_ids(GameSession.WARRIOR_ID).count("healing_potion"), 0,
		"The potion must be consumed, not reusable"
	)
