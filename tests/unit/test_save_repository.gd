extends GutTest
## Covers SaveRepository (see docs/plans/2026-08-10-initial-campaign-and-
## automation/02-atomic-save-repository.md): atomic writes, distinct
## diagnostic codes for every way a load can fail, and the all-or-nothing
## guarantee that a failed load never touches a prepared GameSession.
##
## Every test points its own repository at TEST_SAVE_PATH -- one unique
## filename under user:// -- rather than the real campaign-save.json, and
## before/after_each remove only that exact path (plus its ".tmp" sibling)
## so no test can leak state into another test or into a real save.

const SaveRepositoryScript := preload("res://scripts/save/save_repository.gd")
const GameSessionScript := preload("res://scripts/autoload/game_session.gd")
const TEST_SAVE_PATH := "user://test_save_repository_campaign.json"
const TEST_TMP_PATH := "user://test_save_repository_campaign.json.tmp"


func before_each() -> void:
	_remove_if_exists(TEST_SAVE_PATH)
	_remove_if_exists(TEST_TMP_PATH)


func after_each() -> void:
	_remove_if_exists(TEST_SAVE_PATH)
	_remove_if_exists(TEST_TMP_PATH)


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _repository() -> SaveRepositoryScript:
	return SaveRepositoryScript.new(TEST_SAVE_PATH)


func _populated_session() -> Node:
	var session: Node = GameSessionScript.new()
	autofree(session)
	session.world_turn = 9
	session.gold = 42
	session.create_party()
	session.parties[0].carry.mana_crystals = {1: 3, 2: 1}
	return session


## --- Test-injectable exact path -----------------------------------------


func test_repository_uses_the_injected_path_not_the_real_save_file() -> void:
	var repository := _repository()

	assert_eq(repository.save_path, TEST_SAVE_PATH)
	assert_ne(repository.save_path, SaveRepositoryScript.DEFAULT_SAVE_PATH)


## --- Atomic write ---------------------------------------------------------


func test_first_write_produces_a_file_that_parses_as_json() -> void:
	var repository := _repository()
	var session := _populated_session()

	var result := repository.save_campaign(session)

	assert_true(result.ok, result.get("error", ""))
	assert_true(FileAccess.file_exists(TEST_SAVE_PATH))
	var json := JSON.new()
	assert_eq(json.parse(FileAccess.get_file_as_string(TEST_SAVE_PATH)), OK)
	assert_eq(typeof(json.data), TYPE_DICTIONARY)


func test_second_write_replaces_the_file_instead_of_appending() -> void:
	var repository := _repository()
	var first_session := _populated_session()
	var second_session := _populated_session()
	second_session.world_turn = 55
	second_session.gold = 7

	repository.save_campaign(first_session)
	repository.save_campaign(second_session)

	var text := FileAccess.get_file_as_string(TEST_SAVE_PATH)
	var json := JSON.new()
	assert_eq(json.parse(text), OK, "The file must remain valid single-document JSON, not two documents concatenated")
	assert_eq(json.data.world_turn, 55)
	assert_eq(json.data.gold, 7)


func test_successful_write_leaves_no_temp_file_behind() -> void:
	var repository := _repository()

	repository.save_campaign(_populated_session())

	assert_false(FileAccess.file_exists(TEST_TMP_PATH))


## --- Distinct diagnostic codes for read failures --------------------------


func test_has_valid_save_is_false_when_no_file_exists() -> void:
	var repository := _repository()

	assert_false(repository.has_valid_save())


func test_load_reports_absent_status_when_no_file_exists() -> void:
	var repository := _repository()

	var result := repository.load_campaign(_populated_session())

	assert_false(result.ok)
	assert_eq(result.status, SaveRepositoryScript.LoadStatus.ABSENT)


func test_load_reports_corrupt_status_for_unparseable_json() -> void:
	var repository := _repository()
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string("{not valid json")
	file.close()

	var result := repository.load_campaign(_populated_session())

	assert_false(result.ok)
	assert_eq(result.status, SaveRepositoryScript.LoadStatus.CORRUPT)


func test_load_reports_wrong_envelope_status_for_valid_json_that_is_not_an_object() -> void:
	var repository := _repository()
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(["not", "an", "object"]))
	file.close()

	var result := repository.load_campaign(_populated_session())

	assert_false(result.ok)
	assert_eq(result.status, SaveRepositoryScript.LoadStatus.WRONG_ENVELOPE)


func test_load_reports_invalid_snapshot_status_for_an_object_that_fails_snapshot_validation() -> void:
	var repository := _repository()
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 999, "not": "a real snapshot"}))
	file.close()

	var result := repository.load_campaign(_populated_session())

	assert_false(result.ok)
	assert_eq(result.status, SaveRepositoryScript.LoadStatus.INVALID_SNAPSHOT)


func test_load_reports_ok_status_for_a_real_save() -> void:
	var repository := _repository()
	repository.save_campaign(_populated_session())

	var result := repository.load_campaign(_populated_session())

	assert_true(result.ok, result.get("error", ""))
	assert_eq(result.status, SaveRepositoryScript.LoadStatus.OK)


## --- has_valid_save() validates both envelope and snapshot ----------------


func test_has_valid_save_is_false_for_corrupt_json() -> void:
	var repository := _repository()
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string("{not valid json")
	file.close()

	assert_false(repository.has_valid_save())


func test_has_valid_save_is_false_for_a_wrong_envelope() -> void:
	var repository := _repository()
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(["not", "an", "object"]))
	file.close()

	assert_false(repository.has_valid_save())


func test_has_valid_save_is_false_for_a_well_formed_object_with_an_invalid_snapshot() -> void:
	var repository := _repository()
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 999}))
	file.close()

	assert_false(repository.has_valid_save())


func test_has_valid_save_is_true_for_a_real_save() -> void:
	var repository := _repository()
	repository.save_campaign(_populated_session())

	assert_true(repository.has_valid_save())


## --- A failed load never imports or changes a prepared GameSession -------


func test_failed_load_does_not_mutate_a_prepared_session_when_the_file_is_absent() -> void:
	var repository := _repository()
	var session := _populated_session()

	var result := repository.load_campaign(session)

	assert_false(result.ok)
	assert_eq(session.world_turn, 9)
	assert_eq(session.gold, 42)
	assert_eq(session.get_party_carry(session.parties[0].id).mana_crystals, {1: 3, 2: 1})


func test_failed_load_does_not_mutate_a_prepared_session_when_the_file_is_corrupt() -> void:
	var repository := _repository()
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string("{not valid json")
	file.close()
	var session := _populated_session()

	var result := repository.load_campaign(session)

	assert_false(result.ok)
	assert_eq(session.world_turn, 9)
	assert_eq(session.gold, 42)


func test_failed_load_does_not_mutate_a_prepared_session_when_the_snapshot_is_invalid() -> void:
	var repository := _repository()
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 999}))
	file.close()
	var session := _populated_session()

	var result := repository.load_campaign(session)

	assert_false(result.ok)
	assert_eq(session.world_turn, 9)
	assert_eq(session.gold, 42)


## --- Real round trip: JSON's lossy int/key conversions are undone --------


func test_round_trip_preserves_int_valued_numeric_fields() -> void:
	var repository := _repository()
	var written_session := _populated_session()

	repository.save_campaign(written_session)
	var loaded_session: Node = GameSessionScript.new()
	autofree(loaded_session)
	var result := repository.load_campaign(loaded_session)

	assert_true(result.ok, result.get("error", ""))
	assert_eq(loaded_session.world_turn, 9)
	assert_true(typeof(loaded_session.world_turn) == TYPE_INT)
	assert_eq(loaded_session.gold, 42)
	assert_true(typeof(loaded_session.gold) == TYPE_INT)


func test_round_trip_preserves_int_keyed_mana_crystal_tiers() -> void:
	var repository := _repository()
	var written_session := _populated_session()
	written_session.mana_crystals = {3: 4}

	repository.save_campaign(written_session)
	var loaded_session: Node = GameSessionScript.new()
	autofree(loaded_session)
	var result := repository.load_campaign(loaded_session)

	assert_true(result.ok, result.get("error", ""))
	var carry: Dictionary = loaded_session.get_party_carry(loaded_session.parties[0].id)
	assert_eq(carry.mana_crystals, {1: 3, 2: 1})
	assert_eq(
		carry.mana_crystals.get(1, 0), 3,
		"An int-keyed lookup must work after a real JSON round trip, not just a plain dictionary equality check"
	)
	assert_eq(loaded_session.mana_crystals, {3: 4})
	assert_eq(loaded_session.mana_crystals.get(3, 0), 4)


func test_round_trip_preserves_numeric_only_tutorial_ids_as_string_keys() -> void:
	var repository := _repository()
	var written_session := _populated_session()
	written_session.tutorial_progress = {"101": true}

	repository.save_campaign(written_session)
	var loaded_session: Node = GameSessionScript.new()
	autofree(loaded_session)
	var result := repository.load_campaign(loaded_session)

	assert_true(result.ok, result.get("error", ""))
	assert_true(loaded_session.tutorial_progress.has("101"))
	assert_false(loaded_session.tutorial_progress.has(101))
	assert_true(typeof(loaded_session.tutorial_progress.keys()[0]) == TYPE_STRING)


func test_load_rejects_a_non_numeric_crystal_tier_without_mutating_the_target_session() -> void:
	var repository := _repository()
	var invalid_session := _populated_session()
	invalid_session.mana_crystals = {"tier_one": 3}
	assert_true(repository.save_campaign(invalid_session).ok)
	var target_session := _populated_session()
	var before: Dictionary = target_session.export_campaign_snapshot()

	var result := repository.load_campaign(target_session)

	assert_false(result.ok)
	assert_eq(result.status, SaveRepositoryScript.LoadStatus.INVALID_SNAPSHOT)
	assert_string_contains(result.error, "mana_crystals contains a non-integer tier")
	assert_eq(target_session.export_campaign_snapshot(), before)


## The highest-risk conversion path in the save format: a party's
## travel_route is an Array[{"x": int, "y": int}] on disk, standing in for
## Array[Vector2i] -- a doubly-nested structure (Array of Dictionaries of
## ints) that has to survive both CampaignSnapshot's Vector2i <-> Dictionary
## conversion and JSON.stringify()/parse()'s float-for-every-number lossiness
## (see SaveRepository._normalize_json_value()) through an actual file, not
## just an in-memory to_dictionary()/from_dictionary() round trip.
func test_round_trip_preserves_a_non_empty_travel_route_through_a_real_file() -> void:
	var repository := _repository()
	var written_session: Node = GameSessionScript.new()
	autofree(written_session)
	written_session.create_party()
	written_session.assign_adventurer_to_selected_party(GameSessionScript.WARRIOR_ID)
	written_session.depart_selected_party()
	written_session.set_deployed_party_position(Vector2i(3, 3))
	written_session.set_deployed_party_route([Vector2i(4, 3), Vector2i(4, 4), Vector2i(5, 4)] as Array[Vector2i])

	repository.save_campaign(written_session)
	var loaded_session: Node = GameSessionScript.new()
	autofree(loaded_session)
	var result := repository.load_campaign(loaded_session)

	assert_true(result.ok, result.get("error", ""))
	var loaded_party: Dictionary = loaded_session.get_selected_party()
	assert_eq(loaded_party.travel_route, [Vector2i(4, 3), Vector2i(4, 4), Vector2i(5, 4)])
	for step in loaded_party.travel_route:
		assert_true(step is Vector2i, "Each restored travel_route step must be a real Vector2i, not a leftover {x, y} dict")


func test_load_campaign_imports_into_the_given_session_on_success() -> void:
	var repository := _repository()
	repository.save_campaign(_populated_session())
	var loaded_session: Node = GameSessionScript.new()
	autofree(loaded_session)
	loaded_session.world_turn = 1
	loaded_session.gold = 0

	var result := repository.load_campaign(loaded_session)

	assert_true(result.ok, result.get("error", ""))
	assert_eq(loaded_session.world_turn, 9)
	assert_eq(loaded_session.gold, 42)
