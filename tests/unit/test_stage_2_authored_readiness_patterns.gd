extends GutTest
## Proving suite for Step 6 of docs/plans/2026-08-21-stage-2-party-readiness/
## 06-authored-readiness-patterns.md. Like Step 4's test_stage_2_scout_
## tier_two.gd, this is a PROVING step: the tier-1 flanking/loot-banking
## mechanics and the tier-3 mixed-force composition already ship (Steps 2-5
## of this plan, plus docs/plans/2026-08-18-critical-hits-and-flanking and
## docs/plans/2026-08-18-core-loop-and-engagement/05-authored-encounters-
## and-final-boss.md). This file demonstrates the existing tier-1 and tier-3
## readiness patterns already teach their intended lesson (docs/designs/
## campaign-loop.md's "Tier gates must be understandable" paragraph: "Tier 1
## teaches formation, facing, flanking, and banking loot ... tier 3 tests
## target priority against mixed forces") against the actual authored
## CAMPAIGN_OBJECTIVES/EXPEDITIONS compositions, through real ScenarioContract/
## BattleStateFactory hydration and real GameSession loot state -- never a
## parallel balance model. The tier-2 pattern (Scout intel, ranged pressure,
## armour/resistance, potions) is already proven by test_stage_2_scout_
## tier_two.gd; test_ranged_enemy_ai.gd separately proves ranged pressure is
## bidirectional against the authored tier-2 composition.
##
## No enemy composition, stat, or reward value here differs from what
## GameSession.CAMPAIGN_OBJECTIVES/EXPEDITIONS/*_ENEMY_STATS and
## config/campaign_scenarios.json already ship -- every fixture below only
## re-expresses that already-authored, already-balanced content as a named,
## regression-pinned proof.

const ScenarioContract := preload("res://scripts/tools/battle_scenarios/scenario_contract.gd")
const BattleStateFactory := preload("res://scripts/tools/battle_scenarios/battle_state_factory.gd")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const GameSessionScript := preload("res://scripts/autoload/game_session.gd")


func _scenario(raw: Dictionary) -> Dictionary:
	return ScenarioContract.normalize(raw)


## --- Tier 1: "formation, facing, flanking" fixture --------------------------
## Named for obj_tier1_1_goblin_outpost (GameSession.EXPEDITIONS' own entry:
## one Goblin + two Kobolds -- mirrored exactly here) and the flanking rules
## Step 2/3 of docs/plans/2026-08-18-critical-hits-and-flanking already
## implement (BattleController.get_flank_type()/try_attack_selected_unit()).
## The Goblin's own shared tactical profile (GOBLIN_ENEMY_STATS) carries
## guard 0, so flanking's hit-chance bonus (a Guard *penalty* applied to the
## defender) has nothing to reduce here -- proving the pattern must instead
## show the OTHER half of flanking's effect: the side/rear critical-chance
## bonus (side +0.20, rear +0.50 -- see game_config.json's
## side_flank_crit_bonus/rear_flank_crit_bonus), which always applies
## regardless of a defender's own Guard.
func _tier_one_formation_fixture_scenario(warrior_position: Dictionary) -> Dictionary:
	return _scenario({
		"scenario_id": "tier_one_formation_and_flanking_pattern",
		"board": {"width": 6, "height": 6},
		"player": {
			"units": [
				{
					"id": "warrior_1", "template_id": "warrior",
					"weapon_id": "longsword_iron", "armor_id": "leather_armor",
					"position": warrior_position,
				},
			],
		},
		"enemy": {
			"units": [
				{"id": "goblin_1", "template_id": "goblin", "position": {"x": 3, "y": 3}, "facing": "right"},
				{"id": "kobold_1", "template_id": "kobold", "position": {"x": 0, "y": 0}},
				{"id": "kobold_2", "template_id": "kobold", "position": {"x": 0, "y": 5}},
			],
		},
	})


func test_tier_one_formation_fixture_validates_cleanly_and_hydrates_the_authored_goblin_outpost_composition() -> void:
	var scenario := _tier_one_formation_fixture_scenario({"x": 4, "y": 3})
	var errors: Array[String] = ScenarioContract.validate(scenario)
	assert_eq(errors, [] as Array[String], "The tier-one fixture must validate cleanly")

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)
	assert_eq(controller.units.size(), 4, "One Warrior plus the goblin_outpost's own one Goblin, two Kobolds")
	var goblin = controller.get_unit_at(Vector2i(3, 3))
	assert_eq(goblin.max_health, GameSessionScript.GOBLIN_ENEMY_STATS.max_health)
	assert_eq(goblin.defense, 0, "The shipped Goblin profile's guard is 0 -- flanking's Guard penalty has nothing to reduce")
	assert_eq(goblin.resistance, 0)


## Front vs. rear attack against the exact same goblin_outpost Goblin, at the
## identical iteration seed (1): BattleStateFactory.build() seeds hit_roll/
## crit_roll/damage_roll from one shared per-controller RandomNumberGenerator
## drawn in call order, so a front-only attack and a rear-only attack against
## an otherwise-identical fixture draw the SAME hit_roll and crit_roll values
## -- only the flank-derived effective_crit_chance the roll is compared
## against differs (base 5% front vs. base+50%=55% rear). Seed 1 is pinned
## (probed directly, not guessed) because it draws hit_roll=0.3296 (lands a
## hit against the Warrior's 60% level-1 hit chance) and crit_roll=0.2766 --
## below the rear 55% crit threshold but above the front 5% one -- so the
## SAME roll sequence lands a plain hit from the front and a critical hit
## from the rear, a real behavioral split rather than a hand-picked outcome.
func test_tier_one_formation_fixture_demonstrates_a_rear_attack_lands_a_critical_hit_a_front_attack_does_not() -> void:
	# Goblin faces "right" (east) at (3, 3). Attacking from (4, 3) (east,
	# ahead of its facing) is a front attack; attacking from (2, 3) (west,
	# behind its facing) is a rear attack -- both are adjacent (distance 1),
	# within the Warrior's longsword_iron melee range.
	var front_controller: Node2D = BattleStateFactory.build(_tier_one_formation_fixture_scenario({"x": 4, "y": 3}), 1)
	autofree(front_controller)
	var rear_controller: Node2D = BattleStateFactory.build(_tier_one_formation_fixture_scenario({"x": 2, "y": 3}), 1)
	autofree(rear_controller)
	# Stage 5 D2: pin Dodge/Parry off so the seeded RNG stream this fixture's
	# own doc comment probes (hit_roll=0.3296, crit_roll=0.2766, drawn in call
	# order from BattleStateFactory.build()'s per-controller RNG) still lands
	# on crit_roll as its second draw, exactly as before Dodge/Parry existed
	# -- this fixture is about flanking's crit math, not evasion.
	for evasion_controller in [front_controller, rear_controller]:
		evasion_controller.dodge_roll = func() -> float: return 1.0
		evasion_controller.parry_roll = func() -> float: return 1.0

	var front_warrior = front_controller.get_unit_at(Vector2i(4, 3))
	var rear_warrior = rear_controller.get_unit_at(Vector2i(2, 3))
	front_controller.selected_unit = front_warrior
	rear_controller.selected_unit = rear_warrior

	var front_attacked: bool = front_controller.try_attack_selected_unit(Vector2i(3, 3))
	var rear_attacked: bool = rear_controller.try_attack_selected_unit(Vector2i(3, 3))

	assert_true(front_attacked and rear_attacked)
	# Precondition: both runs must land a real hit, or the flank comparison
	# below would be vacuous.
	assert_true(front_controller.last_attack_result.get("hit", false), "Seed 1 must land a hit from the front")
	assert_true(rear_controller.last_attack_result.get("hit", false), "Seed 1 must land a hit from the rear")

	assert_eq(front_controller.last_attack_result.get("flank"), "front")
	assert_eq(rear_controller.last_attack_result.get("flank"), "rear")
	assert_false(
		front_controller.last_attack_result.get("critical", false),
		"The same crit roll must not clear the front's base 5% critical chance"
	)
	assert_true(
		rear_controller.last_attack_result.get("critical", false),
		"The identical crit roll must clear the rear's 50%-boosted critical chance -- real flanking payoff, not a data check"
	)
	var front_damage: int = int(front_controller.last_attack_result.get("damage", 0))
	var rear_damage: int = int(rear_controller.last_attack_result.get("damage", 0))
	assert_gt(front_damage, 0)
	assert_gt(
		rear_damage, front_damage,
		"A rear attack's critical multiplier must deal strictly more damage than the identical front attack -- formation/facing is a real mechanical decision, not flavor"
	)


## Formation fixture: obj_tier1_1_goblin_outpost's exact composition (one
## Goblin, two Kobolds -- all three melee-only, attack_max_range 1 by the
## shared-profile default, since none of GOBLIN_ENEMY_STATS/KOBOLD_ENEMY_
## STATS declares a ranged attack_min_range/attack_max_range) surrounds a
## single front-line tile from three sides. A Scout held two tiles further
## back is out of every one of their reach, not merely harder to reach --
## proving formation (who you place at the front vs. the back) is a real
## reachability decision with consequences, mirroring test_stage_2_scout_
## tier_two.gd's own "pressure without substituting for the front line"
## proof style (get_legal_attack_targets(), not a data check).
func _tier_one_formation_lineup_scenario() -> Dictionary:
	return _scenario({
		"scenario_id": "tier_one_formation_front_line_lineup",
		"board": {"width": 6, "height": 6},
		"player": {
			"units": [
				{"id": "warrior_1", "template_id": "warrior", "position": {"x": 3, "y": 3}},
				{"id": "scout_1", "template_id": "scout", "position": {"x": 3, "y": 5}},
			],
		},
		"enemy": {
			"units": [
				{"id": "goblin_1", "template_id": "goblin", "position": {"x": 3, "y": 2}},
				{"id": "kobold_1", "template_id": "kobold", "position": {"x": 2, "y": 3}},
				{"id": "kobold_2", "template_id": "kobold", "position": {"x": 4, "y": 3}},
			],
		},
	})


func test_tier_one_formation_fixture_demonstrates_the_front_line_absorbs_every_attack_the_back_line_never_faces() -> void:
	var scenario := _tier_one_formation_lineup_scenario()
	var errors: Array[String] = ScenarioContract.validate(scenario)
	assert_eq(errors, [] as Array[String], "The tier-one formation fixture must validate cleanly")

	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)
	var warrior = controller.get_unit_at(Vector2i(3, 3))
	var scout = controller.get_unit_at(Vector2i(3, 5))
	var goblin = controller.get_unit_at(Vector2i(3, 2))
	var kobold_1 = controller.get_unit_at(Vector2i(2, 3))
	var kobold_2 = controller.get_unit_at(Vector2i(4, 3))

	for enemy in [goblin, kobold_1, kobold_2]:
		assert_true(
			controller.get_legal_attack_targets(enemy).has(warrior),
			"Every one of the outpost's own enemies must be able to reach the Warrior holding the front-line tile"
		)
		assert_false(
			controller.get_legal_attack_targets(enemy).has(scout),
			"None of the outpost's melee-only enemies can reach the Scout held two tiles back -- formation, not luck, keeps it safe"
		)


## --- Tier 1: "return and bank loot" fixture ---------------------------------
## Named for obj_tier1_1_goblin_outpost's real loot output (GameSession.
## complete_current_encounter()/_roll_and_queue_loot(), reading its own
## EXPEDITIONS entry's "enemies" groups and ENEMY_LOOT_TABLES) and the two
## ways a battle's carried loot can resolve: merge_battle_loot_into_party()
## (a completed battle) then either deposit_pending_reward() (a safe return
## to bank it) or resolve_party_wipe() (a subsequent wipe before banking).
## docs/designs/campaign-loop.md's loss rule -- "a wipe loses all gold and
## loot" -- is proven here to mean exactly what it says: ALL current gold
## (deposit_pending_reward() merges pending_reward directly into `gold`,
## which resolve_party_wipe() always zeroes, banked or not) but only
## UNBANKED gear/mana crystals (banked_gear/mana_crystals survive a wipe
## once actually banked). The real decision this pattern teaches is
## "banking secures gear and mana crystals, not carried gold" -- proven
## precisely rather than assumed.
##
## Deterministic loot: loot_gold_roll pinned to its own minimum, loot_gear_
## roll pinned to 0.0 (always below GEAR_DROP_CHANCE). A bare GameSessionScript
## instance (not the shared GameSession autoload) matches test_game_session.
## gd's own loot-fixture convention (e.g. test_deposit_pending_reward_banks_
## gold_mana_crystals_and_gear()).
func _completed_goblin_outpost_session() -> Node:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
	session.loot_gear_roll = func() -> float: return 0.0
	session.enter_encounter("obj_tier1_1_goblin_outpost")
	session.complete_current_encounter()
	session.merge_battle_loot_into_party()
	return session


func test_completing_the_goblin_outpost_leaves_its_loot_pending_not_yet_safe() -> void:
	var session := _completed_goblin_outpost_session()

	# One Goblin (loot_id "goblin", gold_min 1) + two Kobolds (loot_id
	# "kobold", gold_min 0 each) + the flat first-clear bonus
	# (loot_gold_roll(18, 22) * difficulty 1, pinned to 18) = 19.
	assert_eq(session.pending_reward, 19)
	assert_eq(session.pending_gear, {"shortsword_iron": 1, "dagger_iron": 2})
	assert_eq(session.pending_mana_crystals, {1: 3})
	# The core of the "return and bank" decision: victory alone never makes
	# loot safe. It still sits in the party's carried, at-risk store.
	assert_eq(session.gold, 0, "Pending reward is not yet real gold")
	assert_eq(session.banked_gear, {}, "Pending gear is not yet banked")
	assert_eq(session.mana_crystals, {}, "Pending crystals are not yet banked")


func test_a_wipe_before_returning_forfeits_the_goblin_outposts_pending_loot() -> void:
	var session := _completed_goblin_outpost_session()
	assert_gt(session.pending_reward, 0, "Setup: the outpost must have queued real loot before the wipe")

	session.resolve_party_wipe()

	assert_eq(session.gold, 0)
	assert_eq(session.pending_reward, 0)
	assert_eq(session.pending_gear, {})
	assert_eq(session.pending_mana_crystals, {})
	assert_eq(session.banked_gear, {}, "Nothing was ever banked, so nothing here to preserve")


func test_returning_to_deposit_the_goblin_outposts_loot_preserves_gear_and_crystals_through_a_later_wipe_but_not_gold() -> void:
	var session := _completed_goblin_outpost_session()

	session.deposit_pending_reward()
	assert_eq(session.gold, 19, "Setup: returning to bank must pay the outpost's queued reward")
	assert_eq(session.banked_gear, {"shortsword_iron": 1, "dagger_iron": 2})
	assert_eq(session.mana_crystals, {1: 3})

	# Simulates the party pushing on to the next node and later wiping.
	session.resolve_party_wipe()

	assert_eq(session.banked_gear, {"shortsword_iron": 1, "dagger_iron": 2}, "Banked gear must survive a later wipe")
	assert_eq(session.mana_crystals, {1: 3}, "Banked mana crystals must survive a later wipe")
	assert_eq(
		session.gold, 0,
		"Gold is carried currency, not stored gear -- a wipe always forfeits it, banked into `gold` or not"
	)


## --- Tier 3: "mixed-force target priority" fixture --------------------------
## Named for obj_tier3_2_mixed_forces_ambush's exact composition (GameSession.
## EXPEDITIONS' own entry: one Hobgoblin Elite, one Orc Bruiser, one Goblin
## Shaman -- mirrored exactly here). The Goblin Shaman (GOBLIN_SHAMAN_ENEMY_
## STATS: max_health 9, guard/resistance both 0 via the still-legacy hit_
## chance/defense fallback, role "ranged_support", attack_max_range 3) is the
## legible priority target against the two armored melee elites (ORC_
## BRUISER_ENEMY_STATS/HOBGOBLIN_ELITE_ENEMY_STATS: guard 10/5, resistance
## 15/10, attack_max_range 1 -- melee only): it dies fastest to the same
## attack AND is the only one of the three that can strike from range,
## punishing a party that tries to just tank past it.
func _tier_three_mixed_forces_fixture_scenario(engaged_template_id: String) -> Dictionary:
	# All three of obj_tier3_2_mixed_forces_ambush's own enemies are always
	# present (compositional fidelity); whichever one is "engaged" sits
	# adjacent (distance 1, facing the attacker) so the same single attack
	# call is directly comparable across all three variants -- the other two
	# sit far away and never act (no attack call ever reaches them here, so
	# they never consume a roll from the shared per-iteration RNG).
	var enemies: Array = []
	var slots := {
		"hobgoblin_elite": {"id": "hobgoblin_elite_1", "far": {"x": 0, "y": 0}},
		"orc_bruiser": {"id": "orc_bruiser_1", "far": {"x": 0, "y": 5}},
		"goblin_shaman": {"id": "goblin_shaman_1", "far": {"x": 5, "y": 0}},
	}
	for template_id in slots:
		var slot: Dictionary = slots[template_id]
		var position: Dictionary = {"x": 3, "y": 3} if template_id == engaged_template_id else slot.far
		var facing: String = "down" if template_id == engaged_template_id else "left"
		enemies.append({"id": slot.id, "template_id": template_id, "position": position, "facing": facing})

	return _scenario({
		"scenario_id": "tier_three_mixed_forces_target_priority_pattern_%s" % engaged_template_id,
		"board": {"width": 6, "height": 6},
		"player": {
			"units": [
				{
					"id": "warrior_1", "template_id": "warrior",
					"weapon_id": "longsword_iron", "armor_id": "leather_armor",
					"position": {"x": 3, "y": 4},
				},
			],
		},
		"enemy": {"units": enemies},
	})


func test_tier_three_fixture_validates_cleanly_and_hydrates_the_authored_mixed_forces_composition() -> void:
	var scenario := _tier_three_mixed_forces_fixture_scenario("goblin_shaman")
	var errors: Array[String] = ScenarioContract.validate(scenario)
	assert_eq(errors, [] as Array[String], "The tier-three fixture must validate cleanly")

	var controller: Node2D = BattleStateFactory.build(scenario, 90)
	autofree(controller)
	assert_eq(controller.units.size(), 4, "One Warrior plus the mixed_forces_ambush's own three enemies")


## Identical Warrior attack (same seed 90, same front-flank geometry) against
## each of the three mixed_forces_ambush enemies in turn: seed 90 was probed
## directly (not guessed) to draw hit_roll=0.1367 (below even the tightest
## effective hit chance of the three -- the Orc Bruiser's 60%-10%=50%),
## crit_roll=0.3292 (above every front-flank 5% critical threshold, so none
## of the three crits -- an apples-to-apples plain-hit comparison), and
## damage_roll=8 (longsword_iron's max). The exact same raw 8 damage lands
## nearly-lethal on the Shaman (no resistance) and only a fraction of either
## armored melee enemy's health (15%/10% resistance) -- a real, computed
## behavioral gap, not a hand-asserted stat comparison.
func test_tier_three_fixture_demonstrates_the_goblin_shaman_is_the_legible_priority_kill() -> void:
	var shaman_controller: Node2D = BattleStateFactory.build(_tier_three_mixed_forces_fixture_scenario("goblin_shaman"), 90)
	autofree(shaman_controller)
	var bruiser_controller: Node2D = BattleStateFactory.build(_tier_three_mixed_forces_fixture_scenario("orc_bruiser"), 90)
	autofree(bruiser_controller)
	var elite_controller: Node2D = BattleStateFactory.build(_tier_three_mixed_forces_fixture_scenario("hobgoblin_elite"), 90)
	autofree(elite_controller)

	for controller in [shaman_controller, bruiser_controller, elite_controller]:
		controller.selected_unit = controller.get_unit_at(Vector2i(3, 4))  # the Warrior
		# Stage 5 D2: pin Dodge/Parry off so seed 90's probed roll sequence
		# (a plain, non-critical hit in every matchup) reproduces unchanged --
		# this fixture is about resistance/damage math, not evasion.
		controller.dodge_roll = func() -> float: return 1.0
		controller.parry_roll = func() -> float: return 1.0

	var shaman_attacked: bool = shaman_controller.try_attack_selected_unit(Vector2i(3, 3))
	var bruiser_attacked: bool = bruiser_controller.try_attack_selected_unit(Vector2i(3, 3))
	var elite_attacked: bool = elite_controller.try_attack_selected_unit(Vector2i(3, 3))

	assert_true(shaman_attacked and bruiser_attacked and elite_attacked)
	# Preconditions: every run must land a real, non-critical hit, or the
	# damage comparison below would be vacuous.
	for result_controller in [shaman_controller, bruiser_controller, elite_controller]:
		assert_true(result_controller.last_attack_result.get("hit", false), "Seed 90 must land a hit in every matchup")
		assert_false(result_controller.last_attack_result.get("critical", false), "Seed 90 must not crit in any matchup -- an apples-to-apples plain hit")

	var shaman = shaman_controller.get_unit_at(Vector2i(3, 3))
	var bruiser = bruiser_controller.get_unit_at(Vector2i(3, 3))
	var elite = elite_controller.get_unit_at(Vector2i(3, 3))

	assert_eq(int(shaman_controller.last_attack_result.get("damage", 0)), 8, "No resistance: the full raw 8 damage lands")
	assert_eq(int(bruiser_controller.last_attack_result.get("damage", 0)), 7, "15% resistance mitigates the identical raw damage")
	assert_eq(int(elite_controller.last_attack_result.get("damage", 0)), 7, "10% resistance mitigates the identical raw damage")

	var shaman_remaining_fraction: float = float(shaman.health) / float(shaman.max_health)
	var bruiser_remaining_fraction: float = float(bruiser.health) / float(bruiser.max_health)
	var elite_remaining_fraction: float = float(elite.health) / float(elite.max_health)

	assert_lt(
		shaman_remaining_fraction, 0.15,
		"The identical attack must leave the Shaman near death (1/9 health) -- the legible fast kill"
	)
	assert_gt(bruiser_remaining_fraction, 0.70, "The armored Bruiser must shrug off the same attack by comparison")
	assert_gt(elite_remaining_fraction, 0.70, "The armored Hobgoblin Elite must shrug off the same attack by comparison")


## The Shaman's own ranged_support role (attack_min_range 1, attack_max_range
## 3) means it can strike a target the two melee-only (attack_max_range 1)
## armored enemies can never reach -- proving the priority-kill lesson is not
## just "it dies fast" but "ignoring it while tanking the melee line still
## costs you," matching test_stage_2_scout_tier_two.gd's own "pressure
## without substituting for the front line" proof style for the reverse
## (enemy-side) case.
func test_tier_three_fixture_demonstrates_the_goblin_shaman_can_strike_from_range_the_armored_melee_enemies_cannot() -> void:
	var scenario := _scenario({
		"scenario_id": "tier_three_mixed_forces_ranged_shaman_threat",
		"board": {"width": 6, "height": 6},
		"player": {"units": [{"id": "warrior_1", "template_id": "warrior", "position": {"x": 3, "y": 0}}]},
		"enemy": {
			"units": [
				# Distances from the Warrior at (3, 0): Elite 6, Bruiser 5 --
				# both well beyond their own melee-only (range 1) reach.
				# Shaman 3 -- exactly its own attack_max_range, same column so
				# the line of sight is clear.
				{"id": "hobgoblin_elite_1", "template_id": "hobgoblin_elite", "position": {"x": 0, "y": 3}},
				{"id": "orc_bruiser_1", "template_id": "orc_bruiser", "position": {"x": 5, "y": 3}},
				{"id": "goblin_shaman_1", "template_id": "goblin_shaman", "position": {"x": 3, "y": 3}},
			],
		},
	})
	var controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(controller)
	var warrior = controller.get_unit_at(Vector2i(3, 0))
	var elite = controller.get_unit_at(Vector2i(0, 3))
	var bruiser = controller.get_unit_at(Vector2i(5, 3))
	var shaman = controller.get_unit_at(Vector2i(3, 3))

	assert_true(
		controller.get_legal_attack_targets(shaman).has(warrior),
		"The Shaman's range-3 attack reaches a target neither armored melee enemy can touch from the same distance"
	)
	assert_false(controller.get_legal_attack_targets(bruiser).has(warrior), "The melee-only Bruiser cannot reach the same target")
	assert_false(controller.get_legal_attack_targets(elite).has(warrior), "The melee-only Hobgoblin Elite cannot reach the same target")
