extends GutTest

const DebugMenuScene := preload("res://scenes/debug/debug_menu.tscn")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const DebugScenariosScript := preload("res://scripts/debug/debug_scenarios.gd")
const TEST_MANIFEST_PATH := "user://test_debug_menu_manifest.json"


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	# Defensive: nothing in this file pins GameSession.enemy_composition_roll/
	# enemy_count_roll today (see test_ruined_fortress_scenario_does_not_leak_
	# state_into_a_later_scenario()'s own comment), but restore real
	# randomness anyway so a later test/file can never inherit a pin left
	# behind by a failed assertion here.
	GameSession.reset_injectable_rolls()

	# Several tests below reload TEST_MANIFEST_PATH, replacing DebugScenarios'
	# shared static cache -- always reload the real one afterward so no test
	# here can leak a synthetic scenario list into another test file (see
	# test_debug_scenarios.gd's after_each for the same rationale).
	if FileAccess.file_exists(TEST_MANIFEST_PATH):
		DirAccess.remove_absolute(TEST_MANIFEST_PATH)
	DebugScenariosScript.load_scenarios()


func _write_debug_menu_manifest(scenarios: Array) -> void:
	var file := FileAccess.open(TEST_MANIFEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"manifest_version": 1, "scenarios": scenarios}))
	file.close()


func _scenario_dict(id: String, category: String, campaign_snapshot: Dictionary = {"version": 1}) -> Dictionary:
	return {
		"id": id,
		"name_key": "debug.%s_test_scenario" % id,
		"category": category,
		"description": "Synthetic scenario for a test-injected manifest.",
		"launch": {"scene": "encampment"},
		"campaign_snapshot": campaign_snapshot,
	}


## --- Dynamic scenario rendering (Step 4) -----------------------------------


func test_debug_menu_renders_one_button_per_manifest_scenario_grouped_by_category_in_source_order() -> void:
	var menu: CanvasLayer = DebugMenuScene.instantiate()
	add_child_autofree(menu)

	assert_false(menu.visible)

	var expected_categories := DebugScenariosScript.get_scenarios_by_category()
	var expected_scenario_count := 0
	var expected_headers: Array = []
	for category in expected_categories:
		expected_headers.append(category.category)
		for scenario in category.scenarios:
			expected_scenario_count += 1
			var button: Button = menu._scenario_buttons.get(scenario.id)
			assert_false(button == null, "expected a button for scenario %s" % scenario.id)
			if button != null:
				assert_eq(button.text, scenario.name_key, "scenario %s's button should show its localized name_key" % scenario.id)

	assert_eq(menu._scenario_buttons.size(), expected_scenario_count)

	var header_texts: Array = []
	for child in menu._scenario_container.get_children():
		if child is Label:
			header_texts.append(child.text)
	assert_eq(header_texts, expected_headers, "category headers must appear in the manifest's source order")


func test_debug_menu_preserves_the_super_power_and_recruit_utility_actions() -> void:
	var menu: CanvasLayer = DebugMenuScene.instantiate()
	add_child_autofree(menu)

	assert_eq(menu.get_node("Panel/Rows/UtilitiesFooter/SuperPowerButton").text, "debug.super_power")
	assert_eq(menu.get_node("Panel/Rows/UtilitiesFooter/RecruitButton").text, "debug.recruit")


## --- Safe reload (Step 4) ---------------------------------------------------


func test_reload_with_a_valid_edited_manifest_rebuilds_the_buttons() -> void:
	var menu: CanvasLayer = DebugMenuScene.instantiate()
	add_child_autofree(menu)

	_write_debug_menu_manifest([_scenario_dict("alpha", "Test")])
	var result: Dictionary = menu._reload(TEST_MANIFEST_PATH)

	assert_true(result.ok)
	assert_eq(menu._scenario_buttons.keys(), ["alpha"])
	assert_eq(menu._scenario_buttons["alpha"].text, "debug.alpha_test_scenario")


func test_reload_with_an_invalid_manifest_preserves_the_current_buttons_and_shows_an_error() -> void:
	var menu: CanvasLayer = DebugMenuScene.instantiate()
	add_child_autofree(menu)
	var original_ids: Array = menu._scenario_buttons.keys()

	var file := FileAccess.open(TEST_MANIFEST_PATH, FileAccess.WRITE)
	file.store_string("{ not valid json")
	file.close()
	var result: Dictionary = menu._reload(TEST_MANIFEST_PATH)

	assert_false(result.ok)
	assert_true(result.errors.size() > 0)
	assert_eq(menu._scenario_buttons.keys(), original_ids, "an invalid reload must not clear the menu")
	assert_string_contains(menu._status_label.text, result.errors[0], "the concise error text should be visible")


## --- Pressing a scenario button (Step 4) ------------------------------------


func test_pressing_a_scenario_button_invokes_run_debug_scenario_and_closes_the_menu_on_ok() -> void:
	var menu: CanvasLayer = DebugMenuScene.instantiate()
	add_child_autofree(menu)
	menu.visible = true

	menu._scenario_buttons["orc_outpost"].pressed.emit()

	assert_eq(
		GameSession.selected_encounter,
		GameSession.ORC_OUTPOST_ID,
		"the button must drive the same run_debug_scenario('orc_outpost') path as before"
	)
	assert_false(menu.visible, "a successful scenario run should close the menu")


func test_pressing_a_scenario_button_keeps_the_menu_open_when_the_launch_fails() -> void:
	var menu: CanvasLayer = DebugMenuScene.instantiate()
	add_child_autofree(menu)
	menu.visible = true

	# Force a failure without touching the real manifest: reload a scenario
	# whose campaign_snapshot fails CampaignSnapshot validation (a bare
	# {"version": 1} is missing every required durable field).
	_write_debug_menu_manifest([_scenario_dict("broken", "Test")])
	assert_true(menu._reload(TEST_MANIFEST_PATH).ok, "the manifest itself is well-formed; only the snapshot is invalid")

	menu._scenario_buttons["broken"].pressed.emit()

	assert_true(menu.visible, "a failed scenario run should not close the menu")


func test_ruined_fortress_scenario_deploys_a_staffed_party_of_three_warriors() -> void:
	assert_eq(GameManager.run_debug_scenario("ruined_fortress"), OK)

	var battlefield: Node2D = preload("res://scenes/battle/battlefield.tscn").instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	var player_units: Array = []
	for unit in controller.units:
		if unit.side != BattleControllerScript.Side.ENEMY:
			player_units.append(unit)

	# A lone Warrior is not a representative test of a large fight -- this
	# scenario stages three level-1 Warriors instead of the single-Warrior
	# party every other debug scenario uses.
	assert_eq(player_units.size(), 3, "The Ruined Fortress debug scenario should field three Warriors, not one")
	for unit in player_units:
		assert_eq(unit.max_health, 10, "Every fielded Warrior should be a fresh level-1 Warrior")


## Goblin Camp's difficulty has a single composition option with a fixed
## count of 1, so it fields its own Goblin regardless of what a preceding
## scenario did -- unlike the old field-by-field apply(), nothing in the
## manifest/snapshot-based apply() pins enemy_composition_roll/
## enemy_count_roll for any scenario anymore, so there is no pinned state
## left for a later scenario to inherit in the first place.
func test_ruined_fortress_scenario_does_not_leak_state_into_a_later_scenario() -> void:
	assert_eq(GameManager.run_debug_scenario("ruined_fortress"), OK)
	assert_eq(GameManager.run_debug_scenario("goblin_camp"), OK)

	var battlefield: Node2D = preload("res://scenes/battle/battlefield.tscn").instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	var enemy_units: Array = []
	for unit in controller.units:
		if unit.side == BattleControllerScript.Side.ENEMY:
			enemy_units.append(unit)
	assert_eq(enemy_units.size(), 1, "The Goblin Camp should field its own 1 Goblin, not the leaked pinned count")
	for unit in enemy_units:
		assert_eq(unit.max_health, 13, "The fielded enemy should be a Goblin, not a leaked Kobold")


func test_ruined_fortress_button_runs_the_ruined_fortress_debug_scenario() -> void:
	var menu: CanvasLayer = DebugMenuScene.instantiate()
	add_child_autofree(menu)
	menu.visible = true

	menu._scenario_buttons["ruined_fortress"].pressed.emit()

	assert_false(menu.visible, "A successful scenario run should close the menu, like the other buttons")


func test_stocked_stores_button_populates_the_trading_post_and_routes_to_stores() -> void:
	var menu: CanvasLayer = DebugMenuScene.instantiate()
	add_child_autofree(menu)
	menu.visible = true

	menu._scenario_buttons["stocked_stores"].pressed.emit()

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
	assert_eq(warrior.max_action_points, BattleControllerScript.SUPER_POWER_ACTION_POINTS)
	assert_eq(warrior.damage_min, 100)
	assert_eq(warrior.damage_max, 100)
	assert_eq(warrior.hit_chance, 1.0)


func test_party_empty_button_runs_the_party_empty_debug_scenario() -> void:
	var menu: CanvasLayer = DebugMenuScene.instantiate()
	add_child_autofree(menu)
	menu.visible = true

	menu._scenario_buttons["party_empty"].pressed.emit()

	assert_eq(GameSession.get_selected_party().member_ids, [] as Array[String])
	assert_false(GameSession.has_deployed_party())
	assert_false(menu.visible, "A successful scenario run should close the menu, like the other buttons")


func test_recruit_button_adds_an_adventurer_and_closes_the_menu() -> void:
	GameSession.reset()
	var menu: CanvasLayer = DebugMenuScene.instantiate()
	add_child_autofree(menu)
	menu.visible = true

	menu._on_recruit_pressed()

	assert_eq(GameSession.adventurers.size(), GameSession.STARTING_ROSTER_SIZE + 1)
	assert_false(menu.visible, "A successful recruit should close the menu, like Super Power")
