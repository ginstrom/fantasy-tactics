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
	GameManager.create_party_on_open = false


func after_each() -> void:
	GameManager.create_party_on_open = false
	GameSession.loot_gold_roll = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
	GameSession.loot_gear_roll = func() -> float: return randf()



## The two "real post-victory scene change" tests above drive a genuine
## get_tree().change_scene_to_file() chain and never unload what they leave
## behind as get_tree().current_scene once the test finishes -- there was
## never a reason to, since none of those tests' own assertions depend on
## it being gone afterward. But a real, still-live scene sitting directly
## under root stays part of the same Viewport's GUI hit-testing for the
## rest of this file's run, and can silently intercept a later test's own
## push_input() click if the click's on-screen position happens to land on
## one of ITS controls (e.g. anywhere in the right-hand two-thirds of the
## screen, where EndTurnButton/InformationPanel live). Any test below this
## point that pushes a real click must call this first so it's only ever
## contending with its own freshly-instanced scene.
func _unload_any_stale_real_scene() -> void:
	if get_tree().current_scene != null:
		get_tree().unload_current_scene()


## GUT's own console/output panel (root/GutRunner/GutLayer) is a real,
## visible CanvasLayer that stays on screen for the whole headless run --
## positioned along the RIGHT two-thirds of the 1280x720 window (roughly
## x=643..1275), which is exactly where World Map's right-aligned TopRow
## content (EndTurnButton, InformationPanel) lives. Godot's GUI hit-testing
## sorts by CanvasLayer, not by node-tree position, so GUT's panel silently
## wins any push_input() click in that region unless it's hidden first. A
## real player never has this panel; it's purely a test-harness artifact.
func _hide_gut_debug_panel() -> CanvasLayer:
	var gut_layer: CanvasLayer = get_tree().root.get_node_or_null("GutRunner/GutLayer")
	if gut_layer != null:
		gut_layer.visible = false
	return gut_layer


## BaseButton's own "pressed" signal fires on release (button-up), not on
## press-down (Godot's default action_mode) -- a single push_input() of a
## pressed=true event is enough to reach a Control's own gui_input, but
## never enough to make a real Button actually register a click. Every real
## push_input()-driven button-click assertion below needs the full down/up
## pair a real mouse click always produces.
func _push_click(viewport: Viewport, position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	viewport.push_input(press, true)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	viewport.push_input(release, true)


func test_fresh_campaign_ui_reaches_a_deployed_first_party() -> void:
	assert_eq(GameSession.parties.size(), 0)
	var parties: Control = PartiesScene.instantiate()
	add_child_autofree(parties)
	var create_button: Button = parties.get_node("Body/Center/VBox/CreatePartyButton")
	assert_true(create_button.visible)
	assert_false(create_button.disabled)
	create_button.emit_signal("pressed")
	parties.get_node("Body/Center/VBox/PartyNameEntry/NameRow/NameInput").text = "Party 1"
	parties.get_node("Body/Center/VBox/PartyNameEntry/NameRow/ConfirmButton").emit_signal("pressed")
	assert_eq(GameSession.parties.size(), 1)

	assert_eq(GameManager.route_context_id, GameSession.FIRST_PARTY_ID)
	var details: Control = PartyDetailsScene.instantiate()
	add_child_autofree(details)
	assert_eq(details.party_id, GameSession.FIRST_PARTY_ID)

	var add_member_button: Button = details.get_node("Body/Center/VBox/AddFromRosterButton")
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


## Covers the rest of the minimal loop: move to an encounter,
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

	# Step 1 of docs/plans/2026-08-21-stage-1-campaign-spine: arrival now
	# offers the Enter/Withdraw panel instead of entering battle immediately
	# -- a real player presses Enter to proceed exactly as this does.
	assert_true(world_map.get_node("%ArrivalPanel").visible, "Arrival must offer the Enter/Withdraw panel")
	world_map.get_node("%EnterButton").pressed.emit()

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
	# Stage 5 D2: pin Dodge/Parry off so this guaranteed hit_roll actually
	# lands as a plain hit, not a randomly-evaded one -- see test_battlefield.gd's
	# _make_battlefield() for the identical fix applied to every test there.
	battlefield.grid.dodge_roll = func() -> float: return 1.0
	battlefield.grid.parry_roll = func() -> float: return 1.0
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
	assert_eq(GameSession.battle_reward, 19, "The goblin camp's rolled reward should be queued in the battle store")
	assert_eq(GameSession.pending_reward, 0, "The battle store only merges into the party's own once the player leaves the summary screen")
	assert_eq(GameSession.gold, 0, "Winning the battle alone must not bank the reward")

	# A real player always leaves the victory summary screen via its OK
	# button before the World Map is reachable at all -- see GameManager.
	# go_to_world_map(), which is what merges the battle store into the
	# party's own. This test jumps position instead of driving the real
	# scene transition (see the routing note above), so it calls the same
	# merge go_to_world_map() would trigger directly.
	GameSession.merge_battle_loot_into_party()
	assert_eq(GameSession.pending_reward, 19, "Leaving the summary screen merges the battle store into the party's own")

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
	assert_eq(GameSession.gold, 19, "Returning to the encampment must bank the queued reward")
	assert_eq(GameSession.pending_reward, 0)

	var encampment: Control = EncampmentScene.instantiate()
	add_child_autofree(encampment)
	var information_panel: Control = encampment.get_node("%InformationPanel")
	assert_eq(information_panel.get_node("Content/Gold").text, tr("information.gold") % 19)



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
	# Stage 5 D2: pin Dodge/Parry off so this guaranteed hit_roll actually
	# lands as a plain hit, not a randomly-evaded one -- see test_battlefield.gd's
	# _make_battlefield() for the identical fix applied to every test there.
	battlefield.grid.dodge_roll = func() -> float: return 1.0
	battlefield.grid.parry_roll = func() -> float: return 1.0
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
	# Stage 5 D2: pin Dodge/Parry off so this guaranteed hit_roll actually
	# lands as a plain hit, not a randomly-evaded one -- see test_battlefield.gd's
	# _make_battlefield() for the identical fix applied to every test there.
	battlefield.grid.dodge_roll = func() -> float: return 1.0
	battlefield.grid.parry_roll = func() -> float: return 1.0
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


## Covers 04-first-campaign-guidance.md's Red requirement directly: instance
## the real World Map with its real CampaignGuide banner visible, then push
## a real InputEventMouseButton (the same Viewport/GUI pipeline the test
## above uses, not the private _handle_tile_click() shortcut) through a
## board tile the banner's fixed top-left rect visually overlaps, and prove
## the click still reaches the board and selects the party. This is the
## regression the banner's MOUSE_FILTER_IGNORE tree exists to prevent.
func test_campaign_guide_never_blocks_a_real_click_through_a_guided_world_map_region() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameManager.deploy_party(GameSession.FIRST_PARTY_ID)
	assert_true(GameSession.has_deployed_party())

	# Move the party to a tile the guide's top-left banner rect (offset
	# 16..332 x, 16..160 y -- see scenes/world/world_map.tscn) visually
	# covers, so a click there is a genuine click-through-the-banner case.
	var covered_position := Vector2i(1, 1)
	GameSession.set_deployed_party_position(covered_position)

	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	assert_eq(world_map.party_position, covered_position)

	var guide: Control = world_map.get_node("%CampaignGuide")
	assert_eq(guide.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the guide must never absorb input")
	assert_eq(
		GameSession.get_campaign_guide_state(), GameSession.CAMPAIGN_GUIDE_SELECT_ROUTE,
		"a freshly deployed party with no route yet should be showing the select-route guide"
	)
	assert_true(guide.visible, "the guide must actually be on screen for this to be a real regression check")

	var covered_pixel_center: Vector2 = Vector2(covered_position) * WorldMapScript.TILE_SIZE + Vector2(32, 32)
	assert_true(
		guide.get_global_rect().has_point(covered_pixel_center),
		"the covered tile must genuinely sit under the guide's rect, or this test proves nothing"
	)

	assert_false(world_map.party_selected)
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = covered_pixel_center
	world_map.get_viewport().push_input(click_event, true)

	assert_true(
		world_map.party_selected,
		"a real click through the guided region must still select the party underneath the banner"
	)


## Manual playtesting found the Dismiss button itself unreachable on the
## World Map: HUD/Margin (and its VBox/TopRow descendants) are LATER
## siblings than HUD/CampaignGuide in world_map.tscn, so Godot's GUI hit
## test checks them first -- and being containers, their default
## mouse_filter (PASS) still claims their own full-width row for hit-testing
## purposes, even though TopRow's visible content (EndTurnButton/
## InformationPanel) is right-aligned far away from where the banner
## actually sits. PASS only bubbles the event up TopRow's own ancestor
## chain; it never lets the separate CampaignGuide sibling branch underneath
## it take the click. This test proves the real pixel a player would click
## -- the Dismiss button's own on-screen rect -- actually reaches it.
func test_campaign_guide_dismiss_button_is_reachable_by_a_real_click_on_the_world_map() -> void:
	_unload_any_stale_real_scene()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameManager.deploy_party(GameSession.FIRST_PARTY_ID)
	assert_true(GameSession.has_deployed_party())

	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	# The Dismiss button's on-screen position depends on CampaignGuide's own
	# internal VBoxContainer sort, which Godot defers to the end of the
	# frame -- let it actually run (empirically, two frames) before trusting
	# get_global_rect().
	await get_tree().process_frame
	await get_tree().process_frame

	var guide: Control = world_map.get_node("%CampaignGuide")
	assert_eq(
		GameSession.get_campaign_guide_state(), GameSession.CAMPAIGN_GUIDE_SELECT_ROUTE,
		"a freshly deployed party with no route yet should be showing the select-route guide"
	)
	assert_true(guide.visible, "the guide must actually be on screen for this to be a real regression check")

	var dismiss_button: Button = guide.get_node("%DismissButton")
	var dismiss_pixel_center: Vector2 = dismiss_button.get_global_rect().get_center()

	# The awaits above give another test elsewhere in this suite a chance to
	# interleave (Godot coroutines don't fully serialize two awaiting tests)
	# and re-plant a stale current_scene -- clear it again, right before
	# this click, not just once at the top of the test.
	_unload_any_stale_real_scene()
	_push_click(world_map.get_viewport(), dismiss_pixel_center)

	assert_true(
		GameSession.tutorial_progress.get(GameSession.CAMPAIGN_GUIDE_SELECT_ROUTE, false),
		"a real click on the Dismiss button's own on-screen position must record the dismissal"
	)
	assert_false(guide.visible, "the guide must hide itself once its message has been dismissed")


## The fix for the Dismiss-button bug above sets mouse_filter = IGNORE on
## HUD/Margin, HUD/Margin/VBox and HUD/Margin/VBox/TopRow -- containers, not
## leaves. IGNORE on a container must only disable that container's own
## catch-all click-absorption, never its descendants' own hit-testing, or
## this would trade one broken button for several others. This proves a
## real click still reaches EndTurnButton (a direct leaf of TopRow/TopRight)
## and PartyViewButton (nested two levels deeper still, inside the
## InformationPanel sub-scene) after the fix.
func test_real_buttons_inside_the_now_ignored_top_row_still_receive_clicks() -> void:
	_unload_any_stale_real_scene()
	var gut_layer := _hide_gut_debug_panel()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameManager.deploy_party(GameSession.FIRST_PARTY_ID)

	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	# Let the deferred container sort (TopRow/TopRight) actually run
	# (empirically, two frames) before trusting any button's get_global_rect().
	await get_tree().process_frame
	await get_tree().process_frame

	var end_turn_button: Button = world_map.get_node("%EndTurnButton")
	var turn_before: int = GameSession.world_turn
	_push_click(world_map.get_viewport(), end_turn_button.get_global_rect().get_center())

	assert_eq(
		GameSession.world_turn, turn_before + 1,
		"EndTurnButton, a direct leaf of the now-IGNORE TopRow, must still receive real clicks"
	)

	# Select the party first so InformationPanel actually renders PartyViewButton.
	world_map._handle_tile_click(world_map.party_position)
	assert_true(world_map.party_selected)
	await get_tree().process_frame
	await get_tree().process_frame
	var information_panel: Control = world_map.get_node("%InformationPanel")
	var party_view_button: Button = information_panel.get_node("Content/PartyViewButton")
	assert_true(party_view_button.visible, "Sanity check: selecting the party must reveal the View Party button")

	# The two awaits above give another test elsewhere in this suite a
	# chance to interleave (Godot coroutines don't fully serialize two
	# awaiting tests) and re-plant a stale current_scene -- clear it again,
	# right before this click, not just once at the top of the test.
	_unload_any_stale_real_scene()
	_push_click(world_map.get_viewport(), party_view_button.get_global_rect().get_center())

	if gut_layer != null:
		gut_layer.visible = true

	assert_eq(
		GameManager.route_context_id, GameSession.FIRST_PARTY_ID,
		"PartyViewButton, nested inside the now-IGNORE chain, must still route the real click through to Party Details"
	)


## Mirrors the World Map Dismiss-button regression test above, but for the
## other surface CampaignGuide is instanced on. Unlike World Map,
## Encampment.tscn instances CampaignGuide as the LAST child of the
## Encampment root (after Body), so it is the frontmost sibling for
## hit-testing there -- the opposite ordering from the World Map bug -- and
## this proves that ordering really does keep the Dismiss button reachable.
func test_campaign_guide_dismiss_button_is_reachable_by_a_real_click_on_encampment() -> void:
	_unload_any_stale_real_scene()
	var encampment: Control = EncampmentScene.instantiate()
	add_child_autofree(encampment)
	# The Dismiss button's on-screen position depends on CampaignGuide's own
	# internal VBoxContainer sort, which Godot defers to the end of the
	# frame -- let it actually run (empirically, two frames) before trusting
	# get_global_rect().
	await get_tree().process_frame
	await get_tree().process_frame

	var guide: Control = encampment.get_node("%CampaignGuide")
	assert_eq(
		GameSession.get_campaign_guide_state(), GameSession.CAMPAIGN_GUIDE_FORM_PARTY,
		"a fresh campaign with no parties yet should be showing the form-party guide"
	)
	assert_true(guide.visible, "the guide must actually be on screen for this to be a real regression check")

	var dismiss_button: Button = guide.get_node("%DismissButton")
	var dismiss_pixel_center: Vector2 = dismiss_button.get_global_rect().get_center()

	# The awaits above give another test elsewhere in this suite a chance to
	# interleave (Godot coroutines don't fully serialize two awaiting tests)
	# and re-plant a stale current_scene -- clear it again, right before
	# this click, not just once at the top of the test.
	_unload_any_stale_real_scene()
	_push_click(encampment.get_viewport(), dismiss_pixel_center)

	assert_true(
		GameSession.tutorial_progress.get(GameSession.CAMPAIGN_GUIDE_FORM_PARTY, false),
		"a real click on the Dismiss button's own on-screen position must record the dismissal"
	)
	assert_false(guide.visible, "the guide must hide itself once its message has been dismissed")


## Step 3 (docs/plans/2026-08-22-stage-3-campaign-assembly/03-final-victory-
## and-free-play-boundaries.md): proves the one hop the rest of this file's
## coverage stops short of -- defeating the real final-boss node through the
## genuine WorldMap -> Battlefield -> GameManager transition chain must land
## on the real, scene-instantiated Campaign Victory screen (its .tscn signal
## wiring, not victory_screen.gd new()'d bare) exactly once, with every
## approved durable summary stat rendered from live GameSession state, and
## its real Continue button must route to the real Encampment showing the
## approved free-play label -- while the completed authored ladder stays
## exactly as victory left it even after a free-play sandbox clear.
##
## The eleven earlier ladder nodes are completed via GameSession directly
## (per this file's own "jump state" convention -- test_game_session.gd's
## test_completing_every_authored_encounter_in_order_wins_the_campaign
## already exhaustively covers replaying that chain step by step); this test
## spends its own clicks solely on what's new here: the final battle's real
## routing and the real post-victory screens.
func test_defeating_the_final_boss_routes_exactly_once_to_the_real_campaign_victory_screen_and_continue_reaches_free_play() -> void:
	_unload_any_stale_real_scene()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameManager.deploy_party(GameSession.FIRST_PARTY_ID)
	assert_true(GameSession.has_deployed_party())

	var chain: Array = []
	var id: String = "obj_tier1_1_goblin_outpost"
	while id != "obj_boss_borderlands_ogre":
		chain.append(id)
		id = GameSession.CAMPAIGN_OBJECTIVES[id].next_objective_id
	for objective_id in chain:
		GameSession.enter_encounter(objective_id)
		GameSession.complete_current_encounter()
	assert_eq(GameSession.campaign_objective_id, "obj_boss_borderlands_ogre", "Sanity check: the ladder must be down to the final boss")
	assert_false(GameSession.is_campaign_completed)

	var ogre_position: Vector2i = GameSession.get_expedition("obj_boss_borderlands_ogre").position
	GameSession.set_deployed_party_position(ogre_position)
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	assert_eq(world_map.party_position, ogre_position)

	world_map._handle_tile_click(world_map.party_position)
	assert_true(world_map.party_selected, "First click on the boss node must select, not enter")
	world_map._handle_tile_click(world_map.party_position)
	assert_true(world_map.get_node("%ArrivalPanel").visible, "Arrival must offer the Enter/Withdraw panel")
	world_map.get_node("%EnterButton").pressed.emit()
	assert_eq(GameSession.selected_encounter, "obj_boss_borderlands_ogre")

	var battlefield: Node2D = BattlefieldScene.instantiate()
	battlefield.enemy_turn_beat_seconds = 0.0
	add_child_autofree(battlefield)
	battlefield.grid.hit_roll = func() -> float: return 0.0
	# Stage 5 D2: pin Dodge/Parry off so this guaranteed hit_roll actually
	# lands as a plain hit, not a randomly-evaded one -- see test_battlefield.gd's
	# _make_battlefield() for the identical fix applied to every test there.
	battlefield.grid.dodge_roll = func() -> float: return 1.0
	battlefield.grid.parry_roll = func() -> float: return 1.0
	GameSession.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
	GameSession.loot_gear_roll = func() -> float: return 1.0
	battlefield.grid.apply_super_power()

	# The Ogre's 90 HP survives one super-power hit even after the fixed 100
	# damage: 100 * (1 - 20% resist) = 80, ten short of a one-shot kill (see
	# battle_controller.gd's damage formula) -- unlike every sandbox/tier
	# enemy this file's other tests one-shot. apply_super_power()'s 100
	# action points leaves ample AP for a second attack in the same turn, so
	# this clicks the Ogre's tile twice rather than once.
	var warrior_start: Vector2i = BattleControllerScript.PLAYER_START_POSITIONS[0]
	var ogre_start: Vector2i = BattleControllerScript.ENEMY_START_POSITIONS[0]
	var adjacent_to_ogre: Vector2i = ogre_start + Vector2i.UP
	battlefield.grid._handle_tile_click(warrior_start)
	battlefield.grid._handle_tile_click(adjacent_to_ogre)
	battlefield.grid._handle_tile_click(ogre_start)
	battlefield.grid._handle_tile_click(ogre_start)

	# The eleven earlier nodes were completed via GameSession directly above
	# (never through Battlefield), so the warrior enters this fight without
	# any of their clear/kill XP -- the Ogre's own 350 XP (150 kill + 200
	# clear) then jumps it several levels in one battle, crossing a
	# PERK_LEVEL_INTERVAL boundary a normal incremental playthrough would
	# spread across many separate battles. level_up.gd's own Continue button
	# is disabled while a perk choice is pending (see is_perk_choice_pending()),
	# so this dismiss loop must pick a perk option whenever one is offered,
	# not just press Continue.
	var settle_frames := 0
	while GameSession.selected_encounter != "" and settle_frames < 30:
		if battlefield.level_up.visible:
			if GameSession.is_perk_choice_pending(battlefield.level_up.adventurer_id):
				var perk_options: VBoxContainer = battlefield.level_up.perk_options_container
				if perk_options.get_child_count() > 0:
					perk_options.get_child(0).emit_signal("pressed")
			else:
				battlefield.level_up.continue_button.emit_signal("pressed")
		await get_tree().process_frame
		settle_frames += 1
	assert_eq(GameSession.selected_encounter, "", "The final battle must resolve before the frame budget ran out")
	assert_true(GameSession.is_campaign_completed, "Defeating the Ogre must flip campaign completion")
	assert_true(GameSession.is_free_play_active)

	# Battlefield._finish_victory() must route the final boss's own victory
	# straight to the Campaign Victory screen -- unlike every earlier node,
	# never by way of BattleResult (see that function's just_won_campaign
	# branch) -- so settle only for VictoryScreen, the same real get_tree().
	# change_scene_to_file() chain the other real-transition tests in this
	# file already exercise.
	var victory_settle_frames := 0
	while (get_tree().current_scene == null or get_tree().current_scene.name != "VictoryScreen") and victory_settle_frames < 10:
		await get_tree().process_frame
		victory_settle_frames += 1
	assert_eq(
		get_tree().current_scene.name, "VictoryScreen",
		"Defeating the final boss must route directly to the real Campaign Victory screen"
	)

	var victory_screen: Control = get_tree().current_scene
	var summary := GameSession.get_campaign_victory_summary()
	assert_eq(victory_screen.get_node("Center/VBox/TurnsLabel").text, tr("victory.stat.turns") % int(summary.world_turns))
	assert_eq(victory_screen.get_node("Center/VBox/BattlesLabel").text, tr("victory.stat.battles_won") % int(summary.battles_won))
	assert_eq(victory_screen.get_node("Center/VBox/CasualtiesLabel").text, tr("victory.stat.casualties") % int(summary.casualties))
	assert_eq(victory_screen.get_node("Center/VBox/GoldLabel").text, tr("victory.stat.gold_banked") % int(summary.gold_banked))
	assert_eq(victory_screen.get_node("Center/VBox/UpgradesLabel").text, tr("victory.stat.upgrades") % int(summary.upgrades_completed))

	# Press the real Continue button through the scene's own .tscn signal
	# wiring (pressed -> _on_continue_pressed), not a direct method call.
	# ContinueButton's own .text property holds the raw translation key set
	# in victory_screen.tscn (unlike the summary labels above, which
	# victory_screen.gd's _refresh() explicitly assigns already-tr()'d
	# strings to) -- Godot's Control auto-translation resolves it for
	# on-screen display without mutating the property itself, so this must
	# tr() the button's own text the same way the real render does, rather
	# than comparing the raw key directly.
	var continue_button: Button = victory_screen.get_node("Center/VBox/ContinueButton")
	assert_eq(tr(continue_button.text), tr("victory.continue_free_play"))
	continue_button.emit_signal("pressed")

	var encampment_settle_frames := 0
	while (get_tree().current_scene == null or get_tree().current_scene.name != "Encampment") and encampment_settle_frames < 10:
		await get_tree().process_frame
		encampment_settle_frames += 1
	assert_eq(get_tree().current_scene.name, "Encampment", "Continue must route to the real Encampment")

	var live_encampment: Node = get_tree().current_scene
	var free_play_label: Label = live_encampment.get_node("CampaignObjectiveBanner/Content/FreePlayLabel")
	assert_true(free_play_label.visible, "The Encampment must visibly announce free play once the campaign is won")
	assert_eq(free_play_label.text, tr("campaign.free_play.active_label"))

	var completed_after_victory: Array = GameSession.completed_objectives.duplicate(true)

	# Post-victory repeatable vacancy activity (a sandbox site, not an
	# authored one) must never reopen the authored ladder.
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	GameSession.complete_current_encounter()

	assert_eq(GameSession.completed_objectives, completed_after_victory, "Sandbox vacancy activity must not touch the authored ladder")
	for objective_id in chain:
		assert_false(GameSession.can_enter_encounter(objective_id), "%s must never reopen after victory" % objective_id)
	assert_false(GameSession.can_enter_encounter("obj_boss_borderlands_ogre"), "The final boss node itself must never reopen after victory")
