extends PanelContainer
class_name CampNav

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
@onready var units_submenu_margin: MarginContainer = $VBox/UnitsSubmenuMargin
@onready var buildings_submenu_margin: MarginContainer = $VBox/BuildingsSubmenuMargin
@onready var trade_submenu_margin: MarginContainer = $VBox/TradeSubmenuMargin

enum Category {
	NONE,
	UNITS,
	BUILDINGS,
	TRADE,
}

## Each parent scene declares its own category; CampNav never infers it from
## scene-tree timing or paths.
@export var category: Category = Category.NONE


func _ready() -> void:
	refresh()


func refresh() -> void:
	units_submenu_margin.visible = category == Category.UNITS
	buildings_submenu_margin.visible = category == Category.BUILDINGS
	trade_submenu_margin.visible = category == Category.TRADE
	deploy_party_button.visible = not GameSession.parties.is_empty()
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


func _on_roster_button_pressed() -> void:
	GameManager.go_to_roster()


func _on_parties_button_pressed() -> void:
	GameManager.go_to_parties()


func _on_recruitment_button_pressed() -> void:
	GameManager.go_to_recruitment()


func _on_guild_hall_button_pressed() -> void:
	GameManager.go_to_guild_hall()


func _on_blacksmith_button_pressed() -> void:
	GameManager.go_to_blacksmith()


func _on_alchemy_workshop_button_pressed() -> void:
	GameManager.go_to_alchemy_workshop()


func _on_runic_workshop_button_pressed() -> void:
	GameManager.go_to_runic_workshop()


func _on_stores_button_pressed() -> void:
	GameManager.go_to_stores()


func _on_shop_button_pressed() -> void:
	GameManager.go_to_shop()
