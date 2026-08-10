extends GutTest

const BlacksmithScene := preload("res://scenes/ui/blacksmith.tscn")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()


func test_blacksmith_shows_build_cost_before_it_has_been_built() -> void:
	var screen: Control = BlacksmithScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/BuildButton").text, "Build Blacksmith — 50 gold")
	assert_true(screen.get_node("Body/Center/VBox/BuildButton").visible)


func test_blacksmith_shows_parallel_job_countdowns_and_only_eligible_actions() -> void:
	GameSession.gold = 200
	assert_true(GameSession.build_blacksmith())
	GameSession.banked_gear["dagger_iron"] = 1
	assert_true(GameSession.start_sharpening("dagger_iron"))
	assert_true(GameSession.upgrade_blacksmith())
	assert_true(GameSession.start_blacksmith_craft("dagger_iron"))
	var screen: Control = BlacksmithScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/LevelLabel").text, "Blacksmith — Level 2")
	assert_eq(screen.get_node("Body/Center/VBox/CraftStatusLabel").text, "Crafting: Iron Dagger — 5 turns remaining")
	assert_eq(screen.get_node("Body/Center/VBox/SharpeningStatusLabel").text, "Sharpening: Iron Dagger — 20 turns remaining")
	assert_false(screen.get_node("Body/Center/VBox/CraftButton").visible)
	assert_false(screen.get_node("Body/Center/VBox/SharpenButton").visible)


func test_blacksmith_back_returns_to_buildings() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/blacksmith.gd")
	assert_string_contains(source, "GameManager.go_to_buildings()")


func test_blacksmith_keeps_the_selected_weapon_when_refreshing_its_craft_price() -> void:
	GameSession.gold = 200
	assert_true(GameSession.build_blacksmith())
	assert_true(GameSession.upgrade_blacksmith())
	var screen: Control = BlacksmithScene.instantiate()
	add_child_autofree(screen)
	var craft_options: OptionButton = screen.get_node("Body/Center/VBox/CraftItemOption")

	craft_options.select(1)
	screen._on_craft_item_option_item_selected(1)

	assert_eq(craft_options.get_selected_metadata(), "shortsword_iron")
	assert_eq(screen.get_node("Body/Center/VBox/CraftButton").text, "Craft — 9 gold")
