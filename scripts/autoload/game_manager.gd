extends Node

const START_MENU_SCENE := "res://scenes/ui/start_menu.tscn"
const PARTY_MANAGER_SCENE := "res://scenes/ui/party_manager.tscn"
const ENCAMPMENT_SCENE := "res://scenes/ui/encampment.tscn"
const STARTING_SETTLEMENT_SCENE := "res://scenes/local/starting_settlement.tscn"
const WORLD_MAP_SCENE := "res://scenes/world/world_map.tscn"
const BATTLEFIELD_SCENE := "res://scenes/battle/battlefield.tscn"
const GAME_MENU_SCENE := "res://scenes/ui/game_menu.tscn"
const DEBUG_MENU_SCENE := "res://scenes/debug/debug_menu.tscn"
const UNITS_SCENE := "res://scenes/ui/units.tscn"
const PARTIES_SCENE := "res://scenes/ui/parties.tscn"
const PARTY_DETAILS_SCENE := "res://scenes/ui/party_details.tscn"
const UNIT_DETAILS_SCENE := "res://scenes/ui/unit_details.tscn"
const DEPLOY_PARTY_SCENE := "res://scenes/ui/deploy_party.tscn"
const ADD_MEMBER_SCENE := "res://scenes/ui/add_member.tscn"
const ROSTER_SCENE := "res://scenes/ui/roster.tscn"
const RECRUITMENT_SCENE := "res://scenes/ui/recruitment.tscn"
const BUILDINGS_SCENE := "res://scenes/ui/buildings.tscn"
const GUILD_HALL_SCENE := "res://scenes/ui/guild_hall.tscn"
const UNIT_DETAILS_ORIGIN_ROSTER := "roster"
const UNIT_DETAILS_ORIGIN_ADD_MEMBER := "add_member"
const UNIT_DETAILS_ORIGIN_PARTY_DETAILS := "party_details"
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")

const EN_TRANSLATION := preload("res://translations/en.tres")

# Hardcoded until a real save system exists; both menus read this to decide
# whether Continue/Load are available.
var has_saved_game: bool = false

# Short-lived context for the detail routes below (e.g. which party Party
# Details should read). It belongs here rather than on GameSession because
# it is UI navigation state, not a durable session record; an invalid
# navigation clears it instead of leaving a stale id behind.
var route_context_id: String = ""

# Which entry path opened Unit Details (currently only the Roster route sets
# this). It is its own field rather than folded into route_context_id
# because Unit Details needs both the adventurer id *and* how we got there;
# like route_context_id, it is cleared on every invalid or destination
# route rather than left to go stale.
var unit_details_origin: String = ""
var add_member_return_party_id: String = ""

var _game_menu: CanvasLayer
var _debug_menu: CanvasLayer

enum DebugTarget { NONE, SETTLEMENT, ENCAMPMENT, PARTY_MANAGER, WORLD_MAP, BATTLEFIELD }


func _ready() -> void:
	TranslationServer.add_translation(EN_TRANSLATION)
	# Added as our own child (instead of per-scene) so one instance persists
	# across every scene change.
	_game_menu = preload(GAME_MENU_SCENE).instantiate()
	add_child(_game_menu)
	if OS.is_debug_build():
		_debug_menu = preload(DEBUG_MENU_SCENE).instantiate()
		add_child(_debug_menu)


func go_to_start_menu() -> Error:
	return _change_scene(START_MENU_SCENE)


func go_to_game(player_name: String = "Player") -> Error:
	GameSession.start_new_game(player_name)
	return go_to_starting_settlement()


func go_to_starting_settlement() -> Error:
	return _change_scene(STARTING_SETTLEMENT_SCENE)


func open_party_manager() -> Error:
	return _change_scene(PARTY_MANAGER_SCENE)


func go_to_encampment() -> Error:
	GameSession.deposit_pending_reward()
	return _change_scene(ENCAMPMENT_SCENE)


func go_to_world_map() -> Error:
	_clear_detail_context()
	return _change_scene(WORLD_MAP_SCENE)


## The pause menu is available from every local screen, so it provides the
## campaign-level escape hatch back to the World Map.  Unpause before changing
## scenes: a paused destination would otherwise be unable to receive input.
func go_to_world_map_from_game_menu() -> Error:
	close_game_menu()
	return go_to_world_map()


## The session owns the single-party restriction; this UI-facing wrapper only
## converts its success value into the Error contract used by screen actions.
func create_party() -> Error:
	if not GameSession.create_party():
		return ERR_INVALID_DATA
	return OK


func depart_selected_party() -> Error:
	if not GameSession.depart_selected_party():
		return ERR_INVALID_DATA
	return _change_scene(WORLD_MAP_SCENE)


func return_party_to_encampment() -> Error:
	GameSession.return_deployed_party_to_settlement()
	return go_to_encampment()


func enter_battle(encounter_id: String) -> Error:
	GameSession.enter_encounter(encounter_id)
	return _change_scene(BATTLEFIELD_SCENE)


func complete_battle() -> Error:
	GameSession.complete_current_encounter()
	return go_to_world_map()


func fail_battle() -> Error:
	GameSession.abandon_current_encounter()
	return return_party_to_encampment()


func go_to_units() -> Error:
	_clear_detail_context()
	return _change_scene(UNITS_SCENE)


func go_to_parties() -> Error:
	_clear_detail_context()
	return _change_scene(PARTIES_SCENE)


func go_to_roster() -> Error:
	_clear_detail_context()
	return _change_scene(ROSTER_SCENE)


func go_to_recruitment() -> Error:
	_clear_detail_context()
	return _change_scene(RECRUITMENT_SCENE)


func go_to_buildings() -> Error:
	_clear_detail_context()
	return _change_scene(BUILDINGS_SCENE)


func go_to_guild_hall() -> Error:
	_clear_detail_context()
	return _change_scene(GUILD_HALL_SCENE)


func go_to_party_details(party_id: String) -> Error:
	if GameSession.get_party(party_id).is_empty():
		_clear_detail_context()
		return ERR_INVALID_DATA
	route_context_id = party_id
	unit_details_origin = ""
	add_member_return_party_id = ""
	return _change_scene(PARTY_DETAILS_SCENE)


## The pre-Roster entry path: unit_details_origin is always cleared here, so
## Unit Details never mistakenly offers roster-only party assignment for a
## unit opened this way (e.g. from Party Details).
func go_to_unit_details(adventurer_id: String) -> Error:
	if GameSession.get_adventurer(adventurer_id).is_empty():
		_clear_detail_context()
		return ERR_INVALID_DATA
	route_context_id = adventurer_id
	unit_details_origin = ""
	add_member_return_party_id = ""
	return _change_scene(UNIT_DETAILS_SCENE)


## The Roster entry path: identical validation to go_to_unit_details(), but
## marks unit_details_origin so Unit Details knows it may offer party
## assignment for this visit.
func go_to_unit_details_from_roster(adventurer_id: String) -> Error:
	if GameSession.get_adventurer(adventurer_id).is_empty():
		_clear_detail_context()
		return ERR_INVALID_DATA
	route_context_id = adventurer_id
	unit_details_origin = UNIT_DETAILS_ORIGIN_ROSTER
	add_member_return_party_id = ""
	return _change_scene(UNIT_DETAILS_SCENE)


func go_to_unit_details_from_add_member(adventurer_id: String, party_id: String) -> Error:
	if GameSession.get_adventurer(adventurer_id).is_empty() or GameSession.get_party(party_id).is_empty():
		_clear_detail_context()
		return ERR_INVALID_DATA
	route_context_id = adventurer_id
	unit_details_origin = UNIT_DETAILS_ORIGIN_ADD_MEMBER
	add_member_return_party_id = party_id
	return _change_scene(UNIT_DETAILS_SCENE)


func go_to_unit_details_from_party_details(adventurer_id: String, party_id: String) -> Error:
	if GameSession.get_adventurer(adventurer_id).is_empty() or GameSession.get_party(party_id).is_empty():
		_clear_detail_context()
		return ERR_INVALID_DATA
	route_context_id = adventurer_id
	unit_details_origin = UNIT_DETAILS_ORIGIN_PARTY_DETAILS
	add_member_return_party_id = party_id
	return _change_scene(UNIT_DETAILS_SCENE)


func go_to_deploy_party() -> Error:
	_clear_detail_context()
	return _change_scene(DEPLOY_PARTY_SCENE)


func go_to_add_member(party_id: String) -> Error:
	if GameSession.get_party(party_id).is_empty():
		_clear_detail_context()
		return ERR_INVALID_DATA
	route_context_id = party_id
	unit_details_origin = ""
	add_member_return_party_id = ""
	return _change_scene(ADD_MEMBER_SCENE)


## Deploys the named encamped party (see GameSession.deploy_party for the
## eligibility rules) and only then routes to the World Map, mirroring
## depart_selected_party()'s deploy-before-scene-change order. An ineligible
## or unknown id deploys nothing and never changes the scene, so a stale
## Deploy Party selection is safe to retry.
func deploy_party(party_id: String) -> Error:
	if not GameSession.deploy_party(party_id):
		return ERR_INVALID_DATA
	return go_to_world_map()


func assign_adventurer_to_party(party_id: String, adventurer_id: String) -> Error:
	if not GameSession.assign_adventurer_to_party(party_id, adventurer_id):
		return ERR_INVALID_DATA
	return OK


## A narrow Error-returning wrapper around GameSession.purchase_recruit, the
## only normal purchase path (see its docstring for the funds/candidate
## validation it performs). Never changes scene itself, matching
## assign_adventurer_to_party()/deploy_party(); Recruitment decides whether
## and when to route to Roster based on the returned Error.
func purchase_recruit(candidate_id: String) -> Error:
	if not GameSession.purchase_recruit(candidate_id):
		return ERR_INVALID_DATA
	return OK


func open_game_menu() -> void:
	_game_menu.refresh()
	_game_menu.visible = true
	get_tree().paused = true


func close_game_menu() -> void:
	_game_menu.visible = false
	get_tree().paused = false


func is_game_menu_open() -> bool:
	return _game_menu.visible


static func debug_scenario_target(scenario_id: String) -> DebugTarget:
	match scenario_id:
		"new_campaign":
			return DebugTarget.SETTLEMENT
		"encampment", "party_ready", "party_empty":
			return DebugTarget.ENCAMPMENT
		"party_manager":
			return DebugTarget.PARTY_MANAGER
		"world_map":
			return DebugTarget.WORLD_MAP
		"goblin_camp", "orc_outpost":
			return DebugTarget.BATTLEFIELD
	return DebugTarget.NONE


func run_debug_scenario(scenario_id: String) -> Error:
	if not OS.is_debug_build():
		return ERR_UNAVAILABLE
	if not DebugScenarios.apply(scenario_id):
		return ERR_INVALID_DATA

	match debug_scenario_target(scenario_id):
		DebugTarget.SETTLEMENT:
			return go_to_starting_settlement()
		DebugTarget.ENCAMPMENT:
			return go_to_encampment()
		DebugTarget.PARTY_MANAGER:
			return open_party_manager()
		DebugTarget.WORLD_MAP:
			return go_to_world_map()
		DebugTarget.BATTLEFIELD:
			return enter_battle(scenario_id)
	return ERR_INVALID_DATA


func apply_super_power() -> Error:
	if not OS.is_debug_build():
		return ERR_UNAVAILABLE
	var controller := get_tree().get_first_node_in_group(BattleControllerScript.GROUP)
	if controller == null:
		return ERR_UNAVAILABLE
	controller.apply_super_power()
	return OK


func recruit_adventurer() -> Error:
	if not OS.is_debug_build():
		return ERR_UNAVAILABLE
	GameSession.recruit_adventurer()
	return OK


func toggle_debug_menu() -> Error:
	if not OS.is_debug_build() or _debug_menu == null:
		return ERR_UNAVAILABLE
	_debug_menu.visible = not _debug_menu.visible
	return OK


func quit_game() -> void:
	get_tree().quit()


func _change_scene(path: String) -> Error:
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Failed to change scene to %s (error %d)" % [path, err])
	return err


func _clear_detail_context() -> void:
	route_context_id = ""
	unit_details_origin = ""
	add_member_return_party_id = ""
