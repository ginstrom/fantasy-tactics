extends GutTest

const GridScript := preload("res://scripts/battle/grid.gd")
const WorldMapScript := preload("res://scripts/world/world_map.gd")
const WorldMapScene := preload("res://scenes/world/world_map.tscn")


func before_each() -> void:
	GameSession.reset()
	_deploy_warrior_party()


func after_each() -> void:
	GameManager.close_game_menu()


func _deploy_warrior_party() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()


func _make_world_map() -> Node2D:
	var world_map: Node2D = WorldMapScript.new()
	world_map.grid = GridScript.new(5, 5)
	autofree(world_map)
	return world_map


func test_party_moves_to_an_adjacent_tile() -> void:
	var world_map := _make_world_map()

	var moved: bool = world_map.try_move_party(Vector2i(1, 0))

	assert_true(moved, "Party should move to an adjacent tile")
	assert_eq(world_map.party_position, Vector2i(1, 0))


func test_party_cannot_move_to_a_non_adjacent_tile() -> void:
	var world_map := _make_world_map()

	var moved: bool = world_map.try_move_party(Vector2i(4, 4))

	assert_false(moved, "Party should not jump to a non-adjacent tile")
	assert_eq(world_map.party_position, Vector2i(0, 0), "Rejected move must not change position")


func test_activating_the_encounter_tile_emits_encounter_activated() -> void:
	var world_map := _make_world_map()
	world_map.party_position = WorldMapScript.ENCOUNTER_POSITION
	watch_signals(world_map)

	var activated: bool = world_map.try_activate_current_tile()

	assert_true(activated, "Standing on the encounter tile should activate it")
	assert_signal_emitted_with_parameters(
		world_map, "encounter_activated", [WorldMapScript.ENCOUNTER_ID]
	)


func test_activating_a_non_encounter_tile_does_nothing() -> void:
	var world_map := _make_world_map()
	watch_signals(world_map)

	var activated: bool = world_map.try_activate_current_tile()

	assert_false(activated, "Standing away from the encounter should not activate anything")
	assert_signal_not_emitted(world_map, "encounter_activated")


func test_clicking_the_party_marker_selects_it() -> void:
	var world_map := _make_world_map()

	world_map._handle_tile_click(world_map.party_position)

	assert_true(world_map.party_selected, "Clicking the party marker should select it")


func test_clicking_the_selected_party_marker_again_deselects_it() -> void:
	var world_map := _make_world_map()
	world_map.party_position = Vector2i(1, 0)
	world_map._handle_tile_click(world_map.party_position)

	world_map._handle_tile_click(world_map.party_position)

	assert_false(world_map.party_selected, "Clicking the selected marker again should deselect it")


func test_clicking_an_adjacent_tile_without_selecting_does_not_move_the_party() -> void:
	var world_map := _make_world_map()

	world_map._handle_tile_click(Vector2i(1, 0))

	assert_eq(
		world_map.party_position, Vector2i(0, 0), "The party should not move without first being selected"
	)


func test_clicking_an_adjacent_tile_after_selecting_moves_the_party() -> void:
	var world_map := _make_world_map()
	world_map._handle_tile_click(world_map.party_position)

	world_map._handle_tile_click(Vector2i(1, 0))

	assert_eq(
		world_map.party_position,
		Vector2i(1, 0),
		"Selecting then clicking an adjacent tile should move the party"
	)
	assert_false(world_map.party_selected, "Moving should clear the selection")


func test_clicking_deployed_party_on_goblin_camp_selects_it_before_entry() -> void:
	var world_map := _make_world_map()
	world_map.party_position = WorldMapScript.ENCOUNTER_POSITION

	world_map._handle_tile_click(world_map.party_position)

	assert_true(world_map.party_selected, "First click on the goblin camp must select, not enter")


func test_clicking_selected_party_on_goblin_camp_emits_encounter_activated() -> void:
	var world_map := _make_world_map()
	world_map.party_position = WorldMapScript.ENCOUNTER_POSITION
	watch_signals(world_map)

	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(world_map.party_position)

	assert_signal_emitted_with_parameters(
		world_map, "encounter_activated", [WorldMapScript.ENCOUNTER_ID]
	)


func test_selected_party_on_goblin_camp_can_move_away_instead_of_entering() -> void:
	var world_map := _make_world_map()
	world_map.party_position = WorldMapScript.ENCOUNTER_POSITION
	world_map._handle_tile_click(world_map.party_position)
	watch_signals(world_map)

	world_map._handle_tile_click(Vector2i(3, 4))

	assert_signal_not_emitted(world_map, "encounter_activated")
	assert_eq(world_map.party_position, Vector2i(3, 4), "A selected party on the camp must be able to move away")


func test_activating_a_completed_encounter_tile_does_nothing() -> void:
	var world_map := _make_world_map()
	world_map.party_position = WorldMapScript.ENCOUNTER_POSITION
	GameSession.completed_encounters.append(WorldMapScript.ENCOUNTER_ID)
	watch_signals(world_map)

	var activated: bool = world_map.try_activate_current_tile()

	assert_false(activated, "A completed encounter must reject entry")
	assert_signal_not_emitted(world_map, "encounter_activated")


func test_clicking_a_completed_encounter_after_selecting_deselects_instead_of_entering() -> void:
	var world_map := _make_world_map()
	world_map.party_position = WorldMapScript.ENCOUNTER_POSITION
	GameSession.completed_encounters.append(WorldMapScript.ENCOUNTER_ID)
	world_map._handle_tile_click(world_map.party_position)

	world_map._handle_tile_click(world_map.party_position)

	assert_false(world_map.party_selected, "A completed encounter must not stay selected forever")


func test_ready_resumes_the_party_position_saved_in_the_session() -> void:
	GameSession.set_deployed_party_position(Vector2i(2, 3))

	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	assert_eq(
		world_map.party_position, Vector2i(2, 3), "World map should resume the party's saved position"
	)


func test_moving_the_party_persists_the_new_position_to_the_session() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(Vector2i(1, 0))

	assert_eq(
		GameSession.get_deployed_party_position(), Vector2i(1, 0), "Moving the party should persist its new position"
	)


func test_world_map_does_not_draw_party_marker_when_no_party_is_deployed() -> void:
	GameSession.reset()
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	assert_eq(world_map.get_node("Markers").get_child_count(), 2)
	assert_false(_markers_include_color(world_map, WorldMapScript.PARTY_COLOR))


func test_clicking_deployed_party_at_settlement_selects_it_before_entry() -> void:
	var world_map := _make_world_map()

	world_map._handle_tile_click(Vector2i(0, 0))

	assert_true(world_map.party_selected)


func test_clicking_selected_party_at_settlement_emits_settlement_activated() -> void:
	var world_map := _make_world_map()
	watch_signals(world_map)

	world_map._handle_tile_click(Vector2i(0, 0))
	world_map._handle_tile_click(Vector2i(0, 0))

	assert_signal_emitted_with_parameters(
		world_map, "settlement_activated", ["starting_settlement"]
	)


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	world_map._unhandled_input(escape_event)

	assert_true(
		world_map.get_viewport().is_input_handled(),
		"World map must mark Escape input as handled before opening the overlay"
	)
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)


func _markers_include_color(world_map: Node2D, color: Color) -> bool:
	for marker in world_map.get_node("Markers").get_children():
		if marker.color == color:
			return true
	return false
