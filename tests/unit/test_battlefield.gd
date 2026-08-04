extends GutTest

const BattlefieldScene := preload("res://scenes/battle/battlefield.tscn")


func after_each() -> void:
	GameManager.close_game_menu()


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	battlefield._unhandled_input(escape_event)

	assert_true(
		battlefield.get_viewport().is_input_handled(),
		"Battlefield must mark Escape input as handled so it doesn't also reach the viewport below"
	)
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)


func test_set_enemy_turn_in_progress_locks_and_unlocks_input() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield._set_enemy_turn_in_progress(true)

	assert_true(battlefield.grid.input_locked)
	assert_true(battlefield.end_turn_button.disabled)

	battlefield._set_enemy_turn_in_progress(false)

	assert_false(battlefield.grid.input_locked)
	assert_false(battlefield.end_turn_button.disabled)


func test_locked_input_ignores_board_clicks() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	battlefield._set_enemy_turn_in_progress(true)

	battlefield.grid._handle_tile_click(Vector2i(1, 1))

	assert_null(battlefield.grid.selected_unit, "A locked board must ignore clicks")


func test_describe_step_reports_a_hit_with_damage() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var attacker = battlefield.grid.get_unit_at(Vector2i(4, 4))
	var step := {"type": "attack", "attacker": attacker, "hit": true, "damage": 1}

	assert_eq(battlefield._describe_step(step), tr("battle.status.hit") % [tr("battle.side.enemy"), 1])


func test_describe_step_reports_a_miss() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var attacker = battlefield.grid.get_unit_at(Vector2i(4, 4))
	var step := {"type": "attack", "attacker": attacker, "hit": false, "damage": 0}

	assert_eq(battlefield._describe_step(step), tr("battle.status.miss") % tr("battle.side.enemy"))


func test_describe_step_reports_an_enemy_move() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var mover = battlefield.grid.get_unit_at(Vector2i(4, 4))
	var step := {"type": "move", "unit": mover, "from": Vector2i(4, 4), "to": Vector2i(4, 3)}

	assert_eq(battlefield._describe_step(step), tr("battle.status.enemy_move") % tr("battle.side.enemy"))


func test_ready_shows_full_health_for_both_units() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(
		battlefield.player_health.text, tr("battle.status.health") % [tr("battle.side.player"), 3, 3]
	)
	assert_eq(
		battlefield.enemy_health.text, tr("battle.status.health") % [tr("battle.side.enemy"), 3, 3]
	)


func test_health_label_shows_defeated_after_a_unit_dies() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var goblin = battlefield.grid.get_unit_at(Vector2i(4, 4))
	goblin.take_damage(goblin.max_health)
	battlefield.grid.units.erase(goblin)

	battlefield._update_health_labels()

	assert_eq(battlefield.enemy_health.text, tr("battle.status.defeated") % tr("battle.side.enemy"))


func test_show_battle_result_shows_the_victory_message_and_locks_input() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield._show_battle_result(true)

	assert_eq(battlefield.status.text, tr("battle.result.victory"))
	assert_true(battlefield._battle_resolved)
	assert_true(battlefield.end_turn_button.disabled)
	assert_true(battlefield.grid.input_locked)


func test_show_battle_result_shows_the_defeat_message_and_locks_input() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield._show_battle_result(false)

	assert_eq(battlefield.status.text, tr("battle.result.defeat"))
	assert_true(battlefield._battle_resolved)


func test_apply_battle_outcome_true_completes_the_encounter() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	GameSession.enter_encounter("goblin_camp")
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield._apply_battle_outcome(true)

	assert_true(GameSession.is_encounter_complete("goblin_camp"))


func test_apply_battle_outcome_false_returns_the_party_home_without_completing() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	GameSession.enter_encounter("goblin_camp")
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield._apply_battle_outcome(false)

	assert_false(GameSession.has_deployed_party())
	assert_false(GameSession.is_encounter_complete("goblin_camp"))
