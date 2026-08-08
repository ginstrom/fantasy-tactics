extends GutTest

const DebugMenuScene := preload("res://scenes/debug/debug_menu.tscn")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	# The Ruined Fortress scenario pins these rolls to force its maximum
	# Kobold count; restore real randomness so later tests/files aren't
	# affected by this singleton's leftover state.
	GameSession.enemy_composition_roll = func(option_count: int) -> int: return randi() % option_count
	GameSession.enemy_count_roll = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)


func test_debug_menu_starts_hidden_with_eleven_stable_scenario_buttons() -> void:
	var menu: CanvasLayer = DebugMenuScene.instantiate()
	add_child_autofree(menu)

	assert_false(menu.visible)
	assert_eq(menu.get_node("Panel/Rows/NewCampaignButton").text, "debug.new_campaign")
	assert_eq(menu.get_node("Panel/Rows/EncampmentButton").text, "debug.encampment")
	assert_eq(menu.get_node("Panel/Rows/PartyManagerButton").text, "debug.party_manager")
	assert_eq(menu.get_node("Panel/Rows/PartyReadyButton").text, "debug.party_ready")
	assert_eq(menu.get_node("Panel/Rows/PartyEmptyButton").text, "debug.party_empty")
	assert_eq(menu.get_node("Panel/Rows/WorldMapButton").text, "debug.world_map")
	assert_eq(menu.get_node("Panel/Rows/GoblinCampButton").text, "debug.goblin_camp")
	assert_eq(menu.get_node("Panel/Rows/OrcOutpostButton").text, "debug.orc_outpost")
	assert_eq(menu.get_node("Panel/Rows/StockedStoresButton").text, "debug.stocked_stores")
	assert_eq(menu.get_node("Panel/Rows/SuperPowerButton").text, "debug.super_power")
	assert_eq(menu.get_node("Panel/Rows/RecruitButton").text, "debug.recruit")


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


func test_ruined_fortress_scenario_deploys_a_staffed_party_and_fields_eight_kobolds() -> void:
	assert_eq(GameManager.run_debug_scenario("ruined_fortress"), OK)

	var battlefield: Node2D = preload("res://scenes/battle/battlefield.tscn").instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	var enemy_units: Array = []
	for unit in controller.units:
		if unit.side == BattleControllerScript.Side.ENEMY:
			enemy_units.append(unit)
	assert_eq(enemy_units.size(), 8, "The forced Kobold roll should field the maximum count")
	for unit in enemy_units:
		assert_eq(unit.max_health, 6, "Every fielded unit should be a Kobold")


func test_ruined_fortress_button_runs_the_ruined_fortress_debug_scenario() -> void:
	var menu: CanvasLayer = DebugMenuScene.instantiate()
	add_child_autofree(menu)
	menu.visible = true

	menu._on_ruined_fortress_pressed()

	assert_false(menu.visible, "A successful scenario run should close the menu, like the other buttons")


func test_stocked_stores_button_populates_the_trading_post_and_routes_to_stores() -> void:
	var menu: CanvasLayer = DebugMenuScene.instantiate()
	add_child_autofree(menu)
	menu.visible = true

	menu._on_stocked_stores_pressed()

	assert_true(GameSession.has_trading_post)
	assert_eq(GameSession.mana_crystals, {1: 2})
	assert_eq(GameSession.banked_gear, {"shortsword_iron": 1})
	assert_false(menu.visible, "A successful scenario run should close the menu, like the other buttons")


func test_super_power_button_stays_open_without_an_active_battlefield() -> void:
	var menu: CanvasLayer = DebugMenuScene.instantiate()
	add_child_autofree(menu)
	menu.visible = true

	menu._on_super_power_pressed()

	assert_true(menu.visible, "There is nothing to apply Super Power to outside of a battle")


func test_super_power_button_maxes_the_party_and_closes_the_menu_during_a_battle() -> void:
	GameSession.reset()
	var battlefield: Node2D = preload("res://scenes/battle/battlefield.tscn").instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	var menu: CanvasLayer = DebugMenuScene.instantiate()
	add_child_autofree(menu)
	menu.visible = true

	menu._on_super_power_pressed()

	assert_false(menu.visible)
	assert_eq(warrior.move_range, 100)
	assert_eq(warrior.damage_min, 100)
	assert_eq(warrior.damage_max, 100)
	assert_eq(warrior.hit_chance, 1.0)


func test_party_empty_button_runs_the_party_empty_debug_scenario() -> void:
	var menu: CanvasLayer = DebugMenuScene.instantiate()
	add_child_autofree(menu)
	menu.visible = true

	menu._on_party_empty_pressed()

	assert_eq(GameSession.get_selected_party().member_ids, [] as Array[String])
	assert_false(GameSession.has_deployed_party())
	assert_false(menu.visible, "A successful scenario run should close the menu, like the other buttons")


func test_recruit_button_adds_an_adventurer_and_closes_the_menu() -> void:
	GameSession.reset()
	var menu: CanvasLayer = DebugMenuScene.instantiate()
	add_child_autofree(menu)
	menu.visible = true

	menu._on_recruit_pressed()

	assert_eq(GameSession.adventurers.size(), 2)
	assert_false(menu.visible, "A successful recruit should close the menu, like Super Power")
