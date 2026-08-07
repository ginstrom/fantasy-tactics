extends Control

## Lists every GameSession adventurer as a TableView row, keyed by stable
## adventurer id (TableView's default row_id_key), and mirrors the selected
## row into the shared InformationPanel — the same selection pattern Parties
## uses for parties (see parties.gd), applied to adventurers instead. Row
## activation and the panel's View button both open the existing Unit
## Details screen, but through the Roster-origin route so that screen knows
## it may offer party assignment (see unit_details.gd).

const TableColumnDescriptor := preload("res://scripts/ui/table_column.gd")

@onready var roster_table: TableView = $Body/Center/VBox/RosterTable
@onready var empty_label: Label = $Body/Center/VBox/EmptyLabel
@onready var information_panel: PanelContainer = $InformationPanel

var selected_adventurer_id: String = ""


func _ready() -> void:
	information_panel.adventurer_selected.connect(_on_information_panel_adventurer_selected)
	roster_table.row_selected.connect(_on_row_selected)
	roster_table.row_activated.connect(_on_row_activated)
	roster_table.set_columns(_build_columns())
	information_panel.refresh()
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	var rows := _build_rows()
	roster_table.set_rows(rows)
	empty_label.visible = rows.is_empty()
	_refresh_selection()


func _build_columns() -> Array[TableColumn]:
	var name_column := TableColumnDescriptor.new(&"name", tr("roster.column.name"))
	name_column.expand = true
	name_column.expand_ratio = 2
	var class_column := TableColumnDescriptor.new(&"class", tr("roster.column.class"))
	var level_column := TableColumnDescriptor.new(
		&"level", tr("roster.column.level"), TableColumnDescriptor.Type.INTEGER
	)
	var status_column := TableColumnDescriptor.new(&"availability_status", tr("roster.column.status"))
	var party_column := TableColumnDescriptor.new(&"party_name", tr("roster.column.party"))
	party_column.expand = true
	return [name_column, class_column, level_column, status_column, party_column]


func _build_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for adventurer in GameSession.adventurers:
		rows.append({
			"id": adventurer.id,
			"name": adventurer.name,
			"class": adventurer["class"],
			"level": adventurer.level,
			"availability_status": tr("availability.%s" % adventurer.availability_status),
			"party_name": _party_name_for(adventurer.id),
		})
	return rows


## The party whose member_ids contains this adventurer, or the localized
## Unassigned string when no party does.
func _party_name_for(adventurer_id: String) -> String:
	for party in GameSession.parties:
		if adventurer_id in party.member_ids:
			return party.name
	return tr("roster.unassigned")


## Mirrors party_details.gd's _refresh_selection: a selection that no longer
## names a real adventurer (the roster changed out from under this screen)
## clears back to the safe, unselected empty state instead of leaving the
## panel pointed at a dead id.
func _refresh_selection() -> void:
	if selected_adventurer_id == "" or GameSession.get_adventurer(selected_adventurer_id).is_empty():
		selected_adventurer_id = ""
		information_panel.refresh()
		return
	information_panel.refresh_adventurer(selected_adventurer_id)


func _on_row_selected(row_id: Variant) -> void:
	selected_adventurer_id = str(row_id)
	_refresh_selection()


func _on_row_activated(row_id: Variant) -> void:
	GameManager.go_to_unit_details_from_roster(str(row_id))


func _on_information_panel_adventurer_selected(adventurer_id: String) -> void:
	GameManager.go_to_unit_details_from_roster(adventurer_id)


func _on_back_pressed() -> void:
	GameManager.go_to_units()
