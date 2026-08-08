extends PanelContainer

## Persistent left-hand navigation instanced into all six top-level camp
## screens (Encampment, Units, Buildings, Trade, Deploy Party, World Map).
## Every destination here is fixed, so — unlike InformationPanel's
## signal-forwarding pattern — each button routes straight through
## GameManager itself rather than bubbling a signal up to a parent screen.

@onready var encampment_button: Button = $VBox/EncampmentButton
@onready var units_button: Button = $VBox/UnitsButton
@onready var buildings_button: Button = $VBox/BuildingsButton
@onready var trade_button: Button = $VBox/TradeButton
@onready var deploy_party_button: Button = $VBox/DeployPartyButton
@onready var world_map_button: Button = $VBox/WorldMapButton


func _ready() -> void:
	refresh()


func refresh() -> void:
	deploy_party_button.disabled = GameSession.get_deployable_encamped_parties().is_empty()


func _on_encampment_button_pressed() -> void:
	GameManager.go_to_encampment()


func _on_units_button_pressed() -> void:
	GameManager.go_to_units()


func _on_buildings_button_pressed() -> void:
	GameManager.go_to_buildings()


func _on_trade_button_pressed() -> void:
	GameManager.go_to_trade()


func _on_deploy_party_button_pressed() -> void:
	GameManager.go_to_deploy_party()


func _on_world_map_button_pressed() -> void:
	GameManager.go_to_world_map()
