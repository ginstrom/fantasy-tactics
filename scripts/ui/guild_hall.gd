extends Control

## Shows the Guild Hall's current level and the party-size cap it grants,
## plus (below the level cap) an Upgrade action gated on GameSession.
## can_upgrade_guild_hall() — the same gold/level rule GameSession enforces
## for the upgrade itself (see game_session.gd), so this screen can never
## offer an upgrade it can't actually perform. At the max level the Upgrade
## action disappears entirely and a Max Level label takes its place, the
## same "retire an action that no longer applies" pattern party_details.gd
## uses for Add Member on a deployed party.

@onready var level_label: Label = $Body/Center/VBox/LevelLabel
@onready var party_size_label: Label = $Body/Center/VBox/PartySizeLabel
@onready var upgrade_button: Button = $Body/Center/VBox/UpgradeButton
@onready var max_level_label: Label = $Body/Center/VBox/MaxLevelLabel


func _ready() -> void:
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	level_label.text = tr("guild_hall.level") % GameSession.guild_hall_level
	party_size_label.text = tr("guild_hall.party_size") % GameSession.get_max_party_size()

	var at_max_level: bool = GameSession.guild_hall_level >= GameSession.GUILD_HALL_MAX_LEVEL
	upgrade_button.visible = not at_max_level
	upgrade_button.disabled = not GameSession.can_upgrade_guild_hall()
	upgrade_button.text = tr("guild_hall.upgrade") % GameSession.GUILD_HALL_UPGRADE_COST
	max_level_label.visible = at_max_level


func _on_upgrade_button_pressed() -> void:
	GameSession.upgrade_guild_hall()
	refresh()


func _on_back_pressed() -> void:
	GameManager.go_to_buildings()
