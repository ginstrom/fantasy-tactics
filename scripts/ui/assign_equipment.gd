extends Control

## Lists roster adventurers for the item named by GameManager.route_context_id
## (see stores.gd/battle_result.gd/party_details.gd, each of which sets it
## before routing here) — every adventurer when
## GameManager.assign_equipment_party_id is empty (Stores' unscoped Equip),
## or only that party's own members when it's set (World Map Party
## Details' Equip, scoped to the current party — the victory summary has
## no Equip action at all, see battle_result.gd).
## Activating a row equips that adventurer immediately — via
## GameSession.equip_item_from_party_store() when this screen is scoped to
## a party (World Map Party Details' Equip, about a deployed party's own
## not-yet-banked loot), or via GameSession.equip_item_from_bank() when
## unscoped (Stores' Equip, always from the bank) — then returns to
## whichever screen sent us here
## (GameManager.assign_equipment_origin), mirroring add_member.gd's
## "activating a row is the action itself" pattern. A row that has gone
## stale (the item was sold/carried away elsewhere while this screen was
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
	for adventurer in _scoped_adventurers():
		rows.append({
			"id": adventurer.id,
			"name": adventurer.name,
			"class": adventurer["class"],
			"level": adventurer.level,
		})
	return rows


func _scoped_adventurers() -> Array:
	if GameManager.assign_equipment_party_id == "":
		return GameSession.adventurers
	var party := GameSession.get_party(GameManager.assign_equipment_party_id)
	var members: Array = []
	for adventurer_id in party.get("member_ids", []):
		var adventurer := GameSession.get_adventurer(adventurer_id)
		if not adventurer.is_empty():
			members.append(adventurer)
	return members


func _on_row_activated(row_id: Variant) -> void:
	var equipped: bool = (
		GameSession.equip_item_from_party_store(str(row_id), item_id)
		if GameManager.assign_equipment_party_id != ""
		else GameSession.equip_item_from_bank(str(row_id), item_id)
	)
	if equipped:
		_return_to_origin()
		return
	refresh()


func _on_back_pressed() -> void:
	_return_to_origin()


func _return_to_origin() -> void:
	match GameManager.assign_equipment_origin:
		GameManager.AssignEquipmentOrigin.PARTY_DETAILS:
			GameManager.go_to_party_details(GameManager.assign_equipment_party_id)
		_:
			GameManager.go_to_stores()
