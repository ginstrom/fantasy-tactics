extends Control

const WARRIOR_ID := "warrior_001"

@onready var party_status: Label = $Center/VBox/PartyStatus
@onready var create_party_button: Button = $Center/VBox/CreatePartyButton
@onready var add_warrior_button: Button = $Center/VBox/AddWarriorButton
@onready var remove_warrior_button: Button = $Center/VBox/RemoveWarriorButton


func _ready() -> void:
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	var party := GameSession.get_selected_party()
	var has_party := not party.is_empty()
	var warrior_is_assigned: bool = has_party and WARRIOR_ID in party.member_ids

	create_party_button.disabled = has_party
	add_warrior_button.visible = has_party and not warrior_is_assigned
	remove_warrior_button.visible = warrior_is_assigned
	if warrior_is_assigned:
		party_status.text = "party.status.assigned"
	elif has_party:
		party_status.text = "party.status.empty"
	else:
		party_status.text = "party.status.unassigned"


func _on_create_party_pressed() -> void:
	GameSession.create_party()
	refresh()


func _on_add_warrior_pressed() -> void:
	GameSession.assign_adventurer_to_selected_party(WARRIOR_ID)
	refresh()


func _on_remove_warrior_pressed() -> void:
	GameSession.remove_adventurer_from_selected_party(WARRIOR_ID)
	refresh()


func _on_back_pressed() -> void:
	GameManager.go_to_encampment()
