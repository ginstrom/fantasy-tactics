extends Control

@onready var population_label: Label = $Body/Center/VBox/PopulationLabel
@onready var parties_label: Label = $Body/Center/VBox/PartiesLabel
@onready var units_label: Label = $Body/Center/VBox/UnitsLabel
@onready var information_panel: PanelContainer = $InformationPanel


func _ready() -> void:
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	population_label.text = tr("encampment.population") % GameSession.adventurers.size()
	parties_label.text = tr("encampment.parties_count") % GameSession.get_encamped_parties().size()
	units_label.text = tr("encampment.units_count") % _count_encamped_units()
	information_panel.refresh()


## Adventurers currently physically present at the encampment: the roster
## minus whoever is out with a deployed party (an encamped-but-unassigned
## party's members still count as present).
func _count_encamped_units() -> int:
	var deployed_member_ids: Array = []
	for party in GameSession.parties:
		if party.get("deployed", false):
			deployed_member_ids.append_array(party.member_ids)
	return GameSession.adventurers.size() - deployed_member_ids.size()
