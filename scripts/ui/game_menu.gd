extends CanvasLayer

@onready var load_button: Button = $Center/VBox/LoadButton
@onready var status_label: Label = $Center/VBox/StatusLabel


func _ready() -> void:
	# PROCESS_MODE_ALWAYS keeps this overlay (and its buttons, which inherit
	# it) receiving input even while GameManager pauses the tree to open it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	refresh()


func refresh() -> void:
	# Reset transient state so the overlay starts clean every time it opens,
	# regardless of what happened the last time it was shown.
	load_button.disabled = not GameManager.has_saved_game
	status_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.close_game_menu()


func _on_return_pressed() -> void:
	GameManager.close_game_menu()


func _on_world_map_pressed() -> void:
	GameManager.go_to_world_map_from_game_menu()


func _on_save_pressed() -> void:
	status_label.text = tr("menu.not_implemented")
	status_label.visible = true


func _on_quit_pressed() -> void:
	GameManager.quit_game()
