extends GutTest

const AlchemyWorkshopScene := preload("res://scenes/ui/alchemy_workshop.tscn")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()


func test_workshop_shows_build_cost_before_it_has_been_built() -> void:
	var screen: Control = AlchemyWorkshopScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/BuildButton").text, "Build Alchemy Workshop — 50 gold")
	assert_true(screen.get_node("Body/Center/VBox/BuildButton").visible)


func test_level_two_workshop_shows_greater_potion_and_craft_countdown() -> void:
	GameSession.gold = 200
	GameSession.mana_crystals[2] = 1
	assert_true(GameSession.build_alchemy_workshop())
	assert_true(GameSession.upgrade_alchemy_workshop())
	assert_true(GameSession.start_alchemy_craft("greater_healing_potion"))
	var screen: Control = AlchemyWorkshopScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/LevelLabel").text, "Alchemy Workshop — Level 2")
	assert_eq(screen.get_node("Body/Center/VBox/CraftStatusLabel").text, "Crafting: Greater Healing Potion — 7 turns remaining")
	assert_false(screen.get_node("Body/Center/VBox/CraftButton").visible)


func test_workshop_back_returns_to_buildings() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/alchemy_workshop.gd")

	assert_string_contains(source, "GameManager.go_to_buildings()")
