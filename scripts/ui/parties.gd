extends Control

## Lists every party as a selectable row and mirrors the selection into the
## shared InformationPanel. The panel never navigates itself (see
## information_panel.gd); this screen decides what its View button does.

@onready var party_list: VBoxContainer = $Center/VBox/PartyList
@onready var empty_label: Label = $Center/VBox/EmptyLabel
@onready var information_panel: PanelContainer = $InformationPanel

var selected_party_id: String = ""


func _ready() -> void:
	information_panel.party_selected.connect(_on_information_panel_party_selected)
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	_rebuild_party_rows()
	_refresh_selection()


## Rebuilds the row list from scratch. Rows are freed immediately (not
## queue_free'd) so a refresh called more than once per frame, as tests do,
# never leaves stale rows sitting alongside new ones.
func _rebuild_party_rows() -> void:
	for child in party_list.get_children():
		party_list.remove_child(child)
		child.free()

	var parties: Array[Dictionary] = GameSession.parties
	empty_label.visible = parties.is_empty()

	for party in parties:
		var row := Button.new()
		row.name = "PartyRow_%s" % party.id
		row.text = party.name
		row.pressed.connect(_on_party_row_pressed.bind(party.id))
		party_list.add_child(row)


func _on_party_row_pressed(party_id: String) -> void:
	selected_party_id = party_id
	_refresh_selection()


## A selection that no longer resolves to a real party (list refreshed out
## from under it) clears back to the safe, unselected empty state instead of
## leaving the panel pointed at a dead id.
func _refresh_selection() -> void:
	if GameSession.get_party(selected_party_id).is_empty():
		selected_party_id = ""
		information_panel.refresh()
		return
	information_panel.refresh_party(selected_party_id)


func _on_information_panel_party_selected(party_id: String) -> void:
	GameManager.go_to_party_details(party_id)


func _on_back_pressed() -> void:
	GameManager.go_to_encampment()
