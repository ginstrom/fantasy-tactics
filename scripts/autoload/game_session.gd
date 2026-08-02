extends Node

const DEFAULT_PARTY: Array[String] = ["hero"]
const DEFAULT_LOCATION := "starting_village"
const DEFAULT_PARTY_POSITION := Vector2i(0, 0)

var party: Array[String] = []
var current_location: String = ""
var selected_encounter: String = ""
var completed_encounters: Array[String] = []
var party_position: Vector2i = DEFAULT_PARTY_POSITION


func _init() -> void:
	reset()


func start_new_game() -> void:
	reset()


func reset() -> void:
	# Duplicate so mutating a session's party never mutates the shared constant.
	party = DEFAULT_PARTY.duplicate()
	current_location = DEFAULT_LOCATION
	selected_encounter = ""
	completed_encounters = []
	party_position = DEFAULT_PARTY_POSITION


func enter_encounter(encounter_id: String) -> void:
	selected_encounter = encounter_id


func complete_current_encounter() -> void:
	if selected_encounter != "" and not completed_encounters.has(selected_encounter):
		completed_encounters.append(selected_encounter)
	selected_encounter = ""


func is_encounter_complete(encounter_id: String) -> bool:
	return completed_encounters.has(encounter_id)
