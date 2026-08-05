extends GutTest

const DebugMenuScene := preload("res://scenes/debug/debug_menu.tscn")


func before_each() -> void:
	GameSession.reset()


func test_debug_menu_starts_hidden_with_seven_stable_scenario_buttons() -> void:
	var menu: CanvasLayer = DebugMenuScene.instantiate()
	add_child_autofree(menu)

	assert_false(menu.visible)
	assert_eq(menu.get_node("Panel/Rows/NewCampaignButton").text, "debug.new_campaign")
	assert_eq(menu.get_node("Panel/Rows/EncampmentButton").text, "debug.encampment")
	assert_eq(menu.get_node("Panel/Rows/PartyManagerButton").text, "debug.party_manager")
	assert_eq(menu.get_node("Panel/Rows/PartyReadyButton").text, "debug.party_ready")
	assert_eq(menu.get_node("Panel/Rows/WorldMapButton").text, "debug.world_map")
	assert_eq(menu.get_node("Panel/Rows/GoblinCampButton").text, "debug.goblin_camp")
	assert_eq(menu.get_node("Panel/Rows/OrcOutpostButton").text, "debug.orc_outpost")


func test_orc_outpost_button_runs_the_orc_outpost_debug_scenario() -> void:
	var menu: CanvasLayer = DebugMenuScene.instantiate()
	add_child_autofree(menu)
	menu.visible = true

	menu._on_orc_outpost_pressed()

	assert_eq(
		GameSession.selected_encounter,
		GameSession.ORC_OUTPOST_ID,
		"The button must drive the same run_debug_scenario('orc_outpost') path as the scenario menu"
	)
	assert_false(menu.visible, "A successful scenario run should close the menu, like the other buttons")
