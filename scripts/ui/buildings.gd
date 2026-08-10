extends Control

## Lists the buildings available at the Encampment as a TableView row per
## building, keyed by a stable building id, following the Roster/Deploy
## Party list-screen pattern (see roster.gd) minus the shared
## InformationPanel — a one-row building list has nothing to summarize.
## Currently the only building is Guild Hall; activating its row routes to
## the Guild Hall screen (see guild_hall.gd).

const TableColumnDescriptor := preload("res://scripts/ui/table_column.gd")

const GUILD_HALL_ROW_ID := "guild_hall"
const BLACKSMITH_ROW_ID := "blacksmith"

@onready var building_table: TableView = $Body/Center/VBox/BuildingTable


func _ready() -> void:
	building_table.row_activated.connect(_on_row_activated)
	building_table.set_columns(_build_columns())
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	building_table.set_rows(_build_rows())


func _build_columns() -> Array[TableColumn]:
	var name_column := TableColumnDescriptor.new(&"name", tr("buildings.column.name"))
	name_column.expand = true
	return [name_column]


func _build_rows() -> Array[Dictionary]:
	return [
		{"id": GUILD_HALL_ROW_ID, "name": tr("buildings.guild_hall")},
		{"id": BLACKSMITH_ROW_ID, "name": tr("buildings.blacksmith")},
	]


func _on_row_activated(row_id: Variant) -> void:
	if str(row_id) == GUILD_HALL_ROW_ID:
		GameManager.go_to_guild_hall()
	elif str(row_id) == BLACKSMITH_ROW_ID:
		GameManager.go_to_blacksmith()


func _on_back_pressed() -> void:
	GameManager.go_to_encampment()
