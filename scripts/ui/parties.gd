extends Control

## Lists every GameSession party as a TableView row, keyed by stable party id
## (TableView's default row_id_key), and mirrors the selected row into the
## shared InformationPanel — the same selection pattern Roster uses for
## adventurers (see roster.gd), applied to parties instead. Row activation and
## the panel's View button both open the existing Party Details screen; this
## screen never mutates a party itself.

const TableColumnDescriptor := preload("res://scripts/ui/table_column.gd")

@onready var party_table: TableView = $Body/Center/VBox/PartyTable
@onready var empty_label: Label = $Body/Center/VBox/EmptyLabel
@onready var create_party_button: Button = $Body/Center/VBox/CreatePartyButton
@onready var party_name_entry: VBoxContainer = $Body/Center/VBox/PartyNameEntry
@onready var party_name_input: LineEdit = $Body/Center/VBox/PartyNameEntry/NameRow/NameInput
@onready var party_name_confirm_button: Button = $Body/Center/VBox/PartyNameEntry/NameRow/ConfirmButton
@onready var information_panel: PanelContainer = %InformationPanel

const PARTY_NAME_CHOICES := ["Party 1", "Alpha Party"]

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
			"status": tr("party_status.deployed" if party.get("deployed", false) else "party_status.encamped"),
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
	party_name_input.text = ""
	party_name_confirm_button.disabled = true
	create_party_button.visible = false
	party_name_entry.visible = true
	party_name_input.grab_focus()


func _on_party_name_random_button_pressed() -> void:
	party_name_input.text = PARTY_NAME_CHOICES[randi() % PARTY_NAME_CHOICES.size()]
	_on_party_name_input_text_changed(party_name_input.text)


func _on_party_name_input_text_changed(new_text: String) -> void:
	party_name_confirm_button.disabled = new_text.strip_edges().is_empty()


func _on_party_name_input_text_submitted(_new_text: String) -> void:
	_on_party_name_confirm_pressed()


func _on_party_name_confirm_pressed() -> void:
	var entered_name := party_name_input.text.strip_edges()
	if entered_name.is_empty():
		return
	GameManager.create_party(entered_name)
	party_name_entry.visible = false
	create_party_button.visible = true
	refresh()


func _on_party_name_cancel_pressed() -> void:
	party_name_entry.visible = false
	create_party_button.visible = true


## Back steps up one level at a time: while the create-party name entry is
## showing, that sub-view is the current level, so Back cancels it (same as
## the entry's own Cancel button) and lands on the plain party list rather
## than jumping straight past it to Units.
func _on_back_pressed() -> void:
	if party_name_entry.visible:
		_on_party_name_cancel_pressed()
		return
	GameManager.go_to_units()
