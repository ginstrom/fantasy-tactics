extends Node

const STARTING_SETTLEMENT_ID := "starting_settlement"
const STARTING_SETTLEMENT_WORLD_POSITION := Vector2i(0, 0)
const WARRIOR_ID := "warrior_001"
const DEFAULT_WARRIOR := {
	"id": WARRIOR_ID,
	"name": "Warrior",
	"class": "warrior",
	"weapon": "sword",
}
const FIRST_PARTY_ID := "party_001"

var adventurers: Array[Dictionary] = []
var parties: Array[Dictionary] = []
var selected_party_id: String = ""
var selected_encounter: String = ""
var completed_encounters: Array[String] = []


func _init() -> void:
	reset()


func start_new_game() -> void:
	reset()


func reset() -> void:
	# The roster owns a copy so a session cannot mutate the shared default data.
	adventurers = [DEFAULT_WARRIOR.duplicate(true)]
	parties = []
	selected_party_id = ""
	selected_encounter = ""
	completed_encounters = []


func create_party() -> bool:
	if not parties.is_empty():
		return false

	parties.append({
		"id": FIRST_PARTY_ID,
		"member_ids": [] as Array[String],
		"location_id": STARTING_SETTLEMENT_ID,
		"world_position": STARTING_SETTLEMENT_WORLD_POSITION,
		"deployed": false,
	})
	selected_party_id = FIRST_PARTY_ID
	return true


func get_selected_party() -> Dictionary:
	var party_index := _get_selected_party_index()
	if party_index == -1:
		return {}
	return parties[party_index]


func get_available_adventurers() -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for adventurer in adventurers:
		if not _is_adventurer_assigned(adventurer.id):
			available.append(adventurer)
	return available


func assign_adventurer_to_selected_party(adventurer_id: String) -> bool:
	var party_index := _get_selected_party_index()
	if party_index == -1 or not _has_adventurer(adventurer_id) or _is_adventurer_assigned(adventurer_id):
		return false

	var member_ids: Array = parties[party_index].member_ids
	member_ids.append(adventurer_id)
	return true


func remove_adventurer_from_selected_party(adventurer_id: String) -> bool:
	var party_index := _get_selected_party_index()
	if party_index == -1:
		return false

	var member_ids: Array = parties[party_index].member_ids
	var member_index := member_ids.find(adventurer_id)
	if member_index == -1:
		return false

	member_ids.remove_at(member_index)
	return true


func can_depart_selected_party() -> bool:
	var party := get_selected_party()
	return not party.is_empty() and not party.deployed and not party.member_ids.is_empty()


func depart_selected_party() -> bool:
	if not can_depart_selected_party():
		return false

	var party_index := _get_selected_party_index()
	parties[party_index].deployed = true
	parties[party_index].location_id = STARTING_SETTLEMENT_ID
	parties[party_index].world_position = STARTING_SETTLEMENT_WORLD_POSITION
	return true


func has_deployed_party() -> bool:
	var party := get_selected_party()
	return not party.is_empty() and party.deployed


func get_deployed_party_position() -> Vector2i:
	if not has_deployed_party():
		return STARTING_SETTLEMENT_WORLD_POSITION
	return get_selected_party().world_position


func set_deployed_party_position(position: Vector2i) -> bool:
	if not has_deployed_party():
		return false

	parties[_get_selected_party_index()].world_position = position
	return true


func return_deployed_party_to_settlement() -> bool:
	if not has_deployed_party():
		return false

	var party_index := _get_selected_party_index()
	parties[party_index].deployed = false
	parties[party_index].location_id = STARTING_SETTLEMENT_ID
	parties[party_index].world_position = STARTING_SETTLEMENT_WORLD_POSITION
	return true


func _get_selected_party_index() -> int:
	for party_index in parties.size():
		if parties[party_index].id == selected_party_id:
			return party_index
	return -1


func _has_adventurer(adventurer_id: String) -> bool:
	for adventurer in adventurers:
		if adventurer.id == adventurer_id:
			return true
	return false


func _is_adventurer_assigned(adventurer_id: String) -> bool:
	for party in parties:
		if adventurer_id in party.member_ids:
			return true
	return false


func enter_encounter(encounter_id: String) -> void:
	selected_encounter = encounter_id


func complete_current_encounter() -> void:
	if selected_encounter != "" and not completed_encounters.has(selected_encounter):
		completed_encounters.append(selected_encounter)
	selected_encounter = ""


func is_encounter_complete(encounter_id: String) -> bool:
	return completed_encounters.has(encounter_id)
