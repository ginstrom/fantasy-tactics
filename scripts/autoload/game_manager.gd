extends Node

const START_MENU_SCENE := "res://scenes/ui/start_menu.tscn"
const PARTY_MANAGER_SCENE := "res://scenes/ui/party_manager.tscn"
const ENCAMPMENT_SCENE := "res://scenes/ui/encampment.tscn"
const STARTING_SETTLEMENT_SCENE := "res://scenes/local/starting_settlement.tscn"
const WORLD_MAP_SCENE := "res://scenes/world/world_map.tscn"
const BATTLEFIELD_SCENE := "res://scenes/battle/battlefield.tscn"
const GAME_MENU_SCENE := "res://scenes/ui/game_menu.tscn"

const EN_TRANSLATION := preload("res://translations/en.tres")

# Hardcoded until a real save system exists; both menus read this to decide
# whether Continue/Load are available.
var has_saved_game: bool = false

var _game_menu: CanvasLayer


func _ready() -> void:
	TranslationServer.add_translation(EN_TRANSLATION)
	# Added as our own child (instead of per-scene) so one instance persists
	# across every scene change.
	_game_menu = preload(GAME_MENU_SCENE).instantiate()
	add_child(_game_menu)


func go_to_start_menu() -> Error:
	return _change_scene(START_MENU_SCENE)


func go_to_game() -> Error:
	GameSession.start_new_game()
	return _change_scene(STARTING_SETTLEMENT_SCENE)


func open_party_manager() -> Error:
	return _change_scene(PARTY_MANAGER_SCENE)


func go_to_encampment() -> Error:
	return _change_scene(ENCAMPMENT_SCENE)


func go_to_world_map() -> Error:
	return _change_scene(WORLD_MAP_SCENE)


func depart_selected_party() -> Error:
	if not GameSession.depart_selected_party():
		return ERR_INVALID_DATA
	return _change_scene(WORLD_MAP_SCENE)


func enter_starting_settlement() -> Error:
	GameSession.return_deployed_party_to_settlement()
	return _change_scene(STARTING_SETTLEMENT_SCENE)


func enter_battle(encounter_id: String) -> Error:
	GameSession.enter_encounter(encounter_id)
	return _change_scene(BATTLEFIELD_SCENE)


func complete_battle() -> Error:
	GameSession.complete_current_encounter()
	return go_to_world_map()


func fail_battle() -> Error:
	GameSession.abandon_current_encounter()
	return enter_starting_settlement()


func open_game_menu() -> void:
	_game_menu.refresh()
	_game_menu.visible = true
	get_tree().paused = true


func close_game_menu() -> void:
	_game_menu.visible = false
	get_tree().paused = false


func is_game_menu_open() -> bool:
	return _game_menu.visible


func quit_game() -> void:
	get_tree().quit()


func _change_scene(path: String) -> Error:
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Failed to change scene to %s (error %d)" % [path, err])
	return err
