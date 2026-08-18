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
	GameSession.reset_injectable_rolls()


func _deploy_warrior_party() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()


func _make_world_map() -> Node2D:
	var world_map: Node2D = WorldMapScript.new()
	world_map.grid = GridScript.new(WorldMapScript.GRID_WIDTH, WorldMapScript.GRID_HEIGHT)
	autofree(world_map)
	return world_map


func test_party_moves_to_an_adjacent_tile() -> void:
	var world_map := _make_world_map()
	var target: Vector2i = WorldMapScript.SETTLEMENT_POSITION + Vector2i(1, 0)

	var moved: bool = world_map.try_move_party(target)

	assert_true(moved, "Party should move to an adjacent tile")
	assert_eq(world_map.party_position, target)


func test_party_cannot_move_to_a_non_adjacent_tile() -> void:
	var world_map := _make_world_map()

	var moved: bool = world_map.try_move_party(Vector2i(4, 4))

	assert_false(moved, "Party should not jump to a non-adjacent tile")
	assert_eq(world_map.party_position, WorldMapScript.SETTLEMENT_POSITION, "Rejected move must not change position")


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


## Regression test for a real bug: _unhandled_input() used to derive the
## clicked tile from board.get_local_mouse_position() -- the Viewport's
## tracked cursor position, refreshed only by MouseMotion events -- instead
## of from the InputEventMouseButton's own .position. Right after a scene
## transition (e.g. Battlefield -> World Map on victory), if the player's
## mouse hasn't physically moved since their last click on the OLD scene,
## Godot never emits a fresh MouseMotion event, so the tracked position is
## stale and can resolve to a tile far from where the player actually
## clicked -- exactly reproducing "the party isn't selectable after a
## battle." This test dispatches a real InputEventMouseButton (not a direct
## _handle_tile_click() call, which bypasses the bug entirely) through the
## real _unhandled_input() path on a fully-instantiated scene, so it
## exercises the same position-resolution code a real click goes through.
func test_a_real_click_event_selects_the_party_even_when_the_tracked_cursor_position_is_stale() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	assert_false(world_map.party_selected)

	var party_pixel_center := Vector2(world_map.party_position) * WorldMapScript.TILE_SIZE + Vector2(32, 32)
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = party_pixel_center

	world_map._unhandled_input(click_event)

	assert_true(
		world_map.party_selected,
		"a real click event carrying its own position must select the party regardless of the Viewport's separately-tracked (possibly stale) cursor position"
	)


## Every existing "real input" regression test in this file (including the
## one directly above) calls _unhandled_input() directly on the WorldMap
## node. That skips Godot's actual GUI input pipeline (Viewport -> Control
## _gui_input propagation -> _unhandled_input only if no Control consumed
## the event first), so none of them can catch a Control silently absorbing
## the click before _unhandled_input ever runs. This test instead pushes
## the event through Viewport.push_input() on the fully-instantiated scene,
## exercising the real pipeline end to end. in_local_coords=true is required
## here: push_input's default (false) reinterprets .position as
## screen-global and re-derives local coordinates via the viewport's own
## transform, which in a headless test run (no real OS window) does not
## reproduce a real click's coordinates -- true is what makes this test
## faithfully emulate the coordinates an actual OS-delivered click carries.
##
## The click lands on the Goblin Camp tile (4,4), not the settlement (0,0):
## the settlement sits under HUD/Margin/VBox/TopRow, a Container whose
## default mouse_filter (PASS) never blocked clicks, which is why a version
## of this test clicking the settlement would have missed the real bug --
## HUD/Margin/VBox/Spacer is a bare Control (default mouse_filter STOP) that
## covers the rest of the board underneath it and silently swallowed clicks
## anywhere below the top HUD row, including every tile the party could
## actually be deployed to after a battle.
func test_a_pushed_click_event_selects_the_party_through_the_real_gui_pipeline() -> void:
	# _ready() reads the party's position from GameSession, so it must be set
	# before instantiation -- setting world_map.party_position afterwards
	# would just get overwritten by _ready() when add_child_autofree() below
	# triggers it.
	GameSession.set_deployed_party_position(GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID).position)
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	await get_tree().process_frame
	assert_false(world_map.party_selected)

	var party_pixel_center := Vector2(world_map.party_position) * WorldMapScript.TILE_SIZE + Vector2(32, 32)
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = party_pixel_center

	# HUD/Margin, HUD/Margin/VBox and HUD/Margin/VBox/TopRow are mouse_filter
	# = IGNORE (see 04-first-campaign-guidance's Dismiss-button fix), so a
	# real click that finds nothing to claim it here now correctly keeps
	# searching *past* this scene entirely -- including whatever real,
	# still-live get_tree().current_scene an earlier, unrelated test left
	# behind via its own GameManager.go_to_*() call and never unloaded (a
	# pre-existing gap in several other test files, not fixed here). A
	# stale current_scene sitting anywhere in the tree can silently absorb
	# this push_input() click before it ever reaches WorldMap's own
	# _unhandled_input -- clear it first so this test only ever contends
	# with the fresh instance above.
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	world_map.get_viewport().push_input(click_event, true)

	assert_true(
		world_map.party_selected,
		"a click pushed through the real Viewport/GUI pipeline must reach _unhandled_input and select the party"
	)


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
		world_map.party_position, WorldMapScript.SETTLEMENT_POSITION, "The party should not move without first being selected"
	)


func test_clicking_an_adjacent_tile_after_selecting_sets_a_route_without_moving() -> void:
	var world_map := _make_world_map()
	var target: Vector2i = WorldMapScript.SETTLEMENT_POSITION + Vector2i(1, 0)
	world_map._handle_tile_click(world_map.party_position)

	world_map._handle_tile_click(target)

	assert_eq(world_map.party_position, WorldMapScript.SETTLEMENT_POSITION, "Setting a route must not move the party")
	assert_eq(GameSession.get_deployed_party_route(), [target])
	assert_true(world_map.party_selected, "Selection should persist after committing a route")


func test_clicking_the_committed_destination_again_takes_one_manual_step() -> void:
	var world_map := _make_world_map()
	var destination: Vector2i = WorldMapScript.SETTLEMENT_POSITION + Vector2i(2, 0)
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(destination)

	world_map._handle_tile_click(destination)

	assert_eq(
		world_map.party_position,
		WorldMapScript.SETTLEMENT_POSITION + Vector2i(1, 0),
		"Clicking the destination again should take one manual step"
	)
	assert_eq(GameSession.get_deployed_party_route(), [destination])


func test_reclicking_the_party_with_a_route_preserves_it_and_enables_repathing() -> void:
	var world_map := _make_world_map()
	var destination: Vector2i = WorldMapScript.SETTLEMENT_POSITION + Vector2i(2, 0)
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(destination)

	world_map._handle_tile_click(world_map.party_position)

	assert_eq(
		GameSession.get_deployed_party_route(),
		[WorldMapScript.SETTLEMENT_POSITION + Vector2i(1, 0), destination],
		"Reclicking the party must not clear its existing route"
	)
	assert_true(world_map.party_selected, "Party should remain selected")
	assert_true(world_map.repathing, "Reclicking a routed party should enter repathing mode")


func test_reclicking_a_routed_party_a_third_time_clears_the_route_and_reaches_the_tiles_own_activation() -> void:
	var world_map := _make_world_map()
	watch_signals(world_map)
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(Vector2i(2, 0))

	world_map._handle_tile_click(world_map.party_position)

	assert_true(world_map.repathing, "Second click on the party's own tile should enter repathing mode")
	assert_false(GameSession.get_deployed_party_route().is_empty(), "Entering repathing must not clear the route")

	world_map._handle_tile_click(world_map.party_position)

	assert_eq(
		GameSession.get_deployed_party_route(), [] as Array[Vector2i],
		"A third reclick must clear the committed route entirely"
	)
	assert_false(world_map.repathing, "Clearing the route must also exit repathing mode")
	assert_signal_emitted_with_parameters(
		world_map, "settlement_activated", [WorldMapScript.SETTLEMENT_ID]
	)


func test_repathing_mode_previews_a_new_route_alongside_the_old_one() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var start: Vector2i = world_map.party_position
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(start + Vector2i(1, 0))
	world_map._handle_tile_click(world_map.party_position)

	world_map._update_hover_route(start + Vector2i(0, 2))
	await get_tree().process_frame

	assert_eq(world_map.hover_route, [start + Vector2i(0, 1), start + Vector2i(0, 2)])
	# Old committed route (1 segment + target + label = 3) plus the new hover
	# preview (2 segments + target + label = 4) must both be visible at once.
	assert_eq(world_map.get_node("Board/Routes").get_child_count(), 7)


func test_right_click_during_repathing_cancels_the_attempt_and_keeps_the_old_route() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var start: Vector2i = world_map.party_position
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(start + Vector2i(1, 0))
	world_map._handle_tile_click(world_map.party_position)
	world_map._update_hover_route(start + Vector2i(0, 2))
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true

	world_map._unhandled_input(right_click)

	assert_eq(world_map.hover_route, [] as Array[Vector2i])
	assert_eq(GameSession.get_deployed_party_route(), [start + Vector2i(1, 0)])
	assert_false(world_map.repathing)


func test_left_click_elsewhere_during_repathing_replaces_the_route() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var start: Vector2i = world_map.party_position
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(start + Vector2i(1, 0))
	world_map._handle_tile_click(world_map.party_position)

	world_map._handle_tile_click(start + Vector2i(0, 2))

	assert_eq(GameSession.get_deployed_party_route(), [start + Vector2i(0, 1), start + Vector2i(0, 2)])
	assert_false(world_map.repathing, "Committing a new route ends repathing mode")


func test_canceling_a_route_reenables_the_hover_affordance() -> void:
	var world_map := _make_world_map()
	var start: Vector2i = world_map.party_position
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(start + Vector2i(2, 0))
	world_map._handle_tile_click(world_map.party_position)

	world_map._update_hover_route(start + Vector2i(1, 0))

	assert_eq(
		world_map.hover_route,
		[start + Vector2i(1, 0)],
		"Canceling the route should bring back the live hover preview"
	)


func test_choosing_a_new_destination_after_a_route_is_set_replaces_it() -> void:
	var world_map := _make_world_map()
	var start: Vector2i = world_map.party_position
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(start + Vector2i(2, 0))

	world_map._handle_tile_click(start + Vector2i(0, 2))

	assert_eq(GameSession.get_deployed_party_route(), [start + Vector2i(0, 1), start + Vector2i(0, 2)])


func test_right_click_cancels_the_hover_preview_and_preserves_the_route() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var start: Vector2i = world_map.party_position
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(start + Vector2i(2, 0))
	world_map._update_hover_route(start + Vector2i(0, 2))
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true

	world_map._unhandled_input(right_click)

	assert_eq(world_map.hover_route, [] as Array[Vector2i])
	assert_eq(GameSession.get_deployed_party_route(), [start + Vector2i(1, 0), start + Vector2i(2, 0)])
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
	var destination: Vector2i = WorldMapScript.SETTLEMENT_POSITION + Vector2i(2, 0)
	GameSession.set_deployed_party_route(
		[WorldMapScript.SETTLEMENT_POSITION + Vector2i(1, 0), destination] as Array[Vector2i]
	)

	assert_eq(world_map.get_route_destination(), destination)


func test_cancel_route_setting_clears_only_the_transient_hover_preview() -> void:
	var world_map := _make_world_map()
	var route_step: Vector2i = WorldMapScript.SETTLEMENT_POSITION + Vector2i(1, 0)
	GameSession.set_deployed_party_route([route_step] as Array[Vector2i])
	world_map.hover_route = [WorldMapScript.SETTLEMENT_POSITION + Vector2i(2, 0)] as Array[Vector2i]

	world_map.cancel_route_setting()

	assert_eq(world_map.hover_route, [] as Array[Vector2i])
	assert_eq(
		GameSession.get_deployed_party_route(),
		[route_step],
		"cancel_route_setting must not touch the durable route"
	)


func test_build_route_orders_horizontal_then_vertical_steps() -> void:
	var world_map := _make_world_map()

	var route: Array = world_map.build_route(Vector2i(0, 0), Vector2i(2, 1))

	assert_eq(route, [Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1)])


func test_build_route_rejects_an_out_of_bounds_endpoint() -> void:
	var world_map := _make_world_map()

	assert_eq(world_map.build_route(Vector2i(-1, 0), Vector2i(2, 1)), [] as Array[Vector2i])
	assert_eq(world_map.build_route(Vector2i(0, 0), Vector2i(7, 7)), [] as Array[Vector2i])


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
	var target: Vector2i = world_map.party_position + Vector2i(1, 0)

	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(target)
	world_map._handle_tile_click(target)

	assert_eq(
		GameSession.get_deployed_party_position(), target, "Moving the party should persist its new position"
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
	var panel: Control = world_map.get_node("%InformationPanel")
	assert_true(panel.get_node("Content/PartyName").visible)
	assert_eq(panel.get_node("Content/PartyName").text, tr("information.party") % "Party 1")


func test_world_map_does_not_draw_party_marker_when_no_party_is_deployed() -> void:
	GameSession.reset()
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	# One ColorRect + one Label per active encounter instance, plus one settlement ColorRect.
	var expected_marker_count := GameSession.get_active_encounters().size() * 2 + 1
	assert_eq(world_map.get_node("Board/Markers").get_child_count(), expected_marker_count)
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

	world_map._handle_tile_click(WorldMapScript.SETTLEMENT_POSITION)

	assert_true(world_map.party_selected)


func test_clicking_selected_party_at_settlement_emits_settlement_activated() -> void:
	var world_map := _make_world_map()
	watch_signals(world_map)

	world_map._handle_tile_click(WorldMapScript.SETTLEMENT_POSITION)
	world_map._handle_tile_click(WorldMapScript.SETTLEMENT_POSITION)

	assert_signal_emitted_with_parameters(
		world_map, "settlement_activated", ["starting_settlement"]
	)


func test_world_map_contains_the_information_panel_showing_the_current_gold_total() -> void:
	GameSession.gold = 25
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("%InformationPanel")

	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)


func test_information_panel_hides_party_name_until_the_party_marker_is_selected() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("%InformationPanel")

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
	var panel: Control = world_map.get_node("%InformationPanel")
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
	var panel: Control = world_map.get_node("%InformationPanel")
	world_map._handle_tile_click(world_map.party_position)

	panel.get_node("Content/PartyViewButton").emit_signal("pressed")

	assert_eq(
		GameManager.route_context_id,
		GameSession.selected_party_id,
		"Pressing View Party on the World Map must ask GameManager to open that party's details"
	)


func test_information_panel_shows_the_party_gold_for_a_selected_party_with_one() -> void:
	GameSession.pending_reward = 15
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("%InformationPanel")

	world_map._handle_tile_click(world_map.party_position)

	assert_true(panel.get_node("Content/PartyGold").visible)
	assert_eq(
		panel.get_node("Content/PartyGold").text, tr("information.party_gold") % 15
	)


func test_information_panel_hides_the_party_gold_row_when_there_is_none() -> void:
	GameSession.pending_reward = 0
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("%InformationPanel")

	world_map._handle_tile_click(world_map.party_position)

	assert_false(panel.get_node("Content/PartyGold").visible)


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
	var start: Vector2i = world_map.party_position
	world_map._handle_tile_click(world_map.party_position)

	world_map._update_hover_route(start + Vector2i(2, 0))

	assert_eq(world_map.hover_route, [start + Vector2i(1, 0), start + Vector2i(2, 0)])


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
		world_map.get_node("Board/Routes").get_child_count() > 0,
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
		world_map.get_node("Board/Routes").get_child_count() > 0,
		"An existing route must stay visible even after the party is deselected"
	)


func test_route_line_stays_visible_when_entering_repathing_mode() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var target: Vector2i = world_map.party_position + Vector2i(1, 0)
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(target)

	world_map._handle_tile_click(world_map.party_position)
	await get_tree().process_frame

	assert_eq(
		world_map.get_node("Board/Routes").get_child_count(), 3,
		"The route must remain visible when entering repathing mode"
	)


func test_hovering_after_a_route_is_committed_does_not_draw_a_preview() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var start: Vector2i = world_map.party_position
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(start + Vector2i(1, 0))

	world_map._update_hover_route(start + Vector2i(0, 2))
	await get_tree().process_frame

	# committed route [(1,0) offset]: 1 segment + target + label = 3, no hover overlay
	assert_eq(
		world_map.get_node("Board/Routes").get_child_count(),
		3,
		"Pathing mode ends once a route is committed, so no ghost preview should be drawn"
	)


func test_hovering_the_current_destination_does_not_duplicate_the_route() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var target: Vector2i = world_map.party_position + Vector2i(1, 0)
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(target)

	world_map._update_hover_route(target)
	await get_tree().process_frame

	assert_eq(world_map.get_node("Board/Routes").get_child_count(), 3)


func test_pressing_end_turn_advances_the_turn_without_a_route() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	world_map._on_end_turn_pressed()

	assert_eq(GameSession.world_turn, 2)
	assert_eq(world_map.party_position, WorldMapScript.SETTLEMENT_POSITION)


func test_active_battle_disables_and_blocks_end_turn() -> void:
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	world_map._on_end_turn_pressed()

	assert_true(world_map.get_node("%EndTurnButton").disabled)
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
	var target: Vector2i = world_map.party_position + Vector2i(1, 0)
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(target)

	world_map._on_end_turn_pressed()

	assert_eq(world_map.party_position, target)
	assert_eq(GameSession.get_deployed_party_position(), target)
	assert_eq(GameSession.world_turn, 2)


func test_pressing_end_turn_does_not_move_again_after_a_manual_step() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var start: Vector2i = world_map.party_position
	var destination: Vector2i = start + Vector2i(2, 0)
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(destination)
	world_map._handle_tile_click(destination)

	world_map._on_end_turn_pressed()

	assert_eq(world_map.party_position, start + Vector2i(1, 0))
	assert_eq(GameSession.world_turn, 2)


func test_end_turn_updates_the_turn_label() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	world_map._on_end_turn_pressed()

	assert_eq(world_map.get_node("%TurnLabel").text, tr("world_map.turn") % 2)


## Task 4: the map only ever draws GameSession's live active-encounter list
## (see _draw_markers), so a vacancy that refills mid-session must appear the
## very next time End Turn redraws the markers — no separate "refresh" step.
func test_world_map_redraws_a_refilled_encounter_after_enough_end_turns() -> void:
	# Force the base delay so the turn loop below still lands exactly on the
	# refill turn rather than depending on the jitter range
	# _resolve_vacancy_delay() now resolves (see GameSession.vacancy_delay_roll).
	GameSession.vacancy_delay_roll = func(_minimum: int, _maximum: int) -> int: return GameSession.ENCOUNTER_VACANCY_TURNS
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	GameSession.complete_current_encounter()
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var before_count := world_map.get_node("Board/Markers").get_child_count()
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

	var after_count := world_map.get_node("Board/Markers").get_child_count()
	assert_eq(
		after_count,
		before_count + 2,
		"A 15-turn refill should add exactly one new encounter marker (ColorRect + Label)"
	)


func _markers_include_color(world_map: Node2D, color: Color) -> bool:
	for marker in world_map.get_node("Board/Markers").get_children():
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
		label.global_position,
		Vector2(goblin_record.position) * WorldMapScript.TILE_SIZE
			+ Vector2(WorldMapScript.TILE_SIZE * 0.1, -WorldMapScript.TILE_SIZE * 0.6)
	)


func _find_expedition_label(world_map: Node2D, name_text: String) -> Label:
	for marker in world_map.get_node("Board/Markers").get_children():
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
	for child in world_map.get_node("Board/Routes").get_children():
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
	# and matching by approximate position (within 1 pixel tolerance for floating point).
	var expected_x := (
		position.x * WorldMapScript.TILE_SIZE + WorldMapScript.TILE_SIZE * 0.1
	)
	var expected_y := maxf(
		position.y * WorldMapScript.TILE_SIZE - WorldMapScript.TILE_SIZE * 0.6,
		WorldMapScript.EXPEDITION_LABEL_MIN_Y
	)
	for marker in world_map.get_node("Board/Markers").get_children():
		if marker is Label:
			if (
				abs(marker.global_position.x - expected_x) < 1.0
				and abs(marker.global_position.y - expected_y) < 1.0
			):
				return marker
	return null


## World Map isn't an encampment screen -- the persistent left nav belongs
## only on Encampment and its sub-screens; the settlement tile is how a
## party returns home from here.
func test_world_map_does_not_contain_the_camp_nav() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	assert_null(world_map.get_node_or_null("HUD/CampNav"))


func test_hud_top_right_stack_holds_turn_label_end_turn_and_information_panel() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	assert_eq(world_map.turn_label.get_parent(), world_map.end_turn_button.get_parent())
	assert_eq(world_map.information_panel.get_parent(), world_map.turn_label.get_parent())


func test_hud_bottom_panel_is_a_panel_container_not_a_manually_offset_panel() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	assert_true(world_map.get_node("%Hint").get_parent() is PanelContainer)


func test_world_map_displays_the_active_campaign_objective() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var banner: Control = world_map.get_node("%CampaignObjectiveBanner")

	assert_eq(banner.get_node("Content/TitleLabel").text, tr("campaign.obj.tier1_1.title"))
	assert_eq(banner.get_node("Content/DescLabel").text, tr("campaign.obj.tier1_1.desc"))


## Step 1 task list item 5: the banner self-subscribes to GameSession.
## campaign_progress_changed (see campaign_objective_banner.gd), so it must
## reflect a completed objective immediately, with no manual refresh call
## required anywhere in world_map.gd.
func test_world_map_campaign_objective_banner_updates_immediately_when_the_objective_advances() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var banner: Control = world_map.get_node("%CampaignObjectiveBanner")
	var title_label: Label = banner.get_node("Content/TitleLabel")
	assert_eq(title_label.text, tr("campaign.obj.tier1_1.title"))

	GameSession.complete_campaign_objective("obj_tier1_1_goblin_outpost")

	assert_eq(title_label.text, tr("campaign.obj.tier1_2.title"))
