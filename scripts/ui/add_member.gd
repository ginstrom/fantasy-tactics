extends Control

## Lists GameSession.get_available_adventurers() for the party named by
## GameManager.route_context_id (see party_details.gd, which sets it before
## routing here) as a TableView row per available adventurer, keyed by stable
## adventurer id, and treats activating a row as the assignment itself: it
## calls GameManager.assign_adventurer_to_party() immediately, then returns
## to Party Details on success. A row that has gone stale (its adventurer got
## assigned elsewhere while this screen was open) fails safely and this
## screen just refreshes the list in place instead of navigating anywhere.
## Selecting (rather than activating) a row only mirrors it into the shared
## InformationPanel as a summary, the same selection pattern Party Details
## uses for its members (see party_details.gd); it never assigns by itself.

const TableColumnDescriptor := preload("res://scripts/ui/table_column.gd")

@onready var adventurer_table: TableView = $Center/VBox/AdventurerTable
@onready var empty_label: Label = $Center/VBox/EmptyLabel
@onready var information_panel: PanelContainer = $InformationPanel

var party_id: String = ""
var selected_adventurer_id: String = ""


func _ready() -> void:
	information_panel.adventurer_selected.connect(_on_information_panel_adventurer_selected)
	information_panel.refresh()
	party_id = GameManager.route_context_id
	adventurer_table.row_selected.connect(_on_row_selected)
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
	_refresh_selection()


func _build_columns() -> Array[TableColumn]:
	var name_column := TableColumnDescriptor.new(&"name", tr("add_member.column.name"))
	name_column.expand = true
	name_column.expand_ratio = 2
	var class_column := TableColumnDescriptor.new(&"class", tr("add_member.column.class"))
	var level_column := TableColumnDescriptor.new(
		&"level", tr("add_member.column.level"), TableColumnDescriptor.Type.INTEGER
	)
	return [name_column, class_column, level_column]


func _build_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for adventurer in GameSession.get_available_adventurers():
		rows.append({
			"id": adventurer.id,
			"name": adventurer.name,
			"class": adventurer["class"],
			"level": adventurer.level,
		})
	return rows


## A selection that no longer names a currently available adventurer (assigned
## elsewhere while this screen was open) clears back to the safe, unselected
## empty state instead of leaving the panel pointed at a stale id.
func _refresh_selection() -> void:
	if selected_adventurer_id == "" or not GameSession.is_adventurer_available(selected_adventurer_id):
		selected_adventurer_id = ""
		information_panel.refresh()
		return
	information_panel.refresh_adventurer(selected_adventurer_id)


func _on_row_selected(row_id: Variant) -> void:
	selected_adventurer_id = str(row_id)
	_refresh_selection()


func _on_row_activated(row_id: Variant) -> void:
	if GameManager.assign_adventurer_to_party(party_id, str(row_id)) == OK:
		GameManager.go_to_party_details(party_id)
		return
	refresh()


func _on_information_panel_adventurer_selected(adventurer_id: String) -> void:
	GameManager.go_to_unit_details(adventurer_id)


func _on_back_pressed() -> void:
	GameManager.go_to_party_details(party_id)
