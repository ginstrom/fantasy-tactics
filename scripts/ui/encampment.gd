extends Control

## Encampment Building Tier Visual States (Technical Design §5,
## docs/plans/2026-08-18-core-loop-and-engagement/
## 07-visual-perspective-and-tactical-polish.md): placeholder art/color +
## a tier name per building level, purely presentational -- these dicts
## never gate or change what GameSession itself does at each level, only how
## that level's card looks. Guild Hall/Shop both cap at level 3 (matching
## GameSession.GUILD_HALL_MAX_LEVEL/shop's own level-3 upgrade path); Temple
## currently only ever reaches level 1 (GameSession.TEMPLE_MAX_LEVEL == 1,
## per vision.md's "Temple recruitment and its later Cleric/Paladin path
## remain deferred campaign-slice work") -- its tier2 entry below is inert
## today and simply becomes reachable, with no code change here, the moment
## that deferred decision ships a second Temple level.
const GUILD_HALL_TIER_NAME_KEYS := {
	1: "encampment.building.guild_hall.tier1",
	2: "encampment.building.guild_hall.tier2",
	3: "encampment.building.guild_hall.tier3",
}
const GUILD_HALL_TIER_COLORS := {
	1: Color(0.55, 0.4, 0.25),
	2: Color(0.5, 0.5, 0.55),
	3: Color(0.85, 0.7, 0.25),
}
const TEMPLE_TIER_NAME_KEYS := {
	1: "encampment.building.temple.tier1",
	2: "encampment.building.temple.tier2",
}
const TEMPLE_TIER_COLORS := {
	1: Color(0.6, 0.75, 0.9),
	2: Color(0.55, 0.35, 0.75),
}
const SHOP_TIER_NAME_KEYS := {
	1: "encampment.building.shop.tier1",
	2: "encampment.building.shop.tier2",
	3: "encampment.building.shop.tier3",
}
const SHOP_TIER_COLORS := {
	1: Color(0.65, 0.55, 0.35),
	2: Color(0.35, 0.6, 0.4),
	3: Color(0.8, 0.65, 0.2),
}

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
@onready var guild_hall_art: ColorRect = %GuildHallArt
@onready var guild_hall_name: Label = %GuildHallName
@onready var guild_hall_level_label: Label = %GuildHallLevel
@onready var temple_card: PanelContainer = %TempleCard
@onready var temple_art: ColorRect = %TempleArt
@onready var temple_name: Label = %TempleName
@onready var temple_level_label: Label = %TempleLevel
@onready var shop_card: PanelContainer = %ShopCard
@onready var shop_art: ColorRect = %ShopArt
@onready var shop_name: Label = %ShopName
@onready var shop_level_label: Label = %ShopLevel

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
	_refresh_building_cards()


## Guild Hall is always built (GameSession.guild_hall_level starts at 1 and
## never drops), so its card always shows -- Temple/Shop only once their
## level is > 0 (mirroring stores.gd's own `shop_level > 0` gate and
## temple.gd's `temple_level > 0` "built" check).
func _refresh_building_cards() -> void:
	_update_building_card(
		guild_hall_art, guild_hall_name, guild_hall_level_label,
		GameSession.guild_hall_level, GUILD_HALL_TIER_NAME_KEYS, GUILD_HALL_TIER_COLORS
	)
	temple_card.visible = GameSession.temple_level > 0
	if temple_card.visible:
		_update_building_card(
			temple_art, temple_name, temple_level_label,
			GameSession.temple_level, TEMPLE_TIER_NAME_KEYS, TEMPLE_TIER_COLORS
		)
	shop_card.visible = GameSession.shop_level > 0
	if shop_card.visible:
		_update_building_card(
			shop_art, shop_name, shop_level_label,
			GameSession.shop_level, SHOP_TIER_NAME_KEYS, SHOP_TIER_COLORS
		)


func _update_building_card(
	art: ColorRect, name_label: Label, level_label: Label, level: int, tier_name_keys: Dictionary, tier_colors: Dictionary
) -> void:
	art.color = tier_colors.get(level, tier_colors[1])
	name_label.text = tr(tier_name_keys.get(level, tier_name_keys[1]))
	level_label.text = tr("encampment.building.level") % level


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
