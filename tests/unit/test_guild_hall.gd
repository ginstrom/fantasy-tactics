extends GutTest

const GuildHallScene := preload("res://scenes/ui/guild_hall.tscn")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()


func test_guild_hall_shows_the_title_and_the_back_action() -> void:
	var screen: Control = GuildHallScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Center/VBox/Title").text, "guild_hall.title")
	assert_eq(screen.get_node("Center/VBox/BackButton").text, "ui.back")


func test_level_one_default_display_shows_the_level_and_party_size() -> void:
	var screen: Control = GuildHallScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Center/VBox/LevelLabel").text, tr("guild_hall.level") % 1)
	assert_eq(screen.get_node("Center/VBox/PartySizeLabel").text, tr("guild_hall.party_size") % 4)


func test_upgrade_button_is_disabled_below_the_upgrade_cost_and_enabled_at_it() -> void:
	var screen: Control = GuildHallScene.instantiate()
	add_child_autofree(screen)
	var upgrade_button: Button = screen.get_node("Center/VBox/UpgradeButton")

	assert_true(upgrade_button.visible)
	assert_true(upgrade_button.disabled, "Level 1 with no gold cannot afford the upgrade")
	assert_eq(upgrade_button.text, tr("guild_hall.upgrade") % GameSession.GUILD_HALL_UPGRADE_COST)

	GameSession.gold = GameSession.GUILD_HALL_UPGRADE_COST
	screen.refresh()

	assert_false(upgrade_button.disabled, "50 gold is exactly enough to afford the upgrade")


func test_pressing_upgrade_raises_the_guild_hall_level_and_shows_the_max_level_state() -> void:
	GameSession.gold = GameSession.GUILD_HALL_UPGRADE_COST
	var screen: Control = GuildHallScene.instantiate()
	add_child_autofree(screen)
	var upgrade_button: Button = screen.get_node("Center/VBox/UpgradeButton")

	upgrade_button.emit_signal("pressed")

	assert_eq(GameSession.guild_hall_level, 2)
	assert_false(screen.get_node("Center/VBox/UpgradeButton").visible, "Max level has no further upgrade to offer")
	assert_true(screen.get_node("Center/VBox/MaxLevelLabel").visible)
	assert_eq(screen.get_node("Center/VBox/PartySizeLabel").text, tr("guild_hall.party_size") % 5)


func test_back_button_returns_to_buildings() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/guild_hall.gd")
	assert_string_contains(source, "GameManager.go_to_buildings()")


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
