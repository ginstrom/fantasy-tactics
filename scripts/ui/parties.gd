extends Control

## Lists every GameSession party as a TableView row, keyed by stable party id
## (TableView's default row_id_key), and mirrors the selected row into the
## shared InformationPanel — the same selection pattern Roster uses for
## adventurers (see roster.gd), applied to parties instead. Row activation and
## the panel's View button both open the existing Party Details screen; this
## screen never mutates a party itself.

const TableColumnDescriptor := preload("res://scripts/ui/table_column.gd")

@onready var party_table: TableView = $Center/VBox/PartyTable
@onready var empty_label: Label = $Center/VBox/EmptyLabel
@onready var create_party_button: Button = $Center/VBox/CreatePartyButton
@onready var information_panel: PanelContainer = $InformationPanel

var selected_party_id: String = ""


func _ready() -> void:
	information_panel.party_selected.connect(_on_information_panel_party_selected)
	party_table.row_selected.connect(_on_row_selected)
	party_table.row_activated.connect(_on_row_activated)
	party_table.set_columns(_build_columns())
	information_panel.refresh()
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	var rows := _build_rows()
	party_table.set_rows(rows)
	empty_label.visible = rows.is_empty()
	create_party_button.disabled = not rows.is_empty()
	_refresh_selection()


func _build_columns() -> Array[TableColumn]:
	var name_column := TableColumnDescriptor.new(&"name", tr("parties.column.party"))
	name_column.expand = true
	name_column.expand_ratio = 2
	var members_column := TableColumnDescriptor.new(
		&"member_count", tr("parties.column.members"), TableColumnDescriptor.Type.INTEGER
	)
	var status_column := TableColumnDescriptor.new(&"status", tr("parties.column.status"))
	return [name_column, members_column, status_column]


func _build_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for party in GameSession.parties:
		rows.append({
			"id": party.id,
			"name": party.name,
			"member_count": party.member_ids.size(),
			"status": "deployed" if party.get("deployed", false) else "encamped",
		})
	return rows


## A selection that no longer resolves to a real party (list refreshed out
## from under it) clears back to the safe, unselected empty state instead of
## leaving the panel pointed at a dead id.
func _refresh_selection() -> void:
	if GameSession.get_party(selected_party_id).is_empty():
		selected_party_id = ""
		information_panel.refresh()
		return
	information_panel.refresh_party(selected_party_id)


func _on_row_selected(row_id: Variant) -> void:
	selected_party_id = str(row_id)
	_refresh_selection()


func _on_row_activated(row_id: Variant) -> void:
	GameManager.go_to_party_details(str(row_id))


func _on_information_panel_party_selected(party_id: String) -> void:
	GameManager.go_to_party_details(party_id)


func _on_create_party_pressed() -> void:
	GameManager.create_party()
	refresh()


func _on_back_pressed() -> void:
	GameManager.go_to_encampment()
