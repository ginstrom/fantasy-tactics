extends PanelContainer

const PARTY_NAME := "Party 1"

@onready var player_name_label: Label = $Content/PlayerName
@onready var gold_label: Label = $Content/Gold
@onready var party_name_label: Label = $Content/PartyName
@onready var party_gold_margin: MarginContainer = $Content/PartyGoldMargin
@onready var party_gold_label: Label = $Content/PartyGoldMargin/PartyGold


func _ready() -> void:
	refresh()


## party_active lets a parent scene say whether "the party" is currently
## selected. Encampment has no selection concept, and any expedition reward is
## banked into the player's total the moment it's entered, so it always
## passes false. World Map passes its click-to-select toggle so party info
## only shows while a party marker is selected there.
func refresh(party_active: bool = false) -> void:
	player_name_label.text = tr("information.player") % GameSession.player_name
	gold_label.text = tr("information.gold") % GameSession.gold

	var show_party := party_active and not GameSession.get_selected_party().is_empty()
	party_name_label.visible = show_party
	party_gold_margin.visible = show_party
	if show_party:
		party_name_label.text = tr("information.party") % PARTY_NAME
		# The party's own earned-but-unbanked reward, shown as its own gold total.
		party_gold_label.text = tr("information.gold") % GameSession.pending_reward
