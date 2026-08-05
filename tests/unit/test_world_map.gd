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
	world_map.party_position = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID).position
	watch_signals(world_map)

	var activated: bool = world_map.try_activate_current_tile()

	assert_true(activated, "Standing on the encounter tile should activate it")
	assert_signal_emitted_with_parameters(
		world_map, "encounter_activated", [GameSession.GOBLIN_CAMP_ID]
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


func test_clicking_an_adjacent_tile_after_selecting_sets_a_route_without_moving() -> void:
	var world_map := _make_world_map()
	world_map._handle_tile_click(world_map.party_position)

	world_map._handle_tile_click(Vector2i(1, 0))

	assert_eq(world_map.party_position, Vector2i(0, 0), "Setting a route must not move the party")
	assert_eq(GameSession.get_deployed_party_route(), [Vector2i(1, 0)])
	assert_true(world_map.party_selected, "Selection should persist after committing a route")


func test_clicking_the_committed_destination_again_takes_one_manual_step() -> void:
	var world_map := _make_world_map()
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(Vector2i(2, 0))

	world_map._handle_tile_click(Vector2i(2, 0))

	assert_eq(
		world_map.party_position, Vector2i(1, 0), "Clicking the destination again should take one manual step"
	)
	assert_eq(GameSession.get_deployed_party_route(), [Vector2i(2, 0)])


func test_clicking_the_party_with_a_route_again_cancels_it() -> void:
	var world_map := _make_world_map()
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(Vector2i(2, 0))

	world_map._handle_tile_click(world_map.party_position)

	assert_eq(world_map.party_position, Vector2i(0, 0), "Canceling a route must not move the party")
	assert_eq(GameSession.get_deployed_party_route(), [] as Array[Vector2i])
	assert_true(world_map.party_selected, "Party should remain selected after canceling its route")


func test_canceling_a_route_reenables_the_hover_affordance() -> void:
	var world_map := _make_world_map()
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(Vector2i(2, 0))
	world_map._handle_tile_click(world_map.party_position)

	world_map._update_hover_route(Vector2i(1, 0))

	assert_eq(
		world_map.hover_route,
		[Vector2i(1, 0)],
		"Canceling the route should bring back the live hover preview"
	)


func test_choosing_a_new_destination_after_a_route_is_set_replaces_it() -> void:
	var world_map := _make_world_map()
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(Vector2i(2, 0))

	world_map._handle_tile_click(Vector2i(0, 2))

	assert_eq(GameSession.get_deployed_party_route(), [Vector2i(0, 1), Vector2i(0, 2)])


func test_right_click_cancels_the_hover_preview_and_preserves_the_route() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(Vector2i(2, 0))
	world_map._update_hover_route(Vector2i(0, 2))
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true

	world_map._unhandled_input(right_click)

	assert_eq(world_map.hover_route, [] as Array[Vector2i])
	assert_eq(GameSession.get_deployed_party_route(), [Vector2i(1, 0), Vector2i(2, 0)])
	assert_false(
		world_map.party_selected, "Dismissing the affordance must deselect the party"
	)


func test_right_click_while_setting_a_first_route_returns_to_the_initial_state() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	world_map._handle_tile_click(world_map.party_position)
	world_map._update_hover_route(Vector2i(1, 0))
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true

	world_map._unhandled_input(right_click)

	assert_false(world_map.party_selected, "No prior route means dismissal returns to the initial state")
	assert_eq(world_map.hover_route, [] as Array[Vector2i])
	assert_eq(GameSession.get_deployed_party_route(), [] as Array[Vector2i])


func test_get_route_destination_returns_party_position_when_no_route() -> void:
	var world_map := _make_world_map()

	assert_eq(world_map.get_route_destination(), world_map.party_position)


func test_get_route_destination_returns_the_final_route_point() -> void:
	var world_map := _make_world_map()
	GameSession.set_deployed_party_route([Vector2i(1, 0), Vector2i(2, 0)] as Array[Vector2i])

	assert_eq(world_map.get_route_destination(), Vector2i(2, 0))


func test_cancel_route_setting_clears_only_the_transient_hover_preview() -> void:
	var world_map := _make_world_map()
	GameSession.set_deployed_party_route([Vector2i(1, 0)] as Array[Vector2i])
	world_map.hover_route = [Vector2i(2, 0)] as Array[Vector2i]

	world_map.cancel_route_setting()

	assert_eq(world_map.hover_route, [] as Array[Vector2i])
	assert_eq(
		GameSession.get_deployed_party_route(),
		[Vector2i(1, 0)],
		"cancel_route_setting must not touch the durable route"
	)


func test_build_route_orders_horizontal_then_vertical_steps() -> void:
	var world_map := _make_world_map()

	var route: Array = world_map.build_route(Vector2i(0, 0), Vector2i(2, 1))

	assert_eq(route, [Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1)])


func test_build_route_rejects_an_out_of_bounds_endpoint() -> void:
	var world_map := _make_world_map()

	assert_eq(world_map.build_route(Vector2i(-1, 0), Vector2i(2, 1)), [] as Array[Vector2i])
	assert_eq(world_map.build_route(Vector2i(0, 0), Vector2i(5, 5)), [] as Array[Vector2i])


func test_build_route_rejects_the_current_tile() -> void:
	var world_map := _make_world_map()

	assert_eq(world_map.build_route(Vector2i(2, 2), Vector2i(2, 2)), [] as Array[Vector2i])


func test_clicking_deployed_party_on_goblin_camp_selects_it_before_entry() -> void:
	var world_map := _make_world_map()
	world_map.party_position = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID).position

	world_map._handle_tile_click(world_map.party_position)

	assert_true(world_map.party_selected, "First click on the goblin camp must select, not enter")


func test_clicking_selected_party_on_goblin_camp_emits_encounter_activated() -> void:
	var world_map := _make_world_map()
	world_map.party_position = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID).position
	watch_signals(world_map)

	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(world_map.party_position)

	assert_signal_emitted_with_parameters(
		world_map, "encounter_activated", [GameSession.GOBLIN_CAMP_ID]
	)


func test_selected_party_on_goblin_camp_can_move_away_instead_of_entering() -> void:
	var world_map := _make_world_map()
	var camp_position: Vector2i = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID).position
	world_map.party_position = camp_position
	GameSession.set_deployed_party_position(camp_position)
	world_map._handle_tile_click(world_map.party_position)
	watch_signals(world_map)

	world_map._handle_tile_click(Vector2i(3, 4))
	world_map._handle_tile_click(Vector2i(3, 4))

	assert_signal_not_emitted(world_map, "encounter_activated")
	assert_eq(world_map.party_position, Vector2i(3, 4), "A selected party on the camp must be able to move away")


func test_activating_a_completed_encounter_tile_does_nothing() -> void:
	var world_map := _make_world_map()
	world_map.party_position = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID).position
	GameSession.completed_encounters.append(GameSession.GOBLIN_CAMP_ID)
	watch_signals(world_map)

	var activated: bool = world_map.try_activate_current_tile()

	assert_false(activated, "A completed encounter must reject entry")
	assert_signal_not_emitted(world_map, "encounter_activated")


func test_clicking_a_completed_encounter_after_selecting_deselects_instead_of_entering() -> void:
	var world_map := _make_world_map()
	world_map.party_position = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID).position
	GameSession.completed_encounters.append(GameSession.GOBLIN_CAMP_ID)
	world_map._handle_tile_click(world_map.party_position)

	world_map._handle_tile_click(world_map.party_position)

	assert_false(world_map.party_selected, "A completed encounter must not stay selected forever")


func test_party_selects_then_activates_each_catalog_expedition_marker() -> void:
	for encounter_id in GameSession.EXPEDITIONS.keys():
		GameSession.reset()
		_deploy_warrior_party()
		var record: Dictionary = GameSession.get_expedition(encounter_id)
		GameSession.set_deployed_party_position(record.position)
		var world_map := _make_world_map()
		world_map.party_position = record.position
		watch_signals(world_map)

		world_map._handle_tile_click(world_map.party_position)
		assert_true(
			world_map.party_selected,
			"First click on %s must select, not enter" % encounter_id
		)

		world_map._handle_tile_click(world_map.party_position)
		assert_signal_emitted_with_parameters(
			world_map, "encounter_activated", [encounter_id]
		)


func test_selected_party_can_route_away_from_each_catalog_expedition_marker() -> void:
	for encounter_id in GameSession.EXPEDITIONS.keys():
		GameSession.reset()
		_deploy_warrior_party()
		var record: Dictionary = GameSession.get_expedition(encounter_id)
		GameSession.set_deployed_party_position(record.position)
		var world_map := _make_world_map()
		world_map.party_position = record.position
		world_map._handle_tile_click(world_map.party_position)
		watch_signals(world_map)
		var destination := _adjacent_tile_within_bounds(record.position)

		world_map._handle_tile_click(destination)
		world_map._handle_tile_click(destination)

		assert_signal_not_emitted(world_map, "encounter_activated")
		assert_eq(
			world_map.party_position,
			destination,
			"A selected party on %s must be able to move away instead of entering" % encounter_id
		)


func test_completing_goblin_camp_rejects_only_goblin_camp_while_orc_outpost_remains_activatable() -> void:
	GameSession.completed_encounters.append(GameSession.GOBLIN_CAMP_ID)
	var goblin_record: Dictionary = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID)
	var orc_record: Dictionary = GameSession.get_expedition(GameSession.ORC_OUTPOST_ID)

	var goblin_map := _make_world_map()
	goblin_map.party_position = goblin_record.position
	assert_false(
		goblin_map.try_activate_current_tile(), "A completed Goblin Camp must reject entry"
	)

	var orc_map := _make_world_map()
	orc_map.party_position = orc_record.position
	assert_true(
		orc_map.try_activate_current_tile(),
		"Orc Outpost must remain activatable while only Goblin Camp is completed"
	)


func _adjacent_tile_within_bounds(pos: Vector2i) -> Vector2i:
	if pos.x > 0:
		return Vector2i(pos.x - 1, pos.y)
	return Vector2i(pos.x + 1, pos.y)


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
	world_map._handle_tile_click(Vector2i(1, 0))

	assert_eq(
		GameSession.get_deployed_party_position(), Vector2i(1, 0), "Moving the party should persist its new position"
	)


func test_world_map_does_not_draw_party_marker_when_no_party_is_deployed() -> void:
	GameSession.reset()
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	# One ColorRect + one Label per catalog expedition, plus one settlement ColorRect.
	var expected_marker_count := GameSession.EXPEDITIONS.size() * 2 + 1
	assert_eq(world_map.get_node("Markers").get_child_count(), expected_marker_count)
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


func test_update_hover_route_sets_the_route_when_selected() -> void:
	var world_map := _make_world_map()
	world_map._handle_tile_click(world_map.party_position)

	world_map._update_hover_route(Vector2i(2, 0))

	assert_eq(world_map.hover_route, [Vector2i(1, 0), Vector2i(2, 0)])


func test_update_hover_route_is_empty_when_not_selected() -> void:
	var world_map := _make_world_map()

	world_map._update_hover_route(Vector2i(2, 0))

	assert_eq(world_map.hover_route, [] as Array[Vector2i])


func test_hover_preview_does_not_update_after_a_route_is_committed() -> void:
	var world_map := _make_world_map()
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(Vector2i(1, 0))

	world_map._update_hover_route(Vector2i(2, 0))

	assert_eq(
		world_map.hover_route,
		[] as Array[Vector2i],
		"Pathing mode ends once a route is committed, so hovering must not preview a new one"
	)


func test_committing_a_route_clears_the_hover_preview() -> void:
	var world_map := _make_world_map()
	world_map._handle_tile_click(world_map.party_position)
	world_map._update_hover_route(Vector2i(2, 0))

	world_map._handle_tile_click(Vector2i(2, 0))

	assert_eq(world_map.hover_route, [] as Array[Vector2i])


func test_taking_a_manual_step_clears_the_hover_preview() -> void:
	var world_map := _make_world_map()
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(Vector2i(2, 0))
	world_map._update_hover_route(Vector2i(2, 0))

	world_map._handle_tile_click(Vector2i(2, 0))

	assert_eq(world_map.hover_route, [] as Array[Vector2i])


func test_deselecting_the_party_clears_the_hover_preview() -> void:
	var world_map := _make_world_map()
	world_map.party_position = Vector2i(1, 0)
	world_map._handle_tile_click(world_map.party_position)
	world_map._update_hover_route(Vector2i(2, 0))

	world_map._handle_tile_click(world_map.party_position)

	assert_eq(world_map.hover_route, [] as Array[Vector2i])


func test_route_line_remains_visible_after_a_route_is_committed() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	world_map._handle_tile_click(world_map.party_position)

	world_map._handle_tile_click(Vector2i(1, 0))

	assert_true(
		world_map.get_node("Routes").get_child_count() > 0,
		"A finalized route must remain visible on the map"
	)


func test_route_line_remains_visible_after_deselecting_with_right_click() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(Vector2i(1, 0))
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true

	world_map._unhandled_input(right_click)

	assert_false(world_map.party_selected)
	assert_true(
		world_map.get_node("Routes").get_child_count() > 0,
		"An existing route must stay visible even after the party is deselected"
	)


func test_route_line_disappears_after_canceling_it_with_a_zero_step_route() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(Vector2i(1, 0))

	world_map._handle_tile_click(world_map.party_position)
	await get_tree().process_frame

	assert_eq(world_map.get_node("Routes").get_child_count(), 0)


func test_hovering_after_a_route_is_committed_does_not_draw_a_preview() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(Vector2i(1, 0))

	world_map._update_hover_route(Vector2i(0, 2))
	await get_tree().process_frame

	# committed route [(1,0)]: 1 segment + target + label = 3, no hover overlay
	assert_eq(
		world_map.get_node("Routes").get_child_count(),
		3,
		"Pathing mode ends once a route is committed, so no ghost preview should be drawn"
	)


func test_hovering_the_current_destination_does_not_duplicate_the_route() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(Vector2i(1, 0))

	world_map._update_hover_route(Vector2i(1, 0))
	await get_tree().process_frame

	assert_eq(world_map.get_node("Routes").get_child_count(), 3)


func test_pressing_end_turn_advances_the_turn_without_a_route() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	world_map._on_end_turn_pressed()

	assert_eq(GameSession.world_turn, 2)
	assert_eq(world_map.party_position, Vector2i(0, 0))


func test_pressing_end_turn_auto_moves_one_unspent_route_step() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(Vector2i(1, 0))

	world_map._on_end_turn_pressed()

	assert_eq(world_map.party_position, Vector2i(1, 0))
	assert_eq(GameSession.get_deployed_party_position(), Vector2i(1, 0))
	assert_eq(GameSession.world_turn, 2)


func test_pressing_end_turn_does_not_move_again_after_a_manual_step() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(Vector2i(2, 0))
	world_map._handle_tile_click(Vector2i(2, 0))

	world_map._on_end_turn_pressed()

	assert_eq(world_map.party_position, Vector2i(1, 0))
	assert_eq(GameSession.world_turn, 2)


func test_end_turn_updates_the_turn_label() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	world_map._on_end_turn_pressed()

	assert_eq(world_map.get_node("HUD/TurnLabel").text, tr("world_map.turn") % 2)


func _markers_include_color(world_map: Node2D, color: Color) -> bool:
	for marker in world_map.get_node("Markers").get_children():
		if marker is ColorRect and marker.color == color:
			return true
	return false
