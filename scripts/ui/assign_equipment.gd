extends Control

## Lists every roster adventurer (GameSession.adventurers) as a TableView
## row, keyed by adventurer id, for the item named by
## GameManager.route_context_id (see stores.gd, which sets it before routing
## here). Activating a row equips that adventurer immediately via
## GameSession.equip_item_from_bank() then returns to Stores — mirroring
## add_member.gd's "activating a row is the action itself" pattern. A row
## that has gone stale (the item was sold elsewhere while this screen was
## open) fails safely and this screen just refreshes in place.

const TableColumnDescriptor := preload("res://scripts/ui/table_column.gd")

@onready var adventurer_table: TableView = $Body/Center/VBox/AdventurerTable
@onready var empty_label: Label = $Body/Center/VBox/EmptyLabel

var item_id: String = ""


func _ready() -> void:
	item_id = GameManager.route_context_id
	adventurer_table.row_activated.connect(_on_row_activated)
	adventurer_table.set_columns(_build_columns())
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	var rows := _build_rows()
	adventurer_table.set_rows(rows)
	empty_label.visible = rows.is_empty()


func _build_columns() -> Array[TableColumn]:
	var name_column := TableColumnDescriptor.new(&"name", tr("assign_equipment.column.name"))
	name_column.expand = true
	name_column.expand_ratio = 2
	var class_column := TableColumnDescriptor.new(&"class", tr("assign_equipment.column.class"))
	var level_column := TableColumnDescriptor.new(
		&"level", tr("assign_equipment.column.level"), TableColumnDescriptor.Type.INTEGER
	)
	return [name_column, class_column, level_column]


func _build_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for adventurer in GameSession.adventurers:
		rows.append({
			"id": adventurer.id,
			"name": adventurer.name,
			"class": adventurer["class"],
			"level": adventurer.level,
		})
	return rows


func _on_row_activated(row_id: Variant) -> void:
	if GameSession.equip_item_from_bank(str(row_id), item_id):
		GameManager.go_to_stores()
		return
	refresh()


func _on_back_pressed() -> void:
	GameManager.go_to_stores()
