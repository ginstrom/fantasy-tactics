extends GutTest
## Stage 1 exit gate (docs/plans/2026-08-21-stage-1-campaign-spine/
## 03-stage-1-exit-gate.md): one integration proof that a fresh Borderlands
## campaign can name its objective, offer pre-battle Withdraw, clear the
## first objective, survive a full wipe into the zero-gold/no-party recovery
## route, and round-trip through a real save/import -- all through public
## GameSession/GameManager contracts. Battle construction and full-arc
## balance evidence remain owned by CampaignSim -> ScenarioContract ->
## BattleStateFactory (see `make campaign-sim`); this is not a second
## campaign simulator and asserts nothing about an arbitrary seed sweep.

const CampaignSimScript := preload("res://scripts/tools/campaign_sim.gd")

## A representative victory seed (CampaignSim.REPRESENTATIVE_VICTORY_SEEDS)
## reused here only as a reliable win for the single, easy first-tier fight
## this test needs -- not a claim this test re-verifies full-campaign
## victory on it.
const JOURNEY_SEED := 4
const MAX_RECOVERY_WAIT_TURNS := 5


func before_each() -> void:
	GameSession.reset()
	GameSession.reset_injectable_rolls()
	GameManager.route_context_id = ""


func after_each() -> void:
	GameSession.reset()
	GameSession.reset_injectable_rolls()
	GameManager.route_context_id = ""


func test_a_fresh_save_names_withdraws_clears_wipes_recovers_and_round_trips_the_first_objective() -> void:
	var sim := CampaignSimScript.new()
	sim.sim_seed = JOURNEY_SEED
	var rng := RandomNumberGenerator.new()
	rng.seed = JOURNEY_SEED
	sim._wire_deterministic_rolls(rng)
	var telemetry := sim._new_telemetry(JOURNEY_SEED)

	# --- 1. A fresh save names and unlocks its first authored objective. ---
	GameSession.start_new_game()
	var first_objective_id: String = GameSession.campaign_objective_id
	assert_eq(first_objective_id, "obj_tier1_1_goblin_outpost")
	assert_true(GameSession.unlocked_authored_encounters.has(first_objective_id))
	assert_true(GameSession.can_enter_encounter(first_objective_id))

	GameSession.create_party()
	var party_id: String = GameSession.selected_party_id
	sim._refill_party(telemetry)
	GameSession.deploy_party(party_id)
	sim._run_encampment_phase(telemetry)
	if not GameSession.has_deployed_party():
		GameSession.deploy_party(party_id)
	sim._travel_to_objective(first_objective_id, telemetry)

	# --- 2. Pre-battle Withdraw with a deterministic harmless roll must
	# leave the objective enterable and never itself enter battle. ---
	var withdraw_results: Array[Dictionary] = GameSession.withdraw_from_encounter(
		first_objective_id, func() -> float: return 0.0
	)
	assert_false(withdraw_results.is_empty(), "Withdraw must resolve for a party standing on the encounter")
	assert_eq(GameSession.selected_encounter, "", "Withdraw must never enter battle")
	assert_true(GameSession.can_enter_encounter(first_objective_id), "Withdraw must leave the objective enterable")
	assert_false(GameSession.is_encounter_complete(first_objective_id))
	# Withdraw records a homeward route but does not itself relocate the
	# party -- see GameSession.withdraw_from_encounter()'s own doc comment --
	# so the party is still standing on the objective and can enter directly.
	assert_eq(
		GameSession.get_deployed_party_position(), GameSession.get_expedition(first_objective_id).position,
		"Setup: Withdraw must not itself move the party away from the objective"
	)

	# --- 3. Enter and complete the first objective through the established
	# battle/completion path; assert exactly the next node unlocks. ---
	var outcome := sim._fight_objective(first_objective_id, telemetry)
	assert_eq(outcome, "victory", "Setup: the journey seed must win the first (easiest) objective")
	assert_true(GameSession.is_encounter_complete(first_objective_id))
	assert_eq(
		GameSession.unlocked_authored_encounters,
		[first_objective_id, "obj_tier1_2_kobold_warren"],
		"Exactly the next authored node must unlock"
	)
	sim._return_to_encampment(telemetry)

	# --- 4. Force a wipe/zero-gold/no-party aftermath through public APIs,
	# advance recovery turns, recruit/form a legal party, and assert
	# completed objectives/upgrades persist. ---
	GameSession.guild_hall_level = 2
	GameSession.shop_level = 1
	var completed_before: Array = GameSession.completed_objectives.duplicate()
	var guild_hall_before: int = GameSession.guild_hall_level

	var health_by_id := {}
	for member_id in GameSession.get_selected_party().member_ids:
		health_by_id[member_id] = 0
	GameSession.resolve_battle_deaths(health_by_id)
	GameSession.resolve_party_wipe()

	assert_eq(GameSession.gold, 0, "A wipe must forfeit gold")
	assert_false(GameSession.has_deployed_party(), "A wipe must leave no deployed party")

	var recovery_turns := 0
	while sim._fieldable_member_ids().is_empty() and recovery_turns < MAX_RECOVERY_WAIT_TURNS:
		GameSession.end_world_turn()
		recovery_turns += 1
		sim._refill_party(telemetry)
	assert_false(
		sim._fieldable_member_ids().is_empty(),
		"Passive Shop income must recover an affordable, fieldable recruit within %d world turns" % MAX_RECOVERY_WAIT_TURNS
	)
	assert_eq(GameSession.completed_objectives, completed_before, "Completed objectives must survive the wipe/recovery cycle")
	assert_eq(GameSession.guild_hall_level, guild_hall_before, "Building upgrades must survive the wipe/recovery cycle")

	GameSession.deploy_party(party_id)
	assert_true(GameSession.has_deployed_party(), "A legal party must be re-formable after recovery")
	assert_eq(GameSession.campaign_objective_id, "obj_tier1_2_kobold_warren", "The unlocked objective must be unchanged by the wipe")
	assert_true(GameSession.can_enter_encounter(GameSession.campaign_objective_id))

	# --- 5. Export/import: objective, roster, position, and reward buckets
	# must round-trip unchanged. ---
	var objective_before: String = GameSession.campaign_objective_id
	var roster_before: Array = GameSession.adventurers.duplicate(true)
	var position_before: Vector2i = GameSession.get_deployed_party_position()
	var pending_reward_before: int = GameSession.pending_reward
	var pending_gear_before: Dictionary = GameSession.pending_gear.duplicate(true)

	var data := GameSession.export_campaign_snapshot()
	var result := GameSession.import_campaign_snapshot(data)

	assert_true(result.ok, result.get("error", ""))
	assert_eq(GameSession.campaign_objective_id, objective_before)
	assert_eq(GameSession.adventurers, roster_before)
	assert_eq(GameSession.get_deployed_party_position(), position_before)
	assert_eq(GameSession.pending_reward, pending_reward_before)
	assert_eq(GameSession.pending_gear, pending_gear_before)
