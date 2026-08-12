class_name LootTable
extends Control

## Reusable gear/mana-crystal loot listing, shared by Stores, the victory
## summary, and the World Map's Party Details screen. Callers supply rows
## via set_rows() — see GameSession.build_loot_rows() for the expected
## id/name/type/count/price shape — and pick an action presentation via
## configure(). Party Details and victory use the detail presentation;
## Stores explicitly uses the direct action bar. Godot's Tree control only
## supports icon buttons, not text-labeled ones, so actions live in real
## Button nodes below the table rather than per-row Tree buttons.
##
## Selling is fully self-contained (it always means GameSession.sell_
## item()): a single-unit row sells immediately, a multi-unit row opens
## SellQuantityDialog first. Equipping is not self-contained, since where
## it should navigate varies by caller — it only emits equip_requested
## (item_id) for the parent to route.
##
## extends Control, not VBoxContainer: SellQuantityDialog and
## LootDetailPanel must float centered over the table, not get squashed
## into a vertical flow. A Container forces every direct child's
## position/size, so Content (Table + ViewButton) is anchored full-rect
## while the two overlays are anchored centered, all independent of any
## container — the same reason battlefield.tscn's LevelUp overlay is a
## child of the plain-Control HUD rather than of any of HUD's own
## VBoxContainers.

signal equip_requested(item_id: String)
signal sold

enum ActionPresentation {
	DETAIL,
	DIRECT_ACTION_BAR,
}

const TableColumnDescriptor := preload("res://scripts/ui/table_column.gd")

@onready var content: VBoxContainer = $Content
@onready var table: TableView = $Content/Table
@onready var view_button: Button = $Content/ViewButton
@onready var direct_action_bar: HBoxContainer = $Content/DirectActionBar
@onready var direct_view_button: Button = $Content/DirectActionBar/ViewButton
@onready var direct_sell_button: Button = $Content/DirectActionBar/SellButton
@onready var direct_equip_button: Button = $Content/DirectActionBar/EquipButton
@onready var empty_label: Label = $EmptyLabel
@onready var sell_dialog: SellQuantityDialog = $SellQuantityDialog
@onready var detail_panel: LootDetailPanel = $LootDetailPanel

var show_sell: bool = false
var show_equip: bool = false
var action_presentation: ActionPresentation = ActionPresentation.DETAIL
var _rows_by_id: Dictionary = {}
var _selected_row_id: String = ""


func _ready() -> void:
	table.row_selected.connect(_on_row_selected)
	table.row_activated.connect(_on_row_activated)
	view_button.pressed.connect(_on_view_button_pressed)
	direct_view_button.pressed.connect(_on_view_button_pressed)
	direct_sell_button.pressed.connect(_on_direct_sell_button_pressed)
	direct_equip_button.pressed.connect(_on_direct_equip_button_pressed)
	sell_dialog.confirmed.connect(_on_sell_dialog_confirmed)
	detail_panel.sell_requested.connect(_on_detail_sell_requested)
	detail_panel.equip_requested.connect(_on_detail_equip_requested)
	table.set_columns(_build_columns())


func configure(
	new_show_sell: bool,
	new_show_equip: bool,
	new_action_presentation: ActionPresentation = ActionPresentation.DETAIL
) -> void:
	show_sell = new_show_sell
	show_equip = new_show_equip
	action_presentation = new_action_presentation
	view_button.visible = action_presentation == ActionPresentation.DETAIL
	direct_action_bar.visible = action_presentation == ActionPresentation.DIRECT_ACTION_BAR
	_refresh_action_state()


func set_rows(rows: Array[Dictionary]) -> void:
	_rows_by_id.clear()
	for row in rows:
		_rows_by_id[row.id] = row
	table.set_rows(rows)
	empty_label.visible = rows.is_empty()
	content.visible = not rows.is_empty()
	if not _rows_by_id.has(_selected_row_id):
		_selected_row_id = ""
	_refresh_action_state()


func _build_columns() -> Array[TableColumn]:
	var name_column := TableColumnDescriptor.new(&"name", tr("loot_table.column.name"))
	name_column.expand = true
	name_column.expand_ratio = 2
	var type_column := TableColumnDescriptor.new(&"type", tr("loot_table.column.type"))
	var count_column := TableColumnDescriptor.new(&"count", tr("loot_table.column.count"), TableColumnDescriptor.Type.INTEGER)
	var price_column := TableColumnDescriptor.new(&"price", tr("loot_table.column.price"), TableColumnDescriptor.Type.INTEGER)
	return [name_column, type_column, count_column, price_column]


func _on_row_selected(row_id: Variant) -> void:
	_selected_row_id = str(row_id)
	_refresh_action_state()


func _on_row_activated(row_id: Variant) -> void:
	_open_detail_for(str(row_id))


func _on_view_button_pressed() -> void:
	if _selected_row_id != "":
		_open_detail_for(_selected_row_id)


func _open_detail_for(item_id: String) -> void:
	var row: Dictionary = _rows_by_id.get(item_id, {})
	if row.is_empty():
		return
	var detail_actions_visible := action_presentation == ActionPresentation.DETAIL
	detail_panel.show_for_row(row, show_sell and detail_actions_visible, show_equip and detail_actions_visible)


func _on_direct_sell_button_pressed() -> void:
	if _selected_row_id != "":
		_handle_sell(_selected_row_id)


func _on_direct_equip_button_pressed() -> void:
	if _selected_row_id != "" and _can_equip_selected_item():
		equip_requested.emit(_selected_row_id)


func _on_detail_sell_requested(item_id: String) -> void:
	_handle_sell(item_id)


func _on_detail_equip_requested(item_id: String) -> void:
	equip_requested.emit(item_id)


func _handle_sell(item_id: String) -> void:
	if GameSession.shop_level <= 0:
		return
	var row: Dictionary = _rows_by_id.get(item_id, {})
	if row.is_empty():
		return
	if int(row.count) <= 1:
		if GameSession.sell_item(item_id, 1):
			sold.emit()
		return
	var unit_price := int(row.price)
	if unit_price <= 0:
		return
	var affordable_quantity := mini(int(row.count), GameSession.shop_gold / unit_price)
	if affordable_quantity <= 0:
		return
	sell_dialog.show_for_item(item_id, str(row.name), affordable_quantity, unit_price)


func _on_sell_dialog_confirmed(item_id: String, quantity: int) -> void:
	if GameSession.sell_item(item_id, quantity):
		sold.emit()


func _refresh_action_state() -> void:
	var has_selection := _rows_by_id.has(_selected_row_id)
	view_button.disabled = not has_selection
	direct_view_button.disabled = not has_selection
	direct_sell_button.disabled = not has_selection or not show_sell or not GameSession.can_sell_item(_selected_row_id)
	direct_equip_button.disabled = not has_selection or not show_equip or not _can_equip_selected_item()


func _can_equip_selected_item() -> bool:
	return not _selected_row_id.begins_with(GameSession.MANA_CRYSTAL_ID_PREFIX)
