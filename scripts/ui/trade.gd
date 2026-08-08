extends Control

## Lists Stores (always present) and, once purchased, Trading Post as
## TableView rows — the same one-row-per-destination pattern buildings.gd
## uses for Guild Hall. Purchasing the Trading Post is a gated action button
## below the table (guild_hall.gd's affordability-gated upgrade-button
## pattern), not a table row, since it is a one-time purchase rather than a
## destination to navigate to until it succeeds.

const TableColumnDescriptor := preload("res://scripts/ui/table_column.gd")

const STORES_ROW_ID := "stores"
const TRADING_POST_ROW_ID := "trading_post"

@onready var trade_table: TableView = $Body/Center/VBox/TradeTable
@onready var purchase_trading_post_button: Button = $Body/Center/VBox/PurchaseTradingPostButton


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
	purchase_trading_post_button.visible = not GameSession.has_trading_post
	purchase_trading_post_button.disabled = not GameSession.can_purchase_trading_post()
	purchase_trading_post_button.text = tr("trade.purchase_trading_post") % GameSession.TRADING_POST_PURCHASE_COST


func _build_columns() -> Array[TableColumn]:
	var name_column := TableColumnDescriptor.new(&"name", tr("trade.column.name"))
	name_column.expand = true
	return [name_column]


func _build_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = [{"id": STORES_ROW_ID, "name": tr("trade.stores")}]
	if GameSession.has_trading_post:
		rows.append({"id": TRADING_POST_ROW_ID, "name": tr("trade.trading_post")})
	return rows


func _on_row_activated(row_id: Variant) -> void:
	if str(row_id) == STORES_ROW_ID:
		GameManager.go_to_stores()
	elif str(row_id) == TRADING_POST_ROW_ID:
		GameManager.go_to_trading_post()


func _on_purchase_trading_post_button_pressed() -> void:
	GameSession.purchase_trading_post()
	refresh()


func _on_back_pressed() -> void:
	GameManager.go_to_encampment()
