extends PanelContainer

const PARTY_NAME := "Party 1"

@onready var gold_label: Label = $Content/Gold
@onready var party_name_label: Label = $Content/PartyName


func _ready() -> void:
	refresh()


## party_active lets a parent scene say whether "the party" is currently
## selected. Encampment has no selection concept and always passes true, since
## it only ever manages the one existing party. World Map passes its
## click-to-select toggle so party info only shows while a party marker is
## selected there.
func refresh(party_active: bool = true) -> void:
	gold_label.text = tr("information.gold") % GameSession.gold

	var show_party := party_active and not GameSession.get_selected_party().is_empty()
	party_name_label.visible = show_party
	if show_party:
		party_name_label.text = tr("information.party") % PARTY_NAME
