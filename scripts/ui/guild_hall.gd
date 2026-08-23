extends Control

## Shows the Guild Hall's current level and the party-size cap it grants,
## plus (below the level cap) an Upgrade action gated on GameSession.
## can_upgrade_guild_hall() — the same gold/level rule GameSession enforces
## for the upgrade itself (see game_session.gd), so this screen can never
## offer an upgrade it can't actually perform. At the max level the Upgrade
## action disappears entirely and a Max Level label takes its place, the
## same "retire an action that no longer applies" pattern party_details.gd
## uses for Add Member on a deployed party.
##
## Also the Watchtower purchase/upgrade UI and the Guild Hall quest board
## (docs/designs/intelligence.md, Stage 5 Step 2): both call straight into
## GameSession (upgrade_watchtower()/accept_quest()), the same "the screen
## never re-derives eligibility, it just calls the durable-state owner and
## re-refreshes" pattern the pre-existing Guild Hall Upgrade button above
## already uses -- neither one is routed through a GameManager wrapper,
## since GameManager only exists for scene navigation and this screen never
## navigates as a result of either action.

@onready var level_label: Label = $Body/Center/VBox/LevelLabel
@onready var party_size_label: Label = $Body/Center/VBox/PartySizeLabel
@onready var roster_cap_label: Label = $Body/Center/VBox/RosterCapLabel
@onready var offer_cap_label: Label = $Body/Center/VBox/OfferCapLabel
@onready var upgrade_button: Button = $Body/Center/VBox/UpgradeButton
@onready var max_level_label: Label = $Body/Center/VBox/MaxLevelLabel
@onready var watchtower_level_label: Label = $Body/Center/VBox/WatchtowerLevelLabel
@onready var watchtower_upgrade_button: Button = $Body/Center/VBox/WatchtowerUpgradeButton
@onready var watchtower_max_level_label: Label = $Body/Center/VBox/WatchtowerMaxLevelLabel
@onready var quests_empty_label: Label = $Body/Center/VBox/QuestsEmptyLabel
@onready var quest_list: VBoxContainer = $Body/Center/VBox/QuestList


func _ready() -> void:
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	level_label.text = tr("guild_hall.level") % GameSession.guild_hall_level
	party_size_label.text = tr("guild_hall.party_size") % GameSession.get_max_party_size()
	roster_cap_label.text = tr("guild_hall.roster_cap") % GameSession.get_roster_cap()
	offer_cap_label.text = tr("guild_hall.offer_cap") % GameSession.get_recruitment_offer_cap()

	var at_max_level: bool = GameSession.guild_hall_level >= GameSession.GUILD_HALL_MAX_LEVEL
	upgrade_button.visible = not at_max_level
	upgrade_button.disabled = not GameSession.can_upgrade_guild_hall()
	var upgrade_key := "guild_hall.upgrade_to_level_3" if GameSession.guild_hall_level == 2 else "guild_hall.upgrade"
	var upgrade_cost := (
		GameSession.GUILD_HALL_LEVEL_3_UPGRADE_COST if GameSession.guild_hall_level == 2 else GameSession.GUILD_HALL_UPGRADE_COST
	)
	upgrade_button.text = tr(upgrade_key) % upgrade_cost
	max_level_label.visible = at_max_level

	_refresh_watchtower()
	_refresh_quests()


func _refresh_watchtower() -> void:
	watchtower_level_label.text = tr("guild_hall.watchtower.level") % GameSession.watchtower_level
	var at_max: bool = GameSession.watchtower_level >= GameSession.WATCHTOWER_MAX_LEVEL
	watchtower_upgrade_button.visible = not at_max
	watchtower_max_level_label.visible = at_max
	if not at_max:
		watchtower_upgrade_button.disabled = not GameSession.can_upgrade_watchtower()
		watchtower_upgrade_button.text = tr("guild_hall.watchtower.upgrade") % GameSession.get_watchtower_upgrade_cost()


## Rebuilds QuestList from scratch every refresh -- the same "clear then
## redraw" pattern world_map.gd's _draw_markers() uses for its own dynamic,
## GameSession-sourced list, rather than trying to diff/reuse rows in place.
func _refresh_quests() -> void:
	# remove_child() (not just queue_free()) so a same-named replacement row
	# added immediately below never collides with a same-frame pending-
	# deletion sibling -- queue_free() alone only marks a node for deletion
	# at the end of the frame, so get_children()/get_node() would otherwise
	# still see the stale row (and Godot would rename the new one to avoid a
	# duplicate sibling name) until then. queue_free() itself is still
	# required rather than free(): this can run from inside a quest row's
	# own AcceptButton "pressed" handler (see _on_quest_accept_pressed()),
	# and freeing a node synchronously while it is still emitting its own
	# signal up the call stack is unsafe.
	for child in quest_list.get_children():
		quest_list.remove_child(child)
		child.queue_free()

	var quests: Array[Dictionary] = GameSession.get_quests()
	quests_empty_label.visible = quests.is_empty()
	for quest in quests:
		quest_list.add_child(_build_quest_row(quest))


func _build_quest_row(quest: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.name = "Quest_%s" % quest.id

	var label := Label.new()
	label.name = "Label"
	label.text = tr("guild_hall.quests.row") % [
		int(quest.tier), tr("guild_hall.quests.status.%s" % quest.status), int(quest.reward_gold)
	]
	row.add_child(label)

	var accept_button := Button.new()
	accept_button.name = "AcceptButton"
	accept_button.text = tr("guild_hall.quests.accept")
	accept_button.visible = String(quest.status) == GameSession.QUEST_STATUS_POSTED
	accept_button.pressed.connect(_on_quest_accept_pressed.bind(String(quest.id)))
	row.add_child(accept_button)

	return row


func _on_quest_accept_pressed(quest_id: String) -> void:
	GameSession.accept_quest(quest_id)
	refresh()


func _on_watchtower_upgrade_button_pressed() -> void:
	GameSession.upgrade_watchtower()
	refresh()


func _on_upgrade_button_pressed() -> void:
	GameSession.upgrade_guild_hall()
	refresh()


func _on_back_pressed() -> void:
	GameManager.go_to_buildings()
