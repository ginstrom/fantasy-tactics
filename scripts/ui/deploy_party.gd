extends Control

## Lists only the parties eligible for deployment (GameSession.
## get_deployable_encamped_parties(), never the full roster) as a TableView
## row per party, keyed by stable party id, and treats activating a row as
## the confirmation itself: it deploys immediately via GameManager.
## deploy_party(), which only changes scene on success. A row that has gone
## stale (its party stopped being eligible after this screen was drawn) fails
## deployment safely and this screen just refreshes the list in place instead
## of navigating anywhere. Selecting (rather than activating) a row only
## mirrors it into the shared InformationPanel as a summary, the same
## selection pattern Parties uses for parties (see parties.gd); it never
## deploys by itself.

const TableColumnDescriptor := preload("res://scripts/ui/table_column.gd")

@onready var party_table: TableView = $Center/VBox/PartyTable
@onready var empty_label: Label = $Center/VBox/EmptyLabel
@onready var information_panel: PanelContainer = $InformationPanel

var selected_party_id: String = ""


func _ready() -> void:
	information_panel.party_selected.connect(_on_information_panel_party_selected)
	information_panel.refresh()
	party_table.row_selected.connect(_on_row_selected)
	party_table.row_activated.connect(_on_row_activated)
	party_table.set_columns(_build_columns())
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	var rows := _build_rows()
	party_table.set_rows(rows)
	empty_label.visible = rows.is_empty()
	_refresh_selection()


func _build_columns() -> Array[TableColumn]:
	var name_column := TableColumnDescriptor.new(&"name", tr("deploy_party.column.party"))
	name_column.expand = true
	name_column.expand_ratio = 2
	var members_column := TableColumnDescriptor.new(
		&"member_count", tr("deploy_party.column.members"), TableColumnDescriptor.Type.INTEGER
	)
	var status_column := TableColumnDescriptor.new(&"status", tr("deploy_party.column.status"))
	return [name_column, members_column, status_column]


func _build_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for party in GameSession.get_deployable_encamped_parties():
		rows.append({
			"id": party.id,
			"name": party.name,
			"member_count": party.member_ids.size(),
			"status": tr("party_status.deployed" if party.get("deployed", false) else "party_status.encamped"),
		})
	return rows


## A selection that no longer names a currently deployable party (deployed or
## invalidated elsewhere while this screen was open) clears back to the safe,
## unselected empty state instead of leaving the panel pointed at a stale id.
func _refresh_selection() -> void:
	if selected_party_id == "" or not GameSession.is_party_deployable(selected_party_id):
		selected_party_id = ""
		information_panel.refresh()
		return
	information_panel.refresh_party(selected_party_id)


func _on_row_selected(row_id: Variant) -> void:
	selected_party_id = str(row_id)
	_refresh_selection()


func _on_row_activated(row_id: Variant) -> void:
	if GameManager.deploy_party(str(row_id)) == OK:
		return
	refresh()


func _on_information_panel_party_selected(party_id: String) -> void:
	GameManager.go_to_party_details(party_id)


func _on_back_pressed() -> void:
	GameManager.go_to_encampment()
