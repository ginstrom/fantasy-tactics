extends GutTest

const GridScript := preload("res://scripts/battle/grid.gd")
const UnitScript := preload("res://scripts/battle/unit.gd")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const BattlefieldScene := preload("res://scenes/battle/battlefield.tscn")


func before_each() -> void:
	GameSession.reset()


func _make_controller(width: int, height: int) -> Node2D:
	var controller: Node2D = BattleControllerScript.new()
	controller.grid = GridScript.new(width, height)
	autofree(controller)
	return controller


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


func test_unit_cannot_move_to_a_non_adjacent_tile() -> void:
	var controller := _make_controller(4, 4)
	var mover = UnitScript.new(Vector2i(0, 0), Color.CORNFLOWER_BLUE)
	controller.units = [mover]
	controller.selected_unit = mover

	var moved: bool = controller.try_move_selected_unit(Vector2i(3, 3))

	assert_false(moved, "Move to a non-adjacent tile should be rejected")
	assert_eq(mover.grid_position, Vector2i(0, 0))


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
	assert_eq(mover.moves_remaining, 0, "The full budget has been spent across both moves")


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
	assert_eq(enemy_unit.moves_remaining, enemy_unit.move_range, "The newly active side's units have not moved yet")

	controller.end_turn()

	assert_eq(controller.active_side, BattleControllerScript.Side.PLAYER, "End turn returns control to the first side")
	assert_eq(player_unit.moves_remaining, player_unit.move_range, "The player's unit regains its movement on its next turn")


func test_ready_spawns_the_documented_warrior_and_goblin() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid

	assert_eq(controller.units.size(), 2)
	var warrior = controller.get_unit_at(Vector2i(1, 1))
	var goblin = controller.get_unit_at(Vector2i(4, 4))
	assert_not_null(warrior, "Warrior should spawn at (1, 1)")
	assert_not_null(goblin, "Goblin should spawn at (4, 4)")
	assert_eq(warrior.side, BattleControllerScript.Side.PLAYER)
	assert_eq(warrior.max_health, 3)
	assert_eq(warrior.move_range, 3)
	assert_eq(warrior.attack_damage, 2)
	assert_eq(warrior.hit_chance, 0.6)
	assert_eq(goblin.side, BattleControllerScript.Side.ENEMY)
	assert_eq(goblin.max_health, 3)
	assert_eq(goblin.move_range, 3)
	assert_eq(goblin.attack_damage, 1)
	assert_eq(goblin.hit_chance, 0.3)
	assert_eq(goblin.attack_name, tr("battle.enemy.goblin.attack"))


func test_ready_builds_the_orc_outpost_enemy_when_orc_outpost_is_selected() -> void:
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid
	var enemy = controller.get_unit_at(BattleControllerScript.GOBLIN_START)

	assert_not_null(enemy, "The orc should spawn at the documented enemy start position")
	assert_eq(enemy.side, BattleControllerScript.Side.ENEMY)
	assert_eq(enemy.max_health, 5)
	assert_eq(enemy.attack_damage, 2)
	assert_eq(enemy.hit_chance, 0.5)
	assert_eq(enemy.attack_name, tr("battle.enemy.orc.attack"))


## Task 2: the player Unit is built from the selected party's first member's
## effective (derived) combat stats rather than fixed constants.
func test_ready_builds_the_player_unit_from_the_first_partys_effective_stats() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 20.0)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid
	var warrior = controller.get_unit_at(Vector2i(1, 1))

	assert_eq(
		warrior.max_health,
		GameSession.get_effective_max_health(GameSession.WARRIOR_ID),
		"The unit's max health must come from GameSession's derived value"
	)
	assert_eq(warrior.max_health, 4, "One level up should have added one max health")
	assert_eq(warrior.health, 4, "A fresh unit starts at full (derived) health")


func test_ready_builds_the_player_unit_with_a_ninety_five_percent_hit_chance_when_raw_attack_reaches_one_hundred() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 140.0)
	GameSession.spend_attack_points(GameSession.WARRIOR_ID, 40)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(Vector2i(1, 1))

	assert_eq(
		GameSession.get_adventurer(GameSession.WARRIOR_ID).stats.attack,
		100,
		"Raw Attack itself must not be capped"
	)
	assert_eq(warrior.hit_chance, 0.95, "Raw Attack 100 should cap the unit's hit chance at 0.95")


func test_ready_builds_the_player_unit_with_one_extra_move_tile_after_choosing_bonus_move() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 50.0)
	GameSession.choose_perk(GameSession.WARRIOR_ID, GameSession.BONUS_MOVE_PERK_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(Vector2i(1, 1))

	assert_eq(warrior.move_range, 4, "The bonus_move perk should add one extra move tile to the player unit")


func test_ready_falls_back_to_the_default_warrior_when_no_party_is_selected() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(Vector2i(1, 1))

	assert_eq(warrior.max_health, GameSession.get_effective_max_health(GameSession.WARRIOR_ID))
	assert_eq(warrior.hit_chance, GameSession.get_effective_hit_chance(GameSession.WARRIOR_ID))
	assert_eq(warrior.move_range, GameSession.get_effective_move_range(GameSession.WARRIOR_ID))


func test_ready_builds_the_goblin_camp_enemy_when_goblin_camp_is_selected() -> void:
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid
	var enemy = controller.get_unit_at(BattleControllerScript.GOBLIN_START)

	assert_not_null(enemy, "The goblin should spawn at the documented enemy start position")
	assert_eq(enemy.side, BattleControllerScript.Side.ENEMY)
	assert_eq(enemy.max_health, 3)
	assert_eq(enemy.attack_damage, 1)
	assert_eq(enemy.hit_chance, 0.3)
	assert_eq(enemy.attack_name, tr("battle.enemy.goblin.attack"))


func test_attack_hits_and_deals_damage_when_the_roll_is_below_hit_chance() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 0.6, "Sword"
	)
	var defender = UnitScript.new(
		Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 3, 1, 0.3, "Short Sword"
	)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.hit_roll = func() -> float: return 0.0

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_true(attacked)
	assert_eq(defender.health, 1, "A hit applies the attacker's fixed damage")
	assert_true(attacker.has_acted)


func test_attack_misses_and_deals_no_damage_when_the_roll_is_at_or_above_hit_chance() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 0.6, "Sword"
	)
	var defender = UnitScript.new(
		Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 3, 1, 0.3, "Short Sword"
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
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 0.6, "Sword"
	)
	var defender = UnitScript.new(
		Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 1, 1, 0.3, "Short Sword"
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


func test_attack_is_rejected_a_second_time_in_the_same_turn() -> void:
	var controller := _make_controller(6, 6)
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 5)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker
	controller.try_attack_selected_unit(defender.grid_position)
	controller.selected_unit = attacker

	var attacked_again: bool = controller.try_attack_selected_unit(defender.grid_position)

	assert_false(attacked_again, "A unit that already attacked this turn cannot attack again")


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
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
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
	var attacker = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var defender = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [attacker, defender]
	controller.selected_unit = attacker

	var attacked: bool = controller.try_attack_selected_unit(defender.grid_position)
	controller.selected_unit = attacker
	var moved: bool = controller.try_move_selected_unit(Vector2i(2, 1))

	assert_true(attacked, "Attacking first must still be legal")
	assert_true(moved, "Moving after attacking must still be legal - order does not matter")


func test_end_turn_resets_has_acted_for_the_newly_active_side() -> void:
	var controller := _make_controller(6, 6)
	var player_unit = UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3)
	var enemy_unit = UnitScript.new(Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3)
	controller.units = [player_unit, enemy_unit]
	controller.active_side = BattleControllerScript.Side.PLAYER
	controller.selected_unit = player_unit
	controller.try_attack_selected_unit(enemy_unit.grid_position)

	controller.end_turn()
	controller.end_turn()

	assert_false(player_unit.has_acted, "The player's unit regains its attack on its next turn")


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
		Vector2i(1, 2), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 3, 1, 0.3, "Short Sword"
	)
	var player_unit = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 0.6, "Sword"
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
		Vector2i(3, 1), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 3, 1, 0.3, "Short Sword"
	)
	var player_unit = UnitScript.new(
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 0.6, "Sword"
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
		Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 3, 3, 2, 0.6
	)
	var goblin = UnitScript.new(
		Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 3, 3, 1, 0.3
	)
	controller.units = [warrior, goblin]

	controller.apply_super_power()

	assert_eq(warrior.move_range, BattleControllerScript.SUPER_POWER_MOVE_RANGE)
	assert_eq(warrior.attack_damage, BattleControllerScript.SUPER_POWER_ATTACK_DAMAGE)
	assert_eq(warrior.hit_chance, BattleControllerScript.SUPER_POWER_HIT_CHANCE)
	assert_eq(goblin.move_range, 3, "Super Power must not affect enemy units")
	assert_eq(goblin.attack_damage, 1, "Super Power must not affect enemy units")
	assert_eq(goblin.hit_chance, 0.3, "Super Power must not affect enemy units")
