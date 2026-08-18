extends Control

@onready var population_label: Label = $Body/Center/VBox/PopulationLabel
@onready var parties_label: Label = $Body/Center/VBox/PartiesLabel
@onready var units_label: Label = $Body/Center/VBox/UnitsLabel
@onready var information_panel: PanelContainer = %InformationPanel
@onready var campaign_guide: PanelContainer = %CampaignGuide
@onready var campaign_objective_banner: PanelContainer = %CampaignObjectiveBanner
@onready var first_party_dialog: PanelContainer = $FirstPartyDialog
@onready var first_party_title: Label = $FirstPartyDialog/Content/Title
@onready var first_party_message: Label = $FirstPartyDialog/Content/Message
@onready var first_party_create_button: Button = $FirstPartyDialog/Content/Buttons/CreateButton
@onready var first_party_dismiss_button: Button = $FirstPartyDialog/Content/Buttons/DismissButton

var first_party_dialog_dismissed := false


func _ready() -> void:
	first_party_title.text = tr("encampment.first_party.title")
	first_party_message.text = tr("encampment.first_party.message")
	first_party_create_button.text = tr("encampment.first_party.create")
	first_party_dismiss_button.text = tr("encampment.first_party.dismiss")
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
	campaign_guide.refresh()
	campaign_objective_banner.refresh()
	first_party_dialog.visible = GameSession.parties.is_empty() and not first_party_dialog_dismissed


func _on_first_party_create_pressed() -> void:
	GameManager.go_to_parties(true)



func _on_first_party_dismiss_pressed() -> void:
	first_party_dialog_dismissed = true
	first_party_dialog.visible = false


## Adventurers currently physically present at the encampment: the roster
## minus whoever is out with a deployed party (an encamped-but-unassigned
## party's members still count as present).
func _count_encamped_units() -> int:
	var deployed_member_ids: Array = []
	for party in GameSession.parties:
		if party.get("deployed", false):
			deployed_member_ids.append_array(party.member_ids)
	return GameSession.adventurers.size() - deployed_member_ids.size()
