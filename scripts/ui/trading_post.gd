extends Control

## Shows Shop status and its unlocked weapon catalogue. Selecting a
## row shows its detail and a Buy action gated on affordability, mirroring
## recruitment.gd's row-selection-drives-a-gated-purchase-button pattern.
## Note: no upgrade tiers here — see this plan's Phase C architecture note.

const TableColumnDescriptor := preload("res://scripts/ui/table_column.gd")

@onready var income_label: Label = $Body/Center/VBox/IncomeLabel
@onready var buy_table: TableView = $Body/Center/VBox/BuyTable
@onready var selected_item_label: Label = $Body/Center/VBox/SelectedItemLabel
@onready var buy_button: Button = $Body/Center/VBox/BuyButton

var selected_item_id: String = ""


func _ready() -> void:
	buy_table.row_selected.connect(_on_row_selected)
	buy_table.set_columns(_build_columns())
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	income_label.text = tr("shop.status") % [GameSession.shop_level, GameSession.shop_gold, GameSession.shop_gold_cap()]
	buy_table.set_rows(_build_rows())
	_refresh_selection()


func _build_columns() -> Array[TableColumn]:
	var name_column := TableColumnDescriptor.new(&"name", tr("shop.column.name"))
	name_column.expand = true
	name_column.expand_ratio = 2
	var type_column := TableColumnDescriptor.new(&"type", tr("shop.column.type"))
	var price_column := TableColumnDescriptor.new(&"price", tr("shop.column.price"), TableColumnDescriptor.Type.INTEGER)
	return [name_column, type_column, price_column]


func _build_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for item_id in GameSession.get_shop_catalogue_item_ids():
		rows.append(_row_for(item_id, GameSession.WEAPONS[item_id]))
	return rows


func _row_for(item_id: String, item: Dictionary) -> Dictionary:
	return {"id": item_id, "name": tr(item.name_key), "type": tr("shop.type.%s" % item.slot), "price": item.price}


func _refresh_selection() -> void:
	var item := GameSession.get_item_definition(selected_item_id)
	if item.is_empty():
		selected_item_id = ""
		selected_item_label.visible = false
		buy_button.visible = false
		return

	selected_item_label.visible = true
	selected_item_label.text = tr("shop.selected") % [tr(item.name_key), item.price]
	buy_button.visible = true
	buy_button.disabled = GameSession.gold < int(item.price) or not GameSession.get_shop_catalogue_item_ids().has(selected_item_id)


func _on_row_selected(row_id: Variant) -> void:
	selected_item_id = str(row_id)
	_refresh_selection()


func _on_buy_button_pressed() -> void:
	GameSession.buy_item(selected_item_id)
	refresh()


func _on_back_pressed() -> void:
	GameManager.go_to_trade()
