extends Control

## Shows the roster of a single party (read from GameManager.route_context_id)
## and mirrors the selected member into the shared InformationPanel, the same
## selection pattern Parties uses for parties (see parties.gd). Add Member is
## hidden entirely for a deployed party, since you can't add a member to a
## party that's out in the field, and disabled for an encamped party with no
## available adventurer left to add.

@onready var party_name_label: Label = $Center/VBox/PartyNameLabel
@onready var member_list: VBoxContainer = $Center/VBox/MemberList
@onready var empty_label: Label = $Center/VBox/EmptyLabel
@onready var add_member_button: Button = $Center/VBox/AddMemberButton
@onready var information_panel: PanelContainer = $InformationPanel

var party_id: String = ""
var selected_adventurer_id: String = ""


func _ready() -> void:
	information_panel.adventurer_selected.connect(_on_information_panel_adventurer_selected)
	party_id = GameManager.route_context_id
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	var party := GameSession.get_party(party_id)
	if party.is_empty():
		party_name_label.text = ""
		_rebuild_member_rows([])
	else:
		party_name_label.text = party.name
		_rebuild_member_rows(party.member_ids)
	# A deployed party is out in the field; Add Member doesn't even make
	# sense to offer, so it disappears entirely rather than merely staying
	# disabled. An encamped party with nobody left to recruit keeps the
	# button visible but disabled, so its presence isn't a mystery.
	add_member_button.visible = not party.get("deployed", false)
	add_member_button.disabled = GameSession.get_available_adventurers().is_empty()
	_refresh_selection()


## Rebuilds the row list from scratch. remove_child() already takes each row
## off get_children() synchronously, so a refresh called more than once per
## frame, as tests do, never leaves stale rows sitting alongside new ones;
## queue_free() only defers the actual deallocation.
func _rebuild_member_rows(member_ids: Array) -> void:
	for child in member_list.get_children():
		member_list.remove_child(child)
		child.queue_free()

	empty_label.visible = member_ids.is_empty()

	for adventurer_id in member_ids:
		var adventurer := GameSession.get_adventurer(adventurer_id)
		if adventurer.is_empty():
			continue
		var row := Button.new()
		row.name = "MemberRow_%s" % adventurer_id
		row.text = tr("party_details.member_row") % [
			adventurer["name"], adventurer["class"], adventurer["level"]
		]
		row.pressed.connect(_on_member_row_pressed.bind(adventurer_id))
		member_list.add_child(row)


func _on_member_row_pressed(adventurer_id: String) -> void:
	selected_adventurer_id = adventurer_id
	_refresh_selection()


## A selection is only valid while it names a current member of this party
## (not merely an adventurer that still exists somewhere): the party may have
## been reset out from under this screen, or the member may have left the
## party. Either way this clears back to the safe, unselected empty state
## instead of leaving the panel pointed at a stale id.
func _refresh_selection() -> void:
	var party := GameSession.get_party(party_id)
	var member_ids: Array = party.get("member_ids", [])
	if selected_adventurer_id == "" or not selected_adventurer_id in member_ids:
		selected_adventurer_id = ""
		information_panel.refresh()
		return
	information_panel.refresh_adventurer(selected_adventurer_id)


func _on_information_panel_adventurer_selected(adventurer_id: String) -> void:
	GameManager.go_to_unit_details(adventurer_id)


func _on_add_member_pressed() -> void:
	GameManager.go_to_add_member(party_id)


## Reachable from both Parties (an encamped party) and, since World Map's
## View Party button was wired up, from World Map (a deployed party). Back
## must return to whichever of those the player actually came from instead
## of always landing on Parties — otherwise a deployed party visually
## "teleports" back to the Encampment. route_context_id is cleared here
## directly (rather than relying on the destination route to do it) because
## go_to_world_map() does not clear it the way go_to_parties() does.
func _on_back_pressed() -> void:
	var deployed: bool = GameSession.get_party(party_id).get("deployed", false)
	GameManager.route_context_id = ""
	if deployed:
		GameManager.go_to_world_map()
	else:
		GameManager.go_to_parties()
