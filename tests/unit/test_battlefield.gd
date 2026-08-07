extends GutTest

const BattlefieldScene := preload("res://scenes/battle/battlefield.tscn")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const PortraitPanelScript := preload("res://scripts/battle/portrait_panel.gd")


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


func test_battlefield_starts_at_round_one() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(battlefield.round_number, 1)


func test_round_increments_only_after_the_enemy_turn_returns_control_to_the_player() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	battlefield.enemy_turn_beat_seconds = 0.0
	add_child_autofree(battlefield)

	battlefield._on_end_turn_pressed()
	assert_eq(battlefield.round_number, 1, "Round must not increment while the enemy is still acting")

	while battlefield._enemy_turn_in_progress:
		await get_tree().process_frame

	assert_eq(battlefield.round_number, 2, "Round increments once control returns to the player")


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
	var selection_before_lock = battlefield.grid.selected_unit
	battlefield._set_enemy_turn_in_progress(true)

	battlefield.grid._handle_tile_click(Vector2i(1, 1))

	assert_eq(
		battlefield.grid.selected_unit, selection_before_lock, "A locked board must ignore clicks"
	)


func test_describe_step_reports_a_hit_with_damage() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var attacker = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	var step := {"type": "attack", "attacker": attacker, "hit": true, "damage": 1}

	assert_eq(battlefield._describe_step(step), tr("battle.status.hit") % [tr("battle.side.enemy"), 1])


func test_describe_step_reports_a_miss() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var attacker = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	var step := {"type": "attack", "attacker": attacker, "hit": false, "damage": 0}

	assert_eq(battlefield._describe_step(step), tr("battle.status.miss") % tr("battle.side.enemy"))


func test_describe_step_reports_an_enemy_move() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var mover = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	var step := {
		"type": "move",
		"unit": mover,
		"from": BattleControllerScript.ENEMY_START_POSITIONS[0],
		"to": Vector2i(4, 3),
	}

	assert_eq(battlefield._describe_step(step), tr("battle.status.enemy_move") % tr("battle.side.enemy"))


## Task 6: the left-side portrait panel (one row per fielded party member)
## and the per-living-enemy HUD list that replaces the old aggregate
## PlayerHealth/EnemyHealth labels.

func _setup_two_member_party() -> String:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.recruit_adventurer()
	# recruit_adventurer() mints the next warrior_NNN id that collides with
	# neither an existing adventurer nor a still-open recruitment candidate
	# template (warrior_002/003/004 stay open after reset()), so the newly
	# recruited id is read back rather than assumed.
	var second_member_id: String = GameSession.adventurers[-1].id
	GameSession.assign_adventurer_to_selected_party(second_member_id)
	return second_member_id


func test_portrait_panel_shows_one_row_per_fielded_party_member() -> void:
	_setup_two_member_party()
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(battlefield.portrait_panel.rows.get_child_count(), 2)
	for row in battlefield.portrait_panel.rows.get_children():
		var health_label: Label = row.find_child("Health", true, false)
		assert_eq(health_label.text, "3/3")


func test_portrait_panel_shows_the_selection_ring_on_the_selected_member() -> void:
	_setup_two_member_party()
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])

	battlefield.grid._select_unit(warrior)

	var row: Node = battlefield.portrait_panel.get_node("Rows/Portrait0")
	var ring: ColorRect = row.find_child("SelectionRing", true, false)
	assert_true(ring.visible)


func test_portrait_panel_dims_a_defeated_member() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	warrior.take_damage(warrior.max_health)
	battlefield.grid.units.erase(warrior)

	battlefield.portrait_panel.refresh()

	assert_eq(
		battlefield.portrait_panel.get_node("Rows/Portrait0").modulate,
		PortraitPanelScript.DEFEATED_MODULATE
	)


## Regression test for a portrait row whose clickable rect had collapsed to a
## few px (a Button's minimum size ignores children added directly rather
## than via its text/icon), while its swatch/label still visibly rendered at
## full size — so the row looked clickable but almost never registered a
## real click. emit_signal("pressed") (see the test above) can't catch this,
## since it bypasses hit-testing entirely.
func test_portrait_row_click_target_spans_its_visible_content() -> void:
	_setup_two_member_party()
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	await get_tree().process_frame
	await get_tree().process_frame

	var row: Control = battlefield.portrait_panel.get_node("Rows/Portrait0")

	assert_eq(
		row.size.y, float(PortraitPanelScript.PORTRAIT_SIZE),
		"The row's clickable height must match its swatch, not the empty-text button minimum"
	)
	assert_gt(row.size.x, 0.0, "The row must stretch to a real clickable width")


## Decorative children default to MOUSE_FILTER_STOP, which (being drawn on
## top of the row Button) would otherwise claim the click for themselves and
## never let the Button register it as a press.
func test_portrait_row_decorative_children_do_not_intercept_clicks() -> void:
	_setup_two_member_party()
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	var row: Control = battlefield.portrait_panel.get_node("Rows/Portrait0")
	for child_name in ["Swatch", "Health", "SelectionRing"]:
		var child: Control = row.find_child(child_name, true, false)
		assert_eq(
			child.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"%s must not intercept clicks meant for the row button" % child_name
		)


func test_clicking_a_portrait_selects_that_party_member() -> void:
	var second_member_id: String = _setup_two_member_party()
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield.portrait_panel.get_node("Rows/Portrait1").emit_signal("pressed")

	assert_eq(battlefield.grid.selected_unit.adventurer_id, second_member_id)


func test_hud_hint_and_status_share_the_top_left_stack() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(battlefield.hint.get_parent(), battlefield.status.get_parent())
	assert_eq(battlefield.enemy_health.get_parent(), battlefield.hint.get_parent())


func test_hud_round_label_and_end_turn_button_share_the_top_right_stack() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(battlefield.round_label.get_parent(), battlefield.end_turn_button.get_parent())


func test_portrait_panel_is_container_driven_not_offset_positioned() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_true(battlefield.portrait_panel.get_parent() is Container)


func test_ready_lists_each_living_enemys_health() -> void:
	GameSession.reset()
	GameSession.enemy_composition_roll = func(_option_count: int) -> int: return 0
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(battlefield.enemy_health.get_child_count(), 2)
	for label in battlefield.enemy_health.get_children():
		assert_eq(label.text, tr("battle.status.health") % [tr("battle.side.enemy"), 3, 3])


func test_enemy_health_list_drops_a_defeated_enemy() -> void:
	GameSession.reset()
	GameSession.enemy_composition_roll = func(_option_count: int) -> int: return 0
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	goblin.take_damage(goblin.max_health)
	battlefield.grid.units.erase(goblin)

	battlefield._update_health_labels()

	assert_eq(battlefield.enemy_health.get_child_count(), 1)


func test_player_health_label_no_longer_exists() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_false(battlefield.has_node("HUD/PlayerHealth"))


func test_show_battle_result_names_the_won_goblin_camp_in_the_victory_message() -> void:
	GameSession.reset()
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield._show_battle_result(true)

	assert_eq(
		battlefield.status.text, tr("battle.result.victory") % tr("expedition.goblin_camp.name")
	)
	assert_true(battlefield._battle_resolved)
	assert_true(battlefield.end_turn_button.disabled)
	assert_true(battlefield.grid.input_locked)


func test_show_battle_result_names_the_won_orc_outpost_in_the_victory_message() -> void:
	GameSession.reset()
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield._show_battle_result(true)

	assert_eq(
		battlefield.status.text, tr("battle.result.victory") % tr("expedition.orc_outpost.name")
	)
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
	assert_eq(GameSession.pending_reward, 10, "Victory should queue the goblin camp's fixed reward")
	assert_eq(GameSession.gold, 0, "Victory alone must not bank the reward")


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
	assert_eq(GameSession.gold, 0, "Defeat must not queue or bank any gold")
	assert_eq(GameSession.pending_reward, 0, "Defeat must not queue or bank any gold")


## Task 2: battle XP events (kill XP on an enemy defeat, clear XP on victory),
## awarded exactly once per encounter attempt regardless of repeated events.

func _setup_goblin_camp_battle() -> Node2D:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	return battlefield


func _setup_orc_outpost_battle(roll_override: Callable = Callable()) -> Node2D:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	if roll_override.is_valid():
		GameSession.enemy_composition_roll = roll_override
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	return battlefield


func _stage_a_killing_blow(battlefield: Node2D) -> Dictionary:
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	var enemy = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	for candidate in battlefield.grid.grid.get_adjacent(warrior.grid_position):
		if battlefield.grid.get_unit_at(candidate) == null:
			enemy.grid_position = candidate
			break
	enemy.health = 1
	battlefield.grid.selected_unit = warrior
	battlefield.grid.hit_roll = func() -> float: return 0.0
	return {"warrior": warrior, "enemy": enemy}


func test_defeating_the_goblin_awards_its_five_point_kill_xp() -> void:
	var battlefield := _setup_goblin_camp_battle()
	var units := _stage_a_killing_blow(battlefield)

	battlefield.grid.try_attack_selected_unit(units.enemy.grid_position)

	assert_eq(GameSession.get_adventurer("warrior_001").progression.xp, 5.0, "A goblin kill should award 5 XP")


func test_defeating_the_orc_awards_its_ten_point_kill_xp() -> void:
	var battlefield := _setup_orc_outpost_battle()
	var units := _stage_a_killing_blow(battlefield)

	battlefield.grid.try_attack_selected_unit(units.enemy.grid_position)

	assert_eq(GameSession.get_adventurer("warrior_001").progression.xp, 10.0, "An orc kill should award 10 XP")


func test_kill_xp_award_guard_prevents_a_duplicate_award_from_a_repeated_event() -> void:
	var battlefield := _setup_goblin_camp_battle()
	var units := _stage_a_killing_blow(battlefield)
	battlefield.grid.try_attack_selected_unit(units.enemy.grid_position)
	var xp_after_first_kill: float = GameSession.get_adventurer("warrior_001").progression.xp

	battlefield._award_kill_xp(units.enemy)

	assert_eq(
		GameSession.get_adventurer("warrior_001").progression.xp,
		xp_after_first_kill,
		"A repeated kill event (e.g. a duplicate signal) for the same already-defeated unit must not award XP twice"
	)


## Regression test for the finding that _award_kill_xp() used to be guarded
## by a single "already awarded this battle" boolean, which silently
## swallowed kill XP for every enemy after the first in a multi-enemy
## battle. enemy_defeated now fires once per defeated unit and the guard
## tracks awarded units individually, so both enemies' kills must each pay
## out their kill_xp. Uses the Orc Outpost forced to its two-goblin option
## since Goblin Camp is now a single-enemy (one-star) site.
func test_defeating_two_enemies_in_one_battle_awards_kill_xp_for_each() -> void:
	var battlefield := _setup_orc_outpost_battle(func(_option_count: int) -> int: return 0)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	var first_enemy = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	var second_enemy = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[1])
	first_enemy.grid_position = warrior.grid_position + Vector2i(1, 0)
	first_enemy.health = 1
	second_enemy.grid_position = warrior.grid_position + Vector2i(0, 1)
	second_enemy.health = 1
	battlefield.grid.selected_unit = warrior
	battlefield.grid.hit_roll = func() -> float: return 0.0

	battlefield.grid.try_attack_selected_unit(first_enemy.grid_position)
	warrior.has_acted = false
	battlefield.grid.try_attack_selected_unit(second_enemy.grid_position)

	assert_eq(
		GameSession.get_adventurer("warrior_001").progression.xp,
		20.0,
		"Defeating both enemies in one battle should award kill_xp (10) twice, not once"
	)


func test_winning_the_goblin_camp_awards_its_ten_point_clear_xp() -> void:
	var battlefield := _setup_goblin_camp_battle()

	battlefield._apply_battle_outcome(true)

	assert_eq(
		GameSession.get_adventurer("warrior_001").progression.xp,
		10.0,
		"Winning the goblin camp should award its 10 clear XP"
	)


func test_winning_the_orc_outpost_awards_its_twenty_point_clear_xp() -> void:
	var battlefield := _setup_orc_outpost_battle()

	battlefield._apply_battle_outcome(true)

	assert_eq(
		GameSession.get_adventurer("warrior_001").progression.xp,
		20.0,
		"Winning the orc outpost should award its 20 clear XP"
	)


func test_clear_xp_award_guard_prevents_a_duplicate_award_from_a_repeated_call() -> void:
	var battlefield := _setup_goblin_camp_battle()
	battlefield._award_clear_xp()
	var xp_after_first_award: float = GameSession.get_adventurer("warrior_001").progression.xp

	battlefield._award_clear_xp()

	assert_eq(
		GameSession.get_adventurer("warrior_001").progression.xp,
		xp_after_first_award,
		"A repeated clear XP call (e.g. a repeated result-timer fire) must not award XP twice"
	)


func test_defeat_awards_no_clear_xp_but_keeps_xp_already_earned_from_a_kill() -> void:
	var battlefield := _setup_goblin_camp_battle()
	var units := _stage_a_killing_blow(battlefield)
	battlefield.grid.try_attack_selected_unit(units.enemy.grid_position)

	battlefield._apply_battle_outcome(false)

	assert_eq(
		GameSession.get_adventurer("warrior_001").progression.xp,
		5.0,
		"Defeat must keep XP already earned from a kill but award no clear XP"
	)
	assert_eq(GameSession.gold, 0, "Defeat must not bank any gold")
	assert_eq(GameSession.pending_reward, 0, "Defeat must not queue any pending gold")


func test_a_level_up_from_kill_xp_raises_the_active_units_max_and_current_health() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 19.0)
	GameSession.depart_selected_party()
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var units := _stage_a_killing_blow(battlefield)

	battlefield.grid.try_attack_selected_unit(units.enemy.grid_position)

	assert_eq(GameSession.get_adventurer("warrior_001").level, 2, "19 + 10 orc kill XP should cross the level 2 threshold")
	assert_eq(units.warrior.max_health, 4, "The active unit's max health must rise immediately on a mid-battle level-up")
	assert_eq(units.warrior.health, 4, "The active unit's current health must rise by the same amount as max health")


## Task 3: the immediate, queued, modal level-up overlay. A queued level-up
## locks the board and End Turn button for as long as any modal is queued or
## showing, shows multiple leveled party members one at a time in stable
## party order, and gates the battle-result scene transition (both the
## kill-triggered and the clear-triggered paths) until every queued level-up
## has resolved.

func test_a_level_up_from_kill_xp_shows_the_modal_and_locks_board_and_end_turn_input() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 19.0)
	GameSession.depart_selected_party()
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var units := _stage_a_killing_blow(battlefield)

	battlefield.grid.try_attack_selected_unit(units.enemy.grid_position)

	assert_true(battlefield.level_up.visible, "A mid-battle level-up must show its overlay immediately")
	assert_eq(battlefield.level_up.adventurer_id, "warrior_001")
	assert_true(battlefield.end_turn_button.disabled)
	assert_true(battlefield.grid.input_locked)


func test_resolving_the_only_queued_level_up_unlocks_board_and_end_turn_input() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 19.0)
	GameSession.depart_selected_party()
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var units := _stage_a_killing_blow(battlefield)
	battlefield.grid.try_attack_selected_unit(units.enemy.grid_position)

	battlefield.level_up.continue_button.emit_signal("pressed")

	assert_false(battlefield.level_up.visible)
	assert_false(battlefield.end_turn_button.disabled)
	assert_false(battlefield.grid.input_locked)


func test_multiple_leveled_party_members_are_shown_one_at_a_time_in_stable_party_order() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.recruit_adventurer()
	# recruit_adventurer() mints the next warrior_NNN id that collides with
	# neither an existing adventurer nor a still-open recruitment candidate
	# template (warrior_002/003/004 stay open after reset()), so the newly
	# recruited id is read back rather than assumed.
	var second_member_id: String = GameSession.adventurers[-1].id
	GameSession.assign_adventurer_to_selected_party(second_member_id)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield._award_party_xp(42.0)

	assert_true(battlefield.level_up.visible)
	assert_eq(battlefield.level_up.adventurer_id, "warrior_001", "The first party member must be shown first")
	assert_true(battlefield.end_turn_button.disabled, "Input must stay locked while a second level-up is still queued")

	battlefield.level_up.continue_button.emit_signal("pressed")

	assert_true(
		battlefield.level_up.visible,
		"The next queued member must show immediately, without an unlocked gap in between"
	)
	assert_eq(battlefield.level_up.adventurer_id, second_member_id)
	assert_true(battlefield.end_turn_button.disabled)

	battlefield.level_up.continue_button.emit_signal("pressed")

	assert_false(battlefield.level_up.visible, "Input unlocks only after the last queued modal completes")
	assert_false(battlefield.end_turn_button.disabled)
	assert_false(battlefield.grid.input_locked)


func test_a_level_up_from_clear_xp_must_resolve_before_the_battle_completes() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 19.0)
	GameSession.depart_selected_party()
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield._apply_battle_outcome(true)

	assert_true(
		battlefield.level_up.visible,
		"Clear XP crossing a level threshold must show the overlay before completing the battle"
	)
	assert_false(
		GameSession.is_encounter_complete(GameSession.ORC_OUTPOST_ID),
		"The battle-result scene transition must wait for the queued level-up to resolve"
	)

	battlefield.level_up.continue_button.emit_signal("pressed")

	assert_true(
		GameSession.is_encounter_complete(GameSession.ORC_OUTPOST_ID),
		"The battle completes once the queued level-up resolves"
	)


func test_a_clear_xp_level_up_that_requires_a_perk_choice_still_gates_completion() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 49.0)
	GameSession.depart_selected_party()
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield._apply_battle_outcome(true)

	assert_true(GameSession.is_perk_choice_pending("warrior_001"))
	battlefield.level_up.continue_button.emit_signal("pressed")
	assert_false(
		GameSession.is_encounter_complete(GameSession.ORC_OUTPOST_ID),
		"A required perk choice must block completion, not just the modal's own Continue button"
	)

	battlefield.level_up.choose_bonus_move_button.emit_signal("pressed")
	battlefield.level_up.continue_button.emit_signal("pressed")

	assert_true(GameSession.is_encounter_complete(GameSession.ORC_OUTPOST_ID))


func test_clear_xp_with_no_level_up_completes_the_battle_immediately() -> void:
	var battlefield := _setup_goblin_camp_battle()

	battlefield._apply_battle_outcome(true)

	assert_false(battlefield.level_up.visible)
	assert_true(GameSession.is_encounter_complete(GameSession.GOBLIN_CAMP_ID))
