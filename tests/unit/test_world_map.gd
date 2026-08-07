extends GutTest

const GridScript := preload("res://scripts/battle/grid.gd")
const WorldMapScript := preload("res://scripts/world/world_map.gd")
const WorldMapScene := preload("res://scenes/world/world_map.tscn")


func before_each() -> void:
	GameSession.reset()
	_deploy_warrior_party()


func after_each() -> void:
	GameManager.close_game_menu()
	GameManager.route_context_id = ""


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


func test_reclicking_the_party_with_a_route_preserves_it_and_enables_repathing() -> void:
	var world_map := _make_world_map()
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(Vector2i(2, 0))

	world_map._handle_tile_click(world_map.party_position)

	assert_eq(
		GameSession.get_deployed_party_route(), [Vector2i(1, 0), Vector2i(2, 0)],
		"Reclicking the party must not clear its existing route"
	)
	assert_true(world_map.party_selected, "Party should remain selected")
	assert_true(world_map.repathing, "Reclicking a routed party should enter repathing mode")


func test_repathing_mode_previews_a_new_route_alongside_the_old_one() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(Vector2i(1, 0))
	world_map._handle_tile_click(world_map.party_position)

	world_map._update_hover_route(Vector2i(0, 2))
	await get_tree().process_frame

	assert_eq(world_map.hover_route, [Vector2i(0, 1), Vector2i(0, 2)])
	# Old committed route (1 segment + target + label = 3) plus the new hover
	# preview (2 segments + target + label = 4) must both be visible at once.
	assert_eq(world_map.get_node("Routes").get_child_count(), 7)


func test_right_click_during_repathing_cancels_the_attempt_and_keeps_the_old_route() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(Vector2i(1, 0))
	world_map._handle_tile_click(world_map.party_position)
	world_map._update_hover_route(Vector2i(0, 2))
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true

	world_map._unhandled_input(right_click)

	assert_eq(world_map.hover_route, [] as Array[Vector2i])
	assert_eq(GameSession.get_deployed_party_route(), [Vector2i(1, 0)])
	assert_false(world_map.repathing)


func test_left_click_elsewhere_during_repathing_replaces_the_route() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(Vector2i(1, 0))
	world_map._handle_tile_click(world_map.party_position)

	world_map._handle_tile_click(Vector2i(0, 2))

	assert_eq(GameSession.get_deployed_party_route(), [Vector2i(0, 1), Vector2i(0, 2)])
	assert_false(world_map.repathing, "Committing a new route ends repathing mode")


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


## Regression coverage for the active-instance model generally, not only the
## specifically-seeded Goblin Camp: any active encounter instance — including
## one using a different template and a freshly minted (non-template) id —
## must be exactly as selectable/activatable as the seeded one.
func _append_orc_outpost_instance() -> Dictionary:
	var orc_position: Vector2i = GameSession.get_expedition(GameSession.ORC_OUTPOST_ID).position
	# GameSession.reset() already seeds a live "orc_outpost" active instance at
	# this same position, so blindly appending here would leave two active
	# instances sharing a tile — an artifact of this fixture, not a real
	# gameplay scenario. Drop any instance already occupying the tile first so
	# the manufactured "encounter_999" instance remains the sole, unambiguous
	# occupant for position-based lookups (e.g. WorldMap._expedition_id_at()).
	GameSession.active_encounters = GameSession.active_encounters.filter(
		func(existing: Dictionary) -> bool: return existing.position != orc_position
	)
	var instance: Dictionary = GameSession._make_encounter_instance(
		"encounter_999", GameSession.ORC_OUTPOST_ID, orc_position
	)
	GameSession.active_encounters.append(instance)
	return instance


func test_party_selects_then_activates_a_manufactured_active_instance() -> void:
	var instance := _append_orc_outpost_instance()
	GameSession.set_deployed_party_position(instance.position)
	var world_map := _make_world_map()
	world_map.party_position = instance.position
	watch_signals(world_map)

	world_map._handle_tile_click(world_map.party_position)
	assert_true(world_map.party_selected, "First click on any active instance must select, not enter")

	world_map._handle_tile_click(world_map.party_position)
	assert_signal_emitted_with_parameters(
		world_map, "encounter_activated", [instance.id]
	)


func test_selected_party_can_route_away_from_a_manufactured_active_instance() -> void:
	var instance := _append_orc_outpost_instance()
	GameSession.set_deployed_party_position(instance.position)
	var world_map := _make_world_map()
	world_map.party_position = instance.position
	world_map._handle_tile_click(world_map.party_position)
	watch_signals(world_map)
	var destination := _adjacent_tile_within_bounds(instance.position)

	world_map._handle_tile_click(destination)
	world_map._handle_tile_click(destination)

	assert_signal_not_emitted(world_map, "encounter_activated")
	assert_eq(
		world_map.party_position,
		destination,
		"A selected party on any active instance must be able to move away instead of entering"
	)


func test_completing_goblin_camp_rejects_only_goblin_camp_while_a_separate_active_instance_remains_activatable() -> void:
	var orc_instance := _append_orc_outpost_instance()
	GameSession.completed_encounters.append(GameSession.GOBLIN_CAMP_ID)
	var goblin_record: Dictionary = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID)

	var goblin_map := _make_world_map()
	goblin_map.party_position = goblin_record.position
	assert_false(
		goblin_map.try_activate_current_tile(), "A completed Goblin Camp must reject entry"
	)

	var orc_map := _make_world_map()
	orc_map.party_position = orc_instance.position
	assert_true(
		orc_map.try_activate_current_tile(),
		"A separate active instance must remain activatable while only Goblin Camp is completed"
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


func test_world_map_renders_a_party_deployed_via_the_deploy_party_action() -> void:
	# Regression coverage: has_deployed_party()/position/marker/selection must
	# keep working for a party GameSession.deploy_party() selected directly,
	# not only for one that departed via the older depart_selected_party() path.
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	assert_true(GameSession.deploy_party(GameSession.FIRST_PARTY_ID))

	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	assert_true(GameSession.has_deployed_party())
	assert_eq(world_map.party_position, GameSession.STARTING_SETTLEMENT_WORLD_POSITION)
	assert_true(_markers_include_color(world_map, WorldMapScript.PARTY_COLOR))

	world_map._handle_tile_click(world_map.party_position)

	assert_true(world_map.party_selected, "The deployed party's marker must remain selectable")
	var panel: Control = world_map.get_node("HUD/InformationPanel")
	assert_true(panel.get_node("Content/PartyName").visible)
	assert_eq(panel.get_node("Content/PartyName").text, tr("information.party") % "Party 1")


func test_world_map_does_not_draw_party_marker_when_no_party_is_deployed() -> void:
	GameSession.reset()
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	# One ColorRect + one Label per active encounter instance, plus one settlement ColorRect.
	var expected_marker_count := GameSession.get_active_encounters().size() * 2 + 1
	assert_eq(world_map.get_node("Markers").get_child_count(), expected_marker_count)
	assert_false(_markers_include_color(world_map, WorldMapScript.PARTY_COLOR))


func test_clicking_the_settlement_without_a_deployed_party_returns_to_encampment() -> void:
	GameSession.reset()
	var world_map := _make_world_map()
	watch_signals(world_map)

	world_map._handle_tile_click(WorldMapScript.SETTLEMENT_POSITION)

	assert_signal_emitted_with_parameters(
		world_map, "settlement_activated", [WorldMapScript.SETTLEMENT_ID]
	)


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


func test_world_map_contains_the_information_panel_showing_the_current_gold_total() -> void:
	GameSession.gold = 25
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("HUD/InformationPanel")

	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)


func test_information_panel_hides_party_name_until_the_party_marker_is_selected() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("HUD/InformationPanel")

	assert_false(
		panel.get_node("Content/PartyName").visible,
		"Party info should stay hidden until the player selects the party marker"
	)

	world_map._handle_tile_click(world_map.party_position)

	assert_true(
		panel.get_node("Content/PartyName").visible,
		"Selecting the party marker should reveal its info"
	)


func test_information_panel_hides_party_name_again_after_deselecting_with_right_click() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("HUD/InformationPanel")
	world_map._handle_tile_click(world_map.party_position)

	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	world_map._unhandled_input(right_click)

	assert_false(panel.get_node("Content/PartyName").visible)


## Regression test: the panel's View Party button used to be wired up with no
## listener on the World Map, so pressing it did nothing (see parties.gd and
## party_details.gd for the same pattern applied to their own screens).
func test_pressing_the_panels_view_party_button_routes_to_party_details() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("HUD/InformationPanel")
	world_map._handle_tile_click(world_map.party_position)

	panel.get_node("Content/PartyViewButton").emit_signal("pressed")

	assert_eq(
		GameManager.route_context_id,
		GameSession.selected_party_id,
		"Pressing View Party on the World Map must ask GameManager to open that party's details"
	)


func test_information_panel_shows_the_pending_reward_for_a_selected_party_with_one() -> void:
	GameSession.pending_reward = 15
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("HUD/InformationPanel")

	world_map._handle_tile_click(world_map.party_position)

	assert_true(panel.get_node("Content/PendingReward").visible)
	assert_eq(
		panel.get_node("Content/PendingReward").text, tr("information.pending_reward") % 15
	)


func test_information_panel_hides_the_pending_reward_row_when_there_is_none() -> void:
	GameSession.pending_reward = 0
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("HUD/InformationPanel")

	world_map._handle_tile_click(world_map.party_position)

	assert_false(panel.get_node("Content/PendingReward").visible)


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


func test_route_line_stays_visible_when_entering_repathing_mode() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(Vector2i(1, 0))

	world_map._handle_tile_click(world_map.party_position)
	await get_tree().process_frame

	assert_eq(
		world_map.get_node("Routes").get_child_count(), 3,
		"The route must remain visible when entering repathing mode"
	)


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


func test_active_battle_disables_and_blocks_end_turn() -> void:
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	world_map._on_end_turn_pressed()

	assert_true(world_map.get_node("HUD/EndTurnButton").disabled)
	assert_eq(GameSession.world_turn, 1)


func test_active_encounter_can_be_reentered_from_the_world_map() -> void:
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	var world_map := _make_world_map()
	world_map.party_position = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID).position
	watch_signals(world_map)

	var activated: bool = world_map.try_activate_current_tile()

	assert_true(activated)
	assert_signal_emitted_with_parameters(
		world_map, "encounter_activated", [GameSession.GOBLIN_CAMP_ID]
	)


func test_active_battle_cannot_be_replaced_by_a_different_encounter() -> void:
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	var world_map := _make_world_map()
	world_map.party_position = GameSession.get_expedition(GameSession.ORC_OUTPOST_ID).position
	watch_signals(world_map)

	var activated: bool = world_map.try_activate_current_tile()

	assert_false(activated)
	assert_signal_not_emitted(world_map, "encounter_activated")


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


## Task 4: the map only ever draws GameSession's live active-encounter list
## (see _draw_markers), so a vacancy that refills mid-session must appear the
## very next time End Turn redraws the markers — no separate "refresh" step.
func test_world_map_redraws_a_refilled_encounter_after_enough_end_turns() -> void:
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	GameSession.complete_current_encounter()
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var before_count := world_map.get_node("Markers").get_child_count()
	# Advance the first 14 turns directly through GameSession (no vacancy
	# fires yet) so the redraw-heavy assertion below only exercises a single,
	# real End Turn press — repeatedly calling _draw_markers() synchronously
	# would otherwise pile up nodes still pending their deferred queue_free().
	for i in GameSession.ENCOUNTER_VACANCY_TURNS - 1:
		GameSession.end_world_turn()

	world_map._on_end_turn_pressed()
	# _draw_markers() queue_free()s the stale markers before adding fresh
	# ones; queue_free() is deferred, so a frame must pass before the node
	# count reflects only the redrawn set (see the other Routes-container
	# tests in this file that already await a frame for the same reason).
	await get_tree().process_frame

	var after_count := world_map.get_node("Markers").get_child_count()
	assert_eq(
		after_count,
		before_count + 2,
		"A 15-turn refill should add exactly one new encounter marker (ColorRect + Label)"
	)


func _markers_include_color(world_map: Node2D, color: Color) -> bool:
	for marker in world_map.get_node("Markers").get_children():
		if marker is ColorRect and marker.color == color:
			return true
	return false


func test_orc_outpost_label_stays_clear_of_the_hint_bar_at_the_top_of_the_map() -> void:
	# The Orc Outpost sits on grid row 0. Its label must not be pushed above
	# the visible playfield (negative y) or behind HUD/Hint (see
	# world_map.tscn), which reserves the screen down to y = 112. The Orc
	# Outpost is not active by default (only Goblin Camp is seeded), so this
	# manufactures an active instance for it to exercise the same regression.
	_append_orc_outpost_instance()
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	var orc_record: Dictionary = GameSession.get_expedition(GameSession.ORC_OUTPOST_ID)
	var label := _find_expedition_label_by_position(world_map, orc_record.position)

	assert_not_null(label, "Orc Outpost's expedition label should be drawn")
	assert_gte(label.position.y, 0.0, "The label must stay within the visible playfield")
	assert_gte(
		label.position.y,
		WorldMapScript.EXPEDITION_LABEL_MIN_Y,
		"The label must not be drawn behind the hint bar"
	)


func test_goblin_camp_label_position_is_unchanged_by_the_hint_bar_clamp() -> void:
	# Row 4 sits well clear of the hint bar already; the fix for row 0 must
	# not shift labels that were never at risk of overlapping it.
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	var goblin_record: Dictionary = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID)
	var label := _find_expedition_label_by_position(world_map, goblin_record.position)

	assert_not_null(label, "Goblin Camp's expedition label should be drawn")
	assert_eq(
		label.position,
		Vector2(goblin_record.position) * WorldMapScript.TILE_SIZE
			+ Vector2(WorldMapScript.TILE_SIZE * 0.1, -WorldMapScript.TILE_SIZE * 0.6)
	)


func _find_expedition_label(world_map: Node2D, name_text: String) -> Label:
	for marker in world_map.get_node("Markers").get_children():
		if marker is Label and marker.text.find(name_text) > -1:
			return marker
	return null


func test_route_preview_label_stays_clear_of_the_hint_bar_at_the_top_of_the_map() -> void:
	# The party starts at row 0. A hover-preview route destined for another
	# tile on row 0 previously produced a label position above the map /
	# behind the hint bar, mirroring the (already-fixed) expedition-label bug.
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	world_map._handle_tile_click(world_map.party_position)

	world_map._update_hover_route(Vector2i(3, 0))
	await get_tree().process_frame

	var label := _find_route_label(world_map)
	assert_not_null(label, "Hover route destination label should be drawn")
	assert_gte(label.position.y, 0.0, "The label must stay within the visible playfield")
	assert_gte(
		label.position.y,
		WorldMapScript.EXPEDITION_LABEL_MIN_Y,
		"The label must not be drawn behind the hint bar"
	)


func _find_route_label(world_map: Node2D) -> Label:
	for child in world_map.get_node("Routes").get_children():
		if child is Label:
			return child
	return null


func test_encounter_labels_show_only_stars_for_difficulty() -> void:
	# Task 2: Goblin Camp (difficulty 1) shows ★, Orc Outpost (difficulty 2) shows ★★
	_append_orc_outpost_instance()
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	var goblin_record: Dictionary = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID)
	var orc_record: Dictionary = GameSession.get_expedition(GameSession.ORC_OUTPOST_ID)

	var goblin_label := _find_expedition_label_by_position(world_map, goblin_record.position)
	var orc_label := _find_expedition_label_by_position(world_map, orc_record.position)

	assert_not_null(goblin_label, "Goblin Camp label should exist")
	assert_not_null(orc_label, "Orc Outpost label should exist")
	assert_eq(goblin_label.text, "★", "Goblin Camp (difficulty 1) should show single star")
	assert_eq(orc_label.text, "★★", "Orc Outpost (difficulty 2) should show two stars")


func test_encounter_labels_do_not_include_names_danger_or_reward() -> void:
	# Task 2: No "Goblin", "Orc", "danger", or "gold" in label text
	_append_orc_outpost_instance()
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	var goblin_record: Dictionary = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID)
	var orc_record: Dictionary = GameSession.get_expedition(GameSession.ORC_OUTPOST_ID)

	var goblin_label := _find_expedition_label_by_position(world_map, goblin_record.position)
	var orc_label := _find_expedition_label_by_position(world_map, orc_record.position)

	assert_not_null(goblin_label)
	assert_not_null(orc_label)
	assert_false(goblin_label.text.contains("Goblin"), "Goblin label should not contain 'Goblin'")
	assert_false(goblin_label.text.contains("Orc"), "Goblin label should not contain 'Orc'")
	assert_false(goblin_label.text.contains("danger"), "Goblin label should not contain 'danger'")
	assert_false(goblin_label.text.contains("gold"), "Goblin label should not contain 'gold'")
	assert_false(orc_label.text.contains("Goblin"), "Orc label should not contain 'Goblin'")
	assert_false(orc_label.text.contains("Orc"), "Orc label should not contain 'Orc'")
	assert_false(orc_label.text.contains("danger"), "Orc label should not contain 'danger'")
	assert_false(orc_label.text.contains("gold"), "Orc label should not contain 'gold'")


func _find_expedition_label_by_position(world_map: Node2D, position: Vector2i) -> Label:
	# Find a label at a given encounter position by checking all labels in Markers
	# and matching by approximate position (within 1 pixel tolerance for floating point)
	var expected_x := position.x * WorldMapScript.TILE_SIZE + WorldMapScript.TILE_SIZE * 0.1
	var expected_y := maxf(
		position.y * WorldMapScript.TILE_SIZE - WorldMapScript.TILE_SIZE * 0.6,
		WorldMapScript.EXPEDITION_LABEL_MIN_Y
	)
	for marker in world_map.get_node("Markers").get_children():
		if marker is Label:
			if abs(marker.position.x - expected_x) < 1.0 and abs(marker.position.y - expected_y) < 1.0:
				return marker
	return null
