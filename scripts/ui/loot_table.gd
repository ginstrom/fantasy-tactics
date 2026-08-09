class_name LootTable
extends Control

## Reusable gear/mana-crystal loot listing, shared by Stores (Step 4), the
## victory summary (Step 6), and the World Map's Party Details screen
## (Step 7). Callers supply rows via set_rows() — see
## GameSession.build_loot_rows() for the expected id/name/type/count/price
## shape — and pick which per-row actions to show via configure().
## Selling is fully self-contained (it always means
## GameSession.sell_item()): a single-unit row sells immediately, a
## multi-unit row opens SellQuantityDialog first. Equipping is not
## self-contained, since where it should navigate varies by caller — a
## click only emits equip_requested(item_id) for the parent to route.
##
## extends Control, not VBoxContainer: SellQuantityDialog must float
## centered over Table/EmptyLabel, not get squashed into their vertical
## flow. A Container forces every direct child's position/size, so Table,
## EmptyLabel, and SellQuantityDialog are instead full-rect/centered via
## their own anchors (see loot_table.tscn) — the same reason
## battlefield.tscn's LevelUp overlay is a child of the plain-Control HUD
## rather than of any of HUD's own VBoxContainers. Table and EmptyLabel can
## safely share the same full-rect space since set_rows() always keeps
## exactly one of them visible.

signal equip_requested(item_id: String)
signal sold

const TableColumnDescriptor := preload("res://scripts/ui/table_column.gd")

@onready var table: TableView = $Table
@onready var empty_label: Label = $EmptyLabel
@onready var sell_dialog: SellQuantityDialog = $SellQuantityDialog

var show_sell: bool = false
var show_equip: bool = false
var _rows_by_id: Dictionary = {}


func _ready() -> void:
	table.action_pressed.connect(_on_action_pressed)
	sell_dialog.confirmed.connect(_on_sell_dialog_confirmed)
	table.set_columns(_build_columns())


func configure(new_show_sell: bool, new_show_equip: bool) -> void:
	show_sell = new_show_sell
	show_equip = new_show_equip
	table.set_columns(_build_columns())


func set_rows(rows: Array[Dictionary]) -> void:
	_rows_by_id.clear()
	for row in rows:
		_rows_by_id[row.id] = row
	table.set_rows(rows)
	empty_label.visible = rows.is_empty()
	table.visible = not rows.is_empty()


func _build_columns() -> Array[TableColumn]:
	var name_column := TableColumnDescriptor.new(&"name", tr("loot_table.column.name"))
	name_column.expand = true
	name_column.expand_ratio = 2
	var type_column := TableColumnDescriptor.new(&"type", tr("loot_table.column.type"))
	var count_column := TableColumnDescriptor.new(&"count", tr("loot_table.column.count"), TableColumnDescriptor.Type.INTEGER)
	var price_column := TableColumnDescriptor.new(&"price", tr("loot_table.column.price"), TableColumnDescriptor.Type.INTEGER)
	var columns: Array[TableColumn] = [name_column, type_column, count_column, price_column]
	if show_sell:
		var sell_column := TableColumnDescriptor.new(&"sell", tr("loot_table.sell"), TableColumnDescriptor.Type.BUTTON)
		sell_column.button_visible = func(_row: Dictionary) -> bool: return GameSession.has_trading_post
		columns.append(sell_column)
	if show_equip:
		var equip_column := TableColumnDescriptor.new(&"equip", tr("loot_table.equip"), TableColumnDescriptor.Type.BUTTON)
		equip_column.button_visible = func(row: Dictionary) -> bool: return not str(row.id).begins_with(GameSession.MANA_CRYSTAL_ID_PREFIX)
		columns.append(equip_column)
	return columns


func _on_action_pressed(row_id: Variant, column_key: StringName) -> void:
	match column_key:
		&"sell":
			_handle_sell(str(row_id))
		&"equip":
			equip_requested.emit(str(row_id))


func _handle_sell(item_id: String) -> void:
	if not GameSession.has_trading_post:
		return
	var row: Dictionary = _rows_by_id.get(item_id, {})
	if row.is_empty():
		return
	if int(row.count) <= 1:
		GameSession.sell_item(item_id, 1)
		sold.emit()
		return
	sell_dialog.show_for_item(item_id, str(row.name), int(row.count), int(row.price))


func _on_sell_dialog_confirmed(item_id: String, quantity: int) -> void:
	GameSession.sell_item(item_id, quantity)
	sold.emit()
