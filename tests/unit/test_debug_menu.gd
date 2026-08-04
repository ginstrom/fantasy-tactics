extends GutTest

const DebugMenuScene := preload("res://scenes/debug/debug_menu.tscn")


func test_debug_menu_starts_hidden_with_six_stable_scenario_buttons() -> void:
	var menu: CanvasLayer = DebugMenuScene.instantiate()
	add_child_autofree(menu)

	assert_false(menu.visible)
	assert_eq(menu.get_node("Panel/Rows/NewCampaignButton").text, "debug.new_campaign")
	assert_eq(menu.get_node("Panel/Rows/EncampmentButton").text, "debug.encampment")
	assert_eq(menu.get_node("Panel/Rows/PartyManagerButton").text, "debug.party_manager")
	assert_eq(menu.get_node("Panel/Rows/PartyReadyButton").text, "debug.party_ready")
	assert_eq(menu.get_node("Panel/Rows/WorldMapButton").text, "debug.world_map")
	assert_eq(menu.get_node("Panel/Rows/GoblinCampButton").text, "debug.goblin_camp")
