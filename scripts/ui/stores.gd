extends Control

## Lists everything banked in storage (GameSession.banked_gear +
## GameSession.mana_crystals) as a TableView row per item, keyed by a stable
## item id (a weapon/armor catalog id, or "mana_crystal_<tier>" for a mana
## crystal stack). Selecting a row shows its detail plus two gated actions —
## Sell (requires a Trading Post) and Assign (gear rows only) — following the
## same row-selection-drives-a-detail-action pattern recruitment.gd/
## unit_details.gd already use.

const TableColumnDescriptor := preload("res://scripts/ui/table_column.gd")

@onready var stores_table: TableView = $Body/Center/VBox/StoresTable
@onready var empty_label: Label = $Body/Center/VBox/EmptyLabel
@onready var selected_item_label: Label = $Body/Center/VBox/SelectedItemLabel
@onready var sell_button: Button = $Body/Center/VBox/SellButton
@onready var assign_button: Button = $Body/Center/VBox/AssignButton

var selected_item_id: String = ""


func _ready() -> void:
	stores_table.row_selected.connect(_on_row_selected)
	stores_table.set_columns(_build_columns())
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	var rows := _build_rows()
	stores_table.set_rows(rows)
	empty_label.visible = rows.is_empty()
	_refresh_selection(rows)


func _build_columns() -> Array[TableColumn]:
	var name_column := TableColumnDescriptor.new(&"name", tr("stores.column.name"))
	name_column.expand = true
	name_column.expand_ratio = 2
	var type_column := TableColumnDescriptor.new(&"type", tr("stores.column.type"))
	var count_column := TableColumnDescriptor.new(&"count", tr("stores.column.count"), TableColumnDescriptor.Type.INTEGER)
	var price_column := TableColumnDescriptor.new(&"price", tr("stores.column.price"), TableColumnDescriptor.Type.INTEGER)
	return [name_column, type_column, count_column, price_column]


func _build_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for item_id in GameSession.banked_gear:
		var count: int = GameSession.banked_gear[item_id]
		if count <= 0:
			continue
		var item := GameSession.get_item_definition(item_id)
		rows.append({
			"id": item_id,
			"name": tr(item.name_key),
			"type": tr("stores.type.%s" % item.slot),
			"count": count,
			"price": GameSession.get_item_sale_price(item_id),
		})
	for tier in GameSession.mana_crystals:
		var count: int = GameSession.mana_crystals[tier]
		if count <= 0:
			continue
		var item_id: String = "%s%d" % [GameSession.MANA_CRYSTAL_ID_PREFIX, tier]
		rows.append({
			"id": item_id,
			"name": tr("stores.mana_crystal") % tier,
			"type": tr("stores.type.mana_crystal"),
			"count": count,
			"price": GameSession.get_item_sale_price(item_id),
		})
	return rows


## A selection that no longer names a current row (sold to zero, or a fresh
## refresh after this screen was reopened) clears back to the safe,
## unselected empty state, mirroring add_member.gd/recruitment.gd's
## _refresh_selection convention.
func _refresh_selection(rows: Array[Dictionary]) -> void:
	var row := _find_row(rows, selected_item_id)
	if row.is_empty():
		selected_item_id = ""
		selected_item_label.visible = false
		sell_button.visible = false
		assign_button.visible = false
		return

	selected_item_label.visible = true
	selected_item_label.text = tr("stores.selected") % [row.name, row.count, row.price]
	sell_button.visible = true
	sell_button.disabled = not GameSession.has_trading_post
	assign_button.visible = not selected_item_id.begins_with(GameSession.MANA_CRYSTAL_ID_PREFIX)


func _find_row(rows: Array[Dictionary], item_id: String) -> Dictionary:
	if item_id == "":
		return {}
	for row in rows:
		if row.id == item_id:
			return row
	return {}


func _on_row_selected(row_id: Variant) -> void:
	selected_item_id = str(row_id)
	_refresh_selection(_build_rows())


func _on_sell_button_pressed() -> void:
	GameSession.sell_item(selected_item_id, 1)
	refresh()


func _on_assign_button_pressed() -> void:
	GameManager.go_to_assign_equipment(selected_item_id)


func _on_back_pressed() -> void:
	GameManager.go_to_trade()
