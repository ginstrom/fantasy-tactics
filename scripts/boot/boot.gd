extends Node


func _ready() -> void:
	# change_scene_to_file cannot run while the tree is still building this node.
	call_deferred("_enter_start_menu")


func _enter_start_menu() -> void:
	GameManager.go_to_start_menu()
