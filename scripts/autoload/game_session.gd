extends Node

const STARTING_SETTLEMENT_ID := "starting_settlement"
const STARTING_SETTLEMENT_WORLD_POSITION := Vector2i(0, 0)
const GOBLIN_CAMP_ID := "goblin_camp"
const ORC_OUTPOST_ID := "orc_outpost"
const EXPEDITIONS: Dictionary = {
	"goblin_camp": {
		"position": Vector2i(4, 4),
		"name_key": "expedition.goblin_camp.name",
		"danger_key": "expedition.danger.low",
		"reward": 10,
		"enemy": {
			"name_key": "battle.enemy.goblin",
			"max_health": 3,
			"attack_damage": 1,
			"hit_chance": 0.3,
		},
	},
	"orc_outpost": {
		"position": Vector2i(4, 0),
		"name_key": "expedition.orc_outpost.name",
		"danger_key": "expedition.danger.high",
		"reward": 25,
		"enemy": {
			"name_key": "battle.enemy.orc",
			"max_health": 5,
			"attack_damage": 2,
			"hit_chance": 0.5,
		},
	},
}
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
var world_turn: int = 1
var gold: int = 0
var pending_reward: int = 0


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
	world_turn = 1
	gold = 0
	pending_reward = 0


func create_party() -> bool:
	if not parties.is_empty():
		return false

	parties.append({
		"id": FIRST_PARTY_ID,
		"member_ids": [] as Array[String],
		"location_id": STARTING_SETTLEMENT_ID,
		"world_position": STARTING_SETTLEMENT_WORLD_POSITION,
		"deployed": false,
		"travel_route": [] as Array[Vector2i],
		"movement_spent": false,
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


func get_deployed_party_route() -> Array[Vector2i]:
	if not has_deployed_party():
		return []
	return get_selected_party().travel_route


func set_deployed_party_route(route: Array[Vector2i]) -> bool:
	if not has_deployed_party() or route.is_empty():
		return false

	var previous: Vector2i = get_selected_party().world_position
	for step in route:
		if _grid_distance(previous, step) != 1:
			return false
		previous = step

	parties[_get_selected_party_index()].travel_route = route
	return true


func clear_deployed_party_route() -> void:
	if not has_deployed_party():
		return
	parties[_get_selected_party_index()].travel_route = [] as Array[Vector2i]


func take_next_route_step() -> bool:
	if not has_deployed_party():
		return false

	var party_index := _get_selected_party_index()
	var party: Dictionary = parties[party_index]
	if party.movement_spent or party.travel_route.is_empty():
		return false

	var route: Array = party.travel_route
	party.world_position = route[0]
	route.remove_at(0)
	party.movement_spent = true
	return true


func end_world_turn() -> bool:
	var auto_moved := false
	if has_deployed_party() and not get_selected_party().movement_spent:
		auto_moved = take_next_route_step()

	world_turn += 1
	if has_deployed_party():
		parties[_get_selected_party_index()].movement_spent = false
	return auto_moved


func return_deployed_party_to_settlement() -> bool:
	if not has_deployed_party():
		return false

	var party_index := _get_selected_party_index()
	parties[party_index].deployed = false
	parties[party_index].location_id = STARTING_SETTLEMENT_ID
	parties[party_index].world_position = STARTING_SETTLEMENT_WORLD_POSITION
	parties[party_index].travel_route = [] as Array[Vector2i]
	parties[party_index].movement_spent = false
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


func _grid_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


func enter_encounter(encounter_id: String) -> void:
	selected_encounter = encounter_id


func complete_current_encounter() -> void:
	if selected_encounter == "":
		return
	var expedition := get_expedition(selected_encounter)
	if not completed_encounters.has(selected_encounter):
		completed_encounters.append(selected_encounter)
	pending_reward = expedition.get("reward", 0)
	selected_encounter = ""


func abandon_current_encounter() -> void:
	selected_encounter = ""


func deposit_pending_reward() -> int:
	var deposited := pending_reward
	gold += deposited
	pending_reward = 0
	return deposited


func is_encounter_complete(encounter_id: String) -> bool:
	return completed_encounters.has(encounter_id)


func get_expedition(encounter_id: String) -> Dictionary:
	if not EXPEDITIONS.has(encounter_id):
		return {}
	return EXPEDITIONS[encounter_id].duplicate(true)
