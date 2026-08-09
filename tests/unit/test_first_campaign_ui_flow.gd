extends GutTest

const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const WorldMapScript := preload("res://scripts/world/world_map.gd")
const PartiesScene := preload("res://scenes/ui/parties.tscn")
const PartyDetailsScene := preload("res://scenes/ui/party_details.tscn")
const AddMemberScene := preload("res://scenes/ui/add_member.tscn")
const DeployPartyScene := preload("res://scenes/ui/deploy_party.tscn")
const WorldMapScene := preload("res://scenes/world/world_map.tscn")
const BattlefieldScene := preload("res://scenes/battle/battlefield.tscn")
const EncampmentScene := preload("res://scenes/ui/encampment.tscn")


func before_each() -> void:
	GameSession.reset()
	GameManager.route_context_id = ""
	GameManager.unit_details_origin = ""
	GameManager.add_member_return_party_id = ""


func after_each() -> void:
	GameSession.loot_gold_roll = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
	GameSession.loot_gear_roll = func() -> float: return randf()


func test_fresh_campaign_ui_reaches_a_deployed_first_party() -> void:
	assert_eq(GameSession.parties.size(), 0)
	var parties: Control = PartiesScene.instantiate()
	add_child_autofree(parties)
	var create_button: Button = parties.get_node("Body/Center/VBox/CreatePartyButton")
	assert_true(create_button.visible)
	assert_false(create_button.disabled)
	create_button.emit_signal("pressed")
	parties.get_node("Body/Center/VBox/PartyNameEntry/ConfirmButton").emit_signal("pressed")
	assert_eq(GameSession.parties.size(), 1)

	var party_table: Tree = parties.get_node("Body/Center/VBox/PartyTable/Tree")
	party_table.get_root().get_first_child().select(0)
	party_table.emit_signal("item_activated")
	var details: Control = PartyDetailsScene.instantiate()
	add_child_autofree(details)
	assert_eq(details.party_id, GameSession.FIRST_PARTY_ID)

	var add_member_button: Button = details.get_node("Body/Center/VBox/AddMemberButton")
	assert_true(add_member_button.visible)
	assert_false(add_member_button.disabled)
	add_member_button.emit_signal("pressed")
	var add_member: Control = AddMemberScene.instantiate()
	add_child_autofree(add_member)
	var adventurer_table: Tree = add_member.get_node("Body/Center/VBox/AdventurerTable/Tree")
	adventurer_table.get_root().get_first_child().select(0)
	adventurer_table.emit_signal("item_activated")
	assert_eq(GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids, [GameSession.WARRIOR_ID])

	GameManager.go_to_deploy_party()
	var deploy_party: Control = DeployPartyScene.instantiate()
	add_child_autofree(deploy_party)
	var deploy_table: Tree = deploy_party.get_node("Body/Center/VBox/PartyTable/Tree")
	assert_ne(deploy_table.get_root().get_first_child(), null)
	deploy_table.get_root().get_first_child().select(0)
	deploy_table.emit_signal("item_activated")

	assert_true(GameSession.has_deployed_party())
	assert_eq(GameManager.route_context_id, "")


## Covers the rest of the minimal loop (see "First playable campaign" in
## docs/plans/first-playable-campaign/game-design.md): move to an encounter,
## enter it, win the battle, then walk the party home
## and bank the reward. Party formation/deployment (the first half of the
## flow) is exercised step-by-step above; movement mechanics themselves (turn
## by turn routing) are covered exhaustively by test_world_map.gd, so this
## test jumps the deployed party's position the same way that file's own
## encounter-activation tests do, and focuses on proving the real signal
## wiring between screens (World Map -> Battlefield -> World Map ->
## Encampment) still drives GameManager/GameSession correctly end to end.
func test_fresh_campaign_completes_the_full_game_loop_and_banks_the_reward() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameManager.deploy_party(GameSession.FIRST_PARTY_ID)
	assert_true(GameSession.has_deployed_party())

	# Move to an encounter + enter it: jump the party onto the seeded Goblin
	# Camp tile, then click it twice (select, then activate) exactly as a
	# player would from the World Map.
	var goblin_position: Vector2i = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID).position
	GameSession.set_deployed_party_position(goblin_position)
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	assert_eq(world_map.party_position, goblin_position)

	world_map._handle_tile_click(world_map.party_position)
	assert_true(world_map.party_selected, "First click on the camp must select, not enter")
	world_map._handle_tile_click(world_map.party_position)

	assert_eq(GameSession.selected_encounter, GameSession.GOBLIN_CAMP_ID)

	# Complete battle: defeat the goblin via the real board-click path (not
	# the private outcome hook other battle tests use directly), so this test
	# also proves a real kill still drives the win pipeline through to
	# GameManager.complete_battle(). The goblin camp is a one-star site and
	# now fields a single goblin (see GameSession.STAR_ENEMY_COMPOSITIONS).
	var battlefield: Node2D = BattlefieldScene.instantiate()
	battlefield.enemy_turn_beat_seconds = 0.0
	add_child_autofree(battlefield)
	battlefield.grid.hit_roll = func() -> float: return 0.0
	GameSession.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
	GameSession.loot_gear_roll = func() -> float: return 1.0
	battlefield.grid.apply_super_power()

	var warrior_start: Vector2i = BattleControllerScript.PLAYER_START_POSITIONS[0]
	var goblin_start: Vector2i = BattleControllerScript.ENEMY_START_POSITIONS[0]
	var adjacent_to_goblin: Vector2i = goblin_start + Vector2i.UP
	battlefield.grid._handle_tile_click(warrior_start)
	battlefield.grid._handle_tile_click(adjacent_to_goblin)
	battlefield.grid._handle_tile_click(goblin_start)

	# Kill XP (5) plus the site's 10 clear XP totals 15 — short of the level
	# 2 threshold (20), so no level-up modal is expected here; the loop below
	# still dismisses one defensively in case a future rebalance changes the
	# math, and caps its wait so a stuck battle fails instead of hanging.
	var settle_frames := 0
	while GameSession.selected_encounter != "" and settle_frames < 30:
		if battlefield.level_up.visible:
			battlefield.level_up.continue_button.emit_signal("pressed")
		await get_tree().process_frame
		settle_frames += 1

	assert_true(GameSession.is_encounter_complete(GameSession.GOBLIN_CAMP_ID))
	assert_eq(GameSession.selected_encounter, "", "Victory should clear the encounter selection")
	assert_eq(GameSession.pending_reward, 1, "The goblin camp's rolled reward should be queued but not yet banked")
	assert_eq(GameSession.gold, 0, "Winning the battle alone must not bank the reward")

	# Move party back to encampment, bank reward: walk the party home (again
	# jumping position, per this test's routing note above) and click the
	# settlement tile to return it, the same single action that also banks
	# the queued reward.
	GameSession.set_deployed_party_position(GameSession.STARTING_SETTLEMENT_WORLD_POSITION)
	var return_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(return_map)
	assert_eq(return_map.party_position, GameSession.STARTING_SETTLEMENT_WORLD_POSITION)

	return_map._handle_tile_click(return_map.party_position)
	assert_true(return_map.party_selected, "First click on the settlement must select, not enter")
	return_map._handle_tile_click(return_map.party_position)

	assert_false(GameSession.has_deployed_party())
	assert_eq(GameSession.gold, 1, "Returning to the encampment must bank the queued reward")
	assert_eq(GameSession.pending_reward, 0)

	var encampment: Control = EncampmentScene.instantiate()
	add_child_autofree(encampment)
	var information_panel: Control = encampment.get_node("%InformationPanel")
	assert_eq(information_panel.get_node("Content/Gold").text, tr("information.gold") % 1)


## Every other test in this file either checks GameSession state directly
## or manually instantiates the next screen as a child, sidestepping the
## real GameManager.complete_battle() -> go_to_world_map() ->
## get_tree().change_scene_to_file() transition entirely. This test
## inspects the actual live scene that real transition produces, since
## that's the exact path a real player's post-victory click lands on.
func test_the_real_post_victory_scene_change_produces_a_selectable_world_map() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameManager.deploy_party(GameSession.FIRST_PARTY_ID)

	var goblin_position: Vector2i = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID).position
	GameSession.set_deployed_party_position(goblin_position)
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)

	var battlefield: Node2D = BattlefieldScene.instantiate()
	battlefield.enemy_turn_beat_seconds = 0.0
	add_child_autofree(battlefield)
	battlefield.grid.hit_roll = func() -> float: return 0.0
	GameSession.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
	GameSession.loot_gear_roll = func() -> float: return 1.0
	battlefield.grid.apply_super_power()

	var warrior_start: Vector2i = BattleControllerScript.PLAYER_START_POSITIONS[0]
	var goblin_start: Vector2i = BattleControllerScript.ENEMY_START_POSITIONS[0]
	var adjacent_to_goblin: Vector2i = goblin_start + Vector2i.UP
	battlefield.grid._handle_tile_click(warrior_start)
	battlefield.grid._handle_tile_click(adjacent_to_goblin)
	battlefield.grid._handle_tile_click(goblin_start)

	var settle_frames := 0
	while GameSession.selected_encounter != "" and settle_frames < 30:
		if battlefield.level_up.visible:
			battlefield.level_up.continue_button.emit_signal("pressed")
		await get_tree().process_frame
		settle_frames += 1
	assert_eq(GameSession.selected_encounter, "", "Victory should have resolved before the frame budget ran out")

	# Battlefield._finish_victory() now routes through GameManager.go_to_
	# battle_result() (the new victory summary screen) before ever reaching
	# the World Map -- both scene changes go through the REAL get_tree().
	# change_scene_to_file(), each deferred to the end of its frame, so
	# settle for the summary screen first, dismiss it with its real OK
	# button exactly as a player would, then settle again for the World Map
	# underneath it.
	var result_settle_frames := 0
	while (get_tree().current_scene == null or get_tree().current_scene.name != "BattleResult") and result_settle_frames < 10:
		await get_tree().process_frame
		result_settle_frames += 1
	assert_eq(get_tree().current_scene.name, "BattleResult", "Victory must land on the summary screen first")

	get_tree().current_scene.get_node("Center/VBox/OkButton").emit_signal("pressed")

	var scene_settle_frames := 0
	while (get_tree().current_scene == null or get_tree().current_scene.name != "WorldMap") and scene_settle_frames < 10:
		await get_tree().process_frame
		scene_settle_frames += 1

	var live_world_map: Node = get_tree().current_scene
	assert_not_null(live_world_map, "a real scene should be live after the post-victory transition")
	assert_eq(live_world_map.name, "WorldMap")
	assert_eq(live_world_map.party_position, goblin_position)
	assert_true(GameSession.has_deployed_party())

	assert_false(live_world_map.party_selected)
	live_world_map._handle_tile_click(live_world_map.party_position)
	assert_true(
		live_world_map.party_selected,
		"clicking the party tile on the REAL post-victory world map must select it"
	)


## Same real GameManager.complete_battle() -> go_to_world_map() ->
## change_scene_to_file() transition as the test above, but this one pushes
## a real InputEventMouseButton through the Viewport/GUI pipeline
## (push_input) instead of calling _handle_tile_click() directly. This is
## the test that actually reproduced
## docs/plans/2026-08-08-world-map-post-battle-selection-bug/index.md's
## reported bug: the Goblin Camp is at (4,4), which sits under
## HUD/Margin/VBox/Spacer (a bare Control, default mouse_filter STOP) in
## world_map.tscn, so the real click was silently absorbed before
## _unhandled_input ever ran -- exactly reproducing "the party isn't
## selectable after a battle," since a battle always ends with the party on
## whatever tile the encounter was at, never back at the settlement.
func test_a_real_click_after_the_real_post_victory_scene_change_selects_the_party() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameManager.deploy_party(GameSession.FIRST_PARTY_ID)

	var goblin_position: Vector2i = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID).position
	GameSession.set_deployed_party_position(goblin_position)
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)

	var battlefield: Node2D = BattlefieldScene.instantiate()
	battlefield.enemy_turn_beat_seconds = 0.0
	add_child_autofree(battlefield)
	battlefield.grid.hit_roll = func() -> float: return 0.0
	GameSession.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
	GameSession.loot_gear_roll = func() -> float: return 1.0
	battlefield.grid.apply_super_power()

	var warrior_start: Vector2i = BattleControllerScript.PLAYER_START_POSITIONS[0]
	var goblin_start: Vector2i = BattleControllerScript.ENEMY_START_POSITIONS[0]
	var adjacent_to_goblin: Vector2i = goblin_start + Vector2i.UP
	battlefield.grid._handle_tile_click(warrior_start)
	battlefield.grid._handle_tile_click(adjacent_to_goblin)
	battlefield.grid._handle_tile_click(goblin_start)

	var settle_frames := 0
	while GameSession.selected_encounter != "" and settle_frames < 30:
		if battlefield.level_up.visible:
			battlefield.level_up.continue_button.emit_signal("pressed")
		await get_tree().process_frame
		settle_frames += 1
	assert_eq(GameSession.selected_encounter, "", "Victory should have resolved before the frame budget ran out")

	# Battlefield._finish_victory() now routes through GameManager.go_to_
	# battle_result() (the new victory summary screen) before ever reaching
	# the World Map -- both scene changes go through the REAL get_tree().
	# change_scene_to_file(), each deferred to the end of its frame, so
	# settle for the summary screen first, dismiss it with its real OK
	# button exactly as a player would, then settle again for the World Map
	# underneath it.
	var result_settle_frames := 0
	while (get_tree().current_scene == null or get_tree().current_scene.name != "BattleResult") and result_settle_frames < 10:
		await get_tree().process_frame
		result_settle_frames += 1
	assert_eq(get_tree().current_scene.name, "BattleResult", "Victory must land on the summary screen first")

	get_tree().current_scene.get_node("Center/VBox/OkButton").emit_signal("pressed")

	var scene_settle_frames := 0
	while (get_tree().current_scene == null or get_tree().current_scene.name != "WorldMap") and scene_settle_frames < 10:
		await get_tree().process_frame
		scene_settle_frames += 1

	var live_world_map: Node = get_tree().current_scene
	assert_not_null(live_world_map, "a real scene should be live after the post-victory transition")
	assert_eq(live_world_map.name, "WorldMap")
	assert_false(live_world_map.party_selected)

	var party_pixel_center: Vector2 = (
		Vector2(live_world_map.party_position) * WorldMapScript.TILE_SIZE + Vector2(32, 32)
	)
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = party_pixel_center
	live_world_map.get_viewport().push_input(click_event, true)

	assert_true(
		live_world_map.party_selected,
		"a click pushed through the real pipeline on the REAL post-victory world map must select the party"
	)
