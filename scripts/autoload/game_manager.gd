extends Node

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const GAME_SCENE := "res://scenes/game/game.tscn"


func go_to_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func go_to_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func quit_game() -> void:
	get_tree().quit()
