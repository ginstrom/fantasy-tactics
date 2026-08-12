extends Control

## Lists the always-present Stores and Shop destinations.
## TableView rows — the same one-row-per-destination pattern buildings.gd
## uses for Guild Hall.

const TableColumnDescriptor := preload("res://scripts/ui/table_column.gd")

const STORES_ROW_ID := "stores"
const SHOP_ROW_ID := "shop"

@onready var trade_table: TableView = $Body/Center/VBox/TradeTable


func _ready() -> void:
	trade_table.row_activated.connect(_on_row_activated)
	trade_table.set_columns(_build_columns())
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	trade_table.set_rows(_build_rows())


func _build_columns() -> Array[TableColumn]:
	var name_column := TableColumnDescriptor.new(&"name", tr("trade.column.name"))
	name_column.expand = true
	return [name_column]


func _build_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = [{"id": STORES_ROW_ID, "name": tr("trade.stores")}]
	if GameSession.shop_level > 0:
		rows.append({"id": SHOP_ROW_ID, "name": tr("trade.shop")})
	return rows


func _on_row_activated(row_id: Variant) -> void:
	if str(row_id) == STORES_ROW_ID:
		GameManager.go_to_stores()
	elif str(row_id) == SHOP_ROW_ID:
		GameManager.go_to_shop()


func _on_back_pressed() -> void:
	GameManager.go_to_encampment()
