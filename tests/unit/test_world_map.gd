extends GutTest

const GridScript := preload("res://scripts/battle/grid.gd")
const WorldMapScript := preload("res://scripts/world/world_map.gd")
const WorldMapScene := preload("res://scenes/world/world_map.tscn")
const GameSessionScript := preload("res://scripts/autoload/game_session.gd")
const ContentCatalogScript := preload("res://scripts/content/content_catalog.gd")


func before_each() -> void:
	GameSession.reset()
	_deploy_warrior_party()


func after_each() -> void:
	GameManager.close_game_menu()
	GameManager.route_context_id = ""
	GameSession.reset_injectable_rolls()
	AudioManager.reset()


func _deploy_warrior_party() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()


func _hide_gut_debug_panel() -> CanvasLayer:
	var gut_layer: CanvasLayer = get_tree().root.get_node_or_null("GutRunner/GutLayer")
	if gut_layer != null:
		gut_layer.visible = false
	return gut_layer


func _make_world_map() -> Node2D:
	var world_map: Node2D = WorldMapScript.new()
	world_map.grid = GridScript.new(WorldMapScript.GRID_WIDTH, WorldMapScript.GRID_HEIGHT)
	autofree(world_map)
	return world_map


## Task 3: Music State Transitions (docs/plans/2026-08-18-core-loop-and-
## engagement/08-audio-system-and-soundscape.md) -- entering the World Map
## requests its own track (scripts/world/world_map.gd's _ready()).
## AudioManager.play_music() itself is exercised directly in
## tests/unit/test_audio_manager.gd -- this only proves World Map calls it
## with the right track id, mirroring test_battlefield.gd's equivalent
## coverage for Battle/Victory/Defeat (Finding 3a, task-1-report.md). Uses
## the real packed scene (WorldMapScene.instantiate()), not the bare
## _make_world_map() helper above, since the music request lives in _ready()
## and _make_world_map() never adds the node to the tree.
func test_entering_the_world_map_requests_the_world_map_music() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()

	add_child_autofree(world_map)

	assert_true(AudioManager.is_music_playing("music_world_map"))


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

	var party_pixel_center := world_map.board.global_position + Vector2(world_map.party_position) * WorldMapScript.TILE_SIZE + Vector2(32, 32)
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

	var party_pixel_center := world_map.board.global_position + Vector2(world_map.party_position) * WorldMapScript.TILE_SIZE + Vector2(32, 32)
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
	var gut_layer := _hide_gut_debug_panel()
	world_map.get_viewport().push_input(click_event, true)
	if gut_layer != null:
		gut_layer.visible = true

	assert_true(
		world_map.party_selected,
		"a click pushed through the real Viewport/GUI pipeline must reach _unhandled_input and select the party"
	)


## docs/plans/2026-08-20-placeholder-sprites/03-world-map-sprites-and-
## acceptance.md regression: tiles and the party marker are now Sprite2D
## nodes rather than ColorRects. A Sprite2D carries no Control mouse_filter
## at all, so unlike the tests above -- which specifically exercise the
## HUD's mouse_filter=IGNORE Controls not swallowing a click -- this proves
## the sprite conversion itself introduced no new interception: a real,
## pushed click landing on the party's own cell (the settlement, at the
## default deployed position) must still reach _unhandled_input and select
## the party exactly as it did when the cell body was a ColorRect.
func test_a_party_cell_click_still_selects_the_party_now_that_tiles_and_the_marker_are_sprites() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	assert_false(world_map.party_selected)

	var party_pixel_center := world_map.board.global_position + Vector2(world_map.party_position) * WorldMapScript.TILE_SIZE + Vector2(32, 32)
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = party_pixel_center

	if get_tree().current_scene != null:
		get_tree().unload_current_scene()
	var gut_layer := _hide_gut_debug_panel()
	world_map.get_viewport().push_input(click_event, true)
	if gut_layer != null:
		gut_layer.visible = true

	assert_true(
		world_map.party_selected,
		"a click on the party's cell must still select it now that the tile and marker underneath are Sprite2D nodes"
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


## Step 2 of docs/plans/2026-08-18-core-loop-and-engagement: a retreat leaves
## the party on the encounter tile it retreated from -- GameManager.
## retreat_from_battle() never touches world_position for a surviving
## retreat (see its own doc comment) -- so a freshly (re)instantiated World
## Map must resume showing the party there, not snapped back to the
## settlement.
func test_world_map_shows_the_party_still_on_the_encounter_tile_after_a_retreat() -> void:
	var encounter_position: Vector2i = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID).position
	GameSession.set_deployed_party_position(encounter_position)
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)

	GameManager.retreat_from_battle()

	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	assert_eq(world_map.party_position, encounter_position)
	assert_true(GameSession.has_deployed_party(), "A survived retreat keeps the party deployed")
	assert_false(GameSession.is_encounter_complete(GameSession.GOBLIN_CAMP_ID), "Retreat leaves the encounter unconquered")


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
	assert_true(_markers_include_party_sprite(world_map))

	world_map._handle_tile_click(world_map.party_position)

	assert_true(world_map.party_selected, "The deployed party's marker must remain selectable")
	var panel: Control = world_map.get_node("%InformationPanel")
	assert_true(panel.get_node("Content/PartyName").visible)
	assert_eq(panel.get_node("Content/PartyName").text, tr("information.party") % "Party 1")


func test_world_map_does_not_draw_party_marker_when_no_party_is_deployed() -> void:
	GameSession.reset()
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	# One ColorRect + one Label per active encounter instance, plus one more
	# ColorRect + Label pair for the current campaign objective's own marker
	# (see _current_campaign_objective_marker() -- sourced independently of
	# active_encounters, so it is not included in that count), plus one
	# settlement ColorRect.
	var expected_marker_count := (GameSession.get_active_encounters().size() + 1) * 2 + 1
	assert_eq(world_map.get_node("Board/Markers").get_child_count(), expected_marker_count)
	assert_false(_markers_include_party_sprite(world_map))


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
	GameSession.parties[0].carry.gold = 15
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("%InformationPanel")

	world_map._handle_tile_click(world_map.party_position)

	assert_true(panel.get_node("Content/PartyGold").visible)
	assert_eq(
		panel.get_node("Content/PartyGold").text, tr("information.party_gold") % 15
	)


func test_information_panel_hides_the_party_gold_row_when_there_is_none() -> void:
	GameSession.parties[0].carry.gold = 0
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("%InformationPanel")

	world_map._handle_tile_click(world_map.party_position)

	assert_false(panel.get_node("Content/PartyGold").visible)


## --- Scout strategic reconnaissance preview (Step 4) ---

func test_hovering_an_encounter_tile_with_a_scout_in_range_reveals_composition() -> void:
	# before_each() already deployed a warrior-only party; assigning a member
	# requires the party to still be encamped, so rebuild it with a Scout
	# before deploying rather than assigning into the already-deployed one.
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var scout := GameSession.get_default_scout("scout_test", "Test Scout")
	GameSession.adventurers.append(scout)
	GameSession.assign_adventurer_to_selected_party("scout_test")
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	var goblin_camp: Dictionary = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID)
	GameSession.set_deployed_party_position(goblin_camp.position)
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("%InformationPanel")

	world_map._update_hovered_encounter(goblin_camp.position)

	assert_true(panel.get_node("Content/EncounterDanger").visible)
	assert_true(panel.get_node("Content/EncounterEnemies").visible)
	assert_eq(
		panel.get_node("Content/EncounterEnemies").text,
		tr("information.encounter_enemies") % [tr("battle.enemy.goblin"), 1]
	)
	assert_false(panel.get_node("Content/EncounterDanger").text.contains("gold"), "Never reveals rewards")


func test_hovering_an_encounter_tile_without_scout_intel_reveals_nothing() -> void:
	# Per index.md's locked decision, the danger tier is gated exactly like
	# composition -- a party with no Scout in range sees neither.
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("%InformationPanel")

	world_map._update_hovered_encounter(GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID).position)

	assert_false(
		panel.get_node("Content/EncounterDanger").visible,
		"No Scout in range means the danger tier is withheld too, not just composition"
	)
	assert_false(panel.get_node("Content/EncounterEnemies").visible)


func test_hovering_away_from_an_encounter_restores_the_default_panel() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("%InformationPanel")
	world_map._update_hovered_encounter(GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID).position)

	world_map._update_hovered_encounter(Vector2i(6, 6))

	assert_false(panel.get_node("Content/EncounterDanger").visible)
	assert_false(panel.get_node("Content/EncounterEnemies").visible)


## Step 4 of docs/plans/2026-08-21-stage-2-party-readiness/
## 04-scout-ranged-and-tier-two-pattern.md's task 2: a real world_map.tscn
## scene test, not just a call into GameSession.get_party_scouting_intel()
## directly -- drives the same _draw_markers()/_update_hovered_encounter()
## path production input drives, against an AUTHORED campaign-ladder node
## (obj_tier2_1_orc_outpost, a mixed Orc Bruiser/Goblin Archer formation --
## see EXPEDITIONS) rather than only the legacy sandbox goblin_camp/
## orc_outpost ids every other marker test above already covers. Proves the
## marker's own star Label (not just the InformationPanel hover preview)
## renders identically for an authored node once a Scout is in range.
func test_world_map_scene_reveals_an_authored_tier_two_markers_star_and_composition_once_a_scout_is_in_range() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var scout := GameSession.get_default_scout("scout_test", "Test Scout")
	GameSession.adventurers.append(scout)
	GameSession.assign_adventurer_to_selected_party("scout_test")
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	# _current_campaign_objective_marker() (world_map.gd) draws whichever node
	# campaign_objective_id currently names -- advancing it directly here
	# (rather than completing the three tier-1 nodes first) is enough to make
	# this authored node's own marker exist to click/hover, matching how
	# get_party_scouting_intel()/get_expedition() themselves never consult
	# unlocked_authored_encounters at all.
	GameSession.campaign_objective_id = "obj_tier2_1_orc_outpost"
	var orc_outpost: Dictionary = GameSession.get_expedition("obj_tier2_1_orc_outpost")
	GameSession.set_deployed_party_position(orc_outpost.position)
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("%InformationPanel")

	var label := _find_expedition_label_by_position(world_map, orc_outpost.position)
	world_map._update_hovered_encounter(orc_outpost.position)

	assert_not_null(label, "The authored node's marker label must exist")
	assert_eq(label.text, "★★", "obj_tier2_1_orc_outpost is difficulty 2")
	assert_true(panel.get_node("Content/EncounterDanger").visible)
	assert_true(panel.get_node("Content/EncounterEnemies").visible)
	assert_eq(
		panel.get_node("Content/EncounterEnemies").text,
		"%s, %s" % [
			tr("information.encounter_enemies") % [tr("battle.enemy.orc_bruiser"), 1],
			tr("information.encounter_enemies") % [tr("battle.enemy.goblin_archer"), 1],
		],
		"Both groups of a mixed authored formation must render, not just the first"
	)


## Companion to the reveal test above, updated for Stage 5 Step 2 (docs/
## designs/intelligence.md line 7-8: "Knowledge does not decay or become
## stale"). Before Stage 5, moving the deployed party back out of legacy
## Scout range hid both the marker's star and the hover preview again; that
## is no longer correct once the persistent Intelligence system has learned
## this encounter's tier. This test now proves the opposite of its
## pre-Stage-5 self: once GameSession.encounter_intel has recorded a
## known_tier for this encounter, moving out of legacy range must NOT hide
## the marker's star or the hover preview -- both must keep showing the same
## persistent info, against the real scene's own redraw path
## (_draw_markers()/_update_hovered_encounter()), not just a second
## GameSession.get_encounter_intel() call in isolation. See
## test_world_map_scene_still_hides_an_authored_tier_two_markers_star_and_
## composition_after_moving_out_of_range_when_no_stage_5_intel_was_learned()
## below for the companion case this rename left uncovered: moving away
## still hides everything when Stage 5 has not learned anything yet (the
## legacy fallback path in _get_marker_star_text()/refresh_encounter()).
func test_world_map_scene_keeps_an_authored_tier_two_markers_star_and_composition_visible_after_moving_out_of_range_once_stage_5_intel_is_learned() -> void:
	# Async: _draw_markers() queue_free()s the prior call's marker children
	# rather than freeing them synchronously, so a second _draw_markers() call
	# within the same test needs a process frame to elapse before searching
	# marker_container again, or a stale (soon-to-be-freed) label with the old
	# "★★" text can still be the first match -- the same deferred-free gotcha
	# several tests above already work around for battlefield/highlight
	# children.
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var scout := GameSession.get_default_scout("scout_test", "Test Scout")
	GameSession.adventurers.append(scout)
	GameSession.assign_adventurer_to_selected_party("scout_test")
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	GameSession.campaign_objective_id = "obj_tier2_1_orc_outpost"
	var orc_outpost: Dictionary = GameSession.get_expedition("obj_tier2_1_orc_outpost")
	GameSession.set_deployed_party_position(orc_outpost.position)
	# Stage 5's own persistent record -- seeded directly rather than
	# simulating turns of RNG-driven detection, matching the pattern
	# test_world_map_scene_hover_shows_only_the_intelligence_systems_
	# currently_known_details() above already uses. INTEL_TIER_MONSTER_COUNTS
	# so the persistent composition row below can assert the exact same
	# "type, count" text the pre-Stage-5 legacy row used to assert, proving
	# the persistent system shows equivalent info, not just a truncated
	# stand-in.
	GameSession.encounter_intel["obj_tier2_1_orc_outpost"] = {
		"discovered": true, "known_tier": GameSession.INTEL_TIER_MONSTER_COUNTS, "quest_id": "",
	}
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("%InformationPanel")
	# Confirm the reveal actually happened first, so the assertions below prove
	# a real transition rather than vacuously passing against a marker that was
	# never revealed in the first place.
	assert_eq(_find_expedition_label_by_position(world_map, orc_outpost.position).text, "★★")

	# Manhattan distance from (6, 6) to (1, 1) is 10, well beyond even the
	# scout_keen_eyes-extended range of 4 -- mirrors how a real move commits
	# (GameSession.set_deployed_party_position()) followed by the screen's own
	# redraw of markers and the hover preview. This puts the party outside the
	# legacy Scout-in-range check entirely -- only the persistent Stage 5
	# record can be keeping the marker/preview visible below.
	GameSession.set_deployed_party_position(Vector2i(6, 6))
	world_map._draw_markers()
	await get_tree().process_frame
	world_map._update_hovered_encounter(orc_outpost.position)

	var label := _find_expedition_label_by_position(world_map, orc_outpost.position)
	assert_not_null(label, "The marker itself (bare location) must still exist")
	assert_eq(
		label.text, "★★",
		"Knowledge does not decay (docs/designs/intelligence.md) -- once Stage 5 has learned this encounter's tier, moving out of legacy Scout range must not withhold the star again"
	)
	assert_true(panel.get_node("Content/EncounterIntelTier").visible)
	assert_true(panel.get_node("Content/EncounterIntelEnemies").visible)
	assert_eq(
		panel.get_node("Content/EncounterIntelEnemies").text,
		"%s, %s" % [
			tr("information.encounter_enemies") % [tr("battle.enemy.orc_bruiser"), 1],
			tr("information.encounter_enemies") % [tr("battle.enemy.goblin_archer"), 1],
		],
		"The persistent Intelligence system's own row must keep showing both groups after the party leaves legacy range"
	)


## Companion to the test above: the legacy Scout-in-range fallback in
## _get_marker_star_text()/refresh_encounter() only applies while Stage 5 has
## not learned anything about this encounter yet (known_tier ==
## GameSession.INTEL_TIER_NONE). This is the case the rename above left
## uncovered -- proves that pre-Stage-5 behavior (moving out of range hides
## the marker's star and the hover preview) is unchanged when there is no
## persistent record to fall back on.
func test_world_map_scene_still_hides_an_authored_tier_two_markers_star_and_composition_after_moving_out_of_range_when_no_stage_5_intel_was_learned() -> void:
	# Async: see the sibling test above for why a process frame must elapse
	# before re-querying marker_container after a second _draw_markers() call.
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var scout := GameSession.get_default_scout("scout_test", "Test Scout")
	GameSession.adventurers.append(scout)
	GameSession.assign_adventurer_to_selected_party("scout_test")
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	GameSession.campaign_objective_id = "obj_tier2_1_orc_outpost"
	var orc_outpost: Dictionary = GameSession.get_expedition("obj_tier2_1_orc_outpost")
	GameSession.set_deployed_party_position(orc_outpost.position)
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("%InformationPanel")
	# Confirm the reveal actually happened first, so the assertions below prove
	# a real transition rather than vacuously passing against a marker that was
	# never revealed in the first place.
	assert_eq(_find_expedition_label_by_position(world_map, orc_outpost.position).text, "★★")
	assert_eq(int(GameSession.get_encounter_intel("obj_tier2_1_orc_outpost").known_tier), GameSession.INTEL_TIER_NONE)

	# Manhattan distance from (6, 6) to (1, 1) is 10, well beyond even the
	# scout_keen_eyes-extended range of 4 -- mirrors how a real move commits
	# (GameSession.set_deployed_party_position()) followed by the screen's own
	# redraw of markers and the hover preview.
	GameSession.set_deployed_party_position(Vector2i(6, 6))
	world_map._draw_markers()
	await get_tree().process_frame
	world_map._update_hovered_encounter(orc_outpost.position)

	var label := _find_expedition_label_by_position(world_map, orc_outpost.position)
	assert_not_null(label, "The marker itself (bare location) must still exist")
	assert_eq(label.text, "", "With no Stage 5 intel learned, out of range must still withhold the star")
	assert_false(panel.get_node("Content/EncounterDanger").visible)
	assert_false(panel.get_node("Content/EncounterEnemies").visible)
	assert_false(panel.get_node("Content/EncounterIntelTier").visible)
	assert_false(panel.get_node("Content/EncounterIntelEnemies").visible)


## World Map exposes only known details (Stage 5 Step 2, docs/designs/
## intelligence.md): a real scene test proving _update_hovered_encounter()
## drives InformationPanel.refresh_encounter_intel() -- via the Intelligence
## system's own GameSession.encounter_intel state, entirely independent of
## the legacy Scout-in-range path both tests above exercise (no scout, no
## deployed party at all here).
func test_world_map_scene_hover_shows_only_the_intelligence_systems_currently_known_details() -> void:
	GameSession.reset()
	GameSession.encounter_intel[GameSession.GOBLIN_CAMP_ID] = {
		"discovered": true, "known_tier": GameSession.INTEL_TIER_MAIN_MONSTER, "quest_id": "",
	}
	var goblin_camp: Dictionary = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID)
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("%InformationPanel")

	world_map._update_hovered_encounter(goblin_camp.position)

	assert_true(panel.get_node("Content/EncounterIntelTier").visible)
	assert_true(panel.get_node("Content/EncounterIntelEnemies").visible)
	assert_eq(
		panel.get_node("Content/EncounterIntelEnemies").text,
		tr("information.encounter_enemy_type_only") % tr("battle.enemy.goblin"),
		"Main monster known must show the type without a count"
	)


## Second symptom from Stage 5 Step 2 playtesting (docs/designs/
## intelligence.md): before this fix, GameSession.get_encounter_intel() (used
## by the Information Panel) and the marker's own star glyph
## (_get_marker_star_text(), which used to call only the legacy
## get_party_scouting_intel()) could disagree -- the panel could show
## tier-level intel for an encounter the party had never approached (e.g.
## learned via Encampment-based detection, which has a base 25 detection
## score even with no Scout/Watchtower per the design doc), while the map
## marker showed nothing for that same encounter. This test seeds Stage 5
## intel exactly as Encampment-based detection would -- no deployed party at
## all, mirroring the seeding the sibling test just above already uses -- and
## proves the marker's own star Label now agrees with the Information Panel
## instead of staying blank.
func test_world_map_scene_marker_star_shows_stage_5_intel_learned_with_no_deployed_party_nearby() -> void:
	GameSession.reset()
	GameSession.encounter_intel[GameSession.GOBLIN_CAMP_ID] = {
		"discovered": true, "known_tier": GameSession.INTEL_TIER_LEVEL, "quest_id": "",
	}
	var goblin_camp: Dictionary = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID)
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("%InformationPanel")

	var label := _find_expedition_label_by_position(world_map, goblin_camp.position)
	world_map._update_hovered_encounter(goblin_camp.position)

	assert_not_null(label, "Goblin Camp label should exist")
	assert_eq(
		label.text, "★",
		"The marker star must reflect Stage 5's persistent intel even with no party ever deployed near this encounter"
	)
	assert_true(panel.get_node("Content/EncounterIntelTier").visible)


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


## docs/plans/2026-08-20-placeholder-sprites/03-world-map-sprites-and-
## acceptance.md: the deployed party's marker is now a catalog-backed
## Sprite2D, not a ColorRect, so a ColorRect-color-based marker lookup can
## never find it -- this is its Sprite2D equivalent.
func _markers_include_party_sprite(world_map: Node2D) -> bool:
	for marker in world_map.get_node("Board/Markers").get_children():
		if marker is Sprite2D and marker.texture == SpriteCatalog.get_unit_texture("world_party"):
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
	# -- gated behind Scout reconnaissance (index.md's locked decision), so
	# this deploys a Scout centered between both encounters: (4, 2) is
	# Manhattan distance 2 from Goblin Camp (4, 4) and distance 2 from Orc
	# Outpost (4, 0), putting both within the required distance-3 range.
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var scout := GameSession.get_default_scout("scout_test", "Test Scout")
	GameSession.adventurers.append(scout)
	GameSession.assign_adventurer_to_selected_party("scout_test")
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	GameSession.set_deployed_party_position(Vector2i(4, 2))
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


func test_encounter_labels_show_no_stars_without_a_scout_in_range() -> void:
	# Finding: fog-of-war must hide the difficulty stars too, not just enemy
	# composition -- before_each() deploys a warrior-only party (no Scout), so
	# the default marker label must render no stars at all.
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	var goblin_record: Dictionary = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID)
	var goblin_label := _find_expedition_label_by_position(world_map, goblin_record.position)

	assert_not_null(goblin_label, "Goblin Camp label should still exist as a node")
	assert_eq(goblin_label.text, "", "No Scout in range means the difficulty stars are withheld")


func test_encounter_labels_show_stars_once_a_scout_is_within_range() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var scout := GameSession.get_default_scout("scout_test", "Test Scout")
	GameSession.adventurers.append(scout)
	GameSession.assign_adventurer_to_selected_party("scout_test")
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	var goblin_camp: Dictionary = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID)
	GameSession.set_deployed_party_position(goblin_camp.position)
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	var goblin_label := _find_expedition_label_by_position(world_map, goblin_camp.position)

	assert_not_null(goblin_label)
	assert_eq(goblin_label.text, "★", "A Scout within range reveals the difficulty stars")


## Step 5 (docs/plans/2026-08-18-core-loop-and-engagement/
## 05-authored-encounters-and-final-boss.md): once intel is earned, the
## rendered star count tracks GameSession.get_threat_stars()' dynamic 1-5
## rating -- rising with world turns elapsed on top of the encounter's own
## base difficulty -- not a value frozen at the encounter's base difficulty
## forever.
func test_encounter_labels_render_dynamic_threat_stars_as_world_turns_elapse() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var scout := GameSession.get_default_scout("scout_test", "Test Scout")
	GameSession.adventurers.append(scout)
	GameSession.assign_adventurer_to_selected_party("scout_test")
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	var goblin_camp: Dictionary = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID)
	GameSession.set_deployed_party_position(goblin_camp.position)
	GameSession.world_turn = 1 + GameSession.THREAT_TURN_INTERVAL
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	var goblin_label := _find_expedition_label_by_position(world_map, goblin_camp.position)

	assert_not_null(goblin_label)
	assert_eq(
		goblin_label.text, "★★",
		"One threat interval elapsed should render one extra star beyond the base difficulty"
	)


func test_encounter_labels_do_not_include_names_danger_or_reward() -> void:
	# Task 2: No "Goblin", "Orc", "danger", or "gold" in label text. Deploys a
	# Scout in range of both markers (see test_encounter_labels_show_only_
	# stars_for_difficulty for the (4, 2) distance math) so the labels are
	# non-empty star strings here, not vacuously-passing empty ones.
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var scout := GameSession.get_default_scout("scout_test", "Test Scout")
	GameSession.adventurers.append(scout)
	GameSession.assign_adventurer_to_selected_party("scout_test")
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	GameSession.set_deployed_party_position(Vector2i(4, 2))
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


## --- Step 5 review fix: normal-play route onto an authored encounter ------
## (docs/plans/2026-08-18-core-loop-and-engagement/
## 05-authored-encounters-and-final-boss.md). GameSession.reset() only ever
## seeds the two sandbox templates into active_encounters, so before this fix
## none of the 12 authored campaign nodes had a clickable World Map marker at
## all -- only the debug menu's direct battlefield jump could reach one. See
## _current_campaign_objective_marker() in world_map.gd.


## A fresh campaign's current objective (obj_tier1_1_goblin_outpost, per
## GameSession.reset()) must be reachable the ordinary way: standing on its
## expedition position and activating the tile.
func test_a_fresh_campaign_shows_a_clickable_marker_at_the_tier1_1_encounter_position() -> void:
	var world_map := _make_world_map()
	var tier1_1: Dictionary = GameSession.get_expedition("obj_tier1_1_goblin_outpost")
	world_map.party_position = tier1_1.position
	watch_signals(world_map)

	var activated: bool = world_map.try_activate_current_tile()

	assert_true(activated, "Standing on the current campaign objective's tile should activate it")
	assert_signal_emitted_with_parameters(
		world_map, "encounter_activated", ["obj_tier1_1_goblin_outpost"]
	)


## Entering via the World Map click path must reach the exact same
## battle-layer entry point (GameManager.enter_battle() -> GameSession.
## enter_encounter()) the debug menu's "Jump to Pre-Boss Encounter" scenario
## already proves works end-to-end for an authored id -- this test only
## proves the World Map's own routing gets there, not the battle layer again.
func test_activating_the_tier1_1_marker_selects_it_as_the_current_encounter() -> void:
	var world_map := _make_world_map()
	var tier1_1: Dictionary = GameSession.get_expedition("obj_tier1_1_goblin_outpost")
	world_map.party_position = tier1_1.position
	# GameManager.enter_battle()'s own position guard checks GameSession's
	# tracked party position, not this bare instance's local party_position
	# (never synced here since _ready() never runs without add_child) -- keep
	# both in agreement so this test still proves the World Map's routing
	# reaches the real battle-entry point, not the position guard itself.
	GameSession.set_deployed_party_position(tier1_1.position)

	world_map.try_activate_current_tile()
	GameManager.enter_battle("obj_tier1_1_goblin_outpost")

	assert_eq(GameSession.selected_encounter, "obj_tier1_1_goblin_outpost")


## The current-objective marker must also be found by hovering/clicking
## detection (_expedition_id_at()), not just by a party already standing on
## it -- otherwise Scout intel preview and click-to-select would silently
## miss it.
func test_the_tier1_1_marker_is_found_by_expedition_id_at() -> void:
	var world_map := _make_world_map()
	var tier1_1: Dictionary = GameSession.get_expedition("obj_tier1_1_goblin_outpost")

	assert_eq(world_map._expedition_id_at(tier1_1.position), "obj_tier1_1_goblin_outpost")


## Stage 6 Step 3 (docs/plans/2026-08-24-stage-6-content-and-domain-
## foundations/03-authored-content-catalog.md): the marker's position must
## be the migrated encounter's own ContentCatalog `world_position`
## specifically -- not merely "whatever GameSession.get_expedition() happens
## to return" (the assertion every other test above already makes), which
## would stay green even if the overlay in GameSession.
## _overlay_content_catalog_definition() silently stopped reading the
## catalog at all and fell back to EXPEDITIONS' own literal (2, 2).
func test_the_tier1_1_marker_sits_at_the_content_catalogs_own_world_position() -> void:
	var world_map := _make_world_map()
	var definition := ContentCatalogScript.get_encounter_definition("obj_tier1_1_goblin_outpost")

	assert_eq(GameSession.get_expedition("obj_tier1_1_goblin_outpost").position, definition.world_position)
	assert_eq(world_map._expedition_id_at(definition.world_position), "obj_tier1_1_goblin_outpost")


## Once Tier 1-1 is completed, the marker must move to the newly-unlocked
## Tier 1-2 node's own position -- never lingering at the now-cleared Tier
## 1-1 tile and never appearing at both simultaneously.
func test_the_marker_moves_to_the_next_unlocked_encounter_after_completing_an_objective() -> void:
	GameSession.complete_campaign_objective("obj_tier1_1_goblin_outpost")
	var world_map := _make_world_map()
	var tier1_1: Dictionary = GameSession.get_expedition("obj_tier1_1_goblin_outpost")
	var tier1_2: Dictionary = GameSession.get_expedition("obj_tier1_2_kobold_warren")

	assert_eq(world_map._expedition_id_at(tier1_1.position), "", "The completed node must no longer have a marker")
	assert_eq(world_map._expedition_id_at(tier1_2.position), "obj_tier1_2_kobold_warren")


## Once the campaign is complete there is no "current objective" left, so no
## authored-node marker (beyond whatever sandbox instances still exist) may
## render at all -- see GameSession.get_current_campaign_objective()'s own
## "{} once complete" contract.
func test_no_current_objective_marker_renders_once_the_campaign_is_complete() -> void:
	var id: String = "obj_tier1_1_goblin_outpost"
	while id != "":
		var next_id: String = GameSessionScript.CAMPAIGN_OBJECTIVES[id].next_objective_id
		GameSession.complete_campaign_objective(id)
		id = next_id
	assert_true(GameSession.is_campaign_completed, "Test setup must actually complete the campaign")
	var world_map := _make_world_map()

	assert_eq(world_map._current_campaign_objective_marker(), {})


## Authored objective UI must identify the required route regardless of
## intel/quest state (Stage 5 Step 2, docs/designs/intelligence.md):
## _expedition_id_at()/try_activate_current_tile() never consult GameSession.
## get_encounter_intel()/get_quests() at all, so the current objective's own
## marker/route works identically whether an unrelated sandbox encounter
## carries a fully-expired quest and full intelligence alongside it.
func test_the_current_objectives_marker_and_route_are_unaffected_by_intel_or_quest_state() -> void:
	GameSession.quest_posting_roll = func() -> float: return 0.0
	GameSession.reset()
	_deploy_warrior_party()  # reset() above cleared before_each()'s own deployed party
	var quest_id: String = String(GameSession.encounter_intel[GameSession.GOBLIN_CAMP_ID].quest_id)
	assert_false(quest_id.is_empty(), "Setup: goblin_camp should have posted a quest")
	GameSession.accept_quest(quest_id)
	for _turn in GameSession.QUEST_DURATION_TURNS_PER_TIER + 1:
		GameSession.end_world_turn()
	assert_eq(GameSession.get_quest(quest_id).status, GameSession.QUEST_STATUS_EXPIRED, "Setup: the quest must have expired")

	var world_map := _make_world_map()
	var tier1_1: Dictionary = GameSession.get_expedition("obj_tier1_1_goblin_outpost")

	assert_eq(world_map._expedition_id_at(tier1_1.position), "obj_tier1_1_goblin_outpost")
	world_map.party_position = tier1_1.position
	assert_true(
		world_map.try_activate_current_tile(),
		"The current authored objective must always be enterable, independent of any quest/intel state elsewhere"
	)


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


## --- Scouting Overlay High-Contrast Palette (Technical Design §4,
## docs/plans/2026-08-18-core-loop-and-engagement/
## 07-visual-perspective-and-tactical-polish.md) ---
## Presentation only: the reveal gating itself (Scout within Manhattan
## distance 3) is already covered above by test_encounter_labels_show_*, so
## these only assert on the label's color treatment once revealed/withheld.

func test_encounter_label_uses_the_high_contrast_palette_once_revealed() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var scout := GameSession.get_default_scout("scout_test", "Test Scout")
	GameSession.adventurers.append(scout)
	GameSession.assign_adventurer_to_selected_party("scout_test")
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	var goblin_camp: Dictionary = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID)
	GameSession.set_deployed_party_position(goblin_camp.position)
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	var label := _find_expedition_label_by_position(world_map, goblin_camp.position)

	assert_eq(label.text, "★")
	assert_true(label.has_theme_color_override("font_color"), "A revealed star count must render in the high-contrast palette")
	assert_eq(label.get_theme_color("font_color"), WorldMapScript.STAR_LABEL_COLOR)
	assert_true(label.has_theme_color_override("font_outline_color"))
	assert_eq(label.get_theme_color("font_outline_color"), WorldMapScript.STAR_LABEL_OUTLINE_COLOR)


## No Scout in range (before_each() deploys a warrior-only party) --
## test_encounter_labels_show_no_stars_without_a_scout_in_range already
## proves the text stays empty; this proves the empty label also stays in
## the theme's default color rather than drawing an eye-catching outline
## around nothing.
func test_encounter_label_stays_in_the_default_palette_when_unrevealed() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	var goblin_record: Dictionary = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID)
	var label := _find_expedition_label_by_position(world_map, goblin_record.position)

	assert_eq(label.text, "")
	assert_false(label.has_theme_color_override("font_color"))


## --- Step 1 of docs/plans/2026-08-21-stage-1-campaign-spine: pre-battle
## Withdraw's arrival panel. encounter_activated must no longer enter battle
## directly -- see _on_encounter_activated() in world_map.gd -- so these use
## the real packed scene (its [connection] block wires the signal) and press
## real button signals, not direct method calls, to prove the .tscn wiring
## itself.

func test_activating_an_encounter_via_the_real_scene_shows_the_arrival_panel_instead_of_entering_battle() -> void:
	var encounter_id := "obj_tier1_1_goblin_outpost"
	GameSession.set_deployed_party_position(GameSession.get_expedition(encounter_id).position)
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("%ArrivalPanel")
	assert_false(panel.visible, "The panel must start hidden")

	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(world_map.party_position)

	assert_true(panel.visible, "Arriving at an available encounter must offer the panel")
	assert_eq(GameSession.selected_encounter, "", "Showing the panel must not itself enter battle")


func test_pressing_withdraw_on_the_arrival_panel_records_a_homeward_route_and_closes_the_panel() -> void:
	var encounter_id := "obj_tier1_1_goblin_outpost"
	GameSession.set_deployed_party_position(GameSession.get_expedition(encounter_id).position)
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(world_map.party_position)
	var panel: Control = world_map.get_node("%ArrivalPanel")
	var withdraw_button: Button = world_map.get_node("%WithdrawButton")

	withdraw_button.pressed.emit()

	assert_false(panel.visible, "Withdraw must close the panel")
	assert_false(GameSession.get_deployed_party_route().is_empty(), "Withdraw must record a homeward route")
	assert_eq(GameSession.selected_encounter, "", "Withdraw must never enter battle")
	assert_true(GameSession.can_enter_encounter(encounter_id), "The encounter must remain available")


func test_pressing_cancel_on_the_arrival_panel_changes_nothing() -> void:
	var encounter_id := "obj_tier1_1_goblin_outpost"
	GameSession.set_deployed_party_position(GameSession.get_expedition(encounter_id).position)
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(world_map.party_position)
	var panel: Control = world_map.get_node("%ArrivalPanel")
	var cancel_button: Button = world_map.get_node("%CancelButton")

	cancel_button.pressed.emit()

	assert_false(panel.visible, "Cancel must close the panel")
	assert_true(GameSession.get_deployed_party_route().is_empty(), "Cancel must not record a route")
	assert_eq(GameSession.selected_encounter, "", "Cancel must not enter battle")
	assert_true(GameSession.can_enter_encounter(encounter_id))


func test_pressing_enter_on_the_arrival_panel_reaches_the_existing_battle_entry_path() -> void:
	var encounter_id := "obj_tier1_1_goblin_outpost"
	GameSession.set_deployed_party_position(GameSession.get_expedition(encounter_id).position)
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(world_map.party_position)
	var panel: Control = world_map.get_node("%ArrivalPanel")
	var enter_button: Button = world_map.get_node("%EnterButton")

	enter_button.pressed.emit()

	assert_eq(GameSession.selected_encounter, encounter_id, "Enter must reach the existing battle-entry path")
	assert_false(panel.visible, "Entering battle must close the arrival panel")


## Step 2 of docs/plans/2026-08-21-stage-1-campaign-spine: the homeward route
## GameSession.withdraw_from_encounter() records must be a real, walkable
## World Map route, not a marker only the save/load layer understands -- a
## freshly (re)instantiated World Map (mirroring how a restored save resumes
## play) must still show the party at the encounter tile and let ordinary
## World Map Turns carry it toward the Encampment.
func test_a_withdrawn_partys_route_still_advances_toward_the_encampment() -> void:
	var encounter_id := "obj_tier1_1_goblin_outpost"
	var encounter_position: Vector2i = GameSession.get_expedition(encounter_id).position
	GameSession.set_deployed_party_position(encounter_position)
	GameSession.withdraw_from_encounter(encounter_id, func() -> float: return 0.95)

	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	assert_eq(world_map.party_position, encounter_position, "The party must still be shown at the encounter tile")
	assert_false(GameSession.get_deployed_party_route().is_empty())

	world_map._on_end_turn_pressed()

	assert_ne(
		world_map.party_position, encounter_position,
		"A World Map Turn must advance the party along its recorded homeward route"
	)
	assert_true(GameSession.has_deployed_party(), "Withdraw must not itself remove the party from the field")


## --- Arrival must open the panel by itself, not wait for a further click ---
## Manual playtesting found that a party who *walks* onto an available
## encounter (rather than being placed there directly and re-clicked, as
## try_activate_current_tile()'s own tests above do) never saw the arrival
## panel at all -- nothing checked for arrival after a movement-driven
## position change, only after an explicit re-click on an already-standing-
## there party. Both real ways a party's position changes on the World Map
## must trigger the same check: the automatic route step a World Map Turn
## takes, and a manual one-tile step onto a route's own destination tile.

func test_arriving_at_an_encounter_via_a_world_map_turn_opens_the_arrival_panel_automatically() -> void:
	var encounter_id := "obj_tier1_1_goblin_outpost"
	var encounter_position: Vector2i = GameSession.get_expedition(encounter_id).position
	var approach_position := encounter_position + Vector2i(1, 0)
	GameSession.set_deployed_party_position(approach_position)
	GameSession.set_deployed_party_route([encounter_position])
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("%ArrivalPanel")
	assert_false(panel.visible)

	world_map._on_end_turn_pressed()

	assert_eq(world_map.party_position, encounter_position, "Setup: the auto route step must land exactly on the encounter")
	assert_true(
		panel.visible,
		"Arriving at an available encounter via a World Map Turn must open the panel automatically"
	)
	assert_eq(GameSession.selected_encounter, "", "Opening the panel must not itself enter battle")


func test_arriving_at_an_encounter_via_a_manual_route_step_click_opens_the_arrival_panel_automatically() -> void:
	var encounter_id := "obj_tier1_1_goblin_outpost"
	var encounter_position: Vector2i = GameSession.get_expedition(encounter_id).position
	var approach_position := encounter_position + Vector2i(1, 0)
	GameSession.set_deployed_party_position(approach_position)
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("%ArrivalPanel")

	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(encounter_position)
	world_map._handle_tile_click(encounter_position)

	assert_eq(world_map.party_position, encounter_position, "Setup: the manual step must land exactly on the encounter")
	assert_true(
		panel.visible,
		"A manual one-tile route step landing on an encounter must open the panel automatically"
	)


func test_end_turn_is_disabled_while_the_arrival_panel_is_open() -> void:
	var encounter_id := "obj_tier1_1_goblin_outpost"
	var encounter_position: Vector2i = GameSession.get_expedition(encounter_id).position
	var approach_position := encounter_position + Vector2i(1, 0)
	GameSession.set_deployed_party_position(approach_position)
	GameSession.set_deployed_party_route([encounter_position])
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	world_map._on_end_turn_pressed()

	assert_true(
		world_map.get_node("%EndTurnButton").disabled,
		"A World Map Turn must not be able to walk the party past an unresolved arrival choice"
	)


## Regression: withdrawing closed the arrival panel but never re-checked the
## End Turn button's disabled state, which _refresh_turn_controls() only ever
## sets on the World-Map-Turn arrival path (see _on_end_turn_pressed()) -- so
## a party that arrived via an automatic route step and then withdrew was
## left permanently unable to end another turn, with no way to walk itself
## home.
func test_end_turn_is_re_enabled_after_withdrawing_from_the_arrival_panel() -> void:
	var encounter_id := "obj_tier1_1_goblin_outpost"
	var encounter_position: Vector2i = GameSession.get_expedition(encounter_id).position
	var approach_position := encounter_position + Vector2i(1, 0)
	GameSession.set_deployed_party_position(approach_position)
	GameSession.set_deployed_party_route([encounter_position])
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	world_map._on_end_turn_pressed()
	var end_turn_button: Button = world_map.get_node("%EndTurnButton")
	assert_true(end_turn_button.disabled, "Setup: the arrival panel must disable End Turn first")

	world_map.get_node("%WithdrawButton").pressed.emit()

	assert_false(
		end_turn_button.disabled,
		"Withdraw must re-enable End Turn so a withdrawn party can walk itself home"
	)


func test_end_turn_is_re_enabled_after_cancelling_the_arrival_panel() -> void:
	var encounter_id := "obj_tier1_1_goblin_outpost"
	var encounter_position: Vector2i = GameSession.get_expedition(encounter_id).position
	var approach_position := encounter_position + Vector2i(1, 0)
	GameSession.set_deployed_party_position(approach_position)
	GameSession.set_deployed_party_route([encounter_position])
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	world_map._on_end_turn_pressed()
	var end_turn_button: Button = world_map.get_node("%EndTurnButton")
	assert_true(end_turn_button.disabled, "Setup: the arrival panel must disable End Turn first")

	world_map.get_node("%CancelButton").pressed.emit()

	assert_false(
		end_turn_button.disabled,
		"Cancel must re-enable End Turn just like Withdraw does"
	)


## --- Step 6: multi-party strategy (decision-ledger.md's D5) -----------------


## Deploys a second party at a distinct position from the first (see
## before_each()'s own _deploy_warrior_party(), party_001). Requires Guild
## Hall level 3 (get_max_party_count() == 2) -- mirrors game_session.gd's own
## multi-party test setup pattern.
func _deploy_second_party_at(position: Vector2i) -> String:
	GameSession.guild_hall_level = GameSession.GUILD_HALL_MAX_LEVEL
	GameSession.create_party("Bravo")
	var bravo_id: String = GameSession.selected_party_id
	GameSession.adventurers.append({
		"id": "warrior_bravo", "name": "Bravo Warrior", "class": "warrior",
		"level": 1, "availability_status": "available",
		"stats": GameSession.get_default_warrior().stats.duplicate(true),
		"health": GameSession.get_default_warrior().health,
		"progression": {"xp": 0.0, "perks": []},
		"equipment": GameSession.get_default_warrior().equipment.duplicate(true),
	})
	GameSession.assign_adventurer_to_party(bravo_id, "warrior_bravo")
	GameSession.deploy_party(bravo_id)
	GameSession.set_deployed_party_position(position, bravo_id)
	# Reselect the first party (Alpha) so it stays "the" World Map party --
	# _deploy_second_party_at() itself must not change which party a caller
	# was already focused on.
	GameSession.select_party(GameSessionScript.FIRST_PARTY_ID)
	return bravo_id


func test_world_map_renders_a_marker_for_every_deployed_party_not_only_the_selected_one() -> void:
	_deploy_second_party_at(Vector2i(0, 0))
	var world_map: Node2D = WorldMapScene.instantiate()

	add_child_autofree(world_map)

	var party_sprites := 0
	for child in world_map.marker_container.get_children():
		if child is Sprite2D and child.texture == SpriteCatalog.get_unit_texture("world_party"):
			party_sprites += 1
	assert_eq(party_sprites, 2, "Both the selected and the other deployed party must render their own marker")


func test_clicking_a_different_deployed_partys_tile_switches_the_selected_party_without_moving_it() -> void:
	var bravo_id := _deploy_second_party_at(Vector2i(0, 0))
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	assert_eq(GameSession.selected_party_id, GameSessionScript.FIRST_PARTY_ID, "Setup: Alpha starts selected")

	world_map._handle_tile_click(Vector2i(0, 0))

	assert_eq(GameSession.selected_party_id, bravo_id, "Clicking Bravo's tile must select Bravo")
	assert_eq(world_map.party_position, Vector2i(0, 0))
	assert_eq(GameSession.get_deployed_party_position(bravo_id), Vector2i(0, 0), "Selecting must never move the party")
	assert_eq(
		GameSession.get_deployed_party_position(GameSessionScript.FIRST_PARTY_ID),
		WorldMapScript.SETTLEMENT_POSITION,
		"Alpha's own position must be untouched by switching selection to Bravo"
	)


## Battle-party tie-break (D5's approved value): the other party's Enter must
## stay visible but disabled while a different party already owns the active
## battle.
func test_arrival_panel_enter_is_disabled_when_another_party_already_owns_the_active_battle() -> void:
	GameSession.create_battle_context("some_other_party_already_fighting", "goblin_camp")
	var encounter_id := "obj_tier1_1_goblin_outpost"
	GameSession.set_deployed_party_position(GameSession.get_expedition(encounter_id).position)
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(world_map.party_position)

	var enter_button: Button = world_map.get_node("%EnterButton")
	assert_true(world_map.get_node("%ArrivalPanel").visible)
	assert_true(enter_button.visible, "Enter must stay visible, only disabled")
	assert_true(enter_button.disabled, "A party may not claim a battle another party already owns")


func test_arrival_panel_enter_stays_enabled_when_no_other_party_owns_the_active_battle() -> void:
	var encounter_id := "obj_tier1_1_goblin_outpost"
	GameSession.set_deployed_party_position(GameSession.get_expedition(encounter_id).position)
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)

	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(world_map.party_position)

	assert_false(world_map.get_node("%EnterButton").disabled)


## --- Send Party modal (docs/designs/world-map-and-encounters.md's "Future
## multi-party model") ---


func test_send_party_requested_opens_a_modal_listing_every_deployed_party() -> void:
	var bravo_id := _deploy_second_party_at(Vector2i(1, 1))
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var modal: Control = world_map.get_node("%SendPartyModal")
	assert_false(modal.visible, "Setup: the modal starts hidden")

	world_map._on_information_panel_send_party_requested(GameSessionScript.GOBLIN_CAMP_ID)

	assert_true(modal.visible)
	var list: Control = world_map.get_node("%SendPartyList")
	assert_eq(list.get_child_count(), 2, "Both deployed parties must be listed")
	var row_names: Array = []
	for row in list.get_children():
		row_names.append(row.name)
	assert_true(row_names.has("SendPartyRow_%s" % GameSessionScript.FIRST_PARTY_ID))
	assert_true(row_names.has("SendPartyRow_%s" % bravo_id))


func test_selecting_a_party_in_the_send_party_modal_sets_only_that_partys_route_and_closes_the_modal() -> void:
	var bravo_id := _deploy_second_party_at(Vector2i(1, 1))
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	world_map._on_information_panel_send_party_requested(GameSessionScript.GOBLIN_CAMP_ID)
	var list: Control = world_map.get_node("%SendPartyList")
	var bravo_row: Control = list.get_node("SendPartyRow_%s" % bravo_id)
	var bravo_send_button: Button = bravo_row.get_node("SendButton")

	bravo_send_button.pressed.emit()

	assert_false(world_map.get_node("%SendPartyModal").visible, "Sending must close the modal")
	assert_false(
		GameSession.get_deployed_party_route(bravo_id).is_empty(),
		"Bravo must receive a route to the requested encounter"
	)
	assert_true(
		GameSession.get_deployed_party_route(GameSessionScript.FIRST_PARTY_ID).is_empty(),
		"Selecting Bravo's row must never touch Alpha's own route"
	)
	var goblin_camp: Dictionary = GameSession.get_expedition(GameSessionScript.GOBLIN_CAMP_ID)
	var bravo_route: Array = GameSession.get_deployed_party_route(bravo_id)
	assert_eq(bravo_route[bravo_route.size() - 1], goblin_camp.position)


func test_send_party_cancel_closes_the_modal_without_changing_any_route() -> void:
	_deploy_second_party_at(Vector2i(1, 1))
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	world_map._on_information_panel_send_party_requested(GameSessionScript.GOBLIN_CAMP_ID)

	world_map.get_node("%SendPartyCancelButton").pressed.emit()

	assert_false(world_map.get_node("%SendPartyModal").visible)
	assert_true(GameSession.get_deployed_party_route(GameSessionScript.FIRST_PARTY_ID).is_empty())


## Task 6: "one arriving/withdrawing/battling while another continues" -- a
## single End Turn press must open the arrival panel for whichever party (if
## any) just landed on a live encounter, while a second, independently
## routed deployed party's own travel simply continues in the background,
## completely unaffected by the first party's arrival.
func test_one_partys_arrival_via_end_turn_does_not_disturb_a_second_partys_ongoing_travel() -> void:
	var encounter_id := "obj_tier1_1_goblin_outpost"
	var encounter_position: Vector2i = GameSession.get_expedition(encounter_id).position
	var alpha_id := GameSessionScript.FIRST_PARTY_ID
	GameSession.set_deployed_party_position(encounter_position + Vector2i(1, 0), alpha_id)
	GameSession.set_deployed_party_route([encounter_position] as Array[Vector2i], alpha_id)
	var bravo_id := _deploy_second_party_at(Vector2i(0, 0))
	GameSession.set_deployed_party_route([Vector2i(0, 1), Vector2i(0, 2)] as Array[Vector2i], bravo_id)
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("%ArrivalPanel")
	assert_false(panel.visible, "Setup: the panel starts hidden")

	world_map._on_end_turn_pressed()

	assert_true(panel.visible, "Alpha's arrival at a live encounter must still open the panel automatically")
	assert_eq(GameSession.get_deployed_party_position(alpha_id), encounter_position)
	assert_eq(
		GameSession.get_deployed_party_position(bravo_id), Vector2i(0, 1),
		"Bravo must take its own route step in the very same End Turn press"
	)
	assert_eq(GameSession.get_deployed_party_route(bravo_id), [Vector2i(0, 2)] as Array[Vector2i])
	assert_eq(GameSession.selected_encounter, "", "Opening the panel must not itself enter battle")

	# Withdrawing Alpha must not touch Bravo's own state at all.
	world_map.get_node("%WithdrawButton").pressed.emit()

	assert_false(panel.visible)
	assert_eq(
		GameSession.get_deployed_party_position(bravo_id), Vector2i(0, 1),
		"Resolving Alpha's arrival must never move or otherwise disturb Bravo"
	)
	assert_eq(GameSession.get_deployed_party_route(bravo_id), [Vector2i(0, 2)] as Array[Vector2i])


## Arrival-visibility clarification (decision-ledger.md's "Arrival-visibility
## clarification, approved 2026-08-24" paragraph): _check_for_arrival() used
## to check only the currently-selected party's own tracked position, so a
## non-selected party that arrived at a live encounter via the very same End
## Turn's own auto route step never opened its arrival panel at all -- the
## player would have to notice and click that party's marker to find out.
func test_a_non_selected_partys_arrival_via_end_turn_switches_selection_and_opens_its_own_panel() -> void:
	var encounter_id := "obj_tier1_1_goblin_outpost"
	var encounter_position: Vector2i = GameSession.get_expedition(encounter_id).position
	var alpha_id := GameSessionScript.FIRST_PARTY_ID
	var alpha_start_position := GameSession.get_deployed_party_position(alpha_id)
	var bravo_id := _deploy_second_party_at(encounter_position + Vector2i(1, 0))
	GameSession.set_deployed_party_route([encounter_position] as Array[Vector2i], bravo_id)
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("%ArrivalPanel")
	assert_false(panel.visible, "Setup: the panel starts hidden")
	assert_eq(GameSession.selected_party_id, alpha_id, "Setup: Alpha starts selected")

	world_map._on_end_turn_pressed()

	assert_eq(
		GameSession.get_deployed_party_position(alpha_id), alpha_start_position,
		"Setup: Alpha itself must not have arrived anywhere this turn"
	)
	assert_eq(
		GameSession.get_deployed_party_position(bravo_id), encounter_position,
		"Setup: Bravo's own auto route step must land exactly on the encounter"
	)
	assert_eq(
		GameSession.selected_party_id, bravo_id,
		"A non-selected party's own arrival must auto-switch selection to it"
	)
	assert_eq(
		world_map.party_position, encounter_position,
		"The World Map's own tracked position must follow the selection switch"
	)
	assert_true(panel.visible, "The newly-selected party's arrival panel must open immediately")
	assert_eq(world_map.pending_arrival_encounter_id, encounter_id)
	assert_eq(GameSession.selected_encounter, "", "Opening the panel must not itself enter battle")


## Tie-break (D5's approved value, unchanged by the clarification above): when
## the already-selected party AND a different deployed party both arrive at
## their own live encounters in the very same End Turn, the selected party's
## own arrival panel still wins -- the other party's arrival is picked up on
## the player's next click, same as today for any change made to a
## non-selected party.
func test_both_parties_arriving_simultaneously_still_opens_only_the_selected_partys_panel() -> void:
	var alpha_id := GameSessionScript.FIRST_PARTY_ID
	var alpha_encounter_id := GameSessionScript.GOBLIN_CAMP_ID
	var alpha_encounter_position: Vector2i = GameSession.get_expedition(alpha_encounter_id).position
	var bravo_encounter_id := GameSessionScript.ORC_OUTPOST_ID
	var bravo_encounter_position: Vector2i = GameSession.get_expedition(bravo_encounter_id).position
	GameSession.set_deployed_party_position(alpha_encounter_position + Vector2i(1, 0), alpha_id)
	GameSession.set_deployed_party_route([alpha_encounter_position] as Array[Vector2i], alpha_id)
	var bravo_id := _deploy_second_party_at(bravo_encounter_position + Vector2i(1, 0))
	GameSession.set_deployed_party_route([bravo_encounter_position] as Array[Vector2i], bravo_id)
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("%ArrivalPanel")
	assert_false(panel.visible, "Setup: the panel starts hidden")

	world_map._on_end_turn_pressed()

	assert_eq(
		GameSession.get_deployed_party_position(alpha_id), alpha_encounter_position,
		"Setup: Alpha's own auto route step must land exactly on its encounter"
	)
	assert_eq(
		GameSession.get_deployed_party_position(bravo_id), bravo_encounter_position,
		"Setup: Bravo's own auto route step must land exactly on its encounter, simultaneously with Alpha's"
	)
	assert_eq(
		GameSession.selected_party_id, alpha_id,
		"The already-selected party's own arrival must take priority when both arrive simultaneously"
	)
	assert_true(panel.visible)
	assert_eq(
		world_map.pending_arrival_encounter_id, alpha_encounter_id,
		"The opened panel must be the already-selected party's own encounter, not the other party's"
	)


## Combined regression (independent review finding against Stage 5 D5's own
## "Arrival-visibility clarification", decision-ledger.md): continues the
## exact simultaneous-arrival scenario above -- Alpha's panel wins the tie
## and opens first -- then proves the reachable next step (clicking Bravo's
## own marker tile while Alpha's panel is STILL open, since nothing on the
## World Map screen blocks tile clicks while ArrivalPanel is visible -- it is
## a small centered PanelContainer, not a full-screen blocker) no longer
## leaves a stale panel naming Alpha's encounter while GameSession.
## selected_party_id has already moved to Bravo. Before the fix,
## _check_for_arrival() no-op'd here (its own arrival_panel.visible guard saw
## Alpha's still-open panel), so pending_arrival_encounter_id stayed Alpha's
## and a later Enter press would have entered Alpha's battle for Bravo.
func test_clicking_the_other_partys_tile_while_its_arrival_panel_is_open_refreshes_the_panel_to_its_own_encounter() -> void:
	var alpha_id := GameSessionScript.FIRST_PARTY_ID
	var alpha_encounter_id := GameSessionScript.GOBLIN_CAMP_ID
	var alpha_encounter_position: Vector2i = GameSession.get_expedition(alpha_encounter_id).position
	var bravo_encounter_id := GameSessionScript.ORC_OUTPOST_ID
	var bravo_encounter_position: Vector2i = GameSession.get_expedition(bravo_encounter_id).position
	GameSession.set_deployed_party_position(alpha_encounter_position + Vector2i(1, 0), alpha_id)
	GameSession.set_deployed_party_route([alpha_encounter_position] as Array[Vector2i], alpha_id)
	var bravo_id := _deploy_second_party_at(bravo_encounter_position + Vector2i(1, 0))
	GameSession.set_deployed_party_route([bravo_encounter_position] as Array[Vector2i], bravo_id)
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("%ArrivalPanel")

	world_map._on_end_turn_pressed()

	# Setup: matches test_both_parties_arriving_simultaneously_still_opens_
	# only_the_selected_partys_panel() above -- Alpha's own arrival wins the
	# tie and its panel is open, stale relative to Bravo.
	assert_eq(GameSession.selected_party_id, alpha_id, "Setup: Alpha wins the simultaneous-arrival tie-break")
	assert_true(panel.visible, "Setup: Alpha's own arrival panel is open")
	assert_eq(world_map.pending_arrival_encounter_id, alpha_encounter_id, "Setup: the open panel names Alpha's encounter")

	world_map._handle_tile_click(bravo_encounter_position)

	assert_eq(
		GameSession.selected_party_id, bravo_id,
		"Clicking Bravo's tile must switch selection to Bravo, same as the single-party switch-selection flow"
	)
	assert_true(panel.visible, "Bravo's own arrival must reopen the panel immediately, not leave it stuck closed")
	assert_eq(
		world_map.pending_arrival_encounter_id, bravo_encounter_id,
		"The panel must refresh to Bravo's own encounter, not stay stuck on Alpha's stale one"
	)
	assert_eq(GameSession.selected_encounter, "", "Refreshing the panel must not itself enter battle")

	# The combined scenario's actual payoff: pressing Enter now must resolve
	# Bravo's own encounter, never Alpha's stale one -- whether that's because
	# the panel itself is now correct (Part B) or because GameManager.
	# enter_battle()'s own position guard would reject a mismatch outright
	# even if it weren't (Part A, the second line of defense) -- see that
	# function's own doc comment.
	var enter_button: Button = world_map.get_node("%EnterButton")
	enter_button.pressed.emit()

	assert_eq(
		GameSession.selected_encounter, bravo_encounter_id,
		"Enter must resolve Bravo's own encounter, never Alpha's stale one"
	)
	assert_eq(
		GameSession.get_active_battle_context().owner_party_id, bravo_id,
		"The battle claim must belong to Bravo, who actually entered"
	)
	assert_false(panel.visible, "Entering battle must close the arrival panel")


## Regression (independent review, third pass): the switch-selection block's
## own _check_for_arrival() call must never re-select a DIFFERENT party than
## the one the player just explicitly clicked. Before this fix, switching
## selection to Bravo while Alpha's arrival panel was still open (Part B,
## above) called the FULL _check_for_arrival() -- including its "other party"
## loop meant for GameSession.end_world_turn(), which found Alpha still
## parked on its own live, unresolved encounter and immediately re-selected
## Alpha, silently undoing the player's click. This scenario differs from the
## one above only in that Bravo itself is NOT standing on any live encounter
## -- so the "own position" check inside _check_for_arrival()/its replacement
## here finds nothing for Bravo, which is exactly the branch that used to
## fall through into the other-party loop and bounce back to Alpha.
func test_clicking_a_party_with_no_arrival_of_its_own_does_not_bounce_selection_back() -> void:
	var alpha_id := GameSessionScript.FIRST_PARTY_ID
	var alpha_encounter_id := GameSessionScript.GOBLIN_CAMP_ID
	var alpha_encounter_position: Vector2i = GameSession.get_expedition(alpha_encounter_id).position
	GameSession.set_deployed_party_position(alpha_encounter_position + Vector2i(1, 0), alpha_id)
	GameSession.set_deployed_party_route([alpha_encounter_position] as Array[Vector2i], alpha_id)
	var bravo_position := Vector2i(0, 0)
	var bravo_id := _deploy_second_party_at(bravo_position)
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	var panel: Control = world_map.get_node("%ArrivalPanel")

	world_map._on_end_turn_pressed()

	# Setup: only Alpha arrives (Bravo never had a route, so it never moved
	# and stands nowhere near a live encounter); Alpha's panel is open.
	assert_eq(GameSession.selected_party_id, alpha_id, "Setup: Alpha arrived and its panel opened")
	assert_true(panel.visible, "Setup: Alpha's own arrival panel is open")

	world_map._handle_tile_click(bravo_position)

	assert_eq(
		GameSession.selected_party_id, bravo_id,
		"Clicking Bravo's tile must select Bravo and keep it selected, even though Bravo has no arrival of its own"
	)
	assert_eq(
		world_map.party_position, bravo_position,
		"The World Map's own tracked position must follow Bravo, not silently snap back to Alpha's"
	)
	assert_false(
		panel.visible,
		"Bravo has no live arrival, so no panel should reopen for anyone -- Alpha's must stay closed, not reopen"
	)


## Information Design Step 3 (03-panels-and-modal-shell.md):
## World Map information has distinct top/right/bottom zones with
## non-intersecting rects at the supported viewport (1280x720), and legacy
## overlapping guidance (CampaignGuide) is absent from the World Map.
func test_world_map_panels_have_non_intersecting_rects_and_no_legacy_overlapping_guidance() -> void:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_null(
		world_map.get_node_or_null("%CampaignGuide"),
		"Legacy overlapping CampaignGuide must be absent from the World Map"
	)

	var objective_banner: Control = world_map.get_node("%CampaignObjectiveBanner")
	var info_panel: Control = world_map.get_node("%InformationPanel")
	var bottom_hint: Control = world_map.get_node("%Hint")

	assert_not_null(objective_banner, "Top zone must contain CampaignObjectiveBanner")
	assert_not_null(info_panel, "Right zone must contain InformationPanel")
	assert_not_null(bottom_hint, "Bottom zone must contain Hint")

	var banner_rect: Rect2 = objective_banner.get_global_rect()
	var info_rect: Rect2 = info_panel.get_global_rect()
	var hint_rect: Rect2 = bottom_hint.get_global_rect()

	assert_false(
		banner_rect.intersects(info_rect),
		"CampaignObjectiveBanner rect %s must not intersect InformationPanel rect %s" % [banner_rect, info_rect]
	)
	assert_false(
		banner_rect.intersects(hint_rect),
		"CampaignObjectiveBanner rect %s must not intersect Hint rect %s" % [banner_rect, hint_rect]
	)
	assert_false(
		info_rect.intersects(hint_rect),
		"InformationPanel rect %s must not intersect Hint rect %s" % [info_rect, hint_rect]
	)
