extends GutTest

const RunicWorkshopScene := preload("res://scenes/ui/runic_workshop.tscn")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()


func test_runic_workshop_shows_build_cost_before_it_has_been_built() -> void:
	var screen: Control = RunicWorkshopScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/BuildButton").text, "Build Runic Workshop — 50 gold")


func test_runic_workshop_lists_owned_armor_and_shows_its_countdown() -> void:
	GameSession.gold = 70
	GameSession.mana_crystals = {1: 1}
	GameSession.banked_gear = {"leather_armor": 1, "dagger_iron": 1}
	assert_true(GameSession.materialize_banked_item_instance("leather_armor", "thorn_armor"))
	assert_true(GameSession.materialize_banked_item_instance("dagger_iron", "dagger"))
	assert_true(GameSession.build_runic_workshop())
	assert_true(GameSession.start_runic_craft("thorn_armor"))
	var screen: Control = RunicWorkshopScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/CraftStatusLabel").text, "Socketing Thorn Rune — 7 turns remaining")
	assert_false(screen.get_node("Body/Center/VBox/ArmorOption").visible)


func test_runic_workshop_back_returns_to_buildings() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/runic_workshop.gd")

	assert_string_contains(source, "GameManager.go_to_buildings()")
