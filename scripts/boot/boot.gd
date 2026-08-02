extends Node


func _ready() -> void:
	# change_scene_to_file cannot run while the tree is still building this node.
	call_deferred("_enter_main_menu")


func _enter_main_menu() -> void:
	GameManager.go_to_main_menu()
