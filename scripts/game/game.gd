extends Node2D


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameManager.go_to_main_menu()
		get_viewport().set_input_as_handled()
