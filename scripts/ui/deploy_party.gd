extends Control

## Lists only the parties eligible for deployment (GameSession.
## get_deployable_encamped_parties(), never the full roster) and treats
## selecting a row as the confirmation itself: it deploys immediately via
## GameManager.deploy_party(), which only changes scene on success. A row
## that has gone stale (its party stopped being eligible after this screen
## was drawn) fails deployment safely and this screen just refreshes the list
## in place instead of navigating anywhere.

@onready var party_list: VBoxContainer = $Center/VBox/PartyList
@onready var empty_label: Label = $Center/VBox/EmptyLabel
@onready var information_panel: PanelContainer = $InformationPanel


func _ready() -> void:
	information_panel.refresh()
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	_rebuild_party_rows()


## Rebuilds the row list from scratch. A row's own pressed handler can be the
## thing that triggers this rebuild (a failed deploy refreshes in place), so
## the old rows are only detached here and queue_free'd rather than free'd
## outright — freeing a node while its own "pressed" signal is still
## unwinding the call stack is invalid and the engine rejects it.
func _rebuild_party_rows() -> void:
	for child in party_list.get_children():
		party_list.remove_child(child)
		child.queue_free()

	var deployable: Array[Dictionary] = GameSession.get_deployable_encamped_parties()
	empty_label.visible = deployable.is_empty()

	for party in deployable:
		var row := Button.new()
		row.name = "PartyRow_%s" % party.id
		row.text = tr("deploy_party.party_row") % [party.name, party.member_ids.size()]
		row.pressed.connect(_on_party_row_pressed.bind(party.id))
		party_list.add_child(row)


func _on_party_row_pressed(party_id: String) -> void:
	if GameManager.deploy_party(party_id) == OK:
		return
	refresh()


func _on_back_pressed() -> void:
	GameManager.go_to_encampment()
