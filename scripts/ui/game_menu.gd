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
	load_button.disabled = not GameManager.has_valid_save()
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
	var result: Dictionary = GameManager.save_current_campaign()
	status_label.text = tr("menu.save_success") if result.ok else tr("menu.save_failed")
	status_label.visible = true
	# A successful save can flip has_valid_save() from false to true (the
	# very first save of a session); recompute Load's disabled state so the
	# player doesn't have to close and reopen the menu to see it unlock.
	load_button.disabled = not GameManager.has_valid_save()


## A successful load already routes away from whatever scene is currently
## showing this overlay (see GameManager.go_to_loaded_campaign()), so there
## is nothing left to update here on success. A failed load never routes or
## closes the menu -- surface the failure and refresh Load's own enabled
## state (has_valid_save() may have just changed, e.g. a corrupt file) so
## the player isn't left looking at a stale control.
func _on_load_pressed() -> void:
	var result: Dictionary = GameManager.go_to_loaded_campaign()
	if not result.ok:
		load_button.disabled = not GameManager.has_valid_save()
		status_label.text = tr("menu.load_failed")
		status_label.visible = true


func _on_quit_pressed() -> void:
	GameManager.quit_game()
