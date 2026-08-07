extends GutTest

const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
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


func test_fresh_campaign_ui_reaches_a_deployed_first_party() -> void:
	assert_eq(GameSession.parties.size(), 0)
	var parties: Control = PartiesScene.instantiate()
	add_child_autofree(parties)
	var create_button: Button = parties.get_node("Body/Center/VBox/CreatePartyButton")
	assert_true(create_button.visible)
	assert_false(create_button.disabled)
	create_button.emit_signal("pressed")
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


## Covers the rest of docs/plans/first-playable-campaign/game-loop-flow.md:
## move to an encounter, enter it, win the battle, then walk the party home
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
	assert_eq(GameSession.pending_reward, 10, "The goblin camp's reward should be queued but not yet banked")
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
	assert_eq(GameSession.gold, 10, "Returning to the encampment must bank the queued reward")
	assert_eq(GameSession.pending_reward, 0)

	var encampment: Control = EncampmentScene.instantiate()
	add_child_autofree(encampment)
	var information_panel: Control = encampment.get_node("%InformationPanel")
	assert_eq(information_panel.get_node("Content/Gold").text, tr("information.gold") % 10)
