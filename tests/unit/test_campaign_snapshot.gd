extends GutTest

const CampaignSnapshot := preload("res://scripts/save/campaign_snapshot.gd")


## Only the withdraw round-trip test below touches the live GameSession
## singleton -- every other test in this file exercises the CampaignSnapshot
## class in isolation. Reset unconditionally anyway so a future test added
## here can never leak session state into a later test file.
func after_each() -> void:
	GameSession.reset()


## A fully-populated snapshot covering every durable category: roster,
## recruitment offers/vacancies, a party with a travel route, selected ids,
## world turn, active encounters/completions/vacancies, gold/buildings,
## every battle/pending/banked reward store, player name, and tutorial
## progress.
func _full_snapshot() -> CampaignSnapshot:
	var snapshot := CampaignSnapshot.new()
	snapshot.adventurers = [
		{"id": "warrior_001", "name": "Warrior", "level": 1, "health": 10, "stats": {"melee": 60, "missile": 60, "guard": 0, "might": 0, "vitality": 10, "max_health": 10}},
		# A purchased recruit in the current format: a generated instance id
		# plus the explicit template_id it claimed at purchase time.
		{"id": "3f2a9c1e-7b4d-4e8a-9c6f-1d2e3f4a5b6c", "name": "Warrior 5", "level": 1, "template_id": "warrior_002", "health": 10, "stats": {"melee": 60, "missile": 60, "guard": 0, "might": 0, "vitality": 10, "max_health": 10}},
	]
	snapshot.recruitment_candidates = [
		{"id": "offer-abc-123", "name": "Warrior 6", "cost": 10, "template_id": "warrior_003", "health": 10, "stats": {"melee": 60, "missile": 60, "guard": 0, "might": 0, "vitality": 10, "max_health": 10}},
	]
	snapshot.recruitment_vacancies = [{"turns_remaining": 12}]
	snapshot.parties = [
		{
			"id": "party_001",
			"member_ids": ["warrior_001"],
			"location_id": "starting_settlement",
			"world_position": Vector2i(4, 4),
			"deployed": true,
			"travel_route": [Vector2i(4, 5), Vector2i(4, 6)],
			"movement_spent": false,
			"name": "Party 1",
			"progression": {},
			"metadata": {},
		},
	]
	snapshot.selected_party_id = "party_001"
	snapshot.selected_encounter = "goblin_camp"
	snapshot.campaign_objective_id = "obj_tier1_2_kobold_warren"
	snapshot.completed_objectives = ["obj_tier1_1_goblin_outpost"]
	snapshot.unlocked_authored_encounters = ["obj_tier1_1_goblin_outpost", "obj_tier1_2_kobold_warren"]
	snapshot.is_campaign_completed = false
	snapshot.is_free_play_active = false
	snapshot.completed_encounters = ["orc_outpost"]
	snapshot.active_encounters = [
		{
			"id": "goblin_camp",
			"template_id": "goblin_camp",
			"position": Vector2i(4, 4),
			"difficulty": 1,
			"enemy": {"name_key": "battle.enemy.goblin", "count": 1},
		},
	]
	snapshot.encounter_vacancies = [{"turns_remaining": 8}]
	snapshot.used_encounter_template_ids = ["goblin_camp", "orc_outpost"]
	snapshot.world_turn = 7
	snapshot.gold = 42
	snapshot.guild_hall_level = 2
	snapshot.temple_level = 1
	snapshot.pending_reward = 17
	snapshot.mana_crystals = {1: 3}
	snapshot.banked_gear = {"shortsword_iron": 1}
	snapshot.pending_mana_crystals = {2: 1}
	snapshot.pending_gear = {"longsword_iron": 1}
	snapshot.battle_reward = 5
	snapshot.battle_mana_crystals = {1: 1}
	snapshot.battle_gear = {"dagger_iron": 1}
	snapshot.has_trading_post = true
	snapshot.shop_level = 2
	snapshot.shop_gold = 150
	snapshot.player_name = "Ryan"
	snapshot.tutorial_progress = {"formed_party": true}
	return snapshot


func test_format_version_is_2() -> void:
	assert_eq(CampaignSnapshot.FORMAT_VERSION, 2)


func test_to_dictionary_tags_the_format_version() -> void:
	var data := CampaignSnapshot.new().to_dictionary()
	assert_eq(data.version, 2)


## Task-list item 3: to_dictionary() exports version 2 with every campaign
## progression field, at their fresh-campaign defaults for a brand-new
## (never-mutated) snapshot.
func test_to_dictionary_exports_version_2_with_all_campaign_progression_fields() -> void:
	var data := CampaignSnapshot.new().to_dictionary()

	assert_eq(data.version, 2)
	assert_eq(data.campaign_objective_id, "obj_tier1_1_goblin_outpost")
	assert_eq(data.completed_objectives, [])
	assert_eq(data.unlocked_authored_encounters, ["obj_tier1_1_goblin_outpost"])
	assert_eq(data.is_campaign_completed, false)
	assert_eq(data.is_free_play_active, false)


func test_to_dictionary_converts_vector2i_fields_to_x_y_dictionaries() -> void:
	var data := _full_snapshot().to_dictionary()

	assert_eq(data.parties[0].world_position, {"x": 4, "y": 4})
	assert_eq(data.parties[0].travel_route, [{"x": 4, "y": 5}, {"x": 4, "y": 6}])
	assert_eq(data.active_encounters[0].position, {"x": 4, "y": 4})


func test_round_trip_preserves_every_durable_category() -> void:
	var original := _full_snapshot()
	var data := original.to_dictionary()

	var result := CampaignSnapshot.from_dictionary(data)

	assert_true(result.ok, result.error)
	var snapshot: Dictionary = result.snapshot
	assert_eq(snapshot.adventurers, original.adventurers)
	assert_eq(snapshot.recruitment_candidates, original.recruitment_candidates)
	assert_eq(snapshot.recruitment_vacancies, original.recruitment_vacancies)
	assert_eq(snapshot.parties[0].world_position, Vector2i(4, 4))
	assert_eq(snapshot.parties[0].travel_route, [Vector2i(4, 5), Vector2i(4, 6)])
	assert_eq(snapshot.selected_party_id, "party_001")
	assert_eq(snapshot.selected_encounter, "goblin_camp")
	assert_eq(snapshot.campaign_objective_id, "obj_tier1_2_kobold_warren")
	assert_eq(snapshot.completed_objectives, ["obj_tier1_1_goblin_outpost"])
	assert_eq(snapshot.unlocked_authored_encounters, ["obj_tier1_1_goblin_outpost", "obj_tier1_2_kobold_warren"])
	assert_eq(snapshot.is_campaign_completed, false)
	assert_eq(snapshot.is_free_play_active, false)
	assert_eq(snapshot.completed_encounters, ["orc_outpost"])
	assert_eq(snapshot.active_encounters[0].position, Vector2i(4, 4))
	assert_eq(snapshot.encounter_vacancies, [{"turns_remaining": 8}])
	assert_eq(snapshot.used_encounter_template_ids, ["goblin_camp", "orc_outpost"])
	assert_eq(snapshot.world_turn, 7)
	assert_eq(snapshot.gold, 42)
	assert_eq(snapshot.guild_hall_level, 2)
	assert_eq(snapshot.temple_level, 1)
	assert_eq(snapshot.pending_reward, 17)
	assert_eq(snapshot.mana_crystals, {1: 3})
	assert_eq(snapshot.banked_gear, {"shortsword_iron": 1})
	assert_eq(snapshot.pending_mana_crystals, {2: 1})
	assert_eq(snapshot.pending_gear, {"longsword_iron": 1})
	assert_eq(snapshot.battle_reward, 5)
	assert_eq(snapshot.battle_mana_crystals, {1: 1})
	assert_eq(snapshot.battle_gear, {"dagger_iron": 1})
	assert_eq(snapshot.has_trading_post, true)
	assert_eq(snapshot.shop_level, 2)
	assert_eq(snapshot.shop_gold, 150)
	assert_eq(snapshot.player_name, "Ryan")
	assert_eq(snapshot.tutorial_progress, {"formed_party": true})


## Step 2 of docs/plans/2026-08-21-stage-1-campaign-spine: pre-battle
## Withdraw's combined health/route/objective/reward state must round-trip
## through the real GameSession.export_campaign_snapshot()/import_campaign_
## snapshot() path. CampaignSnapshot already owns every field Withdraw
## touches -- party health, world_position, travel_route, movement_spent,
## selected_encounter, and the reward buckets -- so this locks that combined
## behavior at the new route boundary rather than adding a snapshot field.
func test_a_withdrawn_partys_state_round_trips_through_the_real_game_session_snapshot() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.depart_selected_party()
	var encounter_id := "obj_tier1_1_goblin_outpost"
	GameSession.set_deployed_party_position(GameSession.get_expedition(encounter_id).position)
	GameSession.withdraw_from_encounter(encounter_id, func() -> float: return 0.95)
	var health_before := GameSession.get_current_health(GameSession.WARRIOR_ID)
	var route_before := GameSession.get_deployed_party_route()
	var position_before := GameSession.get_deployed_party_position()
	var objective_before := GameSession.campaign_objective_id
	var pending_reward_before := GameSession.pending_reward
	var pending_gear_before := GameSession.pending_gear.duplicate(true)
	var data := GameSession.export_campaign_snapshot()
	GameSession.reset()

	var result := GameSession.import_campaign_snapshot(data)

	assert_true(result.ok, result.get("error", ""))
	assert_eq(GameSession.get_current_health(GameSession.WARRIOR_ID), health_before)
	assert_eq(GameSession.get_deployed_party_route(), route_before)
	assert_eq(GameSession.get_deployed_party_position(), position_before)
	assert_eq(GameSession.campaign_objective_id, objective_before)
	assert_true(GameSession.can_enter_encounter(encounter_id), "The encounter must remain available after import")
	assert_eq(GameSession.pending_reward, pending_reward_before)
	assert_eq(GameSession.pending_gear, pending_gear_before)


## Step 3 of docs/plans/2026-08-18-core-loop-and-engagement: temple_level
## serializes/deserializes like any other durable building level, and a
## fresh (never-built) snapshot defaults to 0 -- see GameSession.temple_level's
## own doc comment for why no blessing state is introduced alongside it.
func test_fresh_snapshot_defaults_temple_level_to_zero() -> void:
	var data := CampaignSnapshot.new().to_dictionary()

	assert_eq(data.temple_level, 0)
	assert_false(data.keys().any(func(key): return str(key).to_lower().contains("blessing")))


func test_temple_level_round_trips() -> void:
	var snapshot := CampaignSnapshot.new()
	snapshot.temple_level = 1
	var data := snapshot.to_dictionary()

	var result := CampaignSnapshot.from_dictionary(data)

	assert_true(result.ok, result.error)
	assert_eq(result.snapshot.temple_level, 1)


## A payload predating this step's temple_level field (e.g. a version-2 save
## from before this step shipped) must migrate to the harmless unbuilt
## default rather than being rejected -- the same incremental-field-addition
## pattern blacksmith_level/alchemy_workshop_level already established.
func test_a_payload_missing_temple_level_migrates_to_unbuilt() -> void:
	var data := CampaignSnapshot.new().to_dictionary()
	data.erase("temple_level")

	var result := CampaignSnapshot.from_dictionary(data)

	assert_true(result.ok, result.error)
	assert_eq(result.snapshot.temple_level, 0)


func test_rejects_an_out_of_range_temple_level() -> void:
	var data := CampaignSnapshot.new().to_dictionary()
	data.temple_level = 2

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)


## _normalize_party() must start from a duplicate of the raw party dict and
## only overwrite the fields it validates/converts (mirroring how
## _normalize_id_list()/_normalize_active_encounters() already treat
## unknown fields on adventurers/active encounters), rather than rebuilding
## an explicit whitelist Dictionary literal that silently drops anything
## not already named -- a quest-flag or other future party field must
## survive an export -> import round trip untouched.
func test_unknown_party_fields_survive_a_round_trip() -> void:
	var snapshot := _full_snapshot()
	snapshot.parties[0]["quest_flags"] = {"rescued_npc": true}
	var data := snapshot.to_dictionary()

	var result := CampaignSnapshot.from_dictionary(data)

	assert_true(result.ok, result.error)
	assert_eq(result.snapshot.parties[0].get("quest_flags"), {"rescued_npc": true})


func test_from_dictionary_deep_copies_so_mutating_the_source_does_not_touch_the_result() -> void:
	var data := _full_snapshot().to_dictionary()
	var result := CampaignSnapshot.from_dictionary(data)
	assert_true(result.ok, result.error)

	data.gold = 999
	data.parties[0].world_position = {"x": 0, "y": 0}
	data.adventurers[0].name = "Mutated"

	var snapshot: Dictionary = result.snapshot
	assert_eq(snapshot.gold, 42)
	assert_eq(snapshot.parties[0].world_position, Vector2i(4, 4))
	assert_eq(snapshot.adventurers[0].name, "Warrior")


func test_selected_encounter_may_reference_a_raw_template_id_not_yet_an_active_instance() -> void:
	var snapshot := _full_snapshot()
	snapshot.selected_encounter = "ruined_fortress"
	var data := snapshot.to_dictionary()

	var result := CampaignSnapshot.from_dictionary(data)

	assert_true(result.ok, result.error)
	assert_eq(result.snapshot.selected_encounter, "ruined_fortress")


func test_empty_selected_ids_are_always_valid() -> void:
	var snapshot := CampaignSnapshot.new()
	var data := snapshot.to_dictionary()

	var result := CampaignSnapshot.from_dictionary(data)

	assert_true(result.ok, result.error)


func test_rejects_missing_version() -> void:
	var data := _full_snapshot().to_dictionary()
	data.erase("version")

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)
	assert_eq(result.snapshot, {})
	assert_ne(result.error, "")


func test_rejects_unknown_version() -> void:
	var data := _full_snapshot().to_dictionary()
	data.version = 3

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)


## Task-list item 3: a version 1 payload predates campaign milestone
## progression entirely, so it never carries these five keys at all --
## from_dictionary() must migrate it to a fresh campaign's starting values
## rather than reject it, and must not drop any of its own real (non-
## campaign) roster/building state in the process.
func test_version_1_migrates_missing_campaign_fields_to_starting_values() -> void:
	var data := _full_snapshot().to_dictionary()
	data.version = 1
	data.erase("campaign_objective_id")
	data.erase("completed_objectives")
	data.erase("unlocked_authored_encounters")
	data.erase("is_campaign_completed")
	data.erase("is_free_play_active")

	var result := CampaignSnapshot.from_dictionary(data)

	assert_true(result.ok, result.error)
	assert_eq(result.snapshot.campaign_objective_id, "obj_tier1_1_goblin_outpost")
	assert_eq(result.snapshot.completed_objectives, [])
	assert_eq(result.snapshot.unlocked_authored_encounters, ["obj_tier1_1_goblin_outpost"])
	assert_eq(result.snapshot.is_campaign_completed, false)
	assert_eq(result.snapshot.is_free_play_active, false)
	assert_eq(result.snapshot.gold, 42, "Version 1 migration must not drop the payload's own non-campaign state")
	assert_eq(result.snapshot.guild_hall_level, 2)


func test_rejects_a_version_2_payload_missing_campaign_objective_id() -> void:
	var data := _full_snapshot().to_dictionary()
	data.erase("campaign_objective_id")

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)


func test_rejects_a_version_2_payload_with_a_malformed_completed_objectives_field() -> void:
	var data := _full_snapshot().to_dictionary()
	data.completed_objectives = "not an array"

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)


func test_rejects_a_version_2_payload_with_a_malformed_is_campaign_completed_field() -> void:
	var data := _full_snapshot().to_dictionary()
	data.is_campaign_completed = "not a bool"

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)


func test_rejects_non_dictionary_input() -> void:
	var result := CampaignSnapshot.from_dictionary("not a dictionary")

	assert_false(result.ok)


func test_rejects_a_malformed_scalar_field() -> void:
	var data := _full_snapshot().to_dictionary()
	data.gold = "42"

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)


func test_rejects_a_malformed_list_field() -> void:
	var data := _full_snapshot().to_dictionary()
	data.parties = "not an array"

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)


func test_rejects_a_malformed_vector2i_field() -> void:
	var data := _full_snapshot().to_dictionary()
	data.parties[0].world_position = {"x": 4}

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)


func test_rejects_a_malformed_dictionary_field() -> void:
	var data := _full_snapshot().to_dictionary()
	data.mana_crystals = "not a dictionary"

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)


func test_rejects_duplicate_adventurer_ids() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers.append(data.adventurers[0].duplicate(true))

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)


func test_rejects_duplicate_recruitment_candidate_ids() -> void:
	var data := _full_snapshot().to_dictionary()
	data.recruitment_candidates.append(data.recruitment_candidates[0].duplicate(true))

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)


func test_rejects_duplicate_party_ids() -> void:
	var data := _full_snapshot().to_dictionary()
	data.parties.append(data.parties[0].duplicate(true))

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)


func test_rejects_duplicate_active_encounter_ids() -> void:
	var data := _full_snapshot().to_dictionary()
	data.active_encounters.append(data.active_encounters[0].duplicate(true))

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)


func test_rejects_a_selected_party_id_that_does_not_reference_a_known_party() -> void:
	var data := _full_snapshot().to_dictionary()
	data.selected_party_id = "no_such_party"

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)


func test_rejects_a_selected_encounter_that_does_not_reference_any_known_encounter() -> void:
	var data := _full_snapshot().to_dictionary()
	data.selected_encounter = "no_such_encounter"

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)


## Task-review finding: campaign progress fields must be cross-checked
## against GameSession.CAMPAIGN_OBJECTIVES, the same way selected_encounter
## is cross-checked against EXPEDITIONS/active_encounters above -- a
## corrupted or hand-edited save naming a node that was never in the
## catalog (e.g. a typo, or a node renamed/removed since the save was
## written) must fail import rather than silently being accepted.
func test_rejects_a_version_2_payload_with_an_unknown_campaign_objective_id() -> void:
	var data := _full_snapshot().to_dictionary()
	data.campaign_objective_id = "obj_no_such_objective"

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)


func test_rejects_a_version_2_payload_with_an_unknown_completed_objectives_entry() -> void:
	var data := _full_snapshot().to_dictionary()
	data.completed_objectives = ["obj_no_such_objective"]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)


func test_rejects_a_version_2_payload_with_an_unknown_unlocked_authored_encounters_entry() -> void:
	var data := _full_snapshot().to_dictionary()
	data.unlocked_authored_encounters = ["obj_no_such_objective"]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)


## A campaign_objective_id of "" is the legitimate victory-state value (see
## GameSession.complete_campaign_objective()'s final-node case) and must not
## be rejected just because it names no catalog node.
func test_an_empty_campaign_objective_id_is_valid_for_a_completed_campaign() -> void:
	var snapshot := _full_snapshot()
	snapshot.campaign_objective_id = ""
	snapshot.is_campaign_completed = true
	var data := snapshot.to_dictionary()

	var result := CampaignSnapshot.from_dictionary(data)

	assert_true(result.ok, result.error)
	assert_eq(result.snapshot.campaign_objective_id, "")


func test_legacy_trading_post_true_migrates_to_a_level_one_shop() -> void:
	var data := _full_snapshot().to_dictionary()
	data.erase("shop_level")
	data.erase("shop_gold")
	data.has_trading_post = true
	var result := CampaignSnapshot.from_dictionary(data)
	assert_true(result.ok, result.error)
	assert_eq(result.snapshot.shop_level, 1)
	assert_eq(result.snapshot.shop_gold, 100)


func test_legacy_trading_post_false_migrates_to_a_locked_shop() -> void:
	var data := _full_snapshot().to_dictionary()
	data.erase("shop_level")
	data.erase("shop_gold")
	data.has_trading_post = false
	var result := CampaignSnapshot.from_dictionary(data)
	assert_true(result.ok, result.error)
	assert_eq(result.snapshot.shop_level, 0)
	assert_eq(result.snapshot.shop_gold, 0)


## Legacy saves predate generated instance identity: a purchased recruit's
## record carried the claimed template's id as its own id. Loading such a
## record infers the explicit template_id the live claiming rules now key on.
func test_legacy_adventurer_whose_id_matches_a_template_infers_its_template_id() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [{"id": "warrior_002", "name": "Warrior 2", "level": 1}]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_true(result.ok, result.error)
	assert_eq(result.snapshot.adventurers[0].id, "warrior_002", "Legacy ids are kept verbatim, never re-minted")
	assert_eq(result.snapshot.adventurers[0].get("template_id"), "warrior_002")


func test_legacy_adventurer_whose_id_matches_no_template_loads_without_a_template_id() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [{"id": "warrior_001", "name": "Warrior", "level": 1}]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_true(result.ok, result.error)
	assert_false(result.snapshot.adventurers[0].has("template_id"))


func test_legacy_recruitment_offer_whose_id_matches_a_template_infers_its_template_id() -> void:
	var data := _full_snapshot().to_dictionary()
	data.recruitment_candidates = [{"id": "scout_002", "name": "Scout 2", "cost": 10}]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_true(result.ok, result.error)
	assert_eq(result.snapshot.recruitment_candidates[0].get("template_id"), "scout_002")


func test_current_format_records_keep_generated_ids_and_template_ids_exactly() -> void:
	var data := _full_snapshot().to_dictionary()

	var result := CampaignSnapshot.from_dictionary(data)

	assert_true(result.ok, result.error)
	assert_eq(result.snapshot.adventurers, data.adventurers)
	assert_eq(result.snapshot.recruitment_candidates, data.recruitment_candidates)


func test_legacy_adventurer_stats_migrate_attack_to_skill_tracks_and_recalculate_max_health() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [
		{
			"id": "warrior_001",
			"name": "Warrior",
			"class": "warrior",
			"level": 2,
			"stats": {"attack": 65, "max_health": 15},
			"progression": {"xp": 20.0, "skill_points": 10}
		}
	]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_true(result.ok, result.error)
	var adv: Dictionary = result.snapshot.adventurers[0]
	assert_false(adv.progression.has("skill_points"))
	assert_false(adv.stats.has("attack"))
	assert_eq(adv.stats.melee, 65)
	assert_eq(adv.stats.missile, 65)
	assert_eq(adv.stats.guard, 1)
	assert_eq(adv.stats.might, 3)
	assert_eq(adv.stats.max_health, 20)
	assert_eq(adv.get("health", 0), 20, "Legacy save without health key normalizes to max_health")


## Review finding (docs/plans/2026-08-21-stage-2-party-readiness/
## 02-class-progression-and-perks.md): the health clamp above must clamp to
## the record's EFFECTIVE max health (base stats.max_health plus Juggernaut/
## Devout's percent bonus -- see GameSession.get_effective_max_health()),
## not merely stats.max_health itself. A level-3 Warrior with base
## max_health 30 who has chosen warrior_juggernaut has effective max health
## 35 (30 + round(30 * 15%)); resting to full and round-tripping a snapshot
## must preserve 35, not silently clip it back down to 30.
func test_a_perked_adventurers_health_round_trips_at_its_effective_not_base_max_health() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [
		{
			"id": "warrior_001", "name": "Warrior", "class": "warrior", "level": 3, "health": 35,
			"stats": {"melee": 63, "missile": 63, "guard": 1, "might": 3, "vitality": 10, "max_health": 30},
			"progression": {"xp": 50.0, "perks": ["warrior_juggernaut"]},
		},
	]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_true(result.ok, result.error)
	var adv: Dictionary = result.snapshot.adventurers[0]
	assert_eq(adv.stats.max_health, 30, "Base max_health is unaffected by the perk")
	assert_eq(adv.health, 35, "Health must round-trip at the perked effective max (35), not clamp down to base (30)")


## Same regression, Cleric Devout side (a different class, a different
## percent, and importing via GameSession.import_campaign_snapshot() rather
## than CampaignSnapshot.from_dictionary() directly) -- proves the fix holds
## through the real production import path, not just the isolated
## normalizer.
func test_import_campaign_snapshot_preserves_a_cleric_devout_holders_effective_health() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [
		{
			"id": "cleric_001", "name": "Cleric", "class": "cleric", "level": 3, "health": 40,
			"stats": {"melee": 47, "guard": 14, "might": 3, "spellcasting": 60, "vitality": 12, "max_health": 36},
			"progression": {"xp": 50.0, "perks": ["cleric_devout"]},
		},
	]
	data.selected_party_id = ""
	data.parties = []

	var result := GameSession.import_campaign_snapshot(data)

	assert_true(result.ok, result.error)
	var adv := GameSession.get_adventurer("cleric_001")
	assert_eq(adv.stats.max_health, 36, "Base max_health is unaffected by the perk")
	assert_eq(adv.health, 40, "Health must round-trip at the perked effective max (40), not clamp down to base (36)")
	assert_eq(GameSession.get_effective_max_health("cleric_001"), 40, "36 + round(36 * 10%) = 40")


## Task 2 (docs/plans/2026-08-21-stage-2-party-readiness/
## 02-class-progression-and-perks.md): progression.perks validation. Every
## element must be a String naming either GameSession.BONUS_MOVE_PERK_ID (the
## retired-but-still-valid legacy universal perk) or one of the adventurer's
## own class's CLASS_PERKS ids -- see _validate_perks_field() in campaign_
## snapshot.gd.

func test_valid_new_perk_ids_survive_a_round_trip_unchanged() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [
		{
			"id": "warrior_001", "name": "Warrior", "class": "warrior", "level": 6,
			"stats": {"melee": 60, "missile": 60, "guard": 0, "might": 0, "vitality": 10, "max_health": 60},
			"progression": {"xp": 200.0, "perks": ["warrior_juggernaut", "warrior_bulwark"]},
		},
	]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_true(result.ok, result.error)
	assert_eq(result.snapshot.adventurers[0].progression.perks, ["warrior_juggernaut", "warrior_bulwark"])


func test_a_perk_id_belonging_to_a_different_class_is_rejected_atomically() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [
		{
			"id": "warrior_001", "name": "Warrior", "class": "warrior", "level": 3,
			"stats": {"melee": 60, "missile": 60, "guard": 0, "might": 0, "vitality": 10, "max_health": 30},
			"progression": {"xp": 50.0, "perks": ["scout_quickdraw"]},
		},
	]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok, "A Scout-owned perk id on a Warrior record must be rejected")
	assert_eq(result.snapshot, {}, "A rejected import returns no partial snapshot")


func test_an_unrecognized_perk_id_is_rejected_atomically() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [
		{
			"id": "warrior_001", "name": "Warrior", "class": "warrior", "level": 3,
			"stats": {"melee": 60, "missile": 60, "guard": 0, "might": 0, "vitality": 10, "max_health": 30},
			"progression": {"xp": 50.0, "perks": ["not_a_real_perk"]},
		},
	]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)
	assert_eq(result.snapshot, {})


func test_a_duplicate_perk_id_is_rejected_atomically() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [
		{
			"id": "warrior_001", "name": "Warrior", "class": "warrior", "level": 6,
			"stats": {"melee": 60, "missile": 60, "guard": 0, "might": 0, "vitality": 10, "max_health": 60},
			"progression": {"xp": 200.0, "perks": ["warrior_juggernaut", "warrior_juggernaut"]},
		},
	]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)
	assert_eq(result.snapshot, {})


## The legacy universal perk is not "foreign" to any class -- it must still
## validate successfully everywhere, exactly as it always has.
func test_the_legacy_bonus_move_perk_id_still_validates_for_any_class() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [
		{
			"id": "warrior_001", "name": "Warrior", "class": "warrior", "level": 3,
			"stats": {"melee": 60, "missile": 60, "guard": 0, "might": 0, "vitality": 10, "max_health": 30},
			"progression": {"xp": 50.0, "perks": ["bonus_move"]},
		},
	]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_true(result.ok, result.error)
	assert_eq(result.snapshot.adventurers[0].progression.perks, ["bonus_move"])
