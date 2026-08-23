extends GutTest
## Step 5 (docs/plans/2026-08-22-stage-3-campaign-assembly/
## 05-scripted-full-arc-save-load.md): one real journey, driven only through
## the public GameSession API and CampaignSim's real ScenarioContract ->
## BattleStateFactory -> BattleBot battle path, from a fresh game through the
## entire 12-node authored arc to Final Boss victory and repeatable free
## play, with genuine transactional export/reset/import checkpoints inserted
## along the way. Not a second campaign simulator: every state transition
## below is either a direct GameSession call or a call to one of CampaignSim's
## own already-existing private helpers (_refill_party/_run_encampment_phase/
## _travel_to_objective/_fight_objective/_return_to_encampment/_wire_
## deterministic_rolls) -- the exact machinery CampaignSim.run_campaign()
## itself calls to prove victory on the representative seed set (see that
## file's own header comment). This test does not re-derive
## test_campaign_snapshot.gd's synthetic round-trip/rejection coverage or
## test_stage_1_campaign_spine.gd's single-objective wipe/recovery journey;
## it extends both with a real multi-checkpoint, multi-battle arc and a
## direct, mutation-based proof that export/import never aliases live state.

const CampaignSimScript := preload("res://scripts/tools/campaign_sim.gd")

## A representative victory seed (CampaignSim.REPRESENTATIVE_VICTORY_SEEDS) --
## the whole point of reusing it here is that CampaignSim.run_campaign()
## already proves this exact seed, played through this exact bot/gear/
## recruit/upgrade policy, reaches Final Boss victory. Inserting export/
## reset/import checkpoints into that same call sequence proves the
## checkpoints are transparent to the outcome -- neither export_campaign_
## snapshot(), GameSession.reset(), nor import_campaign_snapshot() ever
## touches an injectable roll Callable (see _wire_deterministic_rolls()), so
## the seeded RNG stream this journey depends on is never perturbed by a
## checkpoint the way a fresh reseed would be.
const JOURNEY_SEED := 4

const TIER1_3_ID := "obj_tier1_3_goblin_warcamp"
const PREBOSS_2_ID := "obj_preboss_2_borderlands_stronghold"
const BOSS_ID := "obj_boss_borderlands_ogre"


func before_each() -> void:
	GameSession.reset()
	GameSession.reset_injectable_rolls()
	GameManager.route_context_id = ""


func after_each() -> void:
	GameSession.reset()
	GameSession.reset_injectable_rolls()
	GameManager.route_context_id = ""


func test_full_arc_survives_checkpoint_export_reset_import_to_final_victory_and_free_play() -> void:
	var sim := CampaignSimScript.new()
	sim.sim_seed = JOURNEY_SEED
	var rng := RandomNumberGenerator.new()
	rng.seed = JOURNEY_SEED
	sim._wire_deterministic_rolls(rng)
	var telemetry := sim._new_telemetry(JOURNEY_SEED)

	# --- 1. Start a fresh game, create/deploy the party. ---
	GameSession.start_new_game()
	assert_eq(GameSession.campaign_objective_id, "obj_tier1_1_goblin_outpost")
	GameSession.create_party()
	var party_id: String = GameSession.selected_party_id
	sim._refill_party(telemetry)
	GameSession.deploy_party(party_id)
	assert_true(GameSession.has_deployed_party(), "Setup: the journey needs a deployed party to begin")

	var checkpoint_1_done := false
	var checkpoint_2_done := false
	var attempts := 0

	while (
		not GameSession.is_campaign_completed
		and GameSession.world_turn < CampaignSimScript.MAX_WORLD_TURNS
		and attempts < CampaignSimScript.MAX_OBJECTIVE_ATTEMPTS
	):
		attempts += 1
		sim._run_encampment_phase(telemetry)
		if GameSession.is_campaign_completed:
			break

		var encounter_id: String = GameSession.campaign_objective_id
		if encounter_id == "" or not GameSession.can_enter_encounter(encounter_id):
			break
		if not GameSession.has_deployed_party():
			GameSession.deploy_party(party_id)
		if not GameSession.has_deployed_party():
			break

		sim._travel_to_objective(encounter_id, telemetry)

		var outcome := sim._fight_objective(encounter_id, telemetry)
		assert_ne(outcome, "error", "Setup: %s must resolve to a legal scenario" % encounter_id)

		# --- 2. Checkpoint 1: fires the instant the third tier-1 node clears
		# (the early-arc checkpoint) -- captured right after the win merges
		# loot into pending_reward (_fight_objective()'s victory branch
		# already ran merge_battle_loot_into_party()) but BEFORE _return_to_
		# encampment() deposits it. This is a real, legitimate save point --
		# production reaches this exact window between the Battle Result
		# screen and returning to the Encampment. ---
		if not checkpoint_1_done and encounter_id == TIER1_3_ID and outcome == "victory":
			checkpoint_1_done = true
			var expected := _run_full_export_reset_import_checkpoint("checkpoint 1 (tier-1 clear)")
			assert_gt(expected.pending_reward, 0, "Setup: checkpoint 1 must be captured with a real unsettled reward")
			assert_eq(expected.battle_reward, 0, "Setup: checkpoint 1 must be captured after merge_battle_loot_into_party() already ran")
			assert_eq(expected.campaign_objective_id, "obj_tier2_1_orc_outpost", "Setup: clearing the third tier-1 node must unlock tier 2")
			assert_true(expected.completed_objectives.has(TIER1_3_ID))

		# --- 3. Checkpoint 2: fires the instant the pre-boss sequence clears
		# (right before the Ogre unlocks), same mid-victory-flow timing as
		# checkpoint 1 -- BEFORE _return_to_encampment() below, so this
		# objective's own reward is still sitting unsettled in pending_reward
		# -- but asserted far more broadly per this step's spec: objective
		# id/order, unlocked/cleared ids, full roster (HP/MP/level/equipment/
		# perks), party location/route, every reward bucket, building levels
		# and jobs (recovery timing), and the seeded RNG injection wiring the
		# next real action (the boss fight) depends on to stay reproducible. ---
		if not checkpoint_2_done and encounter_id == PREBOSS_2_ID and outcome == "victory":
			checkpoint_2_done = true
			var expected := _run_full_export_reset_import_checkpoint("checkpoint 2 (pre-boss clear)")
			assert_gt(expected.pending_reward, 0, "Setup: checkpoint 2 must also be captured with a real unsettled reward")
			assert_eq(expected.campaign_objective_id, BOSS_ID, "Setup: clearing the pre-boss sequence must unlock exactly the Ogre")
			assert_true(expected.completed_objectives.has(PREBOSS_2_ID))
			assert_false(expected.completed_objectives.has(BOSS_ID), "Setup: the boss must not be completed yet")
			assert_true(expected.unlocked_authored_encounters.has(BOSS_ID))

		sim._return_to_encampment(telemetry)

	assert_true(checkpoint_1_done, "Setup: the journey must actually reach and clear the third tier-1 node")
	assert_true(checkpoint_2_done, "Setup: the journey must actually reach and clear the pre-boss sequence")

	# --- 4. Resume through the final boss using the same real battle path;
	# assert exactly one final objective completion fires. ---
	assert_true(GameSession.is_campaign_completed, "The seeded journey must reach Final Boss victory")
	assert_eq(
		GameSession.completed_objectives.count(BOSS_ID), 1,
		"The boss objective must complete exactly once, never zero or duplicated"
	)
	assert_eq(
		GameSession.completed_objectives.size(), GameSession.CAMPAIGN_OBJECTIVES.size(),
		"Every one of the 12 authored nodes, and nothing else, must be recorded complete at victory"
	)
	# Step 6 (docs/plans/2026-08-22-stage-3-campaign-assembly/
	# 06-stage-3-exit-gate.md): the size check above alone cannot catch a
	# duplicated node silently displacing a missing one (still 12 entries
	# either way) or the twelve nodes landing out of authored order -- only a
	# full array comparison against CAMPAIGN_OBJECTIVES' own key order (which
	# is authored in, and exactly mirrors, prerequisite_id/next_objective_id
	# chain order -- see that const's own header comment) proves "all twelve
	# authored IDs complete exactly once, in order" as its own literal claim,
	# independent of trusting complete_campaign_objective()'s internal
	# duplicate-append guard to never regress.
	assert_eq(
		GameSession.completed_objectives, GameSession.CAMPAIGN_OBJECTIVES.keys(),
		"All twelve authored objective IDs must be recorded complete exactly once, in authored order"
	)
	assert_eq(GameSession.campaign_objective_id, "", "Victory must leave no further objective queued")
	assert_true(GameSession.is_free_play_active, "Victory must flip free play the instant set_campaign_victory() runs")

	# --- 5. Post-victory export/import must enter repeatable free play
	# without changing authored history. ---
	var post_victory_expected := _run_full_export_reset_import_checkpoint("checkpoint 3 (post-victory)")
	assert_eq(post_victory_expected.campaign_objective_id, "")
	assert_true(post_victory_expected.is_campaign_completed)
	assert_true(post_victory_expected.is_free_play_active)
	assert_eq(post_victory_expected.completed_objectives.size(), GameSession.CAMPAIGN_OBJECTIVES.size())

	# A real free-play action (entering a non-authored, repeatable sandbox
	# encounter through the actual public API) must never touch authored
	# history -- completed_objectives/campaign_objective_id stay exactly
	# what victory left them.
	assert_false(GameSession.active_encounters.is_empty(), "Setup: at least one repeatable sandbox encounter must still be open in free play")
	var free_play_encounter_id: String = String(GameSession.active_encounters[0].id)
	assert_false(GameSession.is_authored_encounter(free_play_encounter_id), "Setup: free play must offer a non-authored (sandbox) encounter")
	assert_true(GameSession.can_enter_encounter(free_play_encounter_id))
	GameSession.enter_encounter(free_play_encounter_id)
	GameSession.abandon_current_encounter()
	assert_eq(GameSession.campaign_objective_id, "", "Entering repeatable free play must not change campaign_objective_id")
	# Step 6: compared against the full ledger captured moments ago at
	# checkpoint 3 (post_victory_expected.completed_objectives), not merely
	# its size -- a free-play action that somehow reordered or duplicated an
	# authored id while holding the count at 12 would pass a size-only check
	# but must fail this one, closing this step's "repeatable post-victory
	# activity leaves the authored ledger unchanged" requirement for real.
	assert_eq(
		GameSession.completed_objectives, post_victory_expected.completed_objectives,
		"Entering repeatable free play must not change completed_objectives, including their order"
	)


## Captures every durable field this step's spec calls out, performs a
## genuine export -> reset -> import round trip through the real GameSession
## API, and asserts every captured field is restored exactly -- plus a
## direct, mutation-based (not merely value-comparison) proof that neither
## direction of the round trip aliases live state, and that the seeded RNG
## injection wiring the next real action depends on survives untouched.
## Returns the captured "before" state so a caller can add its own
## checkpoint-specific assertions (reward-settlement timing, exact objective
## ids) against the same values.
func _run_full_export_reset_import_checkpoint(context: String) -> Dictionary:
	var expected := _capture_durable_state()
	assert_false(expected.adventurers.is_empty(), "Setup (%s): a live roster must exist to alias-check" % context)

	var data := GameSession.export_campaign_snapshot()

	# --- No-aliasing proof, direction 1: mutating the freshly exported dict
	# must never reach back into the live session it was drawn from --
	# export_campaign_snapshot() must hand back an independent copy, not a
	# reference into GameSession's own live Arrays/Dictionaries. ---
	data["gold"] = int(expected.gold) + 999999
	data["adventurers"][0]["health"] = -1
	assert_eq(GameSession.gold, expected.gold, "%s: mutating the exported dict must not alias live gold" % context)
	assert_eq(GameSession.adventurers[0].health, expected.adventurers[0].health, "%s: mutating the exported dict must not alias the live roster" % context)

	# Re-export a clean copy for the real import -- the mutations above
	# deliberately corrupted the first `data` only to prove independence,
	# not data this checkpoint should actually restore.
	data = GameSession.export_campaign_snapshot()
	var rng_callable_before_reset: Callable = GameSession.loot_gold_roll

	GameSession.reset()

	var result := GameSession.import_campaign_snapshot(data)
	assert_true(result.ok, "%s: import must succeed (%s)" % [context, result.get("error", "")])

	# --- No-aliasing proof, direction 2: mutating the dict AFTER handing it
	# to import() must never reach into the live session import() just
	# populated. ---
	data["gold"] = -1
	data["adventurers"][0]["health"] = -1
	assert_eq(GameSession.gold, expected.gold, "%s: mutating the dict after import() must not alias live gold" % context)
	assert_eq(GameSession.adventurers[0].health, expected.adventurers[0].health, "%s: mutating the dict after import() must not alias the live roster" % context)

	# --- No-aliasing proof, direction 3 ("vice versa"): mutating live
	# session state after import must not reach back into a separately-held
	# snapshot dict taken right after import. Mutates both a plain int field
	# (gold) and a reference-typed nested field (a roster record's health) --
	# an int is always copied by value in GDScript, so only the
	# reference-typed mutation actually exercises the aliasing risk
	# directions 1/2 above test; the gold check is kept alongside it because
	# it's cheap and harmless, not because it proves anything on its own. ---
	var reference := GameSession.export_campaign_snapshot()
	var reference_gold: int = reference.gold
	var reference_health: int = reference.adventurers[0].health
	var live_health_before_mutation: int = GameSession.adventurers[0].health
	GameSession.gold += 4242
	GameSession.adventurers[0]["health"] = -1
	assert_eq(reference.gold, reference_gold, "%s: mutating live state afterward must not alias a previously exported dict's gold" % context)
	assert_eq(reference.adventurers[0].health, reference_health, "%s: mutating live state afterward must not alias a previously exported dict's roster" % context)
	GameSession.gold -= 4242
	GameSession.adventurers[0]["health"] = live_health_before_mutation

	# The deterministic RNG injection wiring must survive the checkpoint
	# untouched -- reset()/import() never reassign an injectable roll
	# Callable (see this file's own header comment), so the same Callable
	# object (bound to the same shared seeded RandomNumberGenerator) must
	# still be in place, proving the next real action (e.g. the boss fight)
	# stays reproducible.
	assert_eq(
		GameSession.loot_gold_roll, rng_callable_before_reset,
		"%s: the seeded RNG injection wiring must survive reset()/import() untouched" % context
	)

	_assert_durable_state_matches(expected, context)
	return expected


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
		"selected_encounter": GameSession.selected_encounter,
		"world_turn": GameSession.world_turn,
		"gold": GameSession.gold,
		"pending_reward": GameSession.pending_reward,
		"battle_reward": GameSession.battle_reward,
		"pending_gear": GameSession.pending_gear.duplicate(true),
		"battle_gear": GameSession.battle_gear.duplicate(true),
		"pending_mana_crystals": GameSession.pending_mana_crystals.duplicate(true),
		"battle_mana_crystals": GameSession.battle_mana_crystals.duplicate(true),
		"mana_crystals": GameSession.mana_crystals.duplicate(true),
		"banked_gear": GameSession.banked_gear.duplicate(true),
		"guild_hall_level": GameSession.guild_hall_level,
		"temple_level": GameSession.temple_level,
		"blacksmith_level": GameSession.blacksmith_level,
		"blacksmith_craft_job": GameSession.blacksmith_craft_job.duplicate(true),
		"blacksmith_sharpening_job": GameSession.blacksmith_sharpening_job.duplicate(true),
		"alchemy_workshop_level": GameSession.alchemy_workshop_level,
		"alchemy_craft_job": GameSession.alchemy_craft_job.duplicate(true),
		"runic_workshop_level": GameSession.runic_workshop_level,
		"runic_craft_job": GameSession.runic_craft_job.duplicate(true),
		"shop_level": GameSession.shop_level,
		"recruitment_vacancies": GameSession.recruitment_vacancies.duplicate(true),
		"encounter_vacancies": GameSession.encounter_vacancies.duplicate(true),
		"active_encounters": GameSession.active_encounters.duplicate(true),
		"completed_encounters": GameSession.completed_encounters.duplicate(true),
	}


func _assert_durable_state_matches(expected: Dictionary, context: String) -> void:
	assert_eq(GameSession.campaign_objective_id, expected.campaign_objective_id, "%s: campaign_objective_id" % context)
	assert_eq(GameSession.completed_objectives, expected.completed_objectives, "%s: completed_objectives" % context)
	assert_eq(GameSession.unlocked_authored_encounters, expected.unlocked_authored_encounters, "%s: unlocked_authored_encounters" % context)
	assert_eq(GameSession.is_campaign_completed, expected.is_campaign_completed, "%s: is_campaign_completed" % context)
	assert_eq(GameSession.is_free_play_active, expected.is_free_play_active, "%s: is_free_play_active" % context)
	assert_eq(GameSession.adventurers, expected.adventurers, "%s: adventurers (roster/HP/MP/level/equipment/perks)" % context)
	assert_eq(GameSession.parties, expected.parties, "%s: parties (location/route/members)" % context)
	assert_eq(GameSession.selected_party_id, expected.selected_party_id, "%s: selected_party_id" % context)
	assert_eq(GameSession.selected_encounter, expected.selected_encounter, "%s: selected_encounter" % context)
	assert_eq(GameSession.world_turn, expected.world_turn, "%s: world_turn" % context)
	assert_eq(GameSession.gold, expected.gold, "%s: gold" % context)
	assert_eq(GameSession.pending_reward, expected.pending_reward, "%s: pending_reward" % context)
	assert_eq(GameSession.battle_reward, expected.battle_reward, "%s: battle_reward" % context)
	assert_eq(GameSession.pending_gear, expected.pending_gear, "%s: pending_gear" % context)
	assert_eq(GameSession.battle_gear, expected.battle_gear, "%s: battle_gear" % context)
	assert_eq(GameSession.pending_mana_crystals, expected.pending_mana_crystals, "%s: pending_mana_crystals" % context)
	assert_eq(GameSession.battle_mana_crystals, expected.battle_mana_crystals, "%s: battle_mana_crystals" % context)
	assert_eq(GameSession.mana_crystals, expected.mana_crystals, "%s: mana_crystals" % context)
	assert_eq(GameSession.banked_gear, expected.banked_gear, "%s: banked_gear" % context)
	assert_eq(GameSession.guild_hall_level, expected.guild_hall_level, "%s: guild_hall_level" % context)
	assert_eq(GameSession.temple_level, expected.temple_level, "%s: temple_level" % context)
	assert_eq(GameSession.blacksmith_level, expected.blacksmith_level, "%s: blacksmith_level" % context)
	assert_eq(GameSession.blacksmith_craft_job, expected.blacksmith_craft_job, "%s: blacksmith_craft_job" % context)
	assert_eq(GameSession.blacksmith_sharpening_job, expected.blacksmith_sharpening_job, "%s: blacksmith_sharpening_job" % context)
	assert_eq(GameSession.alchemy_workshop_level, expected.alchemy_workshop_level, "%s: alchemy_workshop_level" % context)
	assert_eq(GameSession.alchemy_craft_job, expected.alchemy_craft_job, "%s: alchemy_craft_job" % context)
	assert_eq(GameSession.runic_workshop_level, expected.runic_workshop_level, "%s: runic_workshop_level" % context)
	assert_eq(GameSession.runic_craft_job, expected.runic_craft_job, "%s: runic_craft_job" % context)
	assert_eq(GameSession.shop_level, expected.shop_level, "%s: shop_level" % context)
	assert_eq(GameSession.recruitment_vacancies, expected.recruitment_vacancies, "%s: recruitment_vacancies (recovery timing)" % context)
	assert_eq(GameSession.encounter_vacancies, expected.encounter_vacancies, "%s: encounter_vacancies (recovery timing)" % context)
	assert_eq(GameSession.active_encounters, expected.active_encounters, "%s: active_encounters" % context)
	assert_eq(GameSession.completed_encounters, expected.completed_encounters, "%s: completed_encounters" % context)
