extends Control

@onready var deploy_party_button: Button = $Center/VBox/DeployPartyButton
@onready var information_panel: PanelContainer = $InformationPanel


func _ready() -> void:
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	deploy_party_button.disabled = GameSession.get_deployable_encamped_parties().is_empty()
	information_panel.refresh()


func _on_units_button_pressed() -> void:
	GameManager.go_to_units()


func _on_buildings_button_pressed() -> void:
	GameManager.go_to_buildings()


func _on_deploy_party_button_pressed() -> void:
	GameManager.go_to_deploy_party()
