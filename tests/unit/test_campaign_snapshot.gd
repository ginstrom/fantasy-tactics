extends GutTest

const CampaignSnapshot := preload("res://scripts/save/campaign_snapshot.gd")


## A fully-populated snapshot covering every durable category: roster,
## recruitment offers/vacancies, a party with a travel route, selected ids,
## world turn, active encounters/completions/vacancies, gold/buildings,
## every battle/pending/banked reward store, player name, and tutorial
## progress.
func _full_snapshot() -> CampaignSnapshot:
	var snapshot := CampaignSnapshot.new()
	snapshot.adventurers = [
		{"id": "warrior_001", "name": "Warrior", "level": 1, "stats": {"attack": 60}},
	]
	snapshot.recruitment_candidates = [
		{"id": "warrior_002", "name": "Warrior 2", "cost": 10},
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


func test_format_version_is_1() -> void:
	assert_eq(CampaignSnapshot.FORMAT_VERSION, 1)


func test_to_dictionary_tags_the_format_version() -> void:
	var data := CampaignSnapshot.new().to_dictionary()
	assert_eq(data.version, 1)


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
	assert_eq(snapshot.completed_encounters, ["orc_outpost"])
	assert_eq(snapshot.active_encounters[0].position, Vector2i(4, 4))
	assert_eq(snapshot.encounter_vacancies, [{"turns_remaining": 8}])
	assert_eq(snapshot.used_encounter_template_ids, ["goblin_camp", "orc_outpost"])
	assert_eq(snapshot.world_turn, 7)
	assert_eq(snapshot.gold, 42)
	assert_eq(snapshot.guild_hall_level, 2)
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
	data.version = 2

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
