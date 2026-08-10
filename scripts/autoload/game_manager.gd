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
const BLACKSMITH_SCENE := "res://scenes/ui/blacksmith.tscn"
const TRADE_SCENE := "res://scenes/ui/trade.tscn"
const STORES_SCENE := "res://scenes/ui/stores.tscn"
const TRADING_POST_SCENE := "res://scenes/ui/trading_post.tscn"
const ASSIGN_EQUIPMENT_SCENE := "res://scenes/ui/assign_equipment.tscn"
const BATTLE_RESULT_SCENE := "res://scenes/ui/battle_result.tscn"
const UNIT_DETAILS_ORIGIN_ROSTER := "roster"
const UNIT_DETAILS_ORIGIN_ADD_MEMBER := "add_member"
const UNIT_DETAILS_ORIGIN_PARTY_DETAILS := "party_details"
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")

const EN_TRANSLATION := preload("res://translations/en.tres")

## The persistence layer behind save_current_campaign()/load_current_campaign()/
## has_valid_save(). Deliberately a plain, untyped var (not a private
## underscore-prefixed field, and not statically typed to SaveRepository) so
## a test can substitute any object exposing the same save_campaign()/
## load_campaign()/has_valid_save() surface -- most simply a real
## SaveRepository constructed with a throwaway save_path (see
## SaveRepository's own test-injectable path) instead of a repository
## pointed at the real user://campaign-save.json. This is the same
## injectable-dependency shape GameSession's roll Callables use (see
## GameSession.enemy_composition_roll) for swapping real behavior with a
## controlled double. UI scripts must always go through the three wrappers
## below instead of ever reaching into save_repository or the filesystem
## directly (see docs/plans/2026-08-10-initial-campaign-and-automation/
## 02-atomic-save-repository.md).
var save_repository = SaveRepository.new()

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

## Scopes Assign Equipment to one party's own members (the victory summary
## and World Map Party Details' [Equip] — see Steps 6/7 of
## docs/plans/2026-08-09-minor-fixes-and-encounter-loot/) instead of the
## full roster (Stores' [Equip]). Empty means unscoped.
var assign_equipment_party_id: String = ""

## Which screen opened Assign Equipment, so its Back action (and a
## successful equip) can return there instead of always landing on Stores.
enum AssignEquipmentOrigin { STORES, PARTY_DETAILS }
var assign_equipment_origin: AssignEquipmentOrigin = AssignEquipmentOrigin.STORES

# Transient victory-summary payload, mirroring route_context_id's "set
# right before navigating, read once in the destination scene's _ready()"
# pattern. Battlefield builds this from data no other system durably
# tracks (this battle's kills/XP/level-ups), so — unlike route_context_id,
# which always names something GameSession already owns — there is no
# live GameSession id to re-validate on the way in.
var battle_result_summary: Dictionary = {}

var _game_menu: CanvasLayer
var _debug_menu: CanvasLayer

enum DebugTarget { NONE, SETTLEMENT, ENCAMPMENT, PARTY_MANAGER, WORLD_MAP, BATTLEFIELD, STORES }


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
	if not GameSession.has_deployed_party():
		GameSession.deposit_pending_reward()
	return _change_scene(ENCAMPMENT_SCENE)


## Merges the battle store into the party's own store before ever showing
## the World Map -- see GameSession.merge_battle_loot_into_party(). This is
## the single call site both the real "leave the victory summary" path
## (battle_result.gd's OK button) and the screenshot-tour shortcut
## (complete_battle()) route through, so the merge lives here rather than
## in battle_result.gd itself.
func go_to_world_map() -> Error:
	GameSession.merge_battle_loot_into_party()
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
func create_party(party_name: String = "Party 1") -> Error:
	if not GameSession.create_party(party_name):
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


func go_to_blacksmith() -> Error:
	_clear_detail_context()
	return _change_scene(BLACKSMITH_SCENE)


func go_to_trade() -> Error:
	_clear_detail_context()
	return _change_scene(TRADE_SCENE)


func go_to_stores() -> Error:
	_clear_detail_context()
	return _change_scene(STORES_SCENE)


func go_to_trading_post() -> Error:
	_clear_detail_context()
	return _change_scene(TRADING_POST_SCENE)


## Mirrors go_to_unit_details()'s validate-then-route shape: an unknown item
## id, or an unknown party_id when one is given, clears the detail context
## and reports ERR_INVALID_DATA instead of routing to a screen with nothing
## to show. party_id/origin default to the old unscoped, Stores-originated
## behavior so every pre-existing call site keeps working unchanged.
func go_to_assign_equipment(
	item_id: String, party_id: String = "", origin: AssignEquipmentOrigin = AssignEquipmentOrigin.STORES
) -> Error:
	if GameSession.get_item_definition(item_id).is_empty():
		_clear_detail_context()
		return ERR_INVALID_DATA
	if party_id != "" and GameSession.get_party(party_id).is_empty():
		_clear_detail_context()
		return ERR_INVALID_DATA
	route_context_id = item_id
	unit_details_origin = ""
	add_member_return_party_id = ""
	assign_equipment_party_id = party_id
	assign_equipment_origin = origin
	return _change_scene(ASSIGN_EQUIPMENT_SCENE)


func go_to_party_details(party_id: String) -> Error:
	if GameSession.get_party(party_id).is_empty():
		_clear_detail_context()
		return ERR_INVALID_DATA
	route_context_id = party_id
	unit_details_origin = ""
	add_member_return_party_id = ""
	return _change_scene(PARTY_DETAILS_SCENE)


func go_to_battle_result(summary: Dictionary) -> Error:
	_clear_detail_context()
	battle_result_summary = summary
	return _change_scene(BATTLE_RESULT_SCENE)


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
		"goblin_camp", "orc_outpost", "ruined_fortress":
			return DebugTarget.BATTLEFIELD
		"stocked_stores":
			return DebugTarget.STORES
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
		DebugTarget.STORES:
			return go_to_stores()
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


## True only when the current campaign is safe to snapshot: no active
## encounter in progress, and no unsettled battle loot sitting in
## GameSession's battle_* buckets (see GameSession.has_unsettled_battle_
## loot() -- selected_encounter is already cleared by the time complete_
## current_encounter() queues that loot, so the first condition alone does
## not cover the Battle Result screen). Deliberately reads GameSession's own
## durable state rather than the scene tree -- a screen renamed or added
## later can never silently widen or narrow this guard's true meaning the
## way matching on get_tree().current_scene.name could. See
## docs/plans/2026-08-10-initial-campaign-and-automation/
## 03-save-boundaries-and-menu.md.
func can_save_current_campaign() -> bool:
	return GameSession.selected_encounter == "" and not GameSession.has_unsettled_battle_loot()


## Narrow wrapper around save_repository.save_campaign(): writes the current
## GameSession's durable state atomically, but only when
## can_save_current_campaign() allows it. A blocked save never reaches
## save_repository at all -- mid-battle state is never exported, let alone
## written -- and returns an {"ok": false, "error"} result of its own
## instead. Exists so UI code has exactly one call site for writing the
## current campaign and never touches the filesystem or save_repository's
## own internals directly. Returns save_repository's own {"ok", "error"}
## result unchanged on an allowed save.
func save_current_campaign() -> Dictionary:
	if not can_save_current_campaign():
		return {"ok": false, "error": "cannot save during an active encounter"}
	return save_repository.save_campaign(GameSession)


## Narrow wrapper around save_repository.load_campaign(): a failed load (see
## SaveRepository.LoadStatus) never imports anything, leaving GameSession
## completely untouched. Does not decide where to route afterward -- see
## go_to_loaded_campaign() below, which UI code should call instead whenever
## a successful load should also resume play. Returns save_repository's own
## {"ok", "snapshot", "error", "status"} result unchanged.
func load_current_campaign() -> Dictionary:
	return save_repository.load_campaign(GameSession)


## The one "resume a saved campaign" decision Start Menu's Continue/Load and
## the pause menu's Load all share: load_current_campaign() first, and only
## once that succeeds, close the pause menu (a harmless no-op if it was
## never open -- see close_game_menu()) and route to the World Map for a
## deployed party or the Encampment otherwise -- the same two destinations a
## live campaign already reaches via go_to_world_map()/go_to_encampment(),
## but by calling the underlying routing primitives (_clear_detail_context()
## / _change_scene()) directly rather than those two functions themselves.
## This keeps the save/load invariant "preserve, never settle" true by
## construction: go_to_world_map() calls GameSession.
## merge_battle_loot_into_party() and go_to_encampment() calls GameSession.
## deposit_pending_reward(), and neither reward-banking side effect may ever
## sit in the load path, even as a currently-unreachable no-op. A failed
## load changes nothing at all: no scene change, GameSession left completely
## untouched, so whichever screen called this is exactly as it was. Returns
## load_current_campaign()'s own {"ok", "snapshot", "error", "status"}
## result unchanged so the caller can surface its own feedback.
func go_to_loaded_campaign() -> Dictionary:
	var result := load_current_campaign()
	if result.ok:
		close_game_menu()
		if GameSession.has_deployed_party():
			_clear_detail_context()
			_change_scene(WORLD_MAP_SCENE)
		else:
			_change_scene(ENCAMPMENT_SCENE)
	return result


## Narrow wrapper so UI can check save availability without ever reaching
## into SaveRepository's on-disk details directly.
func has_valid_save() -> bool:
	return save_repository.has_valid_save()


func _change_scene(path: String) -> Error:
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Failed to change scene to %s (error %d)" % [path, err])
	return err


func _clear_detail_context() -> void:
	route_context_id = ""
	unit_details_origin = ""
	add_member_return_party_id = ""
	assign_equipment_party_id = ""
	assign_equipment_origin = AssignEquipmentOrigin.STORES
