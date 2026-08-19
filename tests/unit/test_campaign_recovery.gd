extends GutTest
## Anti-soft-lock stress scenarios (docs/plans/2026-08-18-core-loop-and-
## engagement/06-campaign-simulation-and-balance-harness.md, TDD task 3):
## worst-case setback states must never strand a campaign. Reuses CampaignSim's
## own private helpers (party refill, encampment phase, scene-free battle
## construction) rather than reimplementing recovery logic here -- "private
## (underscore-prefixed) methods are fair game" (docs/dev/testing.md) -- so
## this suite proves the exact same code path make campaign-sim exercises,
## not a parallel one that could silently drift from it.

const CampaignSimScript := preload("res://scripts/tools/campaign_sim.gd")
const ScenarioContractScript := preload("res://scripts/tools/battle_scenarios/scenario_contract.gd")
const BattleStateFactoryScript := preload("res://scripts/tools/battle_scenarios/battle_state_factory.gd")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")

const MAX_RECOVERY_WAIT_TURNS := 5


func before_each() -> void:
	GameSession.reset()
	GameSession.reset_injectable_rolls()


## Sets up a party staffed from the starting roster, then wipes it outright
## via the same permadeath/forfeiture path a real full-party defeat takes
## (GameSession.resolve_battle_deaths() + resolve_party_wipe(), the same two
## calls battlefield.gd's _persist_battle_aftermath()/GameManager.fail_
## battle() make) -- not direct field mutation of GameSession.adventurers.
func _wipe_party_and_forfeit_everything() -> void:
	GameSession.create_party()
	for adventurer in GameSession.adventurers.duplicate():
		GameSession.assign_adventurer_to_selected_party(String(adventurer.id))

	var health_by_id := {}
	for member_id in GameSession.get_selected_party().member_ids:
		health_by_id[member_id] = 0
	GameSession.resolve_battle_deaths(health_by_id)
	GameSession.resolve_party_wipe()


## --- Zero-Gold Full Wipe at Tier 2 ------------------------------------------

func test_zero_gold_full_wipe_at_tier_two_recovers_an_affordable_recruit_within_five_turns() -> void:
	# "At Tier 2": Guild Hall level 2 (raised party/roster caps), Shop already
	# built at level 1 (its passive income is the recovery mechanism under
	# test) -- the same durable building state a mid-campaign wipe would find.
	GameSession.guild_hall_level = 2
	GameSession.shop_level = 1
	_wipe_party_and_forfeit_everything()

	assert_eq(GameSession.adventurers.size(), 0, "Every roster member must be gone after the forced wipe")
	assert_eq(GameSession.gold, 0, "Gold must be forfeited by the wipe")
	assert_gt(GameSession.get_recruitment_candidates().size(), 0, "Recruitment offers survive a wipe -- only gold/roster/pending loot are forfeited")

	var sim := CampaignSimScript.new()
	sim.sim_seed = 900

	var turns := 0
	while sim._fieldable_member_ids().is_empty() and turns < MAX_RECOVERY_WAIT_TURNS:
		GameSession.end_world_turn()
		turns += 1
		sim._refill_party()

	assert_true(
		turns <= MAX_RECOVERY_WAIT_TURNS,
		"Passive Shop income must produce an affordable, fieldable recruit within %d world turns of a zero-gold wipe (took %d)"
		% [MAX_RECOVERY_WAIT_TURNS, turns]
	)
	assert_false(sim._fieldable_member_ids().is_empty(), "A Warrior or Scout must have been recruited and assigned to the party")


## Continues the exact recovery from the test above and proves the rebuilt
## party is not just non-empty but combat-capable: it can still clear
## further campaign objectives (Tier 1/2 territory from a fresh session's
## unlock state), i.e. the path to eventual victory was never actually
## closed off by the wipe.
func test_party_rebuild_after_a_wipe_reaches_combat_power_to_clear_further_objectives() -> void:
	GameSession.guild_hall_level = 2
	GameSession.shop_level = 1
	_wipe_party_and_forfeit_everything()

	var sim := CampaignSimScript.new()
	sim.sim_seed = 901
	var telemetry := sim._new_telemetry(901)

	var turns := 0
	while sim._fieldable_member_ids().is_empty() and turns < MAX_RECOVERY_WAIT_TURNS:
		sim._advance_world_turn(telemetry)
		turns += 1
		sim._refill_party(telemetry)
	assert_false(sim._fieldable_member_ids().is_empty(), "Setup: recovery must succeed before this test can prove further progress")

	var cleared_before := GameSession.completed_encounters.size()
	var attempts := 0
	while (
		GameSession.completed_encounters.size() < cleared_before + 2
		and not GameSession.is_campaign_completed
		and attempts < 60
	):
		attempts += 1
		sim._run_encampment_phase(telemetry)
		if GameSession.is_campaign_completed:
			break
		var encounter_id: String = GameSession.campaign_objective_id
		if encounter_id == "" or not GameSession.can_enter_encounter(encounter_id):
			break
		if not GameSession.has_deployed_party():
			GameSession.deploy_party(GameSession.selected_party_id)
		if not GameSession.has_deployed_party():
			break
		sim._travel_to_objective(encounter_id, telemetry)
		sim._fight_objective(encounter_id, telemetry)
		sim._return_to_encampment(telemetry)

	assert_true(
		GameSession.completed_encounters.size() >= cleared_before + 1 or GameSession.is_campaign_completed,
		"The rebuilt party must clear at least one further Tier 1/2 objective, proving the path to victory remains open after the wipe"
	)


## --- Repeated Retreats -------------------------------------------------------

## Forces 3 consecutive Retreats, each pinned (via retreat_roll) to the
## "ten_percent" HP-loss outcome rather than a clean no-loss escape or a
## death -- the scenario's own "with HP penalties" wording -- and drives the
## exact same aftermath persistence CampaignSim/battlefield.gd use
## (resolve_battle_deaths()/apply_battle_aftermath()) plus a Shop-income
## world turn between each retreat, matching the real retreat->World
## Map->Encampment->redeploy cadence. Proves the party recovers (heals,
## keeps earning passive income) rather than spiraling toward bankruptcy.
func test_three_consecutive_retreats_recover_in_encampment_without_an_economic_death_spiral() -> void:
	GameSession.shop_level = 1
	GameSession.gold = 100
	GameSession.create_party()
	for adventurer in GameSession.adventurers.duplicate():
		GameSession.assign_adventurer_to_selected_party(String(adventurer.id))
	GameSession.deploy_party(GameSession.selected_party_id)

	var sim := CampaignSimScript.new()
	sim.sim_seed = 500

	var gold_floor := GameSession.gold
	for retreat_index in 3:
		var expedition := {"enemy": {"name_key": "battle.enemy.goblin", "count": 1}}
		var scenario := ScenarioContractScript.normalize({
			"scenario_id": "retreat_stress_%d" % retreat_index,
			"player": {"units": sim._build_player_units()},
			"enemy": {"units": sim._build_enemy_units(expedition)},
		})
		var seed := ScenarioContractScript.derive_iteration_seed(500, scenario.scenario_id, retreat_index)
		var controller: Node2D = BattleStateFactoryScript.build(scenario, seed)
		# Every board distance on a 6x6 board is "near" (<=3) or "mid" (<=6)
		# per _retreat_distance_bucket() -- both buckets' no_loss threshold is
		# below 0.2, so this roll always lands in "ten_percent", never
		# "death", regardless of the default start positions' exact distance.
		controller.retreat_roll = func() -> float: return 0.2

		var results: Array = controller.try_retreat()
		assert_gt(results.size(), 0, "Retreat must resolve at least one living unit's outcome")
		for result in results:
			assert_eq(String(result.outcome), "ten_percent", "Every unit must take the pinned ten_percent HP-loss outcome, not death")
			assert_false(bool(result.died), "A ten_percent HP-loss outcome must never itself kill a full-health unit")

		var health_by_id := {}
		for unit in controller.units:
			if unit.side == BattleControllerScript.Side.PLAYER and unit.adventurer_id != "":
				health_by_id[unit.adventurer_id] = unit.health
		for adventurer_id in controller.defeated_player_health_by_id:
			health_by_id[adventurer_id] = controller.defeated_player_health_by_id[adventurer_id]
		GameSession.resolve_battle_deaths(health_by_id)
		GameSession.apply_battle_aftermath(health_by_id)
		GameSession.abandon_current_encounter()
		controller.free()

		GameSession.return_deployed_party_to_settlement()
		GameSession.end_world_turn()
		GameSession.deploy_party(GameSession.selected_party_id)

		assert_true(GameSession.gold >= gold_floor, "A Retreat must never itself cost gold -- passive Shop income should only add to it")
		gold_floor = GameSession.gold

	assert_false(sim._fieldable_member_ids().is_empty(), "3 HP-penalty retreats must not wipe the party outright")
	assert_true(GameSession.gold >= 0, "Gold must never go negative across repeated retreats")
