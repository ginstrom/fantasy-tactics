extends GutTest
## Step 7 exit-gate integration proof for docs/plans/2026-08-21-stage-2-
## party-readiness/07-stage-2-exit-gate.md. Unlike Steps 1-6 (each proving
## one slice in isolation), this file is the capstone cross-cutting proof:
## Task 1 below is ONE integration test that walks class-owned perks (Step
## 2), durable Cleric MP/capped recovery/details healing (Step 3), Scout
## ranged/reconnaissance (Step 4), the shared tactical profile (Step 5), and
## an authored tier pattern plus retreat aftermath (Step 6) together across
## one realistic player sequence -- party formation, gear, a perk slot,
## Temple/Cleric, a details heal, capped recovery, battle entry/retreat, and
## a save export/import round trip -- through only public GameSession/
## ScenarioContract/BattleStateFactory APIs, never an internal state poke.
## Task 2 adds one ScenarioContract/BattleStateFactory fixture per Tier 1-3
## pattern, each proving class-resource hydration (Cleric MP, the shared
## tactical profile) alongside that tier's own already-authored combat
## lesson -- reusing the exact geometry/seeds test_stage_2_scout_tier_two.gd
## (Step 4) and test_stage_2_authored_readiness_patterns.gd (Step 6) already
## proved deterministic, with an idle Scout/Cleric unit added alongside
## (BattleStateFactory's hit_roll/crit_roll/damage_roll are lazily drawn from
## one shared per-controller RandomNumberGenerator only when an attack call
## actually consumes them -- see battle_state_factory.gd's build() -- so an
## extra player unit that never attacks or is attacked cannot perturb an
## already-pinned seed's outcome).

const ScenarioContract := preload("res://scripts/tools/battle_scenarios/scenario_contract.gd")
const BattleStateFactory := preload("res://scripts/tools/battle_scenarios/battle_state_factory.gd")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const GameSessionScript := preload("res://scripts/autoload/game_session.gd")


func before_each() -> void:
	GameSession.reset()
	GameSession.reset_injectable_rolls()


func _scenario(raw: Dictionary) -> Dictionary:
	return ScenarioContract.normalize(raw)


## --- Task 1: the full cross-cutting readiness sequence ---------------------
## One player-realistic sequence, in the order the exit-gate brief lists:
## form a legal up-to-five mixed party, equip class-compatible gear, reach a
## deterministic perk slot, build a Temple and recruit a Cleric, execute a
## details heal, advance capped HP/MP recovery, enter and retreat from a
## scenario battle with preserved aftermath, then export/import the result.
func test_full_readiness_sequence_forms_equips_perks_heals_recovers_retreats_and_round_trips_through_public_apis() -> void:
	# --- Form a legal up-to-five mixed party -------------------------------
	# Guild Hall level 3 legally raises the party cap to five (GUILD_HALL_
	# LEVEL_3_PARTY_CAP); a three-role Warrior/Scout/Cleric party sits well
	# within that ceiling -- proving "up to five" describes the legal
	# capacity, not a requirement to fill every slot.
	GameSession.guild_hall_level = 3
	assert_eq(GameSession.get_max_party_size(), 5, "Setup: Guild Hall level 3 must legally allow up to five party members")

	GameSession.create_party()
	assert_true(GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID))
	var scout_id := "readiness_scout"
	var scout := GameSession.get_default_scout(scout_id, "Readiness Scout")
	GameSession.adventurers.append(scout)
	assert_true(GameSession.assign_adventurer_to_selected_party(scout_id))
	assert_eq(GameSession.get_selected_party().member_ids, [GameSession.WARRIOR_ID, scout_id] as Array[String])
	assert_true(
		GameSession.get_selected_party().member_ids.size() <= GameSession.get_max_party_size(),
		"The formed party must be legal under the party cap"
	)

	# --- Equip class-compatible gear ---------------------------------------
	GameSession.banked_gear = {"chainmail_armor": 1, "longbow_iron": 1}
	assert_true(GameSession.can_adventurer_equip_item(GameSession.WARRIOR_ID, "chainmail_armor"))
	assert_true(GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "chainmail_armor"))
	assert_true(GameSession.can_adventurer_equip_item(scout_id, "longbow_iron"))
	assert_true(GameSession.equip_item_from_bank(scout_id, "longbow_iron"))
	assert_eq(GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment.armor, "chainmail_armor")
	assert_eq(GameSession.get_adventurer(scout_id).equipment.weapon, "longbow_iron")
	assert_eq(GameSession.get_effective_defense(GameSession.WARRIOR_ID), GameSession.ARMORS.chainmail_armor.defense)

	# --- Reach a deterministic perk slot ------------------------------------
	# award_party_xp() splits evenly across the two current members, so 100
	# total XP gives each exactly 50 -- get_level_xp_threshold(3)'s own value
	# -- landing both precisely on the level-3 (PERK_LEVEL_INTERVAL) slot.
	var warrior_base_max_health_before_perk: int = GameSession.get_effective_max_health(GameSession.WARRIOR_ID)
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 100.0)
	assert_eq(GameSession.get_adventurer(GameSession.WARRIOR_ID).level, 3)
	assert_eq(GameSession.get_adventurer(scout_id).level, 3)
	assert_true(GameSession.is_perk_choice_pending(GameSession.WARRIOR_ID))
	assert_true(GameSession.is_perk_choice_pending(scout_id))
	assert_eq(
		GameSession.get_available_perks(GameSession.WARRIOR_ID),
		[GameSessionScript.WARRIOR_JUGGERNAUT_PERK_ID, GameSessionScript.WARRIOR_BULWARK_PERK_ID]
	)
	assert_true(GameSession.choose_perk(GameSession.WARRIOR_ID, GameSessionScript.WARRIOR_JUGGERNAUT_PERK_ID))
	assert_true(GameSession.choose_perk(scout_id, GameSessionScript.SCOUT_KEEN_EYES_PERK_ID))
	assert_false(GameSession.is_perk_choice_pending(GameSession.WARRIOR_ID), "PERK_TREE_SIZE caps one earned slot at level 3")
	assert_false(GameSession.is_perk_choice_pending(scout_id))
	# Real mechanical payoff, not just a recorded id: Juggernaut raises max
	# HP, Keen Eyes extends scouting range.
	assert_gt(
		GameSession.get_effective_max_health(GameSession.WARRIOR_ID), warrior_base_max_health_before_perk,
		"warrior_juggernaut must actually raise effective max health"
	)
	assert_eq(GameSession.get_effective_scout_intel_range(scout_id), 4, "3 base + 1 scout_keen_eyes bonus")

	# --- Build a Temple and recruit a Cleric --------------------------------
	GameSession.gold = 500
	assert_true(GameSession.can_build_temple())
	assert_true(GameSession.build_temple())
	assert_eq(GameSession.temple_level, 1)
	var cleric_offers: Array = GameSession.get_recruitment_candidates().filter(func(c): return c.get("class", "") == "cleric")
	assert_eq(cleric_offers.size(), 1, "Setup: building the Temple must guarantee exactly one recruitable Cleric offer")
	var cleric_id: String = cleric_offers[0].id
	assert_true(GameSession.purchase_recruit_for_party(cleric_id, GameSession.FIRST_PARTY_ID))
	assert_true(GameSession.get_selected_party().member_ids.has(cleric_id))
	assert_eq(GameSession.get_selected_party().member_ids.size(), 3, "The mixed party now fields Warrior, Scout, and Cleric")
	assert_eq(
		GameSession.get_current_mp(cleric_id), GameSession.get_effective_max_mp(cleric_id),
		"A freshly recruited Cleric starts at full durable MP"
	)

	# A second perk slot, this time for the Cleric alone: award_party_xp()
	# now splits 150 XP three ways (50 each). The Warrior/Scout climb from
	# their already-spent level-3 slot to level 4 (threshold 90, still short
	# of level 6's next PERK_LEVEL_INTERVAL slot) while the freshly-joined
	# Cleric lands exactly on its own first level-3 slot -- proving all three
	# classes can field a meaningful, class-owned perk choice, not just two.
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 150.0)
	assert_eq(GameSession.get_adventurer(cleric_id).level, 3)
	assert_true(GameSession.is_perk_choice_pending(cleric_id))
	assert_true(GameSession.choose_perk(cleric_id, GameSessionScript.CLERIC_MEDITATION_PERK_ID))
	assert_eq(GameSession.get_effective_spell_range(cleric_id), 4, "3 base + 1 cleric_meditation bonus")

	# --- Execute a details heal ---------------------------------------------
	var warrior_max_hp: int = GameSession.get_effective_max_health(GameSession.WARRIOR_ID)
	assert_true(GameSession.set_adventurer_health(GameSession.WARRIOR_ID, warrior_max_hp - 5))
	GameSession.heal_amount_roll = func(_min_value: int, max_value: int) -> int: return max_value
	var cleric_mp_before_heal: int = GameSession.get_current_mp(cleric_id)
	var warrior_hp_before_heal: int = GameSession.get_current_health(GameSession.WARRIOR_ID)
	assert_true(GameSession.get_legal_heal_targets(cleric_id).has(GameSession.WARRIOR_ID))

	assert_true(GameSession.heal_party_member(cleric_id, GameSession.WARRIOR_ID))

	assert_eq(
		GameSession.get_current_mp(cleric_id), cleric_mp_before_heal - GameSession.DETAILS_HEAL_MP_COST,
		"A details heal must spend exactly DETAILS_HEAL_MP_COST durable MP"
	)
	assert_eq(
		GameSession.get_current_health(GameSession.WARRIOR_ID),
		mini(warrior_hp_before_heal + GameSession.DETAILS_HEAL_MAX, warrior_max_hp),
		"The pinned max heal_amount_roll must land, clamped at max HP"
	)

	# --- Advance capped HP/MP recovery --------------------------------------
	# Drive both resources deep into deficit through public setters (the same
	# durable fields battle aftermath itself writes), then advance many
	# encamped World Map Turns: recovery must climb but never overshoot
	# either effective max, and must actually reach it given enough turns.
	# The over-cap check below reads the *raw stored* record (get_adventurer()
	# duplicates adventurers[] verbatim, unclamped) rather than get_current_
	# health()/get_current_mp() -- those two getters clamp on every read
	# (game_session.gd's own clampi() in each), so asserting through them
	# could never actually catch a broken (or deleted) clamp inside _apply_
	# natural_recovery() itself; the getters would silently launder an
	# over-cap stored value back into range before this test ever saw it.
	assert_true(GameSession.set_adventurer_health(scout_id, 1))
	assert_true(GameSession.set_adventurer_mp(cleric_id, 0))
	var scout_max_hp: int = GameSession.get_effective_max_health(scout_id)
	var cleric_max_mp: int = GameSession.get_effective_max_mp(cleric_id)
	for _turn in 20:
		GameSession.end_world_turn()
		var scout_raw_hp: int = int(GameSession.get_adventurer(scout_id).get("health", 0))
		var cleric_raw_mp: int = int(GameSession.get_adventurer(cleric_id).get("mp_current", 0))
		assert_lte(scout_raw_hp, scout_max_hp, "The raw stored HP itself must never exceed effective max -- not just the clamped-on-read getter")
		assert_lte(cleric_raw_mp, cleric_max_mp, "The raw stored MP itself must never exceed effective max -- not just the clamped-on-read getter")
	assert_eq(GameSession.get_current_health(scout_id), scout_max_hp, "20 encamped turns must be enough to cap HP recovery")
	assert_eq(GameSession.get_current_mp(cleric_id), cleric_max_mp, "20 encamped turns must be enough to cap MP recovery")

	# --- Enter and retreat from a scenario battle, preserving aftermath ----
	var objective_id := "obj_tier1_1_goblin_outpost"
	assert_eq(GameSession.campaign_objective_id, objective_id, "Setup: a fresh campaign's first objective")
	assert_true(GameSession.can_enter_encounter(objective_id))
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	var expedition: Dictionary = GameSession.get_expedition(objective_id)
	GameSession.set_deployed_party_position(expedition.position)
	GameSession.enter_encounter(objective_id)
	assert_eq(GameSession.selected_encounter, objective_id)

	# Deliberately drop the Cleric to a *partial* durable MP (1 of 3) before
	# this battle -- BattleStateFactory defaults an unhydrated player unit's
	# mp_remaining to its own mp_max whenever a scenario spec omits mp_current
	# entirely (battle_state_factory.gd:250), so threading a *full* value (as
	# recovery just capped it to, above) would be indistinguishable from not
	# threading anything at all: the hydration assertion below could pass
	# even if the mp_current wiring were deleted. A partial value makes it a
	# real, falsifiable proof that durable state -- not the factory's own
	# default -- drove hydration.
	assert_true(GameSession.set_adventurer_mp(cleric_id, 1))
	var cleric_mp_before_battle: int = GameSession.get_current_mp(cleric_id)
	assert_eq(cleric_mp_before_battle, 1, "Setup: the Cleric must enter this battle at partial, not full, durable MP")

	# Thread the Warrior's real durable level and Juggernaut-inclusive
	# effective max health into the scenario too (via "level" and a "modifiers.
	# max_health" delta -- both real ScenarioContract fields, see scenario_
	# contract.gd:249/87), so the battle-local unit's stats actually match the
	# durable Warrior instead of silently defaulting to a level-1 (and
	# perk-less) 10 HP stand-in. Without this, the post-retreat HP assertion
	# below would be comparing a tiny scenario-local max_health against the
	# much larger durable effective max and could never meaningfully fail.
	var warrior_level: int = int(GameSession.get_adventurer(GameSession.WARRIOR_ID).level)
	var warrior_effective_max_health: int = GameSession.get_effective_max_health(GameSession.WARRIOR_ID)
	var warrior_vitality: int = int(GameSessionScript.CLASS_DEFINITIONS.warrior.base_stats.vitality)
	var warrior_scenario_base_max_health: int = warrior_vitality * warrior_level
	var warrior_max_health_modifier: int = warrior_effective_max_health - warrior_scenario_base_max_health
	assert_eq(
		GameSession.get_current_health(GameSession.WARRIOR_ID), warrior_effective_max_health,
		"Setup: the Warrior must enter this battle at full durable HP for the retreat-loss math below to be exact"
	)

	var scenario := _scenario({
		"scenario_id": "party_readiness_tier1_retreat",
		"board": {"width": 6, "height": 6},
		"player": {
			"units": [
				{
					"id": GameSession.WARRIOR_ID, "template_id": "warrior",
					"weapon_id": "longsword_iron", "armor_id": "chainmail_armor",
					"position": {"x": 3, "y": 4},
					"level": warrior_level,
					"modifiers": {"max_health": warrior_max_health_modifier},
				},
				{
					"id": scout_id, "template_id": "scout",
					"weapon_id": "longbow_iron", "armor_id": "leather_armor",
					"position": {"x": 1, "y": 4},
				},
				{
					# Hydrates from the party's own durable current MP -- the
					# same value production BattleController._ready() would
					# read via GameSession.get_current_mp() (see scenario_
					# contract.gd's own doc comment on mp_current).
					"id": cleric_id, "template_id": "cleric",
					"weapon_id": "mace_iron", "armor_id": "leather_armor",
					"position": {"x": 5, "y": 4}, "mp_current": cleric_mp_before_battle,
				},
			],
		},
		"enemy": {
			"units": [
				{"id": "goblin_1", "template_id": "goblin", "position": {"x": 3, "y": 1}, "facing": "down"},
				{"id": "kobold_1", "template_id": "kobold", "position": {"x": 2, "y": 1}},
				{"id": "kobold_2", "template_id": "kobold", "position": {"x": 4, "y": 1}},
			],
		},
	})
	var errors: Array[String] = ScenarioContract.validate(scenario)
	assert_eq(errors, [] as Array[String], "The readiness party's own retreat scenario must validate cleanly")

	var controller: Node2D = BattleStateFactory.build(scenario, 7)
	autofree(controller)
	var battle_warrior = controller.get_unit_at(Vector2i(3, 4))
	assert_eq(
		battle_warrior.max_health, warrior_effective_max_health,
		"The battle-local Warrior's max health must match the durable, Juggernaut-inclusive effective max exactly"
	)
	var battle_cleric = controller.get_unit_at(Vector2i(5, 4))
	assert_eq(battle_cleric.mp_max, GameSession.get_effective_max_mp(cleric_id))
	assert_eq(
		battle_cleric.mp_remaining, cleric_mp_before_battle,
		"Battle start must hydrate from the Cleric's own durable current (partial) MP, not the factory's full-MP default"
	)

	# The Cleric casts Bless on the Warrior before retreating -- a real,
	# public BattleController action (not a hand-mutated field) that spends
	# exactly SPELL_MP_COST of the Cleric's own hydrated 1 MP. Without this,
	# the post-aftermath MP assertion below would compare the pre-battle
	# value against itself (nothing else in this fixture ever changes it),
	# which would pass even if apply_battle_mp_aftermath() were a no-op --
	# casting a real spell makes the post-battle value provably different
	# from cleric_mp_before_battle, so write-back can only match by actually
	# threading the battle's own changed MP through.
	controller.selected_unit = battle_cleric
	var cast_bless: bool = controller.try_cast_spell("bless", Vector2i(3, 4))
	assert_true(cast_bless, "The Cleric must be able to cast Bless on the Warrior before retreating")
	var expected_cleric_mp_after_cast: int = cleric_mp_before_battle - BattleControllerScript.SPELL_MP_COST
	assert_eq(
		battle_cleric.mp_remaining, expected_cleric_mp_after_cast,
		"Casting Bless must spend exactly SPELL_MP_COST MP off the battle unit"
	)

	# Every board distance on a 6x6 board is "near" or "mid" per _retreat_
	# distance_bucket(); both buckets' no_loss threshold sits below 0.2, so
	# this pinned roll always lands "ten_percent" -- an HP-loss outcome, not
	# a clean escape or a death -- matching test_campaign_recovery.gd's own
	# established pin for the identical reason.
	controller.retreat_roll = func() -> float: return 0.2
	var retreat_results: Array = controller.try_retreat()
	assert_gt(retreat_results.size(), 0, "Retreat must resolve at least one living unit's outcome")
	for result in retreat_results:
		assert_eq(String(result.outcome), "ten_percent")
		assert_false(bool(result.died))

	# Preserve aftermath exactly as battlefield.gd's own _persist_battle_
	# aftermath() does: health/MP write-back keyed by adventurer id, built
	# from the controller's own surviving units.
	var health_by_id := {}
	var mp_by_id := {}
	for unit in controller.units:
		if unit.side == BattleControllerScript.Side.PLAYER and unit.adventurer_id != "":
			health_by_id[unit.adventurer_id] = unit.health
			if unit.mp_max > 0:
				mp_by_id[unit.adventurer_id] = unit.mp_remaining
	for adventurer_id in controller.defeated_player_health_by_id:
		health_by_id[adventurer_id] = controller.defeated_player_health_by_id[adventurer_id]
	GameSession.resolve_battle_deaths(health_by_id)
	GameSession.apply_battle_aftermath(health_by_id)
	GameSession.apply_battle_mp_aftermath(mp_by_id)
	GameSession.abandon_current_encounter()

	assert_eq(GameSession.selected_encounter, "")
	assert_true(GameSession.can_enter_encounter(objective_id), "A retreat must never complete or lock the objective")
	# Exact, falsifiable expected value -- not a loose "< max" inequality --
	# now that the scenario's max_health was threaded to match the durable
	# (Juggernaut-inclusive) effective max exactly (see setup above): the
	# pinned "ten_percent" outcome must cost precisely ceil(max_health * 0.10)
	# HP (battle_controller.gd's own _retreat_hp_loss() formula), written back
	# durably through the same resolve_battle_deaths()/apply_battle_aftermath()
	# calls production uses.
	var expected_ten_percent_hp_loss: int = int(ceil(warrior_effective_max_health * 0.10))
	var expected_warrior_hp_after_retreat: int = warrior_effective_max_health - expected_ten_percent_hp_loss
	assert_eq(
		GameSession.get_current_health(GameSession.WARRIOR_ID), expected_warrior_hp_after_retreat,
		"The pinned ten_percent retreat outcome must cost exactly ceil(max_health * 0.10) HP, written back durably"
	)
	# Distinct from cleric_mp_before_battle (1) by construction (the Bless
	# cast above spent SPELL_MP_COST off the battle unit) -- this can only
	# pass if apply_battle_mp_aftermath() actually threads the battle's own
	# post-cast MP value through, not merely leaves the pre-battle durable
	# value untouched.
	assert_eq(
		GameSession.get_current_mp(cleric_id), expected_cleric_mp_after_cast,
		"MP aftermath must write back the battle's own post-cast MP, not the untouched pre-battle value"
	)
	assert_true(GameSession.get_adventurer(GameSession.WARRIOR_ID).has("id"), "The Warrior must have survived the ten_percent retreat")
	assert_true(GameSession.get_adventurer(scout_id).has("id"), "The Scout must have survived the ten_percent retreat")
	assert_true(GameSession.get_adventurer(cleric_id).has("id"), "The Cleric must have survived the ten_percent retreat")

	# --- Export/import round trip -------------------------------------------
	var pre_export := {
		"member_ids": GameSession.get_selected_party().member_ids.duplicate(),
		"warrior_hp": GameSession.get_current_health(GameSession.WARRIOR_ID),
		"warrior_perks": GameSession.get_adventurer(GameSession.WARRIOR_ID).progression.perks.duplicate(),
		"warrior_armor": GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment.armor,
		"scout_perks": GameSession.get_adventurer(scout_id).progression.perks.duplicate(),
		"scout_weapon": GameSession.get_adventurer(scout_id).equipment.weapon,
		"scout_intel_range": GameSession.get_effective_scout_intel_range(scout_id),
		"cleric_perks": GameSession.get_adventurer(cleric_id).progression.perks.duplicate(),
		"cleric_mp": GameSession.get_current_mp(cleric_id),
		"cleric_spell_range": GameSession.get_effective_spell_range(cleric_id),
		"gold": GameSession.gold,
		"temple_level": GameSession.temple_level,
		"campaign_objective_id": GameSession.campaign_objective_id,
	}
	var snapshot: Dictionary = GameSession.export_campaign_snapshot()

	GameSession.reset()

	var import_result: Dictionary = GameSession.import_campaign_snapshot(snapshot)
	assert_true(import_result.ok, "The full readiness sequence's state must round-trip cleanly: %s" % import_result.get("error", ""))
	assert_eq(GameSession.get_selected_party().member_ids, pre_export.member_ids)
	assert_eq(GameSession.get_current_health(GameSession.WARRIOR_ID), pre_export.warrior_hp)
	assert_eq(GameSession.get_adventurer(GameSession.WARRIOR_ID).progression.perks, pre_export.warrior_perks)
	assert_eq(GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment.armor, pre_export.warrior_armor)
	assert_eq(GameSession.get_adventurer(scout_id).progression.perks, pre_export.scout_perks)
	assert_eq(GameSession.get_adventurer(scout_id).equipment.weapon, pre_export.scout_weapon)
	assert_eq(GameSession.get_effective_scout_intel_range(scout_id), pre_export.scout_intel_range)
	assert_eq(GameSession.get_adventurer(cleric_id).progression.perks, pre_export.cleric_perks)
	assert_eq(GameSession.get_current_mp(cleric_id), pre_export.cleric_mp)
	assert_eq(GameSession.get_effective_spell_range(cleric_id), pre_export.cleric_spell_range)
	assert_eq(GameSession.gold, pre_export.gold)
	assert_eq(GameSession.temple_level, pre_export.temple_level)
	assert_eq(GameSession.campaign_objective_id, pre_export.campaign_objective_id)


## --- Task 2: one fixture per authored tier ----------------------------------
## Each fixture below reuses the exact geometry and pinned iteration seed an
## earlier proving step (Step 4's test_stage_2_scout_tier_two.gd or Step 6's
## test_stage_2_authored_readiness_patterns.gd) already established as
## deterministic, with an idle Scout and/or Cleric added to the player side
## to additionally prove class-resource (Cleric MP) and shared tactical
## profile (melee/missile/guard/spellcasting/magic_resistance) hydration in
## the same fixture -- never a parallel balance model, and never a change to
## that already-authored geometry/seed's own combat outcome.

## --- Tier 1 fixture: formation/flanking + class-resource hydration --------
func _tier_one_readiness_fixture_scenario(warrior_position: Dictionary) -> Dictionary:
	return _scenario({
		"scenario_id": "party_readiness_tier_one_pattern",
		"board": {"width": 6, "height": 6},
		"player": {
			"units": [
				{
					"id": "warrior_1", "template_id": "warrior",
					"weapon_id": "longsword_iron", "armor_id": "leather_armor",
					"position": warrior_position,
				},
				{
					"id": "scout_1", "template_id": "scout",
					"weapon_id": "shortbow_iron", "armor_id": "leather_armor",
					"position": {"x": 5, "y": 5},
				},
				{
					"id": "cleric_1", "template_id": "cleric",
					"weapon_id": "mace_iron", "armor_id": "leather_armor",
					"position": {"x": 5, "y": 0}, "mp_current": 2,
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


func test_tier_one_fixture_hydrates_class_resources_and_demonstrates_the_authored_goblin_outposts_flanking_pattern() -> void:
	var scenario := _tier_one_readiness_fixture_scenario({"x": 4, "y": 3})
	var errors: Array[String] = ScenarioContract.validate(scenario)
	assert_eq(errors, [] as Array[String], "The tier-one readiness fixture must validate cleanly")

	var front_controller: Node2D = BattleStateFactory.build(scenario, 1)
	autofree(front_controller)
	var scout = front_controller.get_unit_at(Vector2i(5, 5))
	var cleric = front_controller.get_unit_at(Vector2i(5, 0))

	# Class resources: an explicit mp_current of 2 (of 3) hydrates exactly.
	assert_eq(cleric.mp_max, GameSessionScript.CLASS_DEFINITIONS.cleric.mp_max)
	assert_eq(cleric.mp_remaining, 2)
	# Shared tactical profile (Step 5): melee/missile/guard/spellcasting/
	# magic_resistance all hydrate from the same CLASS_DEFINITIONS base_stats
	# a live adventurer record reads at level 1 -- never a scenario-only stat
	# model.
	assert_eq(cleric.melee, GameSessionScript.CLASS_DEFINITIONS.cleric.base_stats.melee)
	assert_eq(cleric.missile, GameSessionScript.CLASS_DEFINITIONS.cleric.base_stats.missile)
	assert_eq(cleric.spellcasting, GameSessionScript.CLASS_DEFINITIONS.cleric.base_stats.spellcasting)
	assert_eq(
		cleric.guard,
		GameSession.ARMORS.leather_armor.defense + GameSessionScript.CLASS_DEFINITIONS.cleric.base_stats.guard
	)
	assert_eq(cleric.magic_resistance, 0)
	# Hydrated equipment: the Scout's shortbow range matches its own catalog
	# entry exactly (Step 4).
	assert_eq(scout.attack_min_range, GameSession.WEAPONS.shortbow_iron.min_range)
	assert_eq(scout.attack_max_range, GameSession.WEAPONS.shortbow_iron.max_range)

	# Seeded result: the identical front-vs-rear geometry/seed Step 6 already
	# probed (front lands a plain hit, rear lands a critical) reproduces
	# unchanged with the extra idle Scout/Cleric present.
	var rear_controller: Node2D = BattleStateFactory.build(_tier_one_readiness_fixture_scenario({"x": 2, "y": 3}), 1)
	autofree(rear_controller)
	var front_warrior = front_controller.get_unit_at(Vector2i(4, 3))
	var rear_warrior = rear_controller.get_unit_at(Vector2i(2, 3))
	front_controller.selected_unit = front_warrior
	rear_controller.selected_unit = rear_warrior

	var front_attacked: bool = front_controller.try_attack_selected_unit(Vector2i(3, 3))
	var rear_attacked: bool = rear_controller.try_attack_selected_unit(Vector2i(3, 3))

	assert_true(front_attacked and rear_attacked)
	assert_true(front_controller.last_attack_result.get("hit", false), "Seed 1 must land a hit from the front")
	assert_true(rear_controller.last_attack_result.get("hit", false), "Seed 1 must land a hit from the rear")
	assert_false(front_controller.last_attack_result.get("critical", false), "The front's base 5% critical chance must not clear")
	assert_true(rear_controller.last_attack_result.get("critical", false), "The rear's 50%-boosted critical chance must clear")
	var front_damage: int = int(front_controller.last_attack_result.get("damage", 0))
	var rear_damage: int = int(rear_controller.last_attack_result.get("damage", 0))
	assert_gt(front_damage, 0)
	assert_gt(rear_damage, front_damage, "A rear critical must deal strictly more damage than the identical front attack")


## --- Tier 2 fixture: Scout intel/ranged pressure/armor + class resources --
func _tier_two_readiness_fixture_scenario(warrior_armor_id: String = "chainmail_armor") -> Dictionary:
	return _scenario({
		"scenario_id": "party_readiness_tier_two_pattern",
		"board": {"width": 6, "height": 6},
		"player": {
			"units": [
				{
					"id": "warrior_1", "template_id": "warrior",
					"weapon_id": "longsword_iron", "armor_id": warrior_armor_id,
					"position": {"x": 3, "y": 4},
				},
				{
					"id": "scout_1", "template_id": "scout",
					"weapon_id": "shortbow_iron", "armor_id": "leather_armor",
					"position": {"x": 0, "y": 3},
				},
				{
					"id": "cleric_1", "template_id": "cleric",
					"weapon_id": "mace_iron", "armor_id": "leather_armor",
					"position": {"x": 0, "y": 0}, "mp_current": 1,
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


func test_tier_two_fixture_hydrates_class_resources_and_demonstrates_scout_intel_ranged_pressure_and_armor_counterplay() -> void:
	var scenario := _tier_two_readiness_fixture_scenario()
	var errors: Array[String] = ScenarioContract.validate(scenario)
	assert_eq(errors, [] as Array[String], "The tier-two readiness fixture must validate cleanly")

	var controller: Node2D = BattleStateFactory.build(scenario, 42)
	autofree(controller)
	var warrior = controller.get_unit_at(Vector2i(3, 4))
	var scout = controller.get_unit_at(Vector2i(0, 3))
	var cleric = controller.get_unit_at(Vector2i(0, 0))
	var bruiser = controller.get_unit_at(Vector2i(3, 3))

	# Class resources: an explicit mp_current of 1 (of 3) hydrates exactly.
	assert_eq(cleric.mp_max, GameSessionScript.CLASS_DEFINITIONS.cleric.mp_max)
	assert_eq(cleric.mp_remaining, 1)
	assert_eq(cleric.spellcasting, GameSessionScript.CLASS_DEFINITIONS.cleric.base_stats.spellcasting)

	# Hydrated equipment/profile: the prepared Warrior wears upgraded
	# chainmail, and the Scout's shortbow range matches its own catalog
	# entry exactly.
	assert_eq(warrior.defense, GameSession.ARMORS.chainmail_armor.defense)
	assert_eq(warrior.resistance, GameSession.ARMORS.chainmail_armor.resistance)
	assert_eq(scout.attack_min_range, GameSession.WEAPONS.shortbow_iron.min_range)
	assert_eq(scout.attack_max_range, GameSession.WEAPONS.shortbow_iron.max_range)

	# Scout intel -> ranged pressure: the Scout can pressure the Bruiser from
	# range with a clear line of sight, while the armored Warrior -- not the
	# Scout -- holds the adjacent front-line tile the Bruiser can strike.
	assert_true(controller.get_legal_attack_targets(scout).has(bruiser))
	assert_true(controller.get_legal_attack_targets(bruiser).has(warrior))
	assert_false(controller.get_legal_attack_targets(bruiser).has(scout))


## Seeded result: reuses Step 4's own probed seed 1, which lands a hit in
## both runs -- only the Warrior's armor differs between the two builds.
func test_tier_two_fixture_demonstrates_the_chainmail_warriors_armor_reduces_the_identical_bruiser_attacks_damage() -> void:
	var chainmail_controller: Node2D = BattleStateFactory.build(_tier_two_readiness_fixture_scenario("chainmail_armor"), 1)
	autofree(chainmail_controller)
	var leather_controller: Node2D = BattleStateFactory.build(_tier_two_readiness_fixture_scenario("leather_armor"), 1)
	autofree(leather_controller)

	for controller in [chainmail_controller, leather_controller]:
		controller.active_side = BattleControllerScript.Side.ENEMY
		controller.selected_unit = controller.get_unit_at(Vector2i(3, 3))  # the Bruiser

	var chainmail_attacked: bool = chainmail_controller.try_attack_selected_unit(Vector2i(3, 4))
	var leather_attacked: bool = leather_controller.try_attack_selected_unit(Vector2i(3, 4))

	assert_true(chainmail_attacked and leather_attacked)
	assert_true(chainmail_controller.last_attack_result.get("hit", false), "Seed 1 must land a hit against the chainmail Warrior")
	assert_true(leather_controller.last_attack_result.get("hit", false), "Seed 1 must land a hit against the leather Warrior")
	var chainmail_damage: int = int(chainmail_controller.last_attack_result.get("damage", 0))
	var leather_damage: int = int(leather_controller.last_attack_result.get("damage", 0))
	assert_gt(chainmail_damage, 0)
	assert_gt(leather_damage, 0)
	assert_lt(
		chainmail_damage, leather_damage,
		"The chainmail-armored Warrior must take strictly less damage from the identical Bruiser attack"
	)


## --- Tier 3 fixture: mixed-force target priority + class resources --------
func _tier_three_readiness_fixture_scenario(engaged_template_id: String) -> Dictionary:
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
		"scenario_id": "party_readiness_tier_three_pattern_%s" % engaged_template_id,
		"board": {"width": 6, "height": 6},
		"player": {
			"units": [
				{
					"id": "warrior_1", "template_id": "warrior",
					"weapon_id": "longsword_iron", "armor_id": "leather_armor",
					"position": {"x": 3, "y": 4},
				},
				{
					"id": "scout_1", "template_id": "scout",
					"weapon_id": "shortbow_iron", "armor_id": "leather_armor",
					"position": {"x": 5, "y": 5},
				},
				{
					"id": "cleric_1", "template_id": "cleric",
					"weapon_id": "mace_iron", "armor_id": "leather_armor",
					"position": {"x": 0, "y": 4},
				},
			],
		},
		"enemy": {"units": enemies},
	})


func test_tier_three_fixture_hydrates_class_resources_and_demonstrates_the_goblin_shaman_is_the_legible_priority_kill() -> void:
	var shaman_controller: Node2D = BattleStateFactory.build(_tier_three_readiness_fixture_scenario("goblin_shaman"), 90)
	autofree(shaman_controller)
	var bruiser_controller: Node2D = BattleStateFactory.build(_tier_three_readiness_fixture_scenario("orc_bruiser"), 90)
	autofree(bruiser_controller)
	var elite_controller: Node2D = BattleStateFactory.build(_tier_three_readiness_fixture_scenario("hobgoblin_elite"), 90)
	autofree(elite_controller)

	# Class resources/profile hydration: a full-MP Cleric (no explicit
	# mp_current here -- see scenario_contract.gd's own doc comment on that
	# field's -1 "not specified" default) alongside the Scout's shortbow
	# range, present in every one of this tier's three variants.
	var cleric = shaman_controller.get_unit_at(Vector2i(0, 4))
	assert_eq(cleric.mp_max, GameSessionScript.CLASS_DEFINITIONS.cleric.mp_max)
	assert_eq(cleric.mp_remaining, GameSessionScript.CLASS_DEFINITIONS.cleric.mp_max)
	var scout = shaman_controller.get_unit_at(Vector2i(5, 5))
	assert_eq(scout.attack_min_range, GameSession.WEAPONS.shortbow_iron.min_range)
	assert_eq(scout.attack_max_range, GameSession.WEAPONS.shortbow_iron.max_range)

	for controller in [shaman_controller, bruiser_controller, elite_controller]:
		controller.selected_unit = controller.get_unit_at(Vector2i(3, 4))  # the Warrior

	var shaman_attacked: bool = shaman_controller.try_attack_selected_unit(Vector2i(3, 3))
	var bruiser_attacked: bool = bruiser_controller.try_attack_selected_unit(Vector2i(3, 3))
	var elite_attacked: bool = elite_controller.try_attack_selected_unit(Vector2i(3, 3))

	assert_true(shaman_attacked and bruiser_attacked and elite_attacked)
	for result_controller in [shaman_controller, bruiser_controller, elite_controller]:
		assert_true(result_controller.last_attack_result.get("hit", false), "Seed 90 must land a hit in every matchup")
		assert_false(result_controller.last_attack_result.get("critical", false), "Seed 90 must not crit in any matchup")

	var shaman = shaman_controller.get_unit_at(Vector2i(3, 3))
	var bruiser = bruiser_controller.get_unit_at(Vector2i(3, 3))
	var elite = elite_controller.get_unit_at(Vector2i(3, 3))

	assert_eq(int(shaman_controller.last_attack_result.get("damage", 0)), 8, "No resistance: the full raw 8 damage lands")
	assert_eq(int(bruiser_controller.last_attack_result.get("damage", 0)), 7, "15% resistance mitigates the identical raw damage")
	assert_eq(int(elite_controller.last_attack_result.get("damage", 0)), 7, "10% resistance mitigates the identical raw damage")

	var shaman_remaining_fraction: float = float(shaman.health) / float(shaman.max_health)
	var bruiser_remaining_fraction: float = float(bruiser.health) / float(bruiser.max_health)
	var elite_remaining_fraction: float = float(elite.health) / float(elite.max_health)

	assert_lt(shaman_remaining_fraction, 0.15, "The identical attack must leave the Shaman near death -- the legible fast kill")
	assert_gt(bruiser_remaining_fraction, 0.70, "The armored Bruiser must shrug off the same attack by comparison")
	assert_gt(elite_remaining_fraction, 0.70, "The armored Hobgoblin Elite must shrug off the same attack by comparison")
