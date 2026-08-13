extends Control

## Units hub. Parties, Roster, and Recruitment all route to real screens.

@onready var parties_label: Label = $Body/Center/VBox/PartiesRow/PartiesLabel
@onready var parties_view_button: Button = $Body/Center/VBox/PartiesRow/PartiesViewButton
@onready var roster_label: Label = $Body/Center/VBox/RosterRow/RosterLabel
@onready var roster_view_button: Button = $Body/Center/VBox/RosterRow/RosterViewButton
@onready var recruitment_label: Label = $Body/Center/VBox/RecruitmentRow/RecruitmentLabel
@onready var recruitment_view_button: Button = $Body/Center/VBox/RecruitmentRow/RecruitmentViewButton
@onready var information_panel: PanelContainer = %InformationPanel


func _ready() -> void:
	parties_view_button.text = tr("units.view")
	roster_view_button.text = tr("units.view")
	recruitment_view_button.text = tr("units.view")
	information_panel.refresh()
	refresh()



func refresh() -> void:
	parties_label.text = tr("units.parties_count") % GameSession.parties.size()
	roster_label.text = tr("units.roster_count") % GameSession.adventurers.size()
	recruitment_label.text = tr("units.recruitment_count") % GameSession.get_recruitment_candidates().size()



func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func _on_roster_pressed() -> void:
	GameManager.go_to_roster()


func _on_parties_pressed() -> void:
	GameManager.go_to_parties()


func _on_recruitment_pressed() -> void:
	GameManager.go_to_recruitment()


func _on_back_pressed() -> void:
	GameManager.go_to_encampment()
