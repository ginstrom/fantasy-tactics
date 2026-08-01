extends Node

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const GAME_SCENE := "res://scenes/game/game.tscn"


func go_to_main_menu() -> Error:
	return _change_scene(MAIN_MENU_SCENE)


func go_to_game() -> Error:
	return _change_scene(GAME_SCENE)


func quit_game() -> void:
	get_tree().quit()


func _change_scene(path: String) -> Error:
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Failed to change scene to %s (error %d)" % [path, err])
	return err
