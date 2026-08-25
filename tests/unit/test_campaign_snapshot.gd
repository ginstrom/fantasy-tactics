extends GutTest

const CampaignSnapshot := preload("res://scripts/save/campaign_snapshot.gd")


## Only the withdraw round-trip test below touches the live GameSession
## singleton -- every other test in this file exercises the CampaignSnapshot
## class in isolation. Reset unconditionally anyway so a future test added
## here can never leak session state into a later test file.
func after_each() -> void:
	GameSession.reset()


## A fully-populated snapshot covering every durable category: roster,
## recruitment offers/vacancies, a party with a travel route and its own
## PartyCarry, selected ids, world turn, active encounters/completions/
## vacancies, gold/buildings, banked reward stores, player name, and
## tutorial progress.
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
			"carry": {"gold": 17, "gear": {"longsword_iron": 1}, "mana_crystals": {2: 1}, "item_instance_ids": [] as Array[String]},
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
	snapshot.mana_crystals = {1: 3}
	snapshot.banked_gear = {"shortsword_iron": 1}
	snapshot.has_trading_post = true
	snapshot.shop_level = 2
	snapshot.shop_gold = 150
	snapshot.player_name = "Ryan"
	snapshot.tutorial_progress = {"formed_party": true}
	snapshot.journal_entries = [
		{
			"id": "entry-1",
			"sequence": 1,
			"section": "log",
			"kind": "discovery",
			"title_key": "journal.discovery.goblin_camp",
			"detail": {"encounter_id": "goblin_camp"},
			"read": true,
		},
		{
			"id": "entry-2",
			"sequence": 2,
			"section": "quests",
			"kind": "quest",
			"title_key": "journal.quest.accepted",
			"detail": {"quest_id": "q1"},
			"read": false,
		},
	]
	return snapshot


func test_format_version_is_4() -> void:
	assert_eq(CampaignSnapshot.FORMAT_VERSION, 4)


func test_to_dictionary_tags_the_format_version() -> void:
	var data := CampaignSnapshot.new().to_dictionary()
	assert_eq(data.version, 4)


## Task-list item 3: to_dictionary() exports the current format version with
## every campaign progression field, at their fresh-campaign defaults for a
## brand-new (never-mutated) snapshot.
func test_to_dictionary_exports_current_version_with_all_campaign_progression_fields() -> void:
	var data := CampaignSnapshot.new().to_dictionary()

	assert_eq(data.version, 4)
	assert_eq(data.campaign_objective_id, "obj_tier1_1_goblin_outpost")
	assert_eq(data.completed_objectives, [])
	assert_eq(data.unlocked_authored_encounters, ["obj_tier1_1_goblin_outpost"])
	assert_eq(data.is_campaign_completed, false)
	assert_eq(data.is_free_play_active, false)
	assert_eq(data.journal_entries, [])


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
	assert_eq(snapshot.parties[0].carry, {"gold": 17, "gear": {"longsword_iron": 1}, "mana_crystals": {2: 1}, "item_instance_ids": [] as Array[String]})
	assert_eq(snapshot.mana_crystals, {1: 3})
	assert_eq(snapshot.banked_gear, {"shortsword_iron": 1})
	assert_eq(snapshot.has_trading_post, true)
	assert_eq(snapshot.shop_level, 2)
	assert_eq(snapshot.shop_gold, 150)
	assert_eq(snapshot.player_name, "Ryan")
	assert_eq(snapshot.tutorial_progress, {"formed_party": true})
	assert_eq(snapshot.journal_entries, original.journal_entries)



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
	var party_id: String = GameSession.selected_party_id
	var carry_before := GameSession.get_party_carry(party_id)
	var data := GameSession.export_campaign_snapshot()
	GameSession.reset()

	var result := GameSession.import_campaign_snapshot(data)

	assert_true(result.ok, result.get("error", ""))
	assert_eq(GameSession.get_current_health(GameSession.WARRIOR_ID), health_before)
	assert_eq(GameSession.get_deployed_party_route(), route_before)
	assert_eq(GameSession.get_deployed_party_position(), position_before)
	assert_eq(GameSession.campaign_objective_id, objective_before)
	assert_true(GameSession.can_enter_encounter(encounter_id), "The encounter must remain available after import")
	assert_eq(GameSession.get_party_carry(party_id), carry_before)


## Step 3 (docs/plans/2026-08-22-stage-3-campaign-assembly/03-final-victory-
## and-free-play-boundaries.md): once GameSession.set_campaign_victory() has
## fired, the durable campaign_objective_id=""/completed_objectives(full)/
## is_campaign_completed=true/is_free_play_active=true boundary must survive
## a real export -> import round trip exactly as GameSession left it.
func test_post_victory_boundary_round_trips_through_the_real_game_session_snapshot() -> void:
	GameSession.reset()
	GameSession.completed_objectives.assign(GameSession.CAMPAIGN_OBJECTIVES.keys())
	GameSession.campaign_objective_id = ""
	GameSession.set_campaign_victory()
	var data := GameSession.export_campaign_snapshot()
	GameSession.reset()

	var result := GameSession.import_campaign_snapshot(data)

	assert_true(result.ok, result.get("error", ""))
	assert_eq(GameSession.campaign_objective_id, "")
	assert_eq(GameSession.completed_objectives.size(), GameSession.CAMPAIGN_OBJECTIVES.size())
	assert_true(GameSession.is_campaign_completed)
	assert_true(GameSession.is_free_play_active)


## A hand-edited or corrupted save claiming free play is active while the
## campaign itself is not marked complete describes a state real play can
## never produce -- set_campaign_victory() flips is_campaign_completed and
## is_free_play_active atomically together (see GameSession), so nothing in
## the real game ever leaves one true and the other false. Import must
## reject that combination rather than silently granting free play to an
## incomplete campaign.
func test_import_rejects_free_play_active_without_campaign_completed() -> void:
	GameSession.reset()
	var data := GameSession.export_campaign_snapshot()
	data.is_free_play_active = true
	data.is_campaign_completed = false

	var result := GameSession.import_campaign_snapshot(data)

	assert_false(result.ok, "An incomplete campaign must never import as free play")


## export_campaign_snapshot() deliberately never exports the in-progress
## battle context at all (see its own doc comment) -- a save is only ever
## possible while has_unsettled_battle_loot() is false, so there is never a
## live battle context to round-trip. A party's own not-yet-banked carry, by
## contrast, IS part of the snapshot and must round-trip untouched, never
## folded into gold the way deposit_party_carry() does.
func test_import_never_settles_a_partys_carry_into_the_bank() -> void:
	GameSession.reset()
	GameSession.create_party()
	var party_id: String = GameSession.selected_party_id
	GameSession.set_campaign_victory()
	GameSession.parties[0].carry = {"gold": 37, "gear": {"dagger_iron": 1}, "mana_crystals": {1: 2}, "item_instance_ids": [] as Array[String]}
	var gold_before := GameSession.gold
	var carry_before := GameSession.get_party_carry(party_id)
	var data := GameSession.export_campaign_snapshot()
	GameSession.reset()

	var result := GameSession.import_campaign_snapshot(data)

	assert_true(result.ok, result.get("error", ""))
	assert_eq(GameSession.get_party_carry(party_id), carry_before, "A party's own carry must round-trip untouched")
	assert_eq(GameSession.gold, gold_before, "Import must never bank a party's carry into gold")


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


## Stage 6 Step 2 (decision-ledger.md's "Playtest reset policy"): unlike
## every earlier version bump, this one rejects EVERY prior format (1-3),
## not only versions strictly newer than FORMAT_VERSION -- see FORMAT_
## VERSION's own doc comment. data.version = 3 (this format's own previous
## value, and the exact version _full_snapshot() would have carried before
## this step) is deliberately included alongside a version that never
## existed, to lock that a pre-Stage-6 save is rejected outright rather than
## migrated.
func test_rejects_unknown_version() -> void:
	var data := _full_snapshot().to_dictionary()
	data.version = 99

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)


func test_rejects_a_pre_stage_6_format_version() -> void:
	var data := _full_snapshot().to_dictionary()
	data.version = 3

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)


## Task-list item 4 (Stage 5 Step 2, docs/designs/intelligence.md): format
## version 3 adds GameSession.encounter_intel/quests/watchtower_level/
## quest_posting_blocked_until_turn. A round trip through to_dictionary() ->
## from_dictionary() must preserve every field exactly, including the
## quest's own back-link to the encounter_intel record that named it.
func test_to_dictionary_and_from_dictionary_round_trip_intelligence_and_quest_state() -> void:
	var snapshot := _full_snapshot()
	snapshot.encounter_intel = {
		"goblin_camp": {"discovered": true, "known_tier": 2, "quest_id": "quest_001"},
		"obj_tier1_1_goblin_outpost": {"discovered": true, "known_tier": 0, "quest_id": ""},
	}
	snapshot.quests = {
		"quest_001": {
			"id": "quest_001",
			"encounter_id": "goblin_camp",
			"tier": 1,
			"status": "active",
			"posted_turn": 1,
			"accepted_turn": 2,
			"expires_turn": 12,
			"reward_gold": 10,
		},
	}
	snapshot.quest_posting_blocked_until_turn = 30
	snapshot.watchtower_level = 2

	var data := snapshot.to_dictionary()
	var result := CampaignSnapshot.from_dictionary(data)

	assert_true(result.ok, result.error)
	assert_eq(result.snapshot.encounter_intel, snapshot.encounter_intel)
	assert_eq(result.snapshot.quests, snapshot.quests)
	assert_eq(result.snapshot.quest_posting_blocked_until_turn, 30)
	assert_eq(result.snapshot.watchtower_level, 2)


## Stage 6 Step 2 (decision-ledger.md PartyCarry contract): negative gold,
## a non-Dictionary gear/mana_crystals, or a non-Array item_instance_ids
## describes a carry record real play can never produce (GameSession's own
## carry mutators only ever add non-negative counts) -- CampaignSnapshot must
## reject it rather than silently accept a hand-edited or corrupted save.
func test_rejects_a_party_with_negative_carry_gold() -> void:
	var snapshot := _full_snapshot()
	snapshot.parties[0].carry.gold = -1
	var data := snapshot.to_dictionary()

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)
	assert_eq(result.snapshot, {}, "A rejected import returns no partial snapshot")


func test_rejects_a_party_with_a_non_dictionary_carry_gear() -> void:
	var snapshot := _full_snapshot()
	snapshot.parties[0].carry.gear = "not a dictionary"
	var data := snapshot.to_dictionary()

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)


func test_rejects_a_party_with_a_non_array_carry_item_instance_ids() -> void:
	var snapshot := _full_snapshot()
	snapshot.parties[0].carry.item_instance_ids = "not an array"
	var data := snapshot.to_dictionary()

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)


## Transactional import: a malformed party carry record must reject the
## entire payload without ever assigning it into a live GameSession, mirroring
## test_import_rejects_a_malformed_encounter_intel_entry_without_mutating_the_
## live_session() below.
func test_import_rejects_a_malformed_party_carry_without_mutating_the_live_session() -> void:
	GameSession.reset()
	GameSession.create_party()
	var before := GameSession.export_campaign_snapshot()

	var snapshot := GameSession.export_campaign_snapshot()
	snapshot.parties[0].carry.gold = -5

	var result := GameSession.import_campaign_snapshot(snapshot)

	assert_false(result.ok)
	assert_eq(GameSession.export_campaign_snapshot(), before)


func test_rejects_an_encounter_intel_entry_with_an_out_of_range_known_tier() -> void:
	var snapshot := _full_snapshot()
	snapshot.encounter_intel = {"goblin_camp": {"discovered": true, "known_tier": 5, "quest_id": ""}}
	var data := snapshot.to_dictionary()

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)
	assert_eq(result.snapshot, {}, "A rejected import returns no partial snapshot")


## Transactional import: a malformed encounter_intel entry must reject the
## entire payload without ever assigning it into a live GameSession, mirroring
## the existing owned_item_instances/mp_current rejection tests elsewhere in
## this file. Exercised at the GameSession level (not just CampaignSnapshot's
## own from_dictionary()) since that is the boundary the "never partially
## lands" guarantee actually protects.
func test_import_rejects_a_malformed_encounter_intel_entry_without_mutating_the_live_session() -> void:
	GameSession.reset()
	var before := GameSession.export_campaign_snapshot()

	var snapshot := GameSession.export_campaign_snapshot()
	snapshot.encounter_intel.goblin_camp.known_tier = "not an int"

	var result := GameSession.import_campaign_snapshot(snapshot)

	assert_false(result.ok)
	assert_eq(GameSession.export_campaign_snapshot(), before)


func test_rejects_an_encounter_intel_entry_referencing_an_unknown_quest_id() -> void:
	var snapshot := _full_snapshot()
	snapshot.encounter_intel = {"goblin_camp": {"discovered": true, "known_tier": 1, "quest_id": "ghost_quest"}}
	var data := snapshot.to_dictionary()

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)


func test_rejects_a_quest_that_does_not_reference_an_encounter_id_with_a_matching_intel_record() -> void:
	var snapshot := _full_snapshot()
	snapshot.quests = {
		"quest_001": {
			"id": "quest_001",
			"encounter_id": "goblin_camp",
			"tier": 1,
			"status": "posted",
			"posted_turn": 1,
			"accepted_turn": -1,
			"expires_turn": -1,
			"reward_gold": 10,
		},
	}
	# No matching encounter_intel entry with quest_id == "quest_001" -- the
	# quest's own back-link is left dangling.
	var data := snapshot.to_dictionary()

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)


func test_rejects_an_out_of_range_watchtower_level() -> void:
	var snapshot := _full_snapshot()
	snapshot.watchtower_level = 4
	var data := snapshot.to_dictionary()

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)


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


## Knight specialization (Stage 5 D4, decision-ledger.md): a promoted
## record's "specialization" field gates which extra perk ids validate --
## see _validate_specialization_field()/_validate_perks_field() in
## campaign_snapshot.gd.

func test_a_knight_perk_validates_only_alongside_the_matching_specialization_field() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [
		{
			"id": "warrior_001", "name": "Warrior", "class": "warrior", "level": 6,
			"specialization": "knight",
			"stats": {"melee": 60, "missile": 60, "guard": 0, "might": 0, "vitality": 10, "max_health": 60},
			"progression": {
				"xp": 200.0,
				# Stage 6 Step 4 (G3): Shield Bash requires "knight_discipline"
				# first and is mutually exclusive with Chain Blow -- this test's
				# own concern is the "specialization" field, not the DAG, so it
				# uses a legally reachable graph (Discipline then one branch)
				# rather than both halves of the exclusive pair. See
				# test_campaign_snapshot.gd's own dedicated DAG-rejection test
				# for the adversarial "both branches" case.
				"perks": ["warrior_juggernaut", "warrior_bulwark", "knight_discipline", "knight_shield_bash"],
			},
		},
	]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_true(result.ok, result.error)
	assert_eq(result.snapshot.adventurers[0].specialization, "knight")
	assert_eq(
		result.snapshot.adventurers[0].progression.perks,
		["warrior_juggernaut", "warrior_bulwark", "knight_discipline", "knight_shield_bash"]
	)


## Stage 6 Step 4 (task 7, G3): the adversarial case task 7 exists for -- a
## hand-edited or corrupted save claiming BOTH halves of Knight's mutually
## exclusive Shield Bash/Chain Blow pair. Both ids individually pass
## ownership (each is a real "knight_*" perk), so only PerkCatalog's own DAG/
## mutual-exclusion check (is_valid_perk_graph(), wired into _validate_perks_
## field()) can catch this -- a player must never be able to end up with
## both branches by hand-editing a save.
func test_import_rejects_a_saved_perk_list_containing_both_halves_of_a_mutually_exclusive_pair() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [
		{
			"id": "warrior_001", "name": "Warrior", "class": "warrior", "level": 8,
			"specialization": "knight",
			"stats": {"melee": 60, "missile": 60, "guard": 0, "might": 0, "vitality": 10, "max_health": 60},
			"progression": {
				"xp": 350.0,
				"perks": [
					"warrior_juggernaut", "warrior_bulwark", "knight_discipline",
					"knight_shield_bash", "knight_chain_blow",
				],
			},
		},
	]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok, "A saved perk list claiming both mutually exclusive branches must be rejected")
	assert_string_contains(result.error, "warrior_001")


## The same adversarial case, but missing Discipline entirely -- Shield Bash
## chosen with its own prerequisite never satisfied. Individually a real
## "knight_*" id owned by the Knight specialization, so again only the DAG
## check (not ordinary ownership) can catch it.
func test_import_rejects_a_saved_perk_missing_its_own_prerequisite() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [
		{
			"id": "warrior_001", "name": "Warrior", "class": "warrior", "level": 8,
			"specialization": "knight",
			"stats": {"melee": 60, "missile": 60, "guard": 0, "might": 0, "vitality": 10, "max_health": 60},
			"progression": {
				"xp": 350.0,
				"perks": ["warrior_juggernaut", "warrior_bulwark", "knight_shield_bash"],
			},
		},
	]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok, "Shield Bash without its own Discipline prerequisite must be rejected")


## Archer's own validation (Stage 5 D4): mirrors the Knight test immediately
## above exactly -- _validate_specialization_field()/_validate_perks_field()
## are a general mechanism, not Knight-specific.
func test_an_archer_perk_validates_only_alongside_the_matching_specialization_field() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [
		{
			"id": "warrior_001", "name": "Warrior", "class": "warrior", "level": 6,
			"specialization": "archer",
			"stats": {"melee": 60, "missile": 60, "guard": 0, "might": 0, "vitality": 10, "max_health": 60},
			"progression": {
				"xp": 200.0,
				"perks": ["warrior_juggernaut", "warrior_bulwark", "archer_lock_on", "archer_called_shot"],
			},
		},
	]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_true(result.ok, result.error)
	assert_eq(result.snapshot.adventurers[0].specialization, "archer")
	assert_eq(
		result.snapshot.adventurers[0].progression.perks,
		["warrior_juggernaut", "warrior_bulwark", "archer_lock_on", "archer_called_shot"]
	)


## Battle Mage's own validation (Stage 5 D4): mirrors the Knight/Archer tests
## above exactly, proving the general mechanism also holds for a root class
## (Mage) with an EMPTY CLASS_PERKS entry and a specialization with only ONE
## perk instead of two.
func test_a_battle_mage_perk_validates_only_alongside_the_matching_specialization_field() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [
		{
			"id": "mage_001", "name": "Mage", "class": "mage", "level": 2,
			"specialization": "battle_mage",
			"stats": {"missile": 25, "spellcasting": 20, "vitality": 8, "max_health": 8},
			"progression": {"xp": 20.0, "perks": ["battle_mage_temporary_guard"]},
		},
	]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_true(result.ok, result.error)
	assert_eq(result.snapshot.adventurers[0].specialization, "battle_mage")
	assert_eq(result.snapshot.adventurers[0].progression.perks, ["battle_mage_temporary_guard"])


## Paladin's own validation (Stage 5 D4): mirrors the Knight/Archer/Battle
## Mage tests above, but with a record that keeps its ROOT perks (Cleric's
## own CLASS_PERKS is non-empty, unlike Mage's) while carrying ZERO
## specialization perks of its own at all -- SPECIALIZATION_PERKS has no
## "paladin" entry, since Paladin's whole ability is keyed to caster
## identity, not a perk-tree choice. This is the real test of whether
## _validate_perks_field()/_validate_specialization_field() are truly
## generic for a zero-perk specialization: Battle Mage above still had ONE
## perk, Knight/Archer had two -- Paladin has none.
func test_a_paladin_record_validates_cleanly_with_its_root_perks_and_zero_specialization_perks() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [
		{
			"id": "cleric_001", "name": "Cleric", "class": "cleric", "level": 6,
			"specialization": "paladin",
			"stats": {"melee": 45, "missile": 30, "guard": 10, "might": 1, "vitality": 12, "max_health": 12},
			"progression": {"xp": 200.0, "perks": ["cleric_meditation", "cleric_devout"]},
		},
	]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_true(result.ok, result.error)
	assert_eq(result.snapshot.adventurers[0].specialization, "paladin")
	assert_eq(result.snapshot.adventurers[0].progression.perks, ["cleric_meditation", "cleric_devout"])


## Regression: a Paladin record that ALSO tries to claim a perk id foreign to
## both Cleric's own CLASS_PERKS and SPECIALIZATION_PERKS.get("paladin", [])
## (empty) must still be rejected atomically, exactly like every other
## specialization's own foreign-perk rejection -- proving the empty Paladin
## entry doesn't accidentally widen validation into accepting anything.
func test_a_perk_foreign_to_paladin_is_rejected_atomically_even_though_paladin_has_no_perks_of_its_own() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [
		{
			"id": "cleric_001", "name": "Cleric", "class": "cleric", "level": 6,
			"specialization": "paladin",
			"stats": {"melee": 45, "missile": 30, "guard": 10, "might": 1, "vitality": 12, "max_health": 12},
			"progression": {"xp": 200.0, "perks": ["cleric_meditation", "cleric_devout", "knight_shield_bash"]},
		},
	]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok, "A Knight perk on a Paladin record must be rejected -- Paladin grants no perks of its own")
	assert_eq(result.snapshot, {})


func test_a_knight_perk_without_the_specialization_field_is_rejected_atomically() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [
		{
			"id": "warrior_001", "name": "Warrior", "class": "warrior", "level": 6,
			"stats": {"melee": 60, "missile": 60, "guard": 0, "might": 0, "vitality": 10, "max_health": 60},
			"progression": {"xp": 200.0, "perks": ["knight_shield_bash"]},
		},
	]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok, "A Knight perk on a never-promoted record must be rejected")
	assert_eq(result.snapshot, {})


func test_an_unknown_specialization_id_is_rejected_atomically() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [
		{
			"id": "warrior_001", "name": "Warrior", "class": "warrior", "level": 6,
			"specialization": "not_a_real_specialization",
			"stats": {"melee": 60, "missile": 60, "guard": 0, "might": 0, "vitality": 10, "max_health": 60},
			"progression": {"xp": 200.0, "perks": []},
		},
	]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)
	assert_eq(result.snapshot, {})


func test_a_specialization_with_a_mismatched_root_class_is_rejected_atomically() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [
		{
			"id": "scout_test", "name": "Scout", "class": "scout", "level": 6,
			"specialization": "knight",
			"stats": {"melee": 60, "missile": 60, "guard": 0, "might": 0, "vitality": 10, "max_health": 60},
			"progression": {"xp": 200.0, "perks": []},
		},
	]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok, "Knight requires root class warrior, not scout")
	assert_eq(result.snapshot, {})


## A save with no "specialization" field at all (every pre-Stage-5-D4 save)
## must import cleanly as not promoted, not a partial/corrupt state -- the
## field is simply absent from the normalized record, exactly like every
## other optional field this file's other tests already cover (mp_current,
## temple_level, etc.).
func test_a_record_with_no_specialization_field_imports_cleanly_as_not_promoted() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [
		{
			"id": "warrior_001", "name": "Warrior", "class": "warrior", "level": 1,
			"stats": {"melee": 60, "missile": 60, "guard": 0, "might": 0, "vitality": 10, "max_health": 10},
			"progression": {"xp": 0.0, "perks": []},
		},
	]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_true(result.ok, result.error)
	assert_false(result.snapshot.adventurers[0].has("specialization"))


## Durable Cleric MP (docs/plans/2026-08-21-stage-2-party-readiness/
## 03-persistent-mp-temple-and-details-healing.md): "mp_current" round-trips
## like health, a missing field migrates to full, and an invalid shape/range
## rejects the whole import atomically -- the same two-pass normalize-then-
## validate pattern the perks tests above exercise for progression.perks.

func test_a_clerics_current_and_max_mp_round_trip() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [
		{
			"id": "cleric_001", "name": "Cleric", "class": "cleric", "level": 1, "health": 12, "mp_current": 1,
			"stats": {"melee": 45, "guard": 10, "might": 1, "spellcasting": 55, "vitality": 12, "max_health": 12},
			"progression": {"xp": 0.0, "perks": []},
		},
	]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_true(result.ok, result.error)
	var adv: Dictionary = result.snapshot.adventurers[0]
	assert_eq(adv.mp_current, 1)
	assert_eq(GameSession.CLASS_DEFINITIONS.cleric.mp_max, 3, "max MP is the class's fixed mp_max, not a stored field")


## Same round trip through the real production import path.
func test_import_campaign_snapshot_preserves_a_clerics_current_mp() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [
		{
			"id": "cleric_001", "name": "Cleric", "class": "cleric", "level": 1, "health": 12, "mp_current": 2,
			"stats": {"melee": 45, "guard": 10, "might": 1, "spellcasting": 55, "vitality": 12, "max_health": 12},
			"progression": {"xp": 0.0, "perks": []},
		},
	]
	data.selected_party_id = ""
	data.parties = []

	var result := GameSession.import_campaign_snapshot(data)

	assert_true(result.ok, result.error)
	assert_eq(GameSession.get_current_mp("cleric_001"), 2)


## docs/designs/campaign-loop.md: "A save with no mp_current field migrates
## it to full."
func test_a_cleric_record_missing_mp_current_migrates_to_full_mp() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [
		{
			"id": "cleric_001", "name": "Cleric", "class": "cleric", "level": 1, "health": 12,
			"stats": {"melee": 45, "guard": 10, "might": 1, "spellcasting": 55, "vitality": 12, "max_health": 12},
			"progression": {"xp": 0.0, "perks": []},
		},
	]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_true(result.ok, result.error)
	assert_eq(result.snapshot.adventurers[0].mp_current, 3, "Missing mp_current migrates to full (mp_max)")


## A Warrior/Scout record never gains a synthesized "mp_current" field --
## only a class that actually carries an mp_max (Cleric today) does.
func test_a_warrior_record_never_gains_a_synthesized_mp_current_field() -> void:
	var data := _full_snapshot().to_dictionary()

	var result := CampaignSnapshot.from_dictionary(data)

	assert_true(result.ok, result.error)
	for adv in result.snapshot.adventurers:
		assert_false((adv as Dictionary).has("mp_current"), "A class-less/Warrior record must never gain mp_current")


func test_rejects_a_non_int_mp_current_without_mutating_the_existing_session() -> void:
	GameSession.reset()
	var starting_adventurers: Array = GameSession.adventurers.duplicate(true)
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [
		{
			"id": "cleric_001", "name": "Cleric", "class": "cleric", "level": 1, "health": 12, "mp_current": "two",
			"stats": {"melee": 45, "guard": 10, "might": 1, "spellcasting": 55, "vitality": 12, "max_health": 12},
			"progression": {"xp": 0.0, "perks": []},
		},
	]
	data.selected_party_id = ""
	data.parties = []

	var result := GameSession.import_campaign_snapshot(data)

	assert_false(result.ok, "A non-int mp_current must reject the whole import")
	assert_eq(GameSession.adventurers, starting_adventurers, "A rejected import must never mutate the live session")


func test_rejects_an_out_of_range_mp_current_without_mutating_the_existing_session() -> void:
	GameSession.reset()
	var starting_adventurers: Array = GameSession.adventurers.duplicate(true)
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [
		{
			"id": "cleric_001", "name": "Cleric", "class": "cleric", "level": 1, "health": 12, "mp_current": 999,
			"stats": {"melee": 45, "guard": 10, "might": 1, "spellcasting": 55, "vitality": 12, "max_health": 12},
			"progression": {"xp": 0.0, "perks": []},
		},
	]
	data.selected_party_id = ""
	data.parties = []

	var result := GameSession.import_campaign_snapshot(data)

	assert_false(result.ok, "An mp_current above the class's mp_max must reject the whole import")
	assert_eq(GameSession.adventurers, starting_adventurers, "A rejected import must never mutate the live session")


func test_rejects_a_negative_mp_current() -> void:
	var data := _full_snapshot().to_dictionary()
	data.adventurers = [
		{
			"id": "cleric_001", "name": "Cleric", "class": "cleric", "level": 1, "health": 12, "mp_current": -1,
			"stats": {"melee": 45, "guard": 10, "might": 1, "spellcasting": 55, "vitality": 12, "max_health": 12},
			"progression": {"xp": 0.0, "perks": []},
		},
	]

	var result := CampaignSnapshot.from_dictionary(data)

	assert_false(result.ok)
	assert_eq(result.snapshot, {})


func test_missing_journal_entries_normalizes_to_empty_array() -> void:
	var data := _full_snapshot().to_dictionary()
	data.erase("journal_entries")

	var result := CampaignSnapshot.from_dictionary(data)
	assert_true(result.ok, result.error)
	assert_eq(result.snapshot.journal_entries, [])


func test_rejects_non_array_journal_entries() -> void:
	var data := _full_snapshot().to_dictionary()
	data.journal_entries = "not_an_array"
	var result := CampaignSnapshot.from_dictionary(data)
	assert_false(result.ok)
	assert_eq(result.snapshot, {})
	assert_eq(result.error, "journal_entries is not an array")


func test_rejects_non_dictionary_journal_entry() -> void:
	var data := _full_snapshot().to_dictionary()
	data.journal_entries = ["not_a_dict"]
	var result := CampaignSnapshot.from_dictionary(data)
	assert_false(result.ok)
	assert_eq(result.snapshot, {})
	assert_eq(result.error, "journal_entries contains a non-dictionary entry")


func test_rejects_journal_entry_with_invalid_id() -> void:
	var data := _full_snapshot().to_dictionary()
	data.journal_entries = [
		{"id": "", "sequence": 1, "section": "log", "kind": "discovery", "title_key": "k", "detail": {}, "read": false}
	]
	var result := CampaignSnapshot.from_dictionary(data)
	assert_false(result.ok)
	assert_eq(result.snapshot, {})
	assert_eq(result.error, "journal_entries contains an entry with an invalid id")


func test_rejects_journal_entries_with_duplicate_id() -> void:
	var data := _full_snapshot().to_dictionary()
	data.journal_entries = [
		{"id": "entry-1", "sequence": 1, "section": "log", "kind": "discovery", "title_key": "k1", "detail": {}, "read": false},
		{"id": "entry-1", "sequence": 2, "section": "log", "kind": "battle", "title_key": "k2", "detail": {}, "read": false},
	]
	var result := CampaignSnapshot.from_dictionary(data)
	assert_false(result.ok)
	assert_eq(result.snapshot, {})
	assert_eq(result.error, "journal_entries contains a duplicate id: entry-1")


func test_rejects_journal_entry_with_invalid_sequence() -> void:
	var data := _full_snapshot().to_dictionary()
	data.journal_entries = [
		{"id": "entry-1", "sequence": "one", "section": "log", "kind": "discovery", "title_key": "k", "detail": {}, "read": false}
	]
	var result := CampaignSnapshot.from_dictionary(data)
	assert_false(result.ok)
	assert_eq(result.snapshot, {})
	assert_eq(result.error, "journal_entry entry-1 has an invalid sequence")


func test_rejects_journal_entry_with_invalid_section() -> void:
	var data := _full_snapshot().to_dictionary()
	data.journal_entries = [
		{"id": "entry-1", "sequence": 1, "section": "invalid_section", "kind": "discovery", "title_key": "k", "detail": {}, "read": false}
	]
	var result := CampaignSnapshot.from_dictionary(data)
	assert_false(result.ok)
	assert_eq(result.snapshot, {})
	assert_eq(result.error, "journal_entry entry-1 has an invalid section: invalid_section")


func test_rejects_journal_entry_with_invalid_kind() -> void:
	var data := _full_snapshot().to_dictionary()
	data.journal_entries = [
		{"id": "entry-1", "sequence": 1, "section": "log", "kind": "", "title_key": "k", "detail": {}, "read": false}
	]
	var result := CampaignSnapshot.from_dictionary(data)
	assert_false(result.ok)
	assert_eq(result.snapshot, {})
	assert_eq(result.error, "journal_entry entry-1 has an invalid kind")


func test_rejects_journal_entry_with_invalid_title_key() -> void:
	var data := _full_snapshot().to_dictionary()
	data.journal_entries = [
		{"id": "entry-1", "sequence": 1, "section": "log", "kind": "discovery", "title_key": "", "detail": {}, "read": false}
	]
	var result := CampaignSnapshot.from_dictionary(data)
	assert_false(result.ok)
	assert_eq(result.snapshot, {})
	assert_eq(result.error, "journal_entry entry-1 has an invalid title_key")


func test_rejects_journal_entry_with_invalid_detail() -> void:
	var data := _full_snapshot().to_dictionary()
	data.journal_entries = [
		{"id": "entry-1", "sequence": 1, "section": "log", "kind": "discovery", "title_key": "k", "detail": "not_dict", "read": false}
	]
	var result := CampaignSnapshot.from_dictionary(data)
	assert_false(result.ok)
	assert_eq(result.snapshot, {})
	assert_eq(result.error, "journal_entry entry-1 has an invalid detail")


func test_rejects_journal_entry_with_invalid_read() -> void:
	var data := _full_snapshot().to_dictionary()
	data.journal_entries = [
		{"id": "entry-1", "sequence": 1, "section": "log", "kind": "discovery", "title_key": "k", "detail": {}, "read": "false"}
	]
	var result := CampaignSnapshot.from_dictionary(data)
	assert_false(result.ok)
	assert_eq(result.snapshot, {})
	assert_eq(result.error, "journal_entry entry-1 has an invalid read flag")


func test_game_session_journal_entries_round_trip_and_rejection_isolation() -> void:
	GameSession.reset()
	var id_1: String = GameSession.append_journal_entry("discovery", "title.1", {"x": 1}, "log")
	var id_2: String = GameSession.append_journal_entry("quest", "title.2", {"y": 2}, "quests")
	GameSession.mark_journal_entry_read(id_1)

	var data := GameSession.export_campaign_snapshot()
	assert_true(data.has("journal_entries"))
	assert_eq((data.journal_entries as Array).size(), 2)

	GameSession.reset()
	assert_eq(GameSession.journal_entries.size(), 0)

	var result := GameSession.import_campaign_snapshot(data)
	assert_true(result.ok, result.get("error", ""))
	assert_eq(GameSession.journal_entries.size(), 2)
	assert_eq(GameSession.journal_entries[0].id, id_1)
	assert_true(GameSession.journal_entries[0].read)
	assert_eq(GameSession.journal_entries[1].id, id_2)
	assert_false(GameSession.journal_entries[1].read)
	assert_eq(GameSession._journal_sequence, 2)

	# Appending next entry continues sequence monotonically
	var id_3: String = GameSession.append_journal_entry("loot", "title.3", {}, "log")
	assert_eq(GameSession.get_journal_entry(id_3).sequence, 3)

	# Malformed snapshot rejects atomically without changing session state
	var malformed_data := data.duplicate(true)
	malformed_data.journal_entries[0].read = "bad"
	var bad_result := GameSession.import_campaign_snapshot(malformed_data)
	assert_false(bad_result.ok)
	assert_eq(GameSession.journal_entries.size(), 3, "Failed import did not alter GameSession state")
