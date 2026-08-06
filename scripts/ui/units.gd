extends Control

## Units hub. Parties and Roster are wired to real screens in this slice;
## Recruitment remains visible but disabled until its system exists,
## following the same disabled-with-its-own-label convention Encampment
## uses for Buildings and Trade.

@onready var information_panel: PanelContainer = $InformationPanel


func _ready() -> void:
	information_panel.refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func _on_roster_pressed() -> void:
	GameManager.go_to_roster()


func _on_parties_pressed() -> void:
	GameManager.go_to_parties()


func _on_back_pressed() -> void:
	GameManager.go_to_encampment()
