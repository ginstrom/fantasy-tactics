extends Control

## Lists GameSession.get_available_adventurers() for the party named by
## GameManager.route_context_id (see party_details.gd, which sets it before
## routing here) and treats selecting a row as the assignment itself: it
## calls GameManager.assign_adventurer_to_party() immediately, then returns
## to Party Details on success. A row that has gone stale (its adventurer
## got assigned elsewhere while this screen was open) fails safely and this
## screen just refreshes the list in place instead of navigating anywhere.

@onready var adventurer_list: VBoxContainer = $Center/VBox/AdventurerList
@onready var empty_label: Label = $Center/VBox/EmptyLabel
@onready var information_panel: PanelContainer = $InformationPanel

var party_id: String = ""


func _ready() -> void:
	information_panel.refresh()
	party_id = GameManager.route_context_id
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	_rebuild_adventurer_rows()


## Rebuilds the row list from scratch. remove_child() already takes each row
## off get_children() synchronously, so a refresh called more than once per
## frame, as tests do, never leaves stale rows sitting alongside new ones;
## queue_free() only defers the actual deallocation.
func _rebuild_adventurer_rows() -> void:
	for child in adventurer_list.get_children():
		adventurer_list.remove_child(child)
		child.queue_free()

	var available: Array[Dictionary] = GameSession.get_available_adventurers()
	empty_label.visible = available.is_empty()

	for adventurer in available:
		var row := Button.new()
		row.name = "AdventurerRow_%s" % adventurer.id
		row.text = tr("add_member.member_row") % [
			adventurer["name"], adventurer["class"], adventurer["level"]
		]
		row.pressed.connect(_on_adventurer_row_pressed.bind(adventurer.id))
		adventurer_list.add_child(row)


func _on_adventurer_row_pressed(adventurer_id: String) -> void:
	if GameManager.assign_adventurer_to_party(party_id, adventurer_id) == OK:
		GameManager.go_to_party_details(party_id)
		return
	refresh()


func _on_back_pressed() -> void:
	GameManager.go_to_party_details(party_id)
