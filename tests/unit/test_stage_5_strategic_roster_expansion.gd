extends GutTest
## Step 7 (docs/plans/2026-08-23-stage-5-strategic-roster-expansion/
## 07-stage-5-exit-gate.md): one real journey, driven only through the public
## GameSession/GameManager contracts (plus CampaignSim's own already-existing
## private helpers for the authored-ladder portions -- the exact same
## machinery test_stage_3_campaign_assembly.gd's own exit-gate journey
## reuses, and the exact same machinery CampaignSim.run_campaign() itself
## calls to prove victory on the representative seed set), that exercises
## every Stage 5 decision (D1-D5, decision-ledger.md) layered on top of a
## real campaign in ONE composed arc: guaranteed authored discovery,
## optional Watchtower/quest intelligence, a promoted Knight specialization
## and its composition-dependent counter, a recruited Mage's Sleep spell and
## its magic-resistance counter, the universal Dodge/Parry/Cover/Opportunity-
## Attack tactical primitives, two independently-routed parties with a
## click-order battle-claim tie-break, and a transactional CampaignSnapshot
## export/reset/import checkpoint taken while BOTH parties are mid-route.
##
## This test does NOT re-derive:
##  - test_stage_3_campaign_assembly.gd's full 12-node arc to Final Boss
##    victory, or its own triple-direction export/import aliasing proof
##    (test_campaign_snapshot.gd already owns the general aliasing contract;
##    this file's own checkpoint below is a single straightforward round
##    trip extended to Stage 5's new fields, not a second aliasing proof).
##  - Any single mechanic's own byte-identical same-seed replay coverage
##    (test_battle_state_factory.gd's Sleep/Knight/Fire-Bolt/Paladin fixtures,
##    test_battle_controller.gd's Dodge/Parry/Cover/Opportunity-Attack unit
##    tests, test_scenario_runner.gd's RNG-isolation proofs, or
##    test_game_session.gd's D1/D5 seeded-roll determinism tests) -- those
##    already prove each mechanic reproduces identically from a fixed seed.
##    This file's own job is proving these mechanics COMPOSE across one real
##    campaign's durable state without corrupting each other or the original
##    single-party arc, which none of the per-slice files above attempt.
##
## Battle-mechanic demonstrations below are deliberately built directly
## through BattleStateFactory.build() (never battlefield.gd/a .tscn/UI
## script) with roll Callables overridden AFTER construction for
## determinism, exactly like test_battle_controller.gd's own established
## convention -- these are proof-of-resolution battles, not a second
## campaign simulator.

const CampaignSimScript := preload("res://scripts/tools/campaign_sim.gd")
const ScenarioContractScript := preload("res://scripts/tools/battle_scenarios/scenario_contract.gd")
const BattleStateFactoryScript := preload("res://scripts/tools/battle_scenarios/battle_state_factory.gd")

## A representative victory seed (CampaignSim.REPRESENTATIVE_VICTORY_SEEDS) --
## reused here (as test_stage_3_campaign_assembly.gd also does) so the
## authored-ladder portion of this journey (tier1_1, tier1_2) is guaranteed
## to clear under CampaignSim's own real bot/gear/recruit policy.
const JOURNEY_SEED := 4

const TIER1_1_ID := "obj_tier1_1_goblin_outpost"
const TIER1_2_ID := "obj_tier1_2_kobold_warren"
const TIER1_3_ID := "obj_tier1_3_goblin_warcamp"

const MAGE_ID := "stage5_exit_gate_mage"
const KNIGHT_ID := "stage5_exit_gate_knight"
const SCOUT_B_ID := "stage5_exit_gate_scout_b"


func before_each() -> void:
	GameSession.reset()
	GameSession.reset_injectable_rolls()
	GameManager.route_context_id = ""


func after_each() -> void:
	GameSession.reset()
	GameSession.reset_injectable_rolls()
	GameManager.route_context_id = ""


func test_stage_5_slices_compose_across_one_real_campaign_journey() -> void:
	var sim := CampaignSimScript.new()
	sim.sim_seed = JOURNEY_SEED
	var rng := RandomNumberGenerator.new()
	rng.seed = JOURNEY_SEED
	sim._wire_deterministic_rolls(rng)
	var telemetry := sim._new_telemetry(JOURNEY_SEED)

	# =========================================================================
	# PART 1 -- Fresh campaign, guaranteed authored discovery, and Step 2's
	# optional Watchtower/quest intelligence layered on top (D1).
	# =========================================================================

	# Deliberately NOT wired to the shared sim RNG (matching CampaignSim's own
	# _wire_deterministic_rolls() doc comment on why these three stay
	# separate) -- forced to guaranteed-success values so this journey's own
	# intel/quest beats are deterministic without perturbing the seeded
	# campaign stream tier1_1/tier1_2 depend on.
	GameSession.quest_posting_roll = func() -> float: return 0.0
	GameSession.detection_roll = func() -> float: return 0.0
	GameSession.intel_tier_roll = func() -> float: return 0.0

	GameSession.start_new_game()
	assert_eq(GameSession.campaign_objective_id, TIER1_1_ID)
	assert_true(
		GameSession.can_enter_encounter(TIER1_1_ID),
		"Guaranteed objective discovery: the first authored node is immediately enterable from turn one, before any intel/quest/watchtower activity"
	)

	# goblin_camp is one of the two live sandbox instances reset() seeds
	# immediately -- with quest_posting_roll forced to succeed, it must carry
	# a posted quest from turn one (D1's "a new live encounter instance is
	# created" trigger).
	var goblin_quest_id := String(GameSession.encounter_intel[GameSession.GOBLIN_CAMP_ID].quest_id)
	assert_ne(goblin_quest_id, "", "Setup: goblin_camp must have a quest posted")
	assert_eq(String(GameSession.get_quest(goblin_quest_id).status), GameSession.QUEST_STATUS_POSTED)

	GameSession.create_party()
	var party_a_id: String = GameSession.selected_party_id
	sim._refill_party(telemetry)
	GameSession.deploy_party(party_a_id)
	assert_true(GameSession.has_deployed_party(party_a_id), "Setup: the journey needs a deployed party to begin")

	# Watchtower purchase (D1's approved balance table, unchanged) raises
	# encampment detection so goblin_camp's intel accumulates within a
	# couple of World Map Turns.
	GameSession.gold += GameSession.WATCHTOWER_TIER_1_COST
	assert_true(GameSession.upgrade_watchtower())
	assert_eq(GameSession.watchtower_level, 1)

	GameSession.end_world_turn()
	GameSession.end_world_turn()
	assert_true(
		bool(GameSession.get_encounter_intel(GameSession.GOBLIN_CAMP_ID).discovered),
		"Watchtower-boosted detection must discover goblin_camp within a couple of World Map Turns"
	)

	assert_true(GameSession.accept_quest(goblin_quest_id))
	var accepted_intel := GameSession.get_encounter_intel(GameSession.GOBLIN_CAMP_ID)
	assert_eq(
		int(accepted_intel.known_tier), GameSession.INTEL_TIER_MAIN_MONSTER,
		"Accepting a quest reveals exactly Tier level + Main monster, per D1's approved value"
	)
	assert_eq(String(GameSession.get_quest(goblin_quest_id).status), GameSession.QUEST_STATUS_ACTIVE)

	# The authored route stays completely unaffected by any of the optional
	# intel/quest activity above (D1's own invariant, restated here as the
	# cross-slice claim: doing Step 2 work must never touch Step 1's spine).
	assert_eq(GameSession.campaign_objective_id, TIER1_1_ID)
	assert_true(GameSession.can_enter_encounter(TIER1_1_ID))

	# =========================================================================
	# PART 2 -- Clear the first authored node through the real battle path,
	# proving the ladder still unlocks normally with Stage 5 state in play.
	# =========================================================================

	sim._run_encampment_phase(telemetry)
	assert_eq(GameSession.campaign_objective_id, TIER1_1_ID, "Setup: seed 4 must still be attempting tier1_1 at this point")
	sim._travel_to_objective(TIER1_1_ID, telemetry)
	var tier1_1_outcome := sim._fight_objective(TIER1_1_ID, telemetry)
	assert_eq(tier1_1_outcome, "victory", "Setup: seed 4 is a representative victory seed -- tier1_1 must clear")
	sim._return_to_encampment(telemetry)

	assert_true(GameSession.completed_objectives.has(TIER1_1_ID))
	assert_eq(GameSession.campaign_objective_id, TIER1_2_ID, "Clearing tier1_1 must unlock tier1_2 regardless of any intel/quest/watchtower activity")
	assert_true(GameSession.can_enter_encounter(TIER1_2_ID))
	assert_eq(String(GameSession.get_quest(goblin_quest_id).status), GameSession.QUEST_STATUS_ACTIVE, "Setup: goblin_camp's own quest must still be active -- clearing a DIFFERENT encounter must not touch it")

	# =========================================================================
	# PART 3 -- Build the Mage (Step 4) and promote a Knight (Step 5) onto the
	# real roster, then raise the Guild Hall to unlock a second party (D5).
	# =========================================================================

	GameSession.adventurers.append(GameSession.get_default_mage(MAGE_ID, "Exit Gate Mage"))
	assert_true(GameSession.assign_adventurer_to_party(party_a_id, MAGE_ID))

	GameSession.adventurers.append(GameSession.get_default_warrior(KNIGHT_ID, "Exit Gate Knight"))
	# A real leveling pass (not a direct .level poke) so .stats/.health stay
	# internally consistent with .level -- CampaignSnapshot's own roster
	# normalization enforces a per-level stat floor (see _normalize_roster_
	# records()'s "never fall below what the record's own level minimally
	# guarantees" migration logic) on every export/import, so a hand-set
	# level with stale level-1 stats would silently drift the instant this
	# journey's own checkpoint (Part 5) round-trips it.
	GameSession._award_adventurer_xp(KNIGHT_ID, GameSession.get_level_xp_threshold(8))
	assert_eq(GameSession.get_adventurer(KNIGHT_ID).level, 8, "Setup: enough XP for one real leveling pass to reach level 8 (earns both root perk slots plus both Knight perk slots)")
	assert_true(GameSession.choose_perk(KNIGHT_ID, GameSession.WARRIOR_JUGGERNAUT_PERK_ID))
	assert_true(GameSession.choose_perk(KNIGHT_ID, GameSession.WARRIOR_BULWARK_PERK_ID))
	assert_true(GameSession.get_available_specializations(KNIGHT_ID).has("knight"), "Setup: both root perks chosen must open Knight promotion eligibility")
	assert_true(GameSession.promote_adventurer(KNIGHT_ID, "knight"))
	assert_true(GameSession.choose_perk(KNIGHT_ID, GameSession.KNIGHT_SHIELD_BASH_PERK_ID))
	assert_true(GameSession.choose_perk(KNIGHT_ID, GameSession.KNIGHT_CHAIN_BLOW_PERK_ID))
	assert_eq(GameSession.get_adventurer_specialization(KNIGHT_ID), "knight")

	# CampaignSim's own _run_encampment_phase() (Part 2 above) already spends
	# available gold on an affordable Guild Hall upgrade every cycle as part
	# of its normal balanced-play policy -- guild_hall_level may already sit
	# above 1 by this point. Top it up to the max explicitly rather than
	# assuming either a fresh level-1 start or CampaignSim's own pace.
	GameSession.gold += 1000
	while GameSession.can_upgrade_guild_hall():
		assert_true(GameSession.upgrade_guild_hall())
	assert_eq(GameSession.guild_hall_level, GameSession.GUILD_HALL_MAX_LEVEL)
	assert_eq(GameSession.get_max_party_count(), 2, "D5: the party cap raises to 2 only once the Guild Hall reaches its top tier")

	assert_true(GameSession.assign_adventurer_to_party(party_a_id, KNIGHT_ID), "Setup: Guild Hall level 3 raises the per-party size cap enough to add the Knight")

	# =========================================================================
	# PART 4 -- Form a second, independently-routed party (D5) and put BOTH
	# parties mid-route at the same instant, ahead of the checkpoint below.
	# =========================================================================

	GameSession.deploy_party(party_a_id)
	assert_true(GameSession.set_deployed_party_route([Vector2i(2, 3), Vector2i(2, 4)] as Array[Vector2i], party_a_id))

	assert_true(GameSession.create_party("Party B"))
	var party_b_id: String = GameSession.selected_party_id
	assert_ne(party_b_id, party_a_id)
	GameSession.adventurers.append(GameSession.get_default_scout(SCOUT_B_ID, "Exit Gate Scout"))
	assert_true(GameSession.assign_adventurer_to_party(party_b_id, SCOUT_B_ID))
	assert_true(GameSession.deploy_party(party_b_id))
	assert_true(GameSession.set_deployed_party_route([Vector2i(3, 2), Vector2i(3, 1), Vector2i(3, 0)] as Array[Vector2i], party_b_id))

	GameSession.end_world_turn()  # every deployed party auto-steps its own unspent route independently (D5)

	assert_eq(GameSession.get_deployed_party_position(party_a_id), Vector2i(2, 3))
	assert_eq(GameSession.get_deployed_party_route(party_a_id), [Vector2i(2, 4)] as Array[Vector2i])
	assert_eq(GameSession.get_deployed_party_position(party_b_id), Vector2i(3, 2))
	assert_eq(GameSession.get_deployed_party_route(party_b_id), [Vector2i(3, 1), Vector2i(3, 0)] as Array[Vector2i])
	assert_ne(
		GameSession.get_deployed_party_position(party_a_id), GameSession.get_deployed_party_position(party_b_id),
		"Setup: the two parties must be travelling two genuinely different routes, not shadowing one another"
	)

	# =========================================================================
	# PART 5 -- CHECKPOINT: a real export -> reset -> import round trip taken
	# while BOTH parties are mid-route, with the Mage/Knight/watchtower/quest
	# state already accumulated -- proving CampaignSnapshot survives the
	# whole accumulated Stage 5 state, not just the original single-party arc.
	# =========================================================================

	var expected := _capture_durable_state()
	var data := GameSession.export_campaign_snapshot()
	GameSession.reset()
	var import_result := GameSession.import_campaign_snapshot(data)
	assert_true(import_result.ok, "Checkpoint import must succeed (%s)" % import_result.get("error", ""))
	_assert_durable_state_matches(expected)

	# select_party()/selected_party_id survive the round trip too -- restore
	# it explicitly as the acting party for the rest of this journey (Party B
	# was the most recently created/selected party before the checkpoint).
	assert_true(GameSession.select_party(party_a_id))

	# =========================================================================
	# PART 6 -- Battle-mechanic demonstrations, built from the POST-IMPORT
	# GameSession state: the Mage's Sleep spell and its magic-resistance
	# counter (Step 4/D3), the promoted Knight's Shield Bash/Chain Blow and
	# its composition-dependent counter (Step 5/D4), and the universal
	# Dodge/Parry/Cover/Opportunity-Attack primitives (Step 3/D2).
	# =========================================================================

	# --- 6a. Mage Sleep vs. orc_outpost's real magic-resistant Orc (D3) -----
	# magic_resistance is read live from GameSession's own orc_outpost
	# expedition data (never a hand-invented number), tying this
	# demonstration to the real "encounter use" Step 4 shipped.
	var orc_stats: Dictionary = GameSession.get_expedition(GameSession.ORC_OUTPOST_ID).enemy
	var mage_scenario := ScenarioContractScript.normalize({
		"scenario_id": "stage5_exit_gate_mage_vs_orc_outpost",
		"player": {"units": [
			_player_unit_spec(MAGE_ID, {"position": {"x": 0, "y": 0}}),
			{
				"id": "sleep_demo_escort", "template_id": "warrior",
				"weapon_id": GameSession.DEFAULT_WEAPON_ID, "armor_id": GameSession.DEFAULT_ARMOR_ID,
				"level": 3, "position": {"x": 0, "y": 1},
			},
		]},
		"enemy": {"units": [
			{
				"id": "resistant_orc", "template_id": sim._enemy_template_id(orc_stats),
				"position": {"x": 1, "y": 0}, "modifiers": {"magic_resistance": int(orc_stats.magic_resistance)},
			},
		]},
		"rules": {"round_limit": CampaignSimScript.MAX_BATTLE_ROUNDS},
	})

	var mage_controller: Node2D = BattleStateFactoryScript.build(mage_scenario, 1)
	autofree(mage_controller)
	var mage_unit = mage_controller.get_unit_at(Vector2i(0, 0))
	var orc_unit = mage_controller.get_unit_at(Vector2i(1, 0))
	assert_eq(orc_unit.magic_resistance, int(orc_stats.magic_resistance), "Setup: the live orc_outpost magic_resistance value must reach the built battle unchanged")
	mage_controller.selected_unit = mage_unit
	mage_controller.sleep_resist_roll = func() -> float: return 1.0  # above any resist chance -- succeeds
	assert_true(mage_controller.try_cast_spell("sleep", orc_unit.grid_position))
	assert_false(mage_controller.last_attack_result.resisted)
	assert_true(mage_controller.has_status(orc_unit, "sleeping"))
	assert_eq(mage_unit.mp_remaining, GameSession.MAGE_MP_MAX - 1)

	# The resistance counter (D3's other half): a separate, disposable
	# controller build with the identical resist roll forced the other way.
	var resisted_controller: Node2D = BattleStateFactoryScript.build(mage_scenario, 1)
	autofree(resisted_controller)
	var resisted_mage = resisted_controller.get_unit_at(Vector2i(0, 0))
	var resisted_orc = resisted_controller.get_unit_at(Vector2i(1, 0))
	resisted_controller.selected_unit = resisted_mage
	resisted_controller.sleep_resist_roll = func() -> float: return 0.0  # below any nonzero resist chance -- resisted
	assert_true(resisted_controller.try_cast_spell("sleep", resisted_orc.grid_position))
	assert_true(resisted_controller.last_attack_result.resisted, "The magic-resistant Orc must be able to fully negate Sleep -- it is not a universal free skip")
	assert_false(resisted_controller.has_status(resisted_orc, "sleeping"))

	# Finish the successful-Sleep battle for real through the same bot
	# resolution path CampaignSim itself uses, then persist its aftermath
	# back into GameSession exactly like a real battle would.
	sim._run_battle_to_resolution(mage_controller, {})
	var mage_dead_ids := sim._persist_battle_state(mage_controller)
	assert_true(mage_dead_ids.is_empty(), "Setup: the Mage/escort pairing must not lose anyone against a single Orc")
	assert_true(GameSession.get_current_health(MAGE_ID) > 0)

	# --- 6b. Promoted Knight vs. its composition-dependent counter (D4) -----
	var knight_favorable_controller: Node2D = BattleStateFactoryScript.build(_knight_scenario(2), 1)
	autofree(knight_favorable_controller)
	var knight_unit = knight_favorable_controller.get_unit_at(Vector2i(0, 0))
	var primary_kobold = knight_favorable_controller.get_unit_at(Vector2i(1, 0))
	var second_kobold = knight_favorable_controller.get_unit_at(Vector2i(1, 1))
	knight_favorable_controller.selected_unit = knight_unit
	knight_favorable_controller.hit_roll = func() -> float: return 0.0
	knight_favorable_controller.crit_roll = func() -> float: return 1.0
	assert_true(knight_favorable_controller.try_shield_bash_selected_unit(primary_kobold.grid_position))
	assert_true(knight_favorable_controller.last_attack_result.hit)
	assert_true(primary_kobold.off_balance_pending, "A landed Shield Bash must off-balance its target")
	assert_false(knight_favorable_controller.last_chain_blow_result.is_empty(), "A clustered composition must let Chain Blow find a second target")
	assert_eq(knight_favorable_controller.last_chain_blow_result.defender, second_kobold)

	# The counter: the exact same promoted Knight against a solitary enemy --
	# Shield Bash still lands, but Chain Blow (present on the Knight either
	# way) finds nothing to strike. A real counterplay interaction, not a
	# flat stat check: composition, not the Knight's own numbers, decides
	# whether Chain Blow pays off.
	var knight_countered_controller: Node2D = BattleStateFactoryScript.build(_knight_scenario(1), 1)
	autofree(knight_countered_controller)
	var solitary_knight_unit = knight_countered_controller.get_unit_at(Vector2i(0, 0))
	var solitary_kobold = knight_countered_controller.get_unit_at(Vector2i(1, 0))
	knight_countered_controller.selected_unit = solitary_knight_unit
	knight_countered_controller.hit_roll = func() -> float: return 0.0
	knight_countered_controller.crit_roll = func() -> float: return 1.0
	assert_true(knight_countered_controller.try_shield_bash_selected_unit(solitary_kobold.grid_position))
	assert_true(knight_countered_controller.last_attack_result.hit, "Shield Bash itself is unaffected by the solitary composition")
	assert_true(
		knight_countered_controller.last_chain_blow_result.is_empty(),
		"A solitary enemy denies Chain Blow's bonus strike entirely -- the counter this composition-dependent perk carries"
	)

	var knight_dead_ids := sim._persist_battle_state(knight_favorable_controller)
	assert_true(knight_dead_ids.is_empty())
	assert_true(GameSession.get_current_health(KNIGHT_ID) > 0)

	# --- 6c. Universal Dodge/Parry/Cover/Opportunity-Attack primitives (D2) -
	# These are unit-level mechanics, not campaign-state-coupled -- unlike
	# 6a/6b above, this demonstration deliberately uses lightweight
	# non-roster units (mirroring test_battle_controller.gd's own
	# established convention) rather than real adventurers, since the
	# cross-slice claim this file exists to prove is state COMPOSITION
	# (Mage/Knight/intel/quest/multi-party durable state), not these
	# already-universal primitives' own resolution, which test_battle_
	# controller.gd/test_scenario_runner.gd already prove exhaustively.
	var dodge_parry_scenario := ScenarioContractScript.normalize({
		"scenario_id": "stage5_exit_gate_dodge_and_parry",
		"player": {"units": [
			{"id": "dodge_attacker", "template_id": "warrior", "weapon_id": GameSession.DEFAULT_WEAPON_ID, "armor_id": GameSession.DEFAULT_ARMOR_ID, "level": 1, "position": {"x": 0, "y": 0}},
			{"id": "parry_attacker", "template_id": "warrior", "weapon_id": GameSession.DEFAULT_WEAPON_ID, "armor_id": GameSession.DEFAULT_ARMOR_ID, "level": 1, "position": {"x": 4, "y": 4}},
		]},
		"enemy": {"units": [
			{"id": "dodge_defender", "template_id": "goblin", "position": {"x": 0, "y": 1}, "modifiers": {"max_health": 500}},
			{"id": "parry_defender", "template_id": "goblin", "position": {"x": 4, "y": 5}, "modifiers": {"max_health": 500}},
		]},
		"rules": {"round_limit": 1},
	})
	var tactics_controller: Node2D = BattleStateFactoryScript.build(dodge_parry_scenario, 1)
	autofree(tactics_controller)

	var dodge_attacker = tactics_controller.get_unit_at(Vector2i(0, 0))
	var dodge_defender = tactics_controller.get_unit_at(Vector2i(0, 1))
	tactics_controller.selected_unit = dodge_attacker
	tactics_controller.hit_roll = func() -> float: return 0.0
	tactics_controller.dodge_roll = func() -> float: return 0.0
	assert_true(tactics_controller.try_attack_selected_unit(dodge_defender.grid_position))
	assert_true(tactics_controller.last_attack_result.dodged)
	assert_true(dodge_attacker.off_balance_pending, "A successful Dodge off-balances the attacker")

	var parry_attacker = tactics_controller.get_unit_at(Vector2i(4, 4))
	var parry_defender = tactics_controller.get_unit_at(Vector2i(4, 5))
	tactics_controller.selected_unit = parry_attacker
	tactics_controller.hit_roll = func() -> float: return 0.0
	tactics_controller.dodge_roll = func() -> float: return 1.0
	tactics_controller.parry_roll = func() -> float: return 0.0
	assert_true(tactics_controller.try_attack_selected_unit(parry_defender.grid_position))
	assert_true(tactics_controller.last_attack_result.parried)
	assert_eq(parry_defender.counter_bonus_pending_against, parry_attacker, "A successful Parry grants the defender a counter-bonus against that same attacker")

	# Cover: placed on goblin_camp's own real, hand-authored Cover tile
	# (battle_controller.gd's _cover_tiles_for_encounter()), not an invented
	# position -- ties this demonstration to Step 3's real "encounter use."
	var cover_scenario := ScenarioContractScript.normalize({
		"scenario_id": "stage5_exit_gate_cover",
		"player": {"units": [{"id": "cover_attacker", "template_id": "scout", "weapon_id": "shortbow_iron", "armor_id": GameSession.DEFAULT_ARMOR_ID, "level": 1, "position": {"x": 4, "y": 0}}]},
		"enemy": {"units": [{"id": "cover_defender", "template_id": "goblin", "position": {"x": 4, "y": 3}, "facing": "up", "modifiers": {"max_health": 500}}]},
		"rules": {"round_limit": 1},
	})
	var cover_controller: Node2D = BattleStateFactoryScript.build(cover_scenario, 1)
	autofree(cover_controller)
	var real_goblin_camp_cover: Dictionary = cover_controller._cover_tiles_for_encounter(GameSession.GOBLIN_CAMP_ID)
	assert_false(real_goblin_camp_cover.is_empty(), "Setup: goblin_camp must carry real, hand-authored Cover tiles")
	for cover_pos in real_goblin_camp_cover:
		cover_controller.grid.cover_tiles[cover_pos] = real_goblin_camp_cover[cover_pos]
	var cover_attacker = cover_controller.get_unit_at(Vector2i(4, 0))
	var cover_defender = cover_controller.get_unit_at(Vector2i(4, 3))
	cover_controller.selected_unit = cover_attacker
	cover_controller.hit_roll = func() -> float: return 0.0
	cover_controller.crit_roll = func() -> float: return 1.0
	assert_true(cover_controller.try_attack_selected_unit(cover_defender.grid_position))
	assert_true(cover_controller.last_attack_result.cover_applied, "A front-facing missile attack against goblin_camp's own real Cover tile must apply its Guard bonus")
	assert_eq(cover_controller.last_attack_result.cover_tile, real_goblin_camp_cover[Vector2i(4, 3)])

	# Opportunity Attack: departing an adjacent melee-capable enemy's reach
	# triggers exactly one free reaction (D2).
	var oa_scenario := ScenarioContractScript.normalize({
		"scenario_id": "stage5_exit_gate_opportunity_attack",
		"player": {"units": [{"id": "oa_mover", "template_id": "warrior", "weapon_id": GameSession.DEFAULT_WEAPON_ID, "armor_id": GameSession.DEFAULT_ARMOR_ID, "level": 1, "position": {"x": 1, "y": 0}}]},
		"enemy": {"units": [{"id": "oa_reactor", "template_id": "goblin", "position": {"x": 0, "y": 0}}]},
		"rules": {"round_limit": 1},
	})
	var oa_controller: Node2D = BattleStateFactoryScript.build(oa_scenario, 1)
	autofree(oa_controller)
	var oa_mover = oa_controller.get_unit_at(Vector2i(1, 0))
	oa_controller.selected_unit = oa_mover
	assert_true(oa_controller.try_move_selected_unit(Vector2i(3, 0)))
	assert_eq(oa_controller.last_reaction_results.size(), 1, "Departing the one adjacent melee-capable enemy's reach must trigger exactly one reaction")
	assert_eq(oa_controller.last_reaction_results[0].type, "reaction")

	# =========================================================================
	# PART 7 -- Resume Party A's authored progress (tier1_2) with the Mage and
	# the promoted Knight now sitting in its own roster/party, proving the
	# ladder still composes correctly with every Stage 5 addition present.
	# =========================================================================

	if not GameSession.has_deployed_party(party_a_id):
		GameSession.deploy_party(party_a_id)
	sim._travel_to_objective(TIER1_2_ID, telemetry)  # also burns world turns that auto-step Party B's own route (D5)
	var tier1_2_outcome := sim._fight_objective(TIER1_2_ID, telemetry)
	assert_ne(tier1_2_outcome, "error", "A promoted specialization in the roster must never turn a normal battle into a scenario validation error")
	assert_eq(tier1_2_outcome, "victory", "Setup: seed 4 must still clear tier1_2 with the Mage/Knight along for the ride")
	sim._return_to_encampment(telemetry)
	assert_true(GameSession.completed_objectives.has(TIER1_2_ID))
	assert_eq(GameSession.campaign_objective_id, TIER1_3_ID)

	# Party B kept independently advancing its own route the whole time --
	# every _advance_world_turn() call inside _fight_objective()'s travel/
	# encampment helpers above auto-steps every deployed party, not only the
	# selected one (D5).
	assert_lt(
		GameSession.get_deployed_party_route(party_b_id).size(), 2,
		"Party B's own route must have kept shrinking independently while Party A fought tier1_2, proving simultaneous independent travel"
	)

	# =========================================================================
	# PART 8 -- Two-party battle-claim ownership tie-break (D5).
	# =========================================================================

	assert_true(GameSession.can_party_enter_battle(party_a_id))
	assert_false(GameSession.create_battle_context(party_a_id, GameSession.GOBLIN_CAMP_ID).is_empty())
	assert_false(GameSession.can_party_enter_battle(party_b_id), "A second party's Enter must be blocked while the first holds the claim")
	assert_true(GameSession.create_battle_context(party_b_id, GameSession.GOBLIN_CAMP_ID).is_empty())
	GameSession.resolve_battle_retreat(GameSession.get_active_battle_context().battle_id)
	assert_true(GameSession.can_party_enter_battle(party_b_id))
	assert_false(GameSession.create_battle_context(party_b_id, GameSession.GOBLIN_CAMP_ID).is_empty())
	GameSession.resolve_battle_retreat(GameSession.get_active_battle_context().battle_id)

	# =========================================================================
	# PART 9 -- Complete goblin_camp's still-active quest for real, proving
	# reward/objective ownership stays correct: the quest reward folds into
	# Party A's own carry via the active battle context's reward, and Party
	# B's own member is completely untouched by any of Party A's battles
	# above.
	# =========================================================================

	var scout_b_health_before := GameSession.get_current_health(SCOUT_B_ID)
	assert_eq(String(GameSession.get_quest(goblin_quest_id).status), GameSession.QUEST_STATUS_ACTIVE, "Setup: the quest must still be active going into this fight")
	var expected_quest_reward := int(round(GameSession.get_encounter_expected_gold_value(1) * (GameSession.QUEST_REWARD_PERCENT / 100.0)))
	assert_eq(int(GameSession.get_quest(goblin_quest_id).reward_gold), expected_quest_reward)

	var goblin_outcome := sim._fight_objective(GameSession.GOBLIN_CAMP_ID, telemetry)

	assert_eq(goblin_outcome, "victory")
	assert_false(GameSession.quests.has(goblin_quest_id), "A quest record is removed once its target clears, whether or not it was active")

	var gold_before_deposit := GameSession.gold
	sim._return_to_encampment(telemetry)
	assert_gt(GameSession.gold, gold_before_deposit, "Party A's own goblin_camp clear (loot + the folded-in quest reward) must actually bank")

	assert_eq(
		GameSession.get_current_health(SCOUT_B_ID), scout_b_health_before,
		"Party B's own member must be completely untouched by any battle Party A fought -- no cross-party state contamination"
	)
	assert_false((GameSession.get_party(party_b_id).member_ids as Array).has(MAGE_ID), "The Mage/Knight belong to Party A only -- membership must never leak across parties")
	assert_false((GameSession.get_party(party_a_id).member_ids as Array).has(SCOUT_B_ID))

	# =========================================================================
	# PART 10 -- Final aftermath: no objective silently skipped/duplicated,
	# no cross-party misattribution, and every new Stage 5 field left in a
	# coherent, non-contradictory state.
	# =========================================================================

	assert_eq(GameSession.completed_objectives.count(TIER1_1_ID), 1)
	assert_eq(GameSession.completed_objectives.count(TIER1_2_ID), 1)
	assert_eq(
		GameSession.completed_objectives, [TIER1_1_ID, TIER1_2_ID],
		"Exactly the two cleared authored nodes, in authored order, nothing skipped or duplicated"
	)
	assert_eq(GameSession.campaign_objective_id, TIER1_3_ID)
	assert_false(GameSession.is_campaign_completed)
	assert_true(GameSession.completed_encounters.has(GameSession.GOBLIN_CAMP_ID))
	assert_true(GameSession.get_current_health(MAGE_ID) > 0)
	assert_true(GameSession.get_current_health(KNIGHT_ID) > 0)
	assert_eq(GameSession.get_adventurer_specialization(KNIGHT_ID), "knight", "Promotion must persist through every battle/checkpoint above")


## --- Scenario-building helpers ---------------------------------------------

## Mirrors CampaignSim._build_player_units()'s per-member body (weapon/armor/
## level/mp_current/perks threading), extended with "extra" overrides (e.g.
## an explicit position) and with the promoted-specialization field
## CampaignSim's own version was missing until this step's fix to
## scripts/tools/campaign_sim.gd -- see that file's own updated doc comment.
func _player_unit_spec(adventurer_id: String, extra: Dictionary = {}) -> Dictionary:
	var adventurer := GameSession.get_adventurer(adventurer_id)
	var spec := {
		"id": adventurer_id,
		"template_id": String(adventurer.get("class", "warrior")),
		"weapon_id": String(adventurer.equipment.get("weapon", GameSession.DEFAULT_WEAPON_ID)),
		"armor_id": String(adventurer.equipment.get("armor", GameSession.DEFAULT_ARMOR_ID)),
		"level": int(adventurer.get("level", 1)),
	}
	if GameSession.get_effective_max_mp(adventurer_id) > 0:
		spec["mp_current"] = GameSession.get_current_mp(adventurer_id)
	var chosen_perks: Array = adventurer.progression.get("perks", [])
	if not chosen_perks.is_empty():
		spec["perks"] = chosen_perks.duplicate()
	var specialization_id := GameSession.get_adventurer_specialization(adventurer_id)
	if specialization_id != "":
		spec["specialization"] = specialization_id
	spec.merge(extra, true)
	return spec


## The promoted Knight (KNIGHT_ID, real GameSession adventurer) against
## `kobold_count` Kobolds clustered adjacent to it -- 2 mirrors ruined_
## fortress's own clustered swarm (Chain Blow finds a second target), 1
## mirrors goblin_camp's own solitary composition (Chain Blow's counter).
func _knight_scenario(kobold_count: int) -> Dictionary:
	var enemy_units: Array = []
	for index in kobold_count:
		enemy_units.append({"id": "kobold_%d" % index, "template_id": "kobold", "position": {"x": 1, "y": index}})
	return ScenarioContractScript.normalize({
		"scenario_id": "stage5_exit_gate_knight_%d_kobolds" % kobold_count,
		"player": {"units": [_player_unit_spec(KNIGHT_ID, {"position": {"x": 0, "y": 0}})]},
		"enemy": {"units": enemy_units},
		"rules": {"round_limit": 1},
	})


## --- Checkpoint helpers ------------------------------------------------------

## Every durable field this journey's own Stage 5 additions touch, on top of
## the fields test_stage_3_campaign_assembly.gd's own checkpoint already
## covers -- watchtower_level/encounter_intel/quests/quest_posting_blocked_
## until_turn (Step 2) are new; parties/selected_party_id already existed but
## now carry more than one entry (Step 6). Deliberately a single round trip
## with a full-field equality assertion, not a second triple-direction
## aliasing proof -- test_campaign_snapshot.gd already owns that contract.
func _capture_durable_state() -> Dictionary:
	return {
		"campaign_objective_id": GameSession.campaign_objective_id,
		"completed_objectives": GameSession.completed_objectives.duplicate(true),
		"unlocked_authored_encounters": GameSession.unlocked_authored_encounters.duplicate(true),
		"is_campaign_completed": GameSession.is_campaign_completed,
		"is_free_play_active": GameSession.is_free_play_active,
		"adventurers": GameSession.adventurers.duplicate(true),
		"parties": GameSession.parties.duplicate(true),
		"selected_party_id": GameSession.selected_party_id,
		"world_turn": GameSession.world_turn,
		"gold": GameSession.gold,
		"guild_hall_level": GameSession.guild_hall_level,
		"watchtower_level": GameSession.watchtower_level,
		"encounter_intel": _encounter_intel_with_authored_backfill(),
		"quests": GameSession.quests.duplicate(true),
		"quest_posting_blocked_until_turn": GameSession.quest_posting_blocked_until_turn,
		"active_encounters": GameSession.active_encounters.duplicate(true),
		"completed_encounters": GameSession.completed_encounters.duplicate(true),
	}


## GameSession.encounter_intel.erase()s a completed encounter's own record
## the instant it clears (_settle_encounter_intelligence()) -- live play never
## looks at a completed authored node's own intel again, so this is
## invisible in a single session. import_campaign_snapshot() always calls
## _backfill_missing_intel_records() afterward, though, which -- as its own
## doc comment documents for the "old save" migration case -- unconditionally
## re-ensures a default (discovered:true, known_tier: none) record for every
## entry in unlocked_authored_encounters, not only ones missing because of an
## old snapshot format. That is real, intentional, already-shipped Step 2
## behavior (every unlocked authored node is GUARANTEED a discovered intel
## record after any load, whether or not it was erased at completion first),
## not something Steps 2-6 broke by composing -- so this checkpoint's own
## "before" snapshot must reflect the same guarantee a reload always
## produces, rather than the transient mid-session erased state, or this
## assertion would fail on a real, working, already-shipped reconciliation.
func _encounter_intel_with_authored_backfill() -> Dictionary:
	var intel: Dictionary = GameSession.encounter_intel.duplicate(true)
	for encounter_id in GameSession.unlocked_authored_encounters:
		if not intel.has(encounter_id):
			intel[encounter_id] = {"discovered": true, "known_tier": GameSession.INTEL_TIER_NONE, "quest_id": ""}
	return intel


func _assert_durable_state_matches(expected: Dictionary) -> void:
	assert_eq(GameSession.campaign_objective_id, expected.campaign_objective_id, "campaign_objective_id")
	assert_eq(GameSession.completed_objectives, expected.completed_objectives, "completed_objectives")
	assert_eq(GameSession.unlocked_authored_encounters, expected.unlocked_authored_encounters, "unlocked_authored_encounters")
	assert_eq(GameSession.is_campaign_completed, expected.is_campaign_completed, "is_campaign_completed")
	assert_eq(GameSession.is_free_play_active, expected.is_free_play_active, "is_free_play_active")
	assert_eq(GameSession.adventurers, expected.adventurers, "adventurers (roster, including the Mage/Knight and the Knight's promotion/perks)")
	assert_eq(GameSession.parties, expected.parties, "parties (both parties' member_ids/location/route/movement_spent)")
	assert_eq(GameSession.selected_party_id, expected.selected_party_id, "selected_party_id")
	assert_eq(GameSession.world_turn, expected.world_turn, "world_turn")
	assert_eq(GameSession.gold, expected.gold, "gold")
	assert_eq(GameSession.guild_hall_level, expected.guild_hall_level, "guild_hall_level")
	assert_eq(GameSession.watchtower_level, expected.watchtower_level, "watchtower_level")
	assert_eq(GameSession.encounter_intel, expected.encounter_intel, "encounter_intel")
	assert_eq(GameSession.quests, expected.quests, "quests")
	assert_eq(GameSession.quest_posting_blocked_until_turn, expected.quest_posting_blocked_until_turn, "quest_posting_blocked_until_turn")
	assert_eq(GameSession.active_encounters, expected.active_encounters, "active_encounters")
	assert_eq(GameSession.completed_encounters, expected.completed_encounters, "completed_encounters")
