extends Control

## Units hub. Parties is the only branch wired to a real screen in this
## slice; Roster and Recruitment are visible but disabled with a concise
## "TBD" label until their systems exist.


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func _on_parties_pressed() -> void:
	GameManager.go_to_parties()


func _on_back_pressed() -> void:
	GameManager.go_to_encampment()
