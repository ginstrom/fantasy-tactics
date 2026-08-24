extends GutTest

const GuildHallScene := preload("res://scenes/ui/guild_hall.tscn")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()


func test_guild_hall_shows_the_title_and_the_back_action() -> void:
	var screen: Control = GuildHallScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/Title").text, "guild_hall.title")
	assert_eq(screen.get_node("Body/Center/VBox/BackButton").text, "ui.back")


## Guild Hall is reached from Buildings, one of the six top-level camp
## screens that all carry the persistent left-hand CampNav (see
## camp_nav.gd's doc comment) — every other sub-screen (PartyDetails,
## AddMember, UnitDetails, Recruitment) already includes it.
func test_guild_hall_contains_the_camp_nav() -> void:
	var screen: Control = GuildHallScene.instantiate()
	add_child_autofree(screen)

	assert_not_null(screen.get_node_or_null("Body/CampNav"))


func test_level_one_default_display_shows_the_level_party_size_and_caps() -> void:
	var screen: Control = GuildHallScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/LevelLabel").text, tr("guild_hall.level") % 1)
	assert_eq(screen.get_node("Body/Center/VBox/PartySizeLabel").text, tr("guild_hall.party_size") % 3)
	assert_eq(screen.get_node("Body/Center/VBox/RosterCapLabel").text, tr("guild_hall.roster_cap") % 10)
	assert_eq(screen.get_node("Body/Center/VBox/OfferCapLabel").text, tr("guild_hall.offer_cap") % 4)


## Stage 5 D5 (decision-ledger.md): Guild Hall level 3 is what raises
## GameSession.get_max_party_count() from 1 to 2 -- shown here alongside the
## pre-existing per-party size/roster/offer caps so the player can see why
## reaching level 3 matters for fielding a second party, not only through
## Parties' own already-existing caps_label.
func test_party_count_label_shows_one_below_level_three_and_two_at_it() -> void:
	var screen: Control = GuildHallScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/PartyCountLabel").text, tr("guild_hall.party_count") % 1)

	GameSession.gold = GameSession.GUILD_HALL_UPGRADE_COST
	screen.get_node("Body/Center/VBox/UpgradeButton").emit_signal("pressed")
	GameSession.gold = GameSession.GUILD_HALL_LEVEL_3_UPGRADE_COST
	screen.get_node("Body/Center/VBox/UpgradeButton").emit_signal("pressed")

	assert_eq(GameSession.guild_hall_level, 3)
	assert_eq(screen.get_node("Body/Center/VBox/PartyCountLabel").text, tr("guild_hall.party_count") % 2)


func test_upgrade_button_is_disabled_below_the_upgrade_cost_and_enabled_at_it() -> void:
	var screen: Control = GuildHallScene.instantiate()
	add_child_autofree(screen)
	var upgrade_button: Button = screen.get_node("Body/Center/VBox/UpgradeButton")

	assert_true(upgrade_button.visible)
	assert_true(upgrade_button.disabled, "Level 1 with no gold cannot afford the upgrade")
	assert_eq(upgrade_button.text, tr("guild_hall.upgrade") % GameSession.GUILD_HALL_UPGRADE_COST)

	GameSession.gold = GameSession.GUILD_HALL_UPGRADE_COST
	screen.refresh()

	assert_false(upgrade_button.disabled, "50 gold is exactly enough to afford the upgrade")


func test_pressing_upgrade_raises_the_guild_hall_level_and_shows_tier_two_state() -> void:
	GameSession.gold = GameSession.GUILD_HALL_UPGRADE_COST
	var screen: Control = GuildHallScene.instantiate()
	add_child_autofree(screen)
	var upgrade_button: Button = screen.get_node("Body/Center/VBox/UpgradeButton")

	upgrade_button.emit_signal("pressed")

	assert_eq(GameSession.guild_hall_level, 2)
	assert_true(screen.get_node("Body/Center/VBox/UpgradeButton").visible, "Level 2 still has a level 3 upgrade to offer")
	assert_false(screen.get_node("Body/Center/VBox/MaxLevelLabel").visible)
	assert_eq(screen.get_node("Body/Center/VBox/PartySizeLabel").text, tr("guild_hall.party_size") % 4)
	assert_eq(screen.get_node("Body/Center/VBox/RosterCapLabel").text, tr("guild_hall.roster_cap") % 15)
	assert_eq(screen.get_node("Body/Center/VBox/OfferCapLabel").text, tr("guild_hall.offer_cap") % 8)
	assert_eq(upgrade_button.text, tr("guild_hall.upgrade_to_level_3") % GameSession.GUILD_HALL_LEVEL_3_UPGRADE_COST)


func test_pressing_upgrade_at_level_two_reaches_the_max_level_state() -> void:
	GameSession.gold = GameSession.GUILD_HALL_UPGRADE_COST
	var screen: Control = GuildHallScene.instantiate()
	add_child_autofree(screen)
	screen.get_node("Body/Center/VBox/UpgradeButton").emit_signal("pressed")
	GameSession.gold = GameSession.GUILD_HALL_LEVEL_3_UPGRADE_COST
	screen.refresh()

	screen.get_node("Body/Center/VBox/UpgradeButton").emit_signal("pressed")

	assert_eq(GameSession.guild_hall_level, 3)
	assert_false(screen.get_node("Body/Center/VBox/UpgradeButton").visible, "Max level has no further upgrade to offer")
	assert_true(screen.get_node("Body/Center/VBox/MaxLevelLabel").visible)
	assert_eq(screen.get_node("Body/Center/VBox/PartySizeLabel").text, tr("guild_hall.party_size") % 5)
	assert_eq(screen.get_node("Body/Center/VBox/RosterCapLabel").text, tr("guild_hall.roster_cap") % 20)
	assert_eq(screen.get_node("Body/Center/VBox/OfferCapLabel").text, tr("guild_hall.offer_cap") % 10)


func test_back_button_returns_to_buildings() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/guild_hall.gd")
	assert_string_contains(source, "GameManager.go_to_buildings()")


## ---------------------------------------------------------------------
## Watchtower purchase (Stage 5 Step 2, docs/designs/intelligence.md).
## ---------------------------------------------------------------------


func test_watchtower_starts_unbuilt_and_the_upgrade_button_shows_tier_one_cost() -> void:
	var screen: Control = GuildHallScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/WatchtowerLevelLabel").text, tr("guild_hall.watchtower.level") % 0)
	var upgrade_button: Button = screen.get_node("Body/Center/VBox/WatchtowerUpgradeButton")
	assert_true(upgrade_button.visible)
	assert_true(upgrade_button.disabled, "No gold yet")
	assert_eq(upgrade_button.text, tr("guild_hall.watchtower.upgrade") % GameSession.WATCHTOWER_TIER_1_COST)
	assert_false(screen.get_node("Body/Center/VBox/WatchtowerMaxLevelLabel").visible)


func test_pressing_watchtower_upgrade_raises_its_level_and_deducts_gold() -> void:
	GameSession.gold = GameSession.WATCHTOWER_TIER_1_COST
	var screen: Control = GuildHallScene.instantiate()
	add_child_autofree(screen)
	var upgrade_button: Button = screen.get_node("Body/Center/VBox/WatchtowerUpgradeButton")

	upgrade_button.emit_signal("pressed")

	assert_eq(GameSession.watchtower_level, 1)
	assert_eq(GameSession.gold, 0)
	assert_eq(screen.get_node("Body/Center/VBox/WatchtowerLevelLabel").text, tr("guild_hall.watchtower.level") % 1)
	assert_eq(upgrade_button.text, tr("guild_hall.watchtower.upgrade") % GameSession.WATCHTOWER_TIER_2_COST)


func test_watchtower_at_max_level_hides_the_upgrade_button_and_shows_max_level() -> void:
	GameSession.watchtower_level = GameSession.WATCHTOWER_MAX_LEVEL
	var screen: Control = GuildHallScene.instantiate()
	add_child_autofree(screen)

	assert_false(screen.get_node("Body/Center/VBox/WatchtowerUpgradeButton").visible)
	assert_true(screen.get_node("Body/Center/VBox/WatchtowerMaxLevelLabel").visible)


## ---------------------------------------------------------------------
## Guild Hall quest board (Stage 5 Step 2, docs/designs/intelligence.md).
## ---------------------------------------------------------------------


func test_the_empty_label_shows_when_no_quests_are_posted() -> void:
	# quest_posting_roll defaults to real randomness; force it off so a fresh
	# reset() never posts a quest, keeping this assertion deterministic.
	GameSession.quest_posting_roll = func() -> float: return 100.0
	GameSession.reset()
	var screen: Control = GuildHallScene.instantiate()
	add_child_autofree(screen)

	assert_true(screen.get_node("Body/Center/VBox/QuestsEmptyLabel").visible)
	assert_eq(screen.get_node("Body/Center/VBox/QuestList").get_child_count(), 0)


func test_a_posted_quest_renders_a_row_with_an_accept_button() -> void:
	GameSession.quest_posting_roll = func() -> float: return 0.0  # guarantee goblin_camp posts a quest
	GameSession.reset()
	var quest: Dictionary = GameSession.get_quests()[0]
	var screen: Control = GuildHallScene.instantiate()
	add_child_autofree(screen)

	assert_false(screen.get_node("Body/Center/VBox/QuestsEmptyLabel").visible)
	var row: Node = screen.get_node("Body/Center/VBox/QuestList/Quest_%s" % quest.id)
	assert_not_null(row)
	assert_eq(
		row.get_node("Label").text,
		tr("guild_hall.quests.row") % [1, tr("guild_hall.quests.status.posted"), int(quest.reward_gold)]
	)
	assert_true(row.get_node("AcceptButton").visible)


func test_pressing_accept_on_a_quest_row_activates_it_and_hides_the_accept_button() -> void:
	GameSession.quest_posting_roll = func() -> float: return 0.0
	GameSession.reset()
	var quest_id: String = String(GameSession.get_quests()[0].id)
	var screen: Control = GuildHallScene.instantiate()
	add_child_autofree(screen)
	var row: Node = screen.get_node("Body/Center/VBox/QuestList/Quest_%s" % quest_id)

	row.get_node("AcceptButton").emit_signal("pressed")

	assert_eq(GameSession.get_quest(quest_id).status, GameSession.QUEST_STATUS_ACTIVE)
	var refreshed_row: Node = screen.get_node("Body/Center/VBox/QuestList/Quest_%s" % quest_id)
	assert_false(refreshed_row.get_node("AcceptButton").visible, "An already-accepted quest offers no further Accept action")
	assert_true(
		GameSession.get_encounter_intel(GameSession.GOBLIN_CAMP_ID).discovered,
		"Accepting must permanently discover the quest's target"
	)


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	var screen: Control = GuildHallScene.instantiate()
	add_child_autofree(screen)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)
