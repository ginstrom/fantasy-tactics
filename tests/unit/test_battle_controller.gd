extends GutTest

const GridScript := preload("res://scripts/battle/grid.gd")
const UnitScript := preload("res://scripts/battle/unit.gd")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const BattlefieldScene := preload("res://scenes/battle/battlefield.tscn")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameSession.reset_injectable_rolls()


func _make_controller(width: int, height: int) -> Node2D:
	var controller: Node2D = BattleControllerScript.new()
	controller.grid = GridScript.new(width, height)
	autofree(controller)
	return controller


func test_units_start_their_active_side_with_six_action_points() -> void:
	var controller := _make_controller(6, 6)
	var player = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE)
	var enemy = UnitScript.new(Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY)
	controller.units = [player, enemy]

	assert_eq(player.max_action_points, 6)
	assert_eq(player.action_points_remaining, 6)
	controller.end_turn()
	assert_eq(enemy.action_points_remaining, 6)


func test_three_moves_then_an_adjacent_attack_spend_the_full_six_action_points() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE)
	var defender = UnitScript.new(Vector2i(3, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker

	assert_true(controller.try_move_selected_unit(Vector2i(3, 0)))
	assert_eq(attacker.action_points_remaining, 3)
	assert_true(controller.try_attack_selected_unit(defender.grid_position))
	assert_eq(attacker.action_points_remaining, 0)


func test_two_adjacent_basic_attacks_are_legal_with_six_action_points() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 1, 10)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker

	assert_true(controller.try_attack_selected_unit(defender.grid_position))
	assert_eq(attacker.action_points_remaining, 3)
	assert_true(controller.try_attack_selected_unit(defender.grid_position))
	assert_eq(attacker.action_points_remaining, 0)


func test_sharpened_weapon_adds_one_raw_damage_before_resistance() -> void:
	var controller := _make_controller(3, 3)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, 0, 6, 3, 2, 2)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 10, 1, 1, 1.0, "Attack", "", 0, 50)
	attacker.raw_damage_bonus = 1
	controller.damage_roll = func(_minimum: int, _maximum: int) -> int: return 2
	controller.hit_roll = func() -> float: return 0.0
	controller.units = [attacker, defender]
	controller.selected_unit = attacker

	assert_true(controller.try_attack_selected_unit(defender.grid_position))
	assert_eq(controller.last_attack_result.damage, 2, "(2 + 1) raw damage rounds to 2 after 50% resistance")


func test_thorn_rune_applies_paralyze_after_a_melee_hit_only_when_its_roll_succeeds() -> void:
	var controller := _make_controller(3, 3)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 10)
	var defender = UnitScript.new(Vector2i(1, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	defender.rune_id = "thorn"
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.active_side = BattleControllerScript.Side.ENEMY
	controller.hit_roll = func() -> float: return 0.0
	controller.rune_trigger_roll = func() -> float: return 0.0

	assert_true(controller.try_attack_selected_unit(defender.grid_position))
	assert_true(controller.has_status(attacker, "paralyzed"))
	assert_true(controller.last_attack_result.get("thorn_triggered", false))
	assert_gt(attacker.health, 0, "Thorn resolves after the hit has already damaged its defender")


func test_thorn_rune_leaves_the_attacker_unaffected_when_the_trigger_roll_fails() -> void:
	var controller := _make_controller(3, 3)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 10)
	var defender = UnitScript.new(Vector2i(1, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	defender.rune_id = "thorn"
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.active_side = BattleControllerScript.Side.ENEMY
	controller.hit_roll = func() -> float: return 0.0
	controller.rune_trigger_roll = func() -> float: return 1.0

	assert_true(controller.try_attack_selected_unit(defender.grid_position))
	assert_false(controller.has_status(attacker, "paralyzed"))
	assert_false(controller.last_attack_result.get("thorn_triggered", false))


func test_paralyze_blocks_actions_without_spending_action_points_and_expires_at_the_round_boundary() -> void:
	var controller := _make_controller(4, 4)
	var player = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	var enemy = UnitScript.new(Vector2i(2, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 10)
	controller.units = [player, enemy]
	controller.selected_unit = player
	assert_true(controller.apply_status(player, "paralyzed"))

	assert_false(controller.try_move_selected_unit(Vector2i(1, 2)))
	assert_false(controller.try_attack_selected_unit(enemy.grid_position))
	assert_eq(player.action_points_remaining, 6)
	assert_false(controller.apply_status(player, "paralyzed"), "Paralyze does not refresh while active")
	controller.end_turn()
	controller.end_turn()

	assert_false(controller.has_status(player, "paralyzed"))
	controller.selected_unit = player
	assert_true(controller.try_move_selected_unit(Vector2i(1, 2)))


func test_paralyzed_enemy_turn_ends_without_moving_or_attacking() -> void:
	var controller := _make_controller(4, 4)
	var player = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10)
	var enemy = UnitScript.new(Vector2i(3, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 10)
	controller.units = [player, enemy]
	assert_true(controller.apply_status(enemy, "paralyzed"))
	controller.end_turn()

	assert_eq(controller.run_enemy_turn(), [])
	assert_eq(enemy.grid_position, Vector2i(3, 1))
	assert_eq(player.health, 10)


func test_paralyze_blocks_potion_use_and_item_transfer_without_mutating_inventory() -> void:
	GameSession.recruit_adventurer()
	var ally_id: String = GameSession.adventurers[-1].id
	GameSession.banked_gear = {"healing_potion": 2}
	assert_true(GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "healing_potion"))
	var controller := _make_controller(4, 4)
	var holder = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10, 1, 1, 1.0, "Sword", GameSession.WARRIOR_ID)
	holder.health = 4
	var ally = UnitScript.new(Vector2i(2, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10, 1, 1, 1.0, "Sword", ally_id)
	controller.units = [holder, ally]
	controller.selected_unit = holder
	assert_true(controller.apply_status(holder, "paralyzed"))

	assert_false(controller.try_use_selected_potion("healing_potion"))
	assert_false(controller.try_transfer_selected_item("healing_potion", ally_id))
	assert_eq(holder.action_points_remaining, 6)
	assert_eq(GameSession.get_carried_item_ids(GameSession.WARRIOR_ID).count("healing_potion"), 1)
	assert_eq(GameSession.get_carried_item_ids(ally_id).count("healing_potion"), 0)


func test_selected_player_transfers_a_carried_potion_to_an_ally_for_two_action_points() -> void:
	GameSession.recruit_adventurer()
	var ally_id: String = GameSession.adventurers[-1].id
	GameSession.banked_gear = {"healing_potion": 1}
	assert_true(GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "healing_potion"))
	var controller := _make_controller(4, 4)
	var holder = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10, 1, 1, 1.0, "Sword", GameSession.WARRIOR_ID)
	var ally = UnitScript.new(Vector2i(2, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10, 1, 1, 1.0, "Sword", ally_id)
	controller.units = [holder, ally]
	controller.selected_unit = holder

	assert_true(controller.try_transfer_selected_item("healing_potion", ally_id))
	assert_eq(holder.action_points_remaining, 4)
	assert_eq(GameSession.get_carried_item_ids(GameSession.WARRIOR_ID).count("healing_potion"), 0)
	assert_eq(GameSession.get_carried_item_ids(ally_id).count("healing_potion"), 1)


func test_selected_player_uses_a_held_potion_for_two_action_points_and_consumes_it() -> void:
	GameSession.banked_gear = {"healing_potion": 1}
	assert_true(GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "healing_potion"))
	var controller := _make_controller(4, 4)
	var holder = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6, 10, 1, 1, 1.0, "Sword", GameSession.WARRIOR_ID)
	holder.health = 4
	controller.healing_roll = func(_minimum: int, maximum: int) -> int: return maximum
	controller.units = [holder]
	controller.selected_unit = holder

	assert_true(controller.try_use_selected_potion("healing_potion"))
	assert_eq(holder.action_points_remaining, 4)
	assert_eq(holder.health, 10, "Healing is capped at the unit maximum")
	assert_eq(GameSession.get_carried_item_ids(GameSession.WARRIOR_ID).count("healing_potion"), 0)


func test_invalid_potion_use_preserves_action_points_and_inventory() -> void:
	GameSession.banked_gear = {"healing_potion": 1}
	assert_true(GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "healing_potion"))
	var controller := _make_controller(4, 4)
	var holder = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 1, 10, 1, 1, 1.0, "Sword", GameSession.WARRIOR_ID)
	holder.health = 5
	controller.units = [holder]
	controller.selected_unit = holder

	assert_false(controller.try_use_selected_potion("healing_potion"))
	assert_eq(holder.action_points_remaining, 1)
	assert_eq(holder.health, 5)
	assert_eq(GameSession.get_carried_item_ids(GameSession.WARRIOR_ID).count("healing_potion"), 1)


func test_unaffordable_attack_preserves_action_points_and_combat_state() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE)
	var defender = UnitScript.new(Vector2i(4, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	assert_true(controller.try_move_selected_unit(Vector2i(4, 0)))
	var health_before: int = defender.health

	assert_false(controller.try_attack_selected_unit(defender.grid_position))
	assert_eq(attacker.action_points_remaining, 2)
	assert_eq(attacker.grid_position, Vector2i(4, 0))
	assert_eq(defender.health, health_before)
	assert_eq(controller.last_attack_result, {})


func test_end_turn_forfeits_departing_action_points_and_resets_only_the_new_side() -> void:
	var controller := _make_controller(6, 6)
	var player = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE)
	var enemy = UnitScript.new(Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY)
	controller.units = [player, enemy]
	controller.selected_unit = player
	assert_true(controller.try_move_selected_unit(Vector2i(4, 1)))

	controller.end_turn()

	assert_eq(player.action_points_remaining, 3, "The departing side keeps its forfeited remainder until its next turn")
	assert_eq(enemy.action_points_remaining, 6)


func test_unit_moves_to_an_unoccupied_adjacent_tile() -> void:
	var controller := _make_controller(4, 4)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE)
	controller.units = [mover]
	controller.selected_unit = mover

	var moved: bool = controller.try_move_selected_unit(Vector2i(2, 1))

	assert_true(moved, "Move to an empty adjacent tile should succeed")
	assert_eq(mover.grid_position, Vector2i(2, 1))


func test_unit_cannot_move_onto_an_occupied_adjacent_tile() -> void:
	var controller := _make_controller(4, 4)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE)
	var blocker = UnitScript.new(Vector2i(2, 1), Color.INDIAN_RED)
	controller.units = [mover, blocker]
	controller.selected_unit = mover

	var moved: bool = controller.try_move_selected_unit(Vector2i(2, 1))

	assert_false(moved, "Move onto an occupied tile should be rejected")
	assert_eq(mover.grid_position, Vector2i(1, 1), "Rejected move must not change position")


func test_unit_can_move_to_an_unoccupied_tile_within_its_action_point_budget() -> void:
	var controller := _make_controller(4, 4)
	var mover = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE)
	controller.units = [mover]
	controller.selected_unit = mover

	var moved: bool = controller.try_move_selected_unit(Vector2i(3, 3))

	assert_true(moved, "Click movement can spend multiple action points at once")
	assert_eq(mover.grid_position, Vector2i(3, 3))


func test_unit_can_move_multiple_tiles_within_its_move_range() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]
	controller.selected_unit = mover

	var moved: bool = controller.try_move_selected_unit(Vector2i(4, 1))

	assert_true(moved, "Move within the unit's move range should succeed")
	assert_eq(mover.grid_position, Vector2i(4, 1))


func test_unit_cannot_move_beyond_its_move_range() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 2)
	controller.units = [mover]
	controller.selected_unit = mover

	var moved: bool = controller.try_move_selected_unit(Vector2i(4, 1))

	assert_false(moved, "Move beyond the move range should be rejected")
	assert_eq(mover.grid_position, Vector2i(1, 1))


func test_unit_cannot_move_through_an_occupied_tile() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var blocker = UnitScript.new(Vector2i(2, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 1)
	controller.units = [mover, blocker]
	controller.selected_unit = mover

	var moved: bool = controller.try_move_selected_unit(Vector2i(3, 1))

	assert_false(moved, "Movement cannot pass through an occupied tile")
	assert_eq(mover.grid_position, Vector2i(1, 1))


func test_unit_can_click_move_multiple_times_within_the_same_turn_while_points_remain() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]
	controller.selected_unit = mover

	var first_moved: bool = controller.try_move_selected_unit(Vector2i(2, 1))
	controller.selected_unit = mover
	var second_moved: bool = controller.try_move_selected_unit(Vector2i(4, 1))

	assert_true(first_moved, "The first move (spending 1 of 3 points) should succeed")
	assert_true(second_moved, "The second move (spending the remaining 2 points) should succeed")
	assert_eq(mover.grid_position, Vector2i(4, 1))
	assert_eq(mover.action_points_remaining, 0, "The full budget has been spent across both moves")


func test_unit_cannot_move_once_its_points_budget_is_exhausted() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]
	controller.selected_unit = mover
	controller.try_move_selected_unit(Vector2i(4, 1))
	controller.selected_unit = mover

	var moved_again: bool = controller.try_move_selected_unit(Vector2i(5, 1))

	assert_false(moved_again, "A unit with no movement points remaining cannot move again")
	assert_eq(mover.grid_position, Vector2i(4, 1))


func test_move_is_rejected_for_a_unit_on_the_inactive_side() -> void:
	var controller := _make_controller(6, 6)
	var enemy = UnitScript.new(Vector2i(1, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [enemy]
	controller.selected_unit = enemy
	controller.active_side = BattleControllerScript.Side.PLAYER

	var moved: bool = controller.try_move_selected_unit(Vector2i(2, 1))

	assert_false(moved, "A unit cannot move on the opposing side's turn")
	assert_eq(enemy.grid_position, Vector2i(1, 1))


func test_end_turn_switches_the_active_side_and_resets_movement() -> void:
	var controller := _make_controller(6, 6)
	var player_unit = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 2)
	var enemy_unit = UnitScript.new(Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 2)
	controller.units = [player_unit, enemy_unit]
	controller.active_side = BattleControllerScript.Side.PLAYER
	controller.selected_unit = player_unit
	controller.try_move_selected_unit(Vector2i(2, 1))

	controller.end_turn()

	assert_eq(controller.active_side, BattleControllerScript.Side.ENEMY, "End turn hands control to the other side")
	assert_eq(enemy_unit.action_points_remaining, enemy_unit.max_action_points, "The newly active side's units have not acted yet")

	controller.end_turn()

	assert_eq(controller.active_side, BattleControllerScript.Side.PLAYER, "End turn returns control to the first side")
	assert_eq(player_unit.action_points_remaining, player_unit.max_action_points, "The player's unit regains its AP on its next turn")


func test_end_turn_selects_the_first_living_player_unit_when_a_new_round_starts() -> void:
	var controller := _make_controller(6, 6)
	var first = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_001"
	)
	var second = UnitScript.new(
		Vector2i(1, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_002"
	)
	var enemy_unit = UnitScript.new(Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 2)
	controller.units = [first, second, enemy_unit]
	controller._player_adventurer_ids = ["warrior_001", "warrior_002"] as Array[String]
	controller.active_side = BattleControllerScript.Side.PLAYER
	controller.selected_unit = second

	controller.end_turn()

	assert_null(controller.selected_unit, "Handing control to the enemy does not select one of its units")

	controller.end_turn()

	assert_eq(controller.active_side, BattleControllerScript.Side.PLAYER, "Control returns to the player")
	assert_eq(
		controller.selected_unit, first, "The first party member should be selected when a new round starts"
	)


func test_end_turn_skips_a_defeated_party_member_when_selecting_at_round_start() -> void:
	var controller := _make_controller(6, 6)
	var first = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_001"
	)
	var second = UnitScript.new(
		Vector2i(1, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_002"
	)
	var enemy_unit = UnitScript.new(Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 2)
	first.health = 0
	controller.units = [first, second, enemy_unit]
	controller._player_adventurer_ids = ["warrior_001", "warrior_002"] as Array[String]
	controller.active_side = BattleControllerScript.Side.PLAYER

	controller.end_turn()
	controller.end_turn()

	assert_eq(
		controller.selected_unit, second, "A defeated party member cannot be the round-start selection"
	)


func test_ready_spawns_one_unit_per_party_member_in_party_order() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.recruit_adventurer()
	var recruit_id: String = GameSession.adventurers[-1].id
	GameSession.assign_adventurer_to_selected_party(recruit_id)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	var player_units: Array = []
	for unit in controller.units:
		if unit.side == BattleControllerScript.Side.PLAYER:
			player_units.append(unit)

	assert_eq(player_units.size(), 2, "One Unit should be fielded per party member")
	var first = controller.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	var second = controller.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[1])
	assert_not_null(first, "The first party member should spawn at the first player start position")
	assert_eq(first.adventurer_id, GameSession.WARRIOR_ID)
	assert_not_null(second, "The second party member should spawn at the second player start position")
	assert_eq(second.adventurer_id, recruit_id)


func test_ready_selects_the_first_party_member_so_round_one_opens_with_a_selection() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.recruit_adventurer()
	var recruit_id: String = GameSession.adventurers[-1].id
	GameSession.assign_adventurer_to_selected_party(recruit_id)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	assert_not_null(controller.selected_unit, "Round one should open with a unit already selected")
	assert_eq(controller.selected_unit.adventurer_id, GameSession.WARRIOR_ID)


func test_ready_spawns_the_full_party_and_the_encounters_full_enemy_count() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	assert_eq(controller.units.size(), 2, "One Warrior (fallback) plus one goblin")
	var warrior = controller.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	assert_not_null(warrior, "Warrior should spawn at the first player start position")
	assert_eq(warrior.side, BattleControllerScript.Side.PLAYER)
	assert_eq(warrior.max_health, 10)
	assert_eq(warrior.max_action_points, BattleControllerScript.BASE_ACTION_POINTS)
	assert_eq(warrior.damage_min, 1)
	assert_eq(warrior.damage_max, 8)
	assert_eq(warrior.hit_chance, 0.6)

	var goblin = controller.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	assert_not_null(goblin, "A goblin should spawn at the first enemy start position")
	assert_eq(goblin.side, BattleControllerScript.Side.ENEMY)
	assert_eq(goblin.max_health, 13)
	assert_eq(goblin.damage_min, 2)
	assert_eq(goblin.damage_max, 2)
	assert_eq(goblin.hit_chance, 0.3)
	assert_eq(goblin.attack_name, tr("battle.enemy.goblin.attack"))


func test_ready_builds_one_orc_when_the_orc_outpost_resolves_to_orcs() -> void:
	GameSession.enemy_composition_roll = func(_option_count: int) -> int: return 1
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	var enemy_units: Array = []
	for unit in controller.units:
		if unit.side == BattleControllerScript.Side.ENEMY:
			enemy_units.append(unit)
	assert_eq(enemy_units.size(), 1, "The orc-outpost's orc option fields one orc")

	var orc = controller.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	assert_not_null(orc)
	assert_eq(orc.side, BattleControllerScript.Side.ENEMY)
	assert_eq(orc.max_health, 22)
	assert_eq(orc.damage_min, 3)
	assert_eq(orc.damage_max, 3)
	assert_eq(orc.hit_chance, 0.5)
	assert_eq(orc.attack_name, tr("battle.enemy.orc.attack"))


func test_ready_builds_two_goblins_when_the_orc_outpost_resolves_to_goblins() -> void:
	GameSession.enemy_composition_roll = func(_option_count: int) -> int: return 0
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	var enemy_units: Array = []
	for unit in controller.units:
		if unit.side == BattleControllerScript.Side.ENEMY:
			enemy_units.append(unit)
	assert_eq(enemy_units.size(), 2, "The orc-outpost's goblins option fields two goblins")

	for index in 2:
		var goblin = controller.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[index])
		assert_not_null(goblin)
		assert_eq(goblin.max_health, 13)
		assert_eq(goblin.damage_min, 2)
		assert_eq(goblin.damage_max, 2)
		assert_eq(goblin.hit_chance, 0.3)


func test_ready_builds_one_goblin_when_the_goblin_camp_is_selected() -> void:
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	var enemy_units: Array = []
	for unit in controller.units:
		if unit.side == BattleControllerScript.Side.ENEMY:
			enemy_units.append(unit)
	assert_eq(enemy_units.size(), 1, "The goblin camp should field one goblin")

	var goblin = controller.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	assert_not_null(goblin)
	assert_eq(goblin.max_health, 13)
	assert_eq(goblin.damage_min, 2)
	assert_eq(goblin.damage_max, 2)
	assert_eq(goblin.hit_chance, 0.3)
	assert_eq(goblin.attack_name, tr("battle.enemy.goblin.attack"))


func test_enemy_start_positions_supports_up_to_eight_enemies() -> void:
	assert_eq(BattleControllerScript.ENEMY_START_POSITIONS.size(), 8)


func test_ready_fields_up_to_eight_enemies_when_the_encounter_has_that_many() -> void:
	GameSession.reset()
	var enemy_stats: Dictionary = GameSession.GOBLIN_ENEMY_STATS.duplicate(true)
	enemy_stats["count"] = 8
	GameSession.active_encounters.append({
		"id": "capacity_test",
		"template_id": GameSession.GOBLIN_CAMP_ID,
		"position": Vector2i(2, 2),
		"name_key": "expedition.goblin_camp.name",
		"danger_key": "expedition.danger.low",
		"difficulty": 1,
		"kill_xp": 5,
		"clear_xp": 10,
		"enemy": enemy_stats,
	})
	GameSession.selected_encounter = "capacity_test"
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	var enemy_units: Array = []
	for unit in controller.units:
		if unit.side == BattleControllerScript.Side.ENEMY:
			enemy_units.append(unit)
	assert_eq(enemy_units.size(), 8, "All eight enemy start positions should be usable")

	var seen_positions: Array[Vector2i] = []
	for unit in enemy_units:
		assert_true(controller.grid.is_in_bounds(unit.grid_position), "Every enemy start position must be on the board")
		assert_false(seen_positions.has(unit.grid_position), "No two enemies should share a start tile")
		seen_positions.append(unit.grid_position)


## Task 2: the player Unit is built from the selected party's first member's
## effective (derived) combat stats rather than fixed constants.
func test_ready_builds_the_player_unit_from_the_first_partys_effective_stats() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 20.0)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid
	var warrior = controller.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])

	assert_eq(
		warrior.max_health,
		GameSession.get_effective_max_health(GameSession.WARRIOR_ID),
		"The unit's max health must come from GameSession's derived value"
	)
	assert_eq(warrior.max_health, 20, "One level up should have added ten max health")
	assert_eq(warrior.health, 20, "A fresh unit starts at full (derived) health")


func test_ready_builds_the_player_unit_with_its_equipped_weapon_range() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])

	assert_eq(
		Vector2i(warrior.attack_min_range, warrior.attack_max_range),
		GameSession.get_effective_weapon_attack_range(GameSession.WARRIOR_ID),
		"Battle range must be copied from the equipped weapon definition"
	)


func test_ready_builds_the_player_unit_with_a_ninety_five_percent_hit_chance_when_raw_attack_reaches_one_hundred() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 140.0)
	GameSession.adventurers[0].stats.melee = 100
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])

	assert_eq(
		GameSession.get_adventurer(GameSession.WARRIOR_ID).stats.melee,
		100,
		"Raw Melee itself must not be capped"
	)
	assert_eq(warrior.hit_chance, 0.95, "Raw Attack 100 should cap the unit's hit chance at 0.95")


func test_ready_builds_the_player_unit_with_one_extra_move_tile_after_choosing_bonus_move() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 50.0)
	GameSession.choose_perk(GameSession.WARRIOR_ID, GameSession.BONUS_MOVE_PERK_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])

	assert_eq(warrior.max_action_points, 7, "The bonus_move perk should add one flexible action point")


func test_ready_falls_back_to_the_default_warrior_when_no_party_is_selected() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])

	assert_eq(warrior.max_health, GameSession.get_effective_max_health(GameSession.WARRIOR_ID))
	assert_eq(warrior.hit_chance, GameSession.get_effective_hit_chance(GameSession.WARRIOR_ID))
	assert_eq(warrior.max_action_points, GameSession.get_effective_action_points(GameSession.WARRIOR_ID))


func test_ready_assigns_the_adventurers_name_as_the_player_units_display_name() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])

	assert_eq(warrior.display_name, "Warrior")
	assert_eq(warrior.enemy_type_name, "", "Player units have no enemy type name")


func test_ready_indexes_even_a_solo_enemy() -> void:
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])

	assert_eq(goblin.display_name, "Goblin 1", "Enemies are always indexed, even the only one fielded")
	assert_eq(goblin.enemy_type_name, "Goblin")


func test_ready_assigns_stable_indexed_display_names_to_same_type_enemies() -> void:
	GameSession.reset()
	var enemy_stats: Dictionary = GameSession.KOBOLD_ENEMY_STATS.duplicate(true)
	enemy_stats["count"] = 3
	GameSession.active_encounters.append({
		"id": "capacity_test",
		"template_id": GameSession.RUINED_FORTRESS_ID,
		"position": Vector2i(2, 2),
		"name_key": "expedition.ruined_fortress.name",
		"danger_key": "expedition.danger.high",
		"difficulty": 3,
		"kill_xp": 3,
		"clear_xp": 30,
		"enemy": enemy_stats,
	})
	GameSession.selected_encounter = "capacity_test"
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	var names: Array = []
	for unit in controller.units:
		if unit.side == BattleControllerScript.Side.ENEMY:
			names.append(unit.display_name)
			assert_eq(unit.enemy_type_name, "Kobold")
	names.sort()
	assert_eq(names, ["Kobold 1", "Kobold 2", "Kobold 3"])


func test_attack_hits_and_deals_damage_when_the_roll_is_below_hit_chance() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword"
	)
	var defender = UnitScript.new(
		Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 3, 1, 1, 0.3, "Short Sword"
	)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_true(attacked)
	assert_eq(defender.health, 1, "A hit applies the attacker's fixed damage")
	assert_eq(attacker.action_points_remaining, 0)


func test_attack_misses_and_deals_no_damage_when_the_roll_is_at_or_above_hit_chance() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword"
	)
	var defender = UnitScript.new(
		Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 3, 1, 1, 0.3, "Short Sword"
	)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.99

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_true(attacked)
	assert_eq(defender.health, 3, "A miss must not change the defender's health")


func test_attack_defeats_and_removes_the_target_when_health_reaches_zero() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword"
	)
	var defender = UnitScript.new(
		Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 1, 1, 1, 0.3, "Short Sword"
	)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0

	controller.try_attack_selected_unit(defender.grid_position)

	assert_false(defender.is_alive())
	assert_eq(controller.units, [attacker], "A defeated unit is removed from the board")
	assert_null(controller.get_unit_at(defender.grid_position))


func test_attack_is_rejected_against_a_non_adjacent_target() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var defender = UnitScript.new(Vector2i(5, 5), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_false(attacked)
	assert_eq(defender.health, defender.max_health)


func test_two_attacks_are_allowed_when_the_unit_can_afford_both() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 5)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.try_attack_selected_unit(defender.grid_position)
	controller.selected_unit = attacker

	var attacked_again: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_true(attacked_again, "A unit can spend its remaining AP on a second attack")


func test_attack_is_rejected_for_a_unit_on_the_inactive_side() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	var defender = UnitScript.new(Vector2i(1, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.active_side = BattleControllerScript.Side.PLAYER

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_false(attacked)


func test_unit_can_move_then_attack_in_the_same_turn() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	var defender = UnitScript.new(Vector2i(2, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker

	var moved: bool = controller.try_move_selected_unit(Vector2i(2, 1))
	controller.selected_unit = attacker
	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_true(moved)
	assert_true(attacked)


func test_unit_can_attack_then_move_in_the_same_turn() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)
	controller.selected_unit = attacker
	var moved: bool = controller.try_move_selected_unit(Vector2i(2, 1))

	assert_true(attacked, "Attacking first must still be legal")
	assert_true(moved, "Moving after attacking must still be legal - order does not matter")


func test_end_turn_resets_action_points_for_the_newly_active_side() -> void:
	var controller := _make_controller(6, 6)
	var player_unit = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var enemy_unit = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [player_unit, enemy_unit]
	controller.active_side = BattleControllerScript.Side.PLAYER
	controller.selected_unit = player_unit
	controller.try_attack_selected_unit(enemy_unit.grid_position)

	controller.end_turn()
	controller.end_turn()

	assert_eq(player_unit.action_points_remaining, player_unit.max_action_points, "The player's unit regains its AP on its next turn")


func test_is_battle_won_when_no_living_enemies_remain() -> void:
	var controller := _make_controller(6, 6)
	var player_unit = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [player_unit]

	assert_true(controller.is_battle_won())
	assert_false(controller.is_battle_lost())


func test_is_battle_lost_when_no_living_player_units_remain() -> void:
	var controller := _make_controller(6, 6)
	var enemy_unit = UnitScript.new(Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [enemy_unit]

	assert_true(controller.is_battle_lost())
	assert_false(controller.is_battle_won())


func test_run_enemy_turn_moves_the_goblin_toward_the_nearest_player_unit() -> void:
	var controller := _make_controller(6, 6)
	var goblin = UnitScript.new(Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 1)
	var player_unit = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 1)
	controller.units = [goblin, player_unit]
	controller.active_side = BattleControllerScript.Side.ENEMY

	var steps: Array = controller.run_enemy_turn()

	assert_eq(steps.size(), 1)
	assert_eq(steps[0].type, "move")
	assert_eq(
		goblin.grid_position,
		Vector2i(4, 3),
		"Of the four adjacent tiles, (4,3) and (3,4) tie for closest to (1,1); reading order picks the smaller y"
	)


func test_run_enemy_turn_attacks_without_moving_when_already_adjacent() -> void:
	var controller := _make_controller(6, 6)
	var goblin = UnitScript.new(
		Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 3, 1, 1, 0.3, "Short Sword"
	)
	var player_unit = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword"
	)
	controller.units = [goblin, player_unit]
	controller.active_side = BattleControllerScript.Side.ENEMY
	controller.hit_roll = func() -> float: return 0.0

	var steps: Array = controller.run_enemy_turn()

	assert_eq(steps.size(), 1)
	assert_eq(steps[0].type, "attack")
	assert_true(steps[0].hit)
	assert_eq(steps[0].damage, 1)
	assert_eq(player_unit.health, 2)
	assert_eq(goblin.grid_position, Vector2i(1, 2), "An already-adjacent goblin should not move")


func test_run_enemy_turn_moves_then_attacks_when_movement_closes_the_gap() -> void:
	var controller := _make_controller(6, 6)
	var goblin = UnitScript.new(
		Vector2i(3, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6, 3, 1, 1, 0.3, "Short Sword"
	)
	var player_unit = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword"
	)
	controller.units = [goblin, player_unit]
	controller.active_side = BattleControllerScript.Side.ENEMY
	controller.hit_roll = func() -> float: return 0.0

	var steps: Array = controller.run_enemy_turn()

	assert_eq(steps.size(), 2)
	assert_eq(steps[0].type, "move")
	assert_eq(
		goblin.grid_position,
		Vector2i(1, 0),
		"The goblin uses its full move range to reach the closest legal tile, then attacks from adjacent range"
	)
	assert_eq(steps[1].type, "attack")
	assert_eq(player_unit.health, 2)


func test_run_enemy_turn_breaks_target_ties_using_reading_order() -> void:
	var controller := _make_controller(6, 6)
	var goblin = UnitScript.new(Vector2i(3, 3), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 1)
	var player_a = UnitScript.new(Vector2i(0, 3), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 1)
	var player_b = UnitScript.new(Vector2i(3, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 1)
	controller.units = [goblin, player_a, player_b]
	controller.active_side = BattleControllerScript.Side.ENEMY

	controller.run_enemy_turn()

	assert_eq(
		goblin.grid_position,
		Vector2i(3, 2),
		"Both player units are 3 tiles away; reading order (top-to-bottom) must pick player_b at (3, 0)"
	)


func test_run_enemy_turn_returns_no_steps_when_no_living_player_units_remain() -> void:
	var controller := _make_controller(6, 6)
	var goblin = UnitScript.new(Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [goblin]
	controller.active_side = BattleControllerScript.Side.ENEMY

	var steps: Array = controller.run_enemy_turn()

	assert_eq(steps, [])
	assert_eq(goblin.grid_position, Vector2i(4, 4))


func test_locked_input_is_ignored_by_handle_tile_click() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]
	controller.input_locked = true

	controller._handle_tile_click(Vector2i(1, 1))

	assert_null(controller.selected_unit, "A locked board must ignore clicks")


func test_apply_super_power_maxes_out_player_units_only() -> void:
	var controller := _make_controller(6, 6)
	var warrior = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6
	)
	var goblin = UnitScript.new(
		Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 3, 1, 1, 0.3
	)
	controller.units = [warrior, goblin]

	controller.apply_super_power()

	assert_eq(warrior.max_action_points, BattleControllerScript.SUPER_POWER_ACTION_POINTS)
	assert_eq(warrior.damage_min, BattleControllerScript.SUPER_POWER_ATTACK_DAMAGE)
	assert_eq(warrior.damage_max, BattleControllerScript.SUPER_POWER_ATTACK_DAMAGE)
	assert_eq(warrior.hit_chance, BattleControllerScript.SUPER_POWER_HIT_CHANCE)
	assert_eq(goblin.max_action_points, 3, "Super Power must not affect enemy units")
	assert_eq(goblin.damage_min, 1, "Super Power must not affect enemy units")
	assert_eq(goblin.damage_max, 1, "Super Power must not affect enemy units")
	assert_eq(goblin.hit_chance, 0.3, "Super Power must not affect enemy units")


func test_wasd_step_moves_one_tile_and_spends_one_movement_point() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]
	controller.selected_unit = mover

	var stepped: bool = controller.try_step_selected_unit(Vector2i.RIGHT)

	assert_true(stepped, "A step onto an empty adjacent tile should succeed")
	assert_eq(mover.grid_position, Vector2i(2, 1))
	assert_eq(mover.action_points_remaining, 2, "A single step spends exactly one action point")


func test_wasd_step_is_rejected_once_movement_points_are_exhausted() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 1)
	controller.units = [mover]
	controller.selected_unit = mover

	var first_step: bool = controller.try_step_selected_unit(Vector2i.RIGHT)
	controller.selected_unit = mover
	var second_step: bool = controller.try_step_selected_unit(Vector2i.RIGHT)

	assert_true(first_step, "The first step (spending the only movement point) should succeed")
	assert_false(second_step, "A unit with no movement points remaining cannot step again")
	assert_eq(mover.grid_position, Vector2i(2, 1))


func test_wasd_step_onto_an_enemy_tile_attacks_instead_of_moving() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword"
	)
	var defender = UnitScript.new(
		Vector2i(2, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 3, 1, 1, 0.3, "Short Sword"
	)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0

	var stepped: bool = controller.try_step_selected_unit(Vector2i.RIGHT)

	assert_true(stepped, "Stepping into an enemy-occupied tile should succeed as an attack")
	assert_eq(defender.health, 1, "The step-attack applies the attacker's fixed damage")
	assert_eq(attacker.action_points_remaining, 0)
	assert_eq(attacker.grid_position, Vector2i(1, 1), "An attacking step must not move the attacker")


func test_wasd_step_is_rejected_while_input_is_locked() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]
	controller.selected_unit = mover
	controller.input_locked = true

	var stepped: bool = controller.try_step_selected_unit(Vector2i.RIGHT)

	assert_false(stepped, "A locked board must ignore WASD steps")
	assert_eq(mover.grid_position, Vector2i(1, 1))


func test_wasd_step_is_rejected_for_a_unit_on_the_inactive_side() -> void:
	var controller := _make_controller(6, 6)
	var enemy = UnitScript.new(Vector2i(1, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [enemy]
	controller.selected_unit = enemy
	controller.active_side = BattleControllerScript.Side.PLAYER

	var stepped: bool = controller.try_step_selected_unit(Vector2i.RIGHT)

	assert_false(stepped, "A unit cannot step on the opposing side's turn")
	assert_eq(enemy.grid_position, Vector2i(1, 1))


func test_wasd_step_is_rejected_for_a_target_outside_the_grid() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]
	controller.selected_unit = mover

	var stepped: bool = controller.try_step_selected_unit(Vector2i.UP)

	assert_false(stepped, "A step off the edge of the grid should be rejected")
	assert_eq(mover.grid_position, Vector2i(0, 0))


func _motion_event_over(controller: Node2D, grid_pos: Vector2i) -> InputEventMouseMotion:
	var motion_event := InputEventMouseMotion.new()
	motion_event.position = (
		controller.global_position + Vector2(grid_pos) * BattleControllerScript.TILE_SIZE + Vector2(32, 32)
	)
	return motion_event


func test_hovering_a_tile_with_a_unit_sets_hovered_unit() -> void:
	var controller := _make_controller(6, 6)
	var enemy = UnitScript.new(Vector2i(2, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [enemy]

	controller._unhandled_input(_motion_event_over(controller, Vector2i(2, 2)))

	assert_eq(controller.hovered_unit, enemy)


func test_hovering_empty_ground_clears_hovered_unit() -> void:
	var controller := _make_controller(6, 6)
	var enemy = UnitScript.new(Vector2i(2, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [enemy]
	controller._unhandled_input(_motion_event_over(controller, Vector2i(2, 2)))

	controller._unhandled_input(_motion_event_over(controller, Vector2i(0, 0)))

	assert_null(controller.hovered_unit)


func test_clicking_an_out_of_range_enemy_pins_it_without_attacking() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var enemy = UnitScript.new(Vector2i(5, 5), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [attacker, enemy]
	controller.selected_unit = attacker

	controller._handle_tile_click(enemy.grid_position)

	assert_eq(controller.inspected_unit, enemy)
	assert_true(enemy.is_alive(), "Clicking an out-of-range enemy must not attack it")


func test_clicking_an_attackable_enemy_still_attacks_instead_of_pinning() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var enemy = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [attacker, enemy]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0

	controller._handle_tile_click(enemy.grid_position)

	assert_eq(attacker.action_points_remaining, 0, "An in-range click must still resolve as an attack")


func test_selecting_a_unit_pins_it_as_the_inspected_unit() -> void:
	var controller := _make_controller(6, 6)
	var warrior = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [warrior]

	controller._select_unit(warrior)

	assert_eq(controller.inspected_unit, warrior)


func test_get_focused_unit_prefers_the_live_hover_over_the_pinned_click() -> void:
	var controller := _make_controller(6, 6)
	var warrior = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var enemy = UnitScript.new(Vector2i(2, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [warrior, enemy]
	controller._select_unit(warrior)
	assert_eq(controller.get_focused_unit(), warrior, "With nothing hovered, the pinned selection shows")

	controller._unhandled_input(_motion_event_over(controller, Vector2i(2, 2)))

	assert_eq(controller.get_focused_unit(), enemy, "A live hover must take priority over the pinned click")


func test_unit_focus_changed_emits_when_the_focused_unit_changes() -> void:
	var controller := _make_controller(6, 6)
	var enemy = UnitScript.new(Vector2i(2, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [enemy]
	var received: Array = []
	controller.unit_focus_changed.connect(func(unit) -> void: received.append(unit))

	controller._unhandled_input(_motion_event_over(controller, Vector2i(2, 2)))

	assert_eq(received, [enemy])


func test_wasd_step_and_a_click_move_share_the_same_movement_budget_in_one_turn() -> void:
	var controller := _make_controller(6, 6)
	var mover = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]
	controller.selected_unit = mover

	var stepped: bool = controller.try_step_selected_unit(Vector2i.RIGHT)
	assert_eq(mover.grid_position, Vector2i(2, 1))
	assert_eq(mover.action_points_remaining, 2)
	controller.selected_unit = mover
	var moved: bool = controller.try_move_selected_unit(Vector2i(4, 1))

	assert_true(stepped, "The WASD step should succeed")
	assert_true(moved, "The remaining budget should cover the multi-tile click move")
	assert_eq(mover.grid_position, Vector2i(4, 1))
	assert_eq(mover.action_points_remaining, 0, "The full budget has been spent across the step and the click move")

	controller.selected_unit = mover
	var further_step: bool = controller.try_step_selected_unit(Vector2i.RIGHT)
	controller.selected_unit = mover
	var further_move: bool = controller.try_move_selected_unit(Vector2i(5, 1))

	assert_false(further_step, "No movement points remain for a further step")
	assert_false(further_move, "No movement points remain for a further click move")


func test_select_unit_by_adventurer_id_selects_a_living_player_unit() -> void:
	var controller := _make_controller(6, 6)
	var warrior = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_001"
	)
	controller.units = [warrior]

	var selected: bool = controller.select_unit_by_adventurer_id("warrior_001")

	assert_true(selected, "A living player unit should be selectable by its adventurer id")
	assert_eq(controller.selected_unit, warrior)


func test_select_unit_by_adventurer_id_is_a_no_op_for_a_defeated_or_unknown_member() -> void:
	var controller := _make_controller(6, 6)
	var warrior = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_001"
	)
	warrior.health = 0
	controller.units = [warrior]

	var selected_defeated: bool = controller.select_unit_by_adventurer_id("warrior_001")
	var selected_unknown: bool = controller.select_unit_by_adventurer_id("no_such_id")

	assert_false(selected_defeated, "A defeated party member cannot be selected")
	assert_false(selected_unknown, "An id with no matching unit cannot be selected")
	assert_null(controller.selected_unit)


func test_select_unit_by_adventurer_id_is_a_no_op_during_the_enemy_turn_or_while_locked() -> void:
	var controller := _make_controller(6, 6)
	var warrior = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_001"
	)
	controller.units = [warrior]
	controller.active_side = BattleControllerScript.Side.ENEMY

	var selected_during_enemy_turn: bool = controller.select_unit_by_adventurer_id("warrior_001")

	assert_false(selected_during_enemy_turn, "Selection is blocked during the enemy's turn")
	assert_null(controller.selected_unit)

	controller.active_side = BattleControllerScript.Side.PLAYER
	controller.input_locked = true
	var selected_while_locked: bool = controller.select_unit_by_adventurer_id("warrior_001")

	assert_false(selected_while_locked, "Selection is blocked while input is locked")
	assert_null(controller.selected_unit)


func test_select_unit_by_number_key_maps_one_based_keys_to_party_order() -> void:
	var controller := _make_controller(6, 6)
	var first = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_001"
	)
	var second = UnitScript.new(
		Vector2i(1, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_002"
	)
	controller.units = [first, second]
	var adventurer_ids: Array[String] = ["warrior_001", "warrior_002"]
	controller._player_adventurer_ids = adventurer_ids

	var selected_first: bool = controller.select_unit_by_number_key(1)
	assert_true(selected_first)
	assert_eq(controller.selected_unit, first)

	var selected_second: bool = controller.select_unit_by_number_key(2)
	assert_true(selected_second)
	assert_eq(controller.selected_unit, second)


func test_select_unit_by_number_key_is_a_no_op_for_a_slot_beyond_the_fielded_party() -> void:
	var controller := _make_controller(6, 6)
	var first = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.6, "Sword", "warrior_001"
	)
	controller.units = [first]
	var adventurer_ids: Array[String] = ["warrior_001"]
	controller._player_adventurer_ids = adventurer_ids

	var selected: bool = controller.select_unit_by_number_key(5)

	assert_false(selected, "A number key beyond the fielded party's size should be a no-op")
	assert_null(controller.selected_unit)


func test_wasd_key_input_steps_the_selected_unit_one_tile() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid
	var warrior = controller.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	controller.selected_unit = warrior

	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = KEY_D
	controller._unhandled_input(key_event)

	assert_eq(
		warrior.grid_position,
		BattleControllerScript.PLAYER_START_POSITIONS[0] + Vector2i.RIGHT,
		"KEY_D should step the selected unit one tile to the right"
	)


## Regression test for the same bug class fixed in world_map.gd: reading
## get_local_mouse_position() (the Viewport's tracked cursor position,
## refreshed only by MouseMotion events, and offset by this node's own
## global_position since BattleController itself -- not a separate Board
## child -- is the CanvasItem) instead of the click event's own .position
## meant a click could resolve to the wrong tile if the mouse hadn't
## physically moved since a scene transition. The first player unit is
## auto-selected at battle start (_select_unit_after_action's turn-start
## call), so this test deliberately clicks a SECOND unit -- selection must
## change to it, which only happens if the click resolves to the correct
## tile; the buggy code's wildly-out-of-bounds tile_pos would leave the
## auto-selected first unit untouched instead.
func test_a_real_click_event_selects_the_correct_unit_even_when_the_tracked_cursor_position_is_stale() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.recruit_adventurer()
	var recruit_id: String = GameSession.adventurers[-1].id
	GameSession.assign_adventurer_to_selected_party(recruit_id)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid
	var warrior = controller.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	var recruit = controller.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[1])
	assert_eq(controller.selected_unit, warrior, "sanity check: the first player unit auto-selects at battle start")

	# InputEventMouseButton.position is in viewport (screen) space, so the
	# controller's own on-screen offset (battlefield.tscn centers the Grid
	# node, not at the origin) must be added -- exactly what a real click
	# reports and what make_input_local() expects to convert back from.
	var recruit_pixel_center := (
		controller.global_position
		+ Vector2(BattleControllerScript.PLAYER_START_POSITIONS[1]) * BattleControllerScript.TILE_SIZE
		+ Vector2(32, 32)
	)
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = recruit_pixel_center

	controller._unhandled_input(click_event)

	assert_eq(
		controller.selected_unit, recruit,
		"a real click event carrying its own position must select the unit under it, regardless of the Viewport's separately-tracked (possibly stale) cursor position -- the buggy code leaves the auto-selected warrior selected instead"
	)


func test_number_key_input_selects_the_matching_fielded_party_member() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.recruit_adventurer()
	var recruit_id: String = GameSession.adventurers[-1].id
	GameSession.assign_adventurer_to_selected_party(recruit_id)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = KEY_2
	controller._unhandled_input(key_event)

	assert_not_null(controller.selected_unit, "KEY_2 should select the second fielded party member")
	assert_eq(controller.selected_unit.adventurer_id, recruit_id)


## Guard-rail: nothing else enforces that the fielding cluster (start
## positions/colors one player Unit is spawned into, see _ready()) can seat
## every member of a party at the Guild Hall's maximum size. If
## PLAYER_START_POSITIONS ever shrank below GUILD_HALL_LEVEL_2_PARTY_CAP,
## _ready()'s `mini(_player_adventurer_ids.size(), PLAYER_START_POSITIONS.size())`
## would silently field fewer units than the party actually has members,
## with no error — this test exists so that regression fails loudly instead.
func test_player_start_positions_can_seat_a_full_max_size_party() -> void:
	assert_true(
		BattleControllerScript.PLAYER_START_POSITIONS.size() >= GameSession.GUILD_HALL_LEVEL_2_PARTY_CAP,
		"The fielding cluster must have at least as many start positions as the max Guild Hall party cap"
	)


func test_select_unit_by_adventurer_id_rejects_a_non_player_unit() -> void:
	var controller := _make_controller(4, 4)
	var enemy = UnitScript.new(Vector2i(1, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 3, 1, 1, 0.3, "Claw")
	enemy.adventurer_id = "not_really_an_adventurer"
	controller.units = [enemy]

	var selected: bool = controller.select_unit_by_adventurer_id("not_really_an_adventurer")

	assert_false(selected)
	assert_null(controller.selected_unit)


func test_attack_damage_is_rolled_between_the_attackers_min_and_max() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 8, 0.6, "Longsword"
	)
	var defender = UnitScript.new(
		Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 20, 1, 1, 0.3, "Short Sword"
	)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0
	controller.damage_roll = func(min_value: int, max_value: int) -> int:
		assert_eq(min_value, 2)
		assert_eq(max_value, 8)
		return 5

	controller.try_attack_selected_unit(defender.grid_position)

	assert_eq(defender.health, 15, "A rolled damage of 5 with no resistance should apply in full")


func test_attack_applies_the_defenders_resistance_rounded_to_the_nearest_integer() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 10, 10, 0.6, "Longsword"
	)
	var defender = UnitScript.new(
		Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 20, 1, 1, 0.3, "Short Sword", "", 0, 10
	)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0
	controller.damage_roll = func(_min_value: int, _max_value: int) -> int: return 10

	controller.try_attack_selected_unit(defender.grid_position)

	assert_eq(defender.health, 11, "10% resistance turns 10 damage into 9 (round(10 * 0.9) = 9)")


func test_attack_hit_chance_is_reduced_by_the_defenders_defense_but_floors_at_the_minimum() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 2, 0.3, "Dagger"
	)
	var defender = UnitScript.new(
		Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 20, 1, 1, 0.3, "Short Sword", "", 0, 0
	)
	defender.defense = 50
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	var observed_threshold := 0.0
	controller.hit_roll = func() -> float:
		observed_threshold = 0.1
		return observed_threshold

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_true(attacked)
	assert_eq(
		defender.health,
		20,
		"0.3 hit chance minus 50 defense floors at 0.05; a 0.1 roll clears the floor and must still miss"
	)


func test_get_targeting_failure_reason_identifies_all_failure_causes() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	attacker.attack_min_range = 1
	attacker.attack_max_range = 3
	var enemy_in_range = UnitScript.new(Vector2i(0, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6)
	var enemy_out_of_range = UnitScript.new(Vector2i(0, 5), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6)
	var obstacle = UnitScript.new(Vector2i(0, 1), Color.DARK_GRAY, BattleControllerScript.Side.PLAYER, 6)
	controller.units = [attacker, enemy_in_range, enemy_out_of_range]

	# Valid target in range
	assert_eq(controller.get_targeting_failure_reason(attacker, enemy_in_range), "")

	# Out of range
	assert_eq(controller.get_targeting_failure_reason(attacker, enemy_out_of_range), "out_of_range")

	# Insufficient AP
	attacker.action_points_remaining = 2
	assert_eq(controller.get_targeting_failure_reason(attacker, enemy_in_range), "insufficient_ap")
	attacker.action_points_remaining = 6

	# Paralyzed
	controller.apply_status(attacker, BattleControllerScript.PARALYZED_STATUS_ID)
	assert_eq(controller.get_targeting_failure_reason(attacker, enemy_in_range), "paralyzed")
	attacker.statuses.clear()

	# Line of sight blocked
	controller.units.append(obstacle)
	assert_eq(controller.get_targeting_failure_reason(attacker, enemy_in_range), "line_of_sight_blocked")


func test_handle_tile_click_records_targeting_failure_and_emits_board_changed() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	attacker.attack_min_range = 1
	attacker.attack_max_range = 1
	var enemy = UnitScript.new(Vector2i(0, 3), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6)
	controller.units = [attacker, enemy]
	controller.selected_unit = attacker
	watch_signals(controller)

	controller._handle_tile_click(enemy.grid_position)

	assert_eq(controller.last_targeting_failure.get("reason", ""), "out_of_range")
	assert_eq(controller.last_targeting_failure.get("attacker"), attacker)
	assert_eq(controller.last_targeting_failure.get("target"), enemy)
	assert_signal_emitted(controller, "board_changed")


func test_get_attackable_tiles_for_unit_returns_ranged_tiles_within_los() -> void:
	var controller := _make_controller(6, 6)
	var scout = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	scout.attack_min_range = 1
	scout.attack_max_range = 3
	var obstacle = UnitScript.new(Vector2i(0, 1), Color.DARK_GRAY, BattleControllerScript.Side.PLAYER, 6)
	controller.units = [scout, obstacle]

	var tiles: Array[Vector2i] = controller.get_attackable_tiles_for_unit(scout)

	assert_true(tiles.has(Vector2i(1, 0)))
	assert_true(tiles.has(Vector2i(2, 0)))
	assert_true(tiles.has(Vector2i(3, 0)))
	assert_true(tiles.has(Vector2i(0, 1)), "Target on occupied tile is attackable")
	assert_false(tiles.has(Vector2i(0, 2)), "Tiles behind obstacle are blocked by LoS")
	assert_false(tiles.has(Vector2i(4, 0)), "Tiles beyond max range 3 are excluded")


func test_update_highlights_renders_attack_and_target_highlights_when_unit_has_sufficient_ap() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller = battlefield.grid
	var scout = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	scout.attack_min_range = 1
	scout.attack_max_range = 3
	var enemy_in_range = UnitScript.new(Vector2i(0, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6)
	controller.units = [scout, enemy_in_range]
	controller._select_unit(scout)

	var has_target_highlight := false
	for child in controller.highlight_container.get_children():
		if child is ColorRect and child.position == Vector2(0, 2) * BattleControllerScript.TILE_SIZE:
			if child.color == BattleControllerScript.TARGET_ATTACK_COLOR:
				has_target_highlight = true

	assert_true(has_target_highlight, "Target enemy tile must be highlighted with TARGET_ATTACK_COLOR")


func test_update_highlights_omits_attack_highlights_when_unit_has_insufficient_ap() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller = battlefield.grid
	var scout = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 2)
	scout.attack_min_range = 1
	scout.attack_max_range = 3
	var enemy_in_range = UnitScript.new(Vector2i(0, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6)
	controller.units = [scout, enemy_in_range]
	controller._select_unit(scout)

	var has_target_highlight := false
	for child in controller.highlight_container.get_children():
		if child is ColorRect and child.color == BattleControllerScript.TARGET_ATTACK_COLOR:
			has_target_highlight = true

	assert_false(has_target_highlight, "Target highlight must not be shown when AP < 3")


## Step 1 of the battle-screen redesign (docs/plans/2026-08-16-battle-screen-redesign):
## two-tier green/yellow movement range highlights.
func test_get_move_and_attack_and_dash_tiles_partition_by_distance_for_six_action_points() -> void:
	var controller := _make_controller(10, 10)
	var mover = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	controller.units = [mover]

	var move_and_attack_tiles: Array[Vector2i] = controller.get_move_and_attack_tiles(mover)
	var dash_tiles: Array[Vector2i] = controller.get_dash_tiles(mover)

	for tile in move_and_attack_tiles:
		var distance: int = controller.grid.get_manhattan_distance(mover.grid_position, tile)
		assert_true(distance <= 3, "Move-and-attack tiles must leave at least 3 AP (the attack cost) after moving")
	for tile in dash_tiles:
		var distance: int = controller.grid.get_manhattan_distance(mover.grid_position, tile)
		assert_true(distance >= 4 and distance <= 6, "Dash tiles must be reachable but leave too little AP to attack")
	assert_true(move_and_attack_tiles.has(Vector2i(3, 0)), "A distance-3 move (3 AP) leaves exactly 3 AP, enough to attack")
	assert_false(move_and_attack_tiles.has(Vector2i(4, 0)), "A distance-4 move leaves only 2 AP, not enough to attack")
	assert_true(dash_tiles.has(Vector2i(4, 0)), "A distance-4 tile is reachable but leaves too little AP to attack")
	assert_true(dash_tiles.has(Vector2i(6, 0)), "A distance-6 move spends the entire 6 AP budget on movement alone")
	assert_false(dash_tiles.has(Vector2i(7, 0)), "A distance-7 tile exceeds the unit's total AP budget")
	assert_false(move_and_attack_tiles.has(mover.grid_position), "The origin is represented by the selection ring, not a movement tile")
	assert_false(dash_tiles.has(mover.grid_position), "The origin is represented by the selection ring, not a movement tile")


func test_get_move_and_attack_tiles_is_empty_and_dash_tiles_cover_every_reachable_tile_for_three_action_points() -> void:
	var controller := _make_controller(10, 10)
	var mover = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	controller.units = [mover]

	var move_and_attack_tiles: Array[Vector2i] = controller.get_move_and_attack_tiles(mover)
	var dash_tiles: Array[Vector2i] = controller.get_dash_tiles(mover)

	assert_eq(move_and_attack_tiles, [] as Array[Vector2i], "3 AP exactly covers the attack cost, leaving nothing for movement first")
	assert_true(dash_tiles.has(Vector2i(1, 0)))
	assert_true(dash_tiles.has(Vector2i(2, 0)))
	assert_true(dash_tiles.has(Vector2i(3, 0)))
	assert_false(dash_tiles.has(mover.grid_position), "The origin is represented by the selection ring, not a movement tile")


func test_get_move_and_attack_tiles_is_empty_and_all_reachable_tiles_are_dash_for_two_action_points() -> void:
	var controller := _make_controller(10, 10)
	var mover = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 2)
	controller.units = [mover]

	var move_and_attack_tiles: Array[Vector2i] = controller.get_move_and_attack_tiles(mover)
	var dash_tiles: Array[Vector2i] = controller.get_dash_tiles(mover)
	var legal_moves: Array[Vector2i] = controller.get_legal_moves(mover)

	assert_eq(move_and_attack_tiles, [] as Array[Vector2i], "2 AP cannot leave 3 AP remaining for an attack no matter the distance")
	assert_eq(dash_tiles.size(), legal_moves.size(), "Every reachable tile must fall into the dash tier")
	for tile in legal_moves:
		assert_true(dash_tiles.has(tile))


func test_update_highlights_renders_two_tier_movement_and_direct_and_indirect_attack_targets_in_precedence_order() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller = battlefield.grid
	# Battlefield._ready() auto-selects a default unit and already populated
	# highlight_container once; those children were queue_free()'d (deferred,
	# not synchronous), so they would still show up in get_children() below
	# alongside our own scenario's highlights unless removed immediately here.
	for stale_child in controller.highlight_container.get_children():
		stale_child.free()

	var scout = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	scout.attack_min_range = 1
	scout.attack_max_range = 1
	# Directly attackable now: adjacent to the scout's current position. Placed
	# off the (0, y) column so it does not block the path to the green tile
	# the indirect target below is reached through.
	var direct_target = UnitScript.new(Vector2i(1, 0), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6)
	# Only attackable after moving: too far to hit from the origin (distance 4 > max
	# range 1), but adjacent to (0, 3), which is a green move-and-attack tile
	# (distance 3, leaving exactly 3 AP to attack).
	var indirect_target = UnitScript.new(Vector2i(0, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6)
	controller.units = [scout, direct_target, indirect_target]

	controller._select_unit(scout)

	var green_tile := Vector2(0, 3) * BattleControllerScript.TILE_SIZE
	var yellow_tile := Vector2(2, 0) * BattleControllerScript.TILE_SIZE
	var origin_tile := Vector2(0, 0) * BattleControllerScript.TILE_SIZE
	var red_target_tile := Vector2(1, 0) * BattleControllerScript.TILE_SIZE
	var orange_target_tile := Vector2(0, 4) * BattleControllerScript.TILE_SIZE

	var children: Array = controller.highlight_container.get_children()
	var green_index := -1
	var yellow_index := -1
	var red_index := -1
	var orange_index := -1
	for index in children.size():
		var child = children[index]
		if not (child is ColorRect):
			continue
		if child.color == BattleControllerScript.LEGAL_MOVE_AND_ATTACK_COLOR and child.position == green_tile:
			green_index = index
		elif child.color == BattleControllerScript.DASH_MOVE_COLOR and child.position == yellow_tile:
			yellow_index = index
		elif child.color == BattleControllerScript.TARGET_ATTACK_COLOR and child.position == red_target_tile:
			red_index = index
		elif child.color == BattleControllerScript.MOVE_AND_ATTACK_TARGET_COLOR and child.position == orange_target_tile:
			orange_index = index
		assert_false(
			(
				child.color == BattleControllerScript.LEGAL_MOVE_AND_ATTACK_COLOR
				or child.color == BattleControllerScript.DASH_MOVE_COLOR
			) and child.position == origin_tile,
			"The origin tile must never receive a movement fill; the selection ring already represents it"
		)

	assert_true(green_index >= 0, "Distance-3 tiles must render as move-and-attack (green) highlights")
	assert_true(yellow_index >= 0, "Distance-4 tiles must render as dash (yellow) highlights")
	assert_true(red_index >= 0, "An enemy directly attackable now must render a red target highlight")
	assert_true(orange_index >= 0, "An enemy attackable only after moving into green range must render an orange target highlight")
	assert_true(red_index > green_index, "Target overlays must render after movement fills so they remain visible on top")
	assert_true(orange_index > green_index, "Target overlays must render after movement fills so they remain visible on top")


