extends GutTest

const BattlefieldScene := preload("res://scenes/battle/battlefield.tscn")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const UnitScript := preload("res://scripts/battle/unit.gd")
const PortraitPanelScript := preload("res://scripts/battle/portrait_panel.gd")


func after_each() -> void:
	GameManager.close_game_menu()
	GameManager.battle_result_summary = {}
	GameSession.reset_injectable_rolls()
	GameSession.loot_gold_roll = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
	GameSession.loot_gear_roll = func() -> float: return randf()


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


func test_battlefield_exposes_the_selected_units_potion_as_a_separate_two_ap_action() -> void:
	GameSession.banked_gear = {"healing_potion": 1}
	assert_true(GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "healing_potion"))
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.selected_unit
	warrior.health = 4
	battlefield._refresh_item_actions()

	assert_true(battlefield.use_potion_button.visible)
	assert_eq(battlefield.potion_option.get_selected_metadata(), "healing_potion")
	battlefield.grid.healing_roll = func(_minimum: int, maximum: int) -> int: return maximum
	battlefield._on_use_potion_pressed()

	assert_eq(warrior.action_points_remaining, 4)
	assert_eq(warrior.health, 10)
	assert_eq(GameSession.get_carried_item_ids(GameSession.WARRIOR_ID).count("healing_potion"), 0)


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
		assert_eq(health_label.text, "10/10")


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
	for child_name in ["Swatch", "SwatchStack", "Health", "HealthBacking", "SelectionRing"]:
		var child: Control = row.find_child(child_name, true, false)
		assert_eq(
			child.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"%s must not intercept clicks meant for the row button" % child_name
		)


func test_portrait_health_label_overlays_the_swatch_instead_of_sitting_beside_it() -> void:
	_setup_two_member_party()
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var row: Control = battlefield.portrait_panel.get_node("Rows/Portrait0")
	var swatch: Control = row.find_child("Swatch", true, false)
	var health_label: Label = row.find_child("Health", true, false)

	assert_eq(
		health_label.get_parent(), swatch.get_parent(),
		"The HP label must live in the same stack as the swatch, not as its sibling in the row's HBoxContainer"
	)
	assert_false(
		health_label.get_parent() is HBoxContainer,
		"The HP label must no longer be a direct child of the row's top-level HBoxContainer"
	)
	assert_eq(health_label.text, "10/10")


func test_clicking_a_portrait_selects_that_party_member() -> void:
	var second_member_id: String = _setup_two_member_party()
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield.portrait_panel.get_node("Rows/Portrait1").emit_signal("pressed")

	assert_eq(battlefield.grid.selected_unit.adventurer_id, second_member_id)


## Battle feedback (Hint, Status, the enemy health list) lives in a bottom
## message panel beneath the battle map, matching the World Map HUD's own
## BottomPanel (see world_map.tscn/test_world_map.gd's
## test_hud_bottom_panel_is_a_panel_container_not_a_manually_offset_panel) --
## not stacked above the left portrait panel, where a tall enemy health list
## (up to 8 entries, see BattleController.ENEMY_START_POSITIONS) used to
## crowd it out. EnemyHealth's own parent is a ScrollContainer (see
## test_enemy_health_list_is_wrapped_in_a_height_capped_scroll_container
## below), not the shared BottomContent stack directly -- Hint and Status
## still share that stack. The scroll container itself sits in ScrollRow
## (alongside LogScroll, see test_bottom_panel_clears_the_battle_grids_
## bottom_edge), which is what's actually parented alongside Hint/Status.
func test_hud_hint_and_status_share_the_bottom_panel_stack() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(battlefield.hint.get_parent(), battlefield.status.get_parent())


func test_thorn_trigger_describes_the_visible_paralyzed_state() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var attacker = UnitScript.new(Vector2i.ZERO, Color.INDIAN_RED, BattleControllerScript.Side.ENEMY)
	attacker.display_name = "Goblin 1"

	assert_eq(battlefield._describe_step({"type": "attack", "attacker": attacker, "thorn_triggered": true}), "Goblin 1 is Paralyzed!")
	assert_eq(
		battlefield.enemy_health.get_parent().get_parent().get_parent(),
		battlefield.hint.get_parent()
	)


## Regression test for a real bug found via a real screenshot: with a full
## 8-enemy Ruined Fortress fight, an unbounded EnemyHealth list grew tall
## enough to visually cover the bottom two rows of the battle grid. Wrapping
## it in a ScrollContainer with a fixed height budget means the panel's
## total height can never grow past that budget no matter how many enemies
## are fielded -- extra entries scroll instead of pushing the panel taller.
func test_enemy_health_list_is_wrapped_in_a_height_capped_scroll_container() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	var scroll_container: Control = battlefield.enemy_health.get_parent()
	assert_true(
		scroll_container is ScrollContainer,
		"The enemy health list must scroll instead of growing without a height bound"
	)
	assert_gt(
		scroll_container.custom_minimum_size.y, 0.0,
		"The scroll container needs a fixed, non-zero height budget so a full 8-enemy list cannot grow into the battle grid"
	)


func test_hud_bottom_panel_is_a_panel_container_not_a_manually_offset_panel() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	# Hint/Status/EnemyHealth stack inside one VBoxContainer (BottomContent),
	# which is itself the PanelContainer's single stretched child -- unlike
	# world_map.tscn's single-Label BottomPanel, this one needs the extra
	# layer to hold three widgets.
	assert_true(battlefield.hint.get_parent().get_parent() is PanelContainer)


func test_bottom_panel_does_not_share_a_parent_with_the_portrait_panel() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_ne(
		battlefield.hint.get_parent(),
		battlefield.portrait_panel.get_parent(),
		"The bottom feedback panel and the left portrait panel must be separate HUD regions, not stacked in the same row"
	)


func test_combat_log_shares_the_bottom_panel_stack_and_starts_empty() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(
		battlefield.log_list.get_parent().get_parent().get_parent(),
		battlefield.hint.get_parent()
	)
	assert_eq(battlefield.log_list.get_child_count(), 0)


func test_combat_log_is_wrapped_in_a_height_capped_scroll_container() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	var scroll_container: Control = battlefield.log_list.get_parent()
	assert_true(scroll_container is ScrollContainer)
	assert_gt(scroll_container.custom_minimum_size.y, 0.0)


## Regression test for a real layout bug found via a real screenshot: adding
## LogScroll stacked above EnemyHealthScroll blew the bottom panel's height
## budget and made it visibly cover the battle grid's bottom rows. LogScroll
## and EnemyHealthScroll must share one height budget (side by side in a row)
## rather than stacking two, so the bottom panel's top edge never rises above
## the grid's bottom edge.
func test_bottom_panel_clears_the_battle_grids_bottom_edge() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	await get_tree().process_frame
	await get_tree().process_frame

	var bottom_panel: Control = battlefield.hint.get_parent().get_parent()
	var grid_bottom_edge: float = (
		battlefield.grid.position.y
		+ BattleControllerScript.GRID_HEIGHT * BattleControllerScript.TILE_SIZE
	)
	assert_true(
		bottom_panel.get_global_rect().position.y >= grid_bottom_edge,
		"The bottom HUD panel must never grow tall enough to cover the battle grid"
	)


func _stage_an_adjacent_pair(battlefield: Node2D) -> Dictionary:
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	goblin.grid_position = warrior.grid_position + Vector2i(1, 0)
	battlefield.grid.selected_unit = warrior
	return {"warrior": warrior, "goblin": goblin}


func test_a_hit_appends_a_detailed_line_naming_both_units_and_the_damage() -> void:
	# Earlier tests in this file leave a two-member party selected without
	# resetting it (see _setup_two_member_party() callers above); reset so the
	# staged pair below gets the single-Warrior fallback fielding it assumes
	# -- otherwise the second party member would already occupy the tile
	# _stage_an_adjacent_pair() moves the goblin onto.
	GameSession.reset()
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var units := _stage_an_adjacent_pair(battlefield)
	battlefield.grid.hit_roll = func() -> float: return 0.0
	battlefield.grid.damage_roll = func(_min_value: int, _max_value: int) -> int: return 3

	battlefield.grid.try_attack_selected_unit(units.goblin.grid_position)
	battlefield._on_board_changed()

	assert_eq(battlefield.log_list.get_child_count(), 1)
	assert_eq(
		battlefield.log_list.get_child(0).text,
		tr("battle.log.hit") % [units.warrior.display_name, units.goblin.display_name, 3]
	)


func test_a_miss_appends_a_miss_line_naming_both_units() -> void:
	GameSession.reset()
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var units := _stage_an_adjacent_pair(battlefield)
	battlefield.grid.hit_roll = func() -> float: return 0.99

	battlefield.grid.try_attack_selected_unit(units.goblin.grid_position)
	battlefield._on_board_changed()

	assert_eq(battlefield.log_list.get_child_count(), 1)
	assert_eq(
		battlefield.log_list.get_child(0).text,
		tr("battle.log.miss") % [units.warrior.display_name, units.goblin.display_name]
	)


func test_a_killing_blow_appends_a_defeated_suffix() -> void:
	GameSession.reset()
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var units := _stage_an_adjacent_pair(battlefield)
	units.goblin.health = 1
	battlefield.grid.hit_roll = func() -> float: return 0.0

	battlefield.grid.try_attack_selected_unit(units.goblin.grid_position)
	battlefield._on_board_changed()

	assert_string_contains(
		battlefield.log_list.get_child(0).text,
		tr("battle.log.defeated") % units.goblin.display_name
	)


func test_a_repeated_board_changed_event_does_not_duplicate_the_log_line() -> void:
	GameSession.reset()
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var units := _stage_an_adjacent_pair(battlefield)
	battlefield.grid.hit_roll = func() -> float: return 0.0
	battlefield.grid.try_attack_selected_unit(units.goblin.grid_position)
	battlefield._on_board_changed()

	battlefield._on_board_changed()

	assert_eq(
		battlefield.log_list.get_child_count(), 1,
		"A repeated board_changed for the same already-logged attack must not re-log it"
	)


func test_enemy_turn_attacks_are_appended_to_the_log() -> void:
	GameSession.reset()
	var battlefield: Node2D = BattlefieldScene.instantiate()
	battlefield.enemy_turn_beat_seconds = 0.0
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	goblin.grid_position = warrior.grid_position + Vector2i(1, 0)
	battlefield.grid.hit_roll = func() -> float: return 0.0
	battlefield._on_end_turn_pressed()

	while battlefield._enemy_turn_in_progress:
		await get_tree().process_frame

	assert_eq(battlefield.log_list.get_child_count(), 2)
	assert_eq(
		battlefield.log_list.get_child(0).text,
		# GOBLIN_ENEMY_STATS.attack_damage is 2 (min == max, so deterministic
		# once hit_roll is forced to 0.0) -- see game_session.gd.
		tr("battle.log.hit") % [goblin.display_name, warrior.display_name, 2]
	)


func test_enemy_turn_moves_are_not_logged() -> void:
	GameSession.reset()
	var battlefield: Node2D = BattlefieldScene.instantiate()
	battlefield.enemy_turn_beat_seconds = 0.0
	add_child_autofree(battlefield)
	# The default fallback fielding (no party assigned) puts the Warrior at
	# PLAYER_START_POSITIONS[0] and the goblin at ENEMY_START_POSITIONS[0],
	# which are not adjacent -- see test_run_enemy_turn_moves_the_goblin_
	# toward_the_nearest_player_unit for the same non-adjacent setup, so this
	# enemy turn is guaranteed to be a move with no attack.
	battlefield._on_end_turn_pressed()

	while battlefield._enemy_turn_in_progress:
		await get_tree().process_frame

	assert_eq(battlefield.log_list.get_child_count(), 0, "A move-only enemy turn must not add any log line")


func test_hud_round_label_and_end_turn_button_share_the_top_right_stack() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(battlefield.round_label.get_parent(), battlefield.end_turn_button.get_parent())


## Task 3: the right-side unit hover/click detail panel, which lives inside
## BodyRow next to PortraitPanel (see unit_info_panel.gd and battlefield.tscn).

## BattleController._ready() auto-selects the first living party member
## (selection ring shown on the board from turn one), so the unit-info panel
## must reflect that same opening selection instead of showing its empty
## prompt despite a unit already being visibly selected.
func test_unit_info_panel_shows_the_auto_selected_unit_at_battle_start() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])

	assert_false(battlefield.unit_info_panel.get_node("Content/EmptyLabel").visible)
	assert_true(battlefield.unit_info_panel.get_node("Content/NameLabel").visible)
	assert_eq(battlefield.unit_info_panel.get_node("Content/NameLabel").text, warrior.display_name)


func test_unit_info_panel_shows_exact_hp_name_class_and_level_for_a_player_unit() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])

	battlefield.grid._set_hovered_unit(warrior)

	var panel: Control = battlefield.unit_info_panel
	assert_false(panel.get_node("Content/EmptyLabel").visible)
	assert_true(panel.get_node("Content/NameLabel").visible)
	assert_eq(panel.get_node("Content/NameLabel").text, "Warrior")
	assert_eq(panel.get_node("Content/ClassLabel").text, tr("information.class") % "warrior")
	assert_eq(panel.get_node("Content/LevelLabel").text, tr("information.level") % 1)
	assert_eq(panel.get_node("Content/HpLabel").text, tr("battle.unit_info.hp") % [10, 10])
	assert_false(panel.get_node("Content/WoundLabel").visible, "Enemies-only row must stay hidden for a player unit")


func test_unit_info_panel_shows_only_a_wound_tier_for_an_enemy_never_exact_hp() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])

	battlefield.grid._set_hovered_unit(goblin)

	var panel: Control = battlefield.unit_info_panel
	assert_eq(panel.get_node("Content/NameLabel").text, goblin.display_name)
	assert_true(panel.get_node("Content/WoundLabel").visible)
	assert_eq(panel.get_node("Content/WoundLabel").text, tr("battle.unit_info.healthy"))
	assert_false(panel.get_node("Content/HpLabel").visible, "Player-only row must stay hidden for an enemy")
	assert_false(panel.get_node("Content/ClassLabel").visible)
	assert_false(panel.get_node("Content/LevelLabel").visible)


func test_unit_info_panel_wound_tiers_match_the_health_percentage_thresholds() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	var panel: Control = battlefield.unit_info_panel

	goblin.health = goblin.max_health  # 100%
	battlefield.grid._set_hovered_unit(goblin)
	assert_eq(panel.get_node("Content/WoundLabel").text, tr("battle.unit_info.healthy"))

	goblin.health = int(goblin.max_health * 0.5)  # 50%, inside the 34-66% band
	battlefield.grid._set_hovered_unit(null)
	battlefield.grid._set_hovered_unit(goblin)
	assert_eq(panel.get_node("Content/WoundLabel").text, tr("battle.unit_info.wounded"))

	goblin.health = 1  # well under 33%
	battlefield.grid._set_hovered_unit(null)
	battlefield.grid._set_hovered_unit(goblin)
	assert_eq(panel.get_node("Content/WoundLabel").text, tr("battle.unit_info.badly_wounded"))


## get_focused_unit() falls back from hover to the pinned selection (see
## BattleController.get_focused_unit()) -- and battle start already pins the
## first party member as that selection (see BattleController._ready()), so
## losing hover reverts to showing that pinned unit, not an empty panel.
func test_unit_info_panel_reverts_to_the_pinned_selection_when_hover_ends() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	battlefield.grid._set_hovered_unit(goblin)

	battlefield.grid._set_hovered_unit(null)

	assert_false(battlefield.unit_info_panel.get_node("Content/EmptyLabel").visible)
	assert_true(battlefield.unit_info_panel.get_node("Content/NameLabel").visible)
	assert_eq(battlefield.unit_info_panel.get_node("Content/NameLabel").text, warrior.display_name)


func test_unit_info_panel_lives_to_the_right_of_the_portrait_panel() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(battlefield.unit_info_panel.get_parent(), battlefield.portrait_panel.get_parent())
	var body_row: Node = battlefield.unit_info_panel.get_parent()
	assert_gt(
		battlefield.unit_info_panel.get_index(), battlefield.portrait_panel.get_index(),
		"The unit info panel must sit after (visually to the right of) the portrait panel in BodyRow"
	)


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
		assert_eq(label.text, tr("battle.status.health") % [tr("battle.side.enemy"), 13, 13])


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
	GameSession.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
	GameSession.loot_gear_roll = func() -> float: return 1.0
	GameSession.enter_encounter("goblin_camp")
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield._apply_battle_outcome(true)

	assert_true(GameSession.is_encounter_complete("goblin_camp"))
	assert_eq(GameSession.battle_reward, 19, "Victory should queue the goblin camp's rolled reward in the battle store")

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


func test_battle_start_reads_stored_adventurer_health() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.set_adventurer_health("warrior_001", 4)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var unit = battlefield.grid.units[0]

	assert_eq(unit.health, 4, "Battlefield unit starts with the adventurer's stored health (4)")
	assert_eq(unit.max_health, 10)


func test_victory_aftermath_persists_surviving_player_unit_health() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	GameSession.enter_encounter("goblin_camp")
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	battlefield.grid.units[0].health = 6

	battlefield._apply_battle_outcome(true)

	assert_eq(GameSession.get_current_health("warrior_001"), 6, "Surviving unit health (6) persists after victory")


func test_defeat_aftermath_persists_downed_player_units_at_one_health() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	GameSession.enter_encounter("goblin_camp")
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	battlefield.grid.units[0].health = 0

	battlefield._apply_battle_outcome(false)

	assert_eq(GameSession.get_current_health("warrior_001"), 1, "Downed units persist at 1 health on defeat")


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
	# Pin to the Orc option (index 1): the Orc Outpost's tier-2 composition
	# randomly resolves to Goblins or an Orc (see STAR_ENEMY_COMPOSITIONS), so
	# leaving this unpinned made the test a real coin flip between 5 and 10 XP.
	var battlefield := _setup_orc_outpost_battle(func(_option_count: int) -> int: return 1)
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
	battlefield.grid.try_attack_selected_unit(second_enemy.grid_position)

	assert_eq(
		GameSession.get_adventurer("warrior_001").progression.xp,
		10.0,
		"Each Goblin should award its own kill_xp (5) regardless of which site it's fought at, not the site's flat kill_xp"
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
	assert_eq(units.warrior.max_health, 20, "The active unit's max health must rise immediately on a mid-battle level-up")
	assert_eq(units.warrior.health, 20, "The active unit's current health must rise by the same amount as max health")


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


func test_a_victorious_battle_reports_kills_grouped_by_type_to_the_summary() -> void:
	var battlefield := _setup_goblin_camp_battle()
	var units := _stage_a_killing_blow(battlefield)
	battlefield.grid.try_attack_selected_unit(units.enemy.grid_position)

	battlefield._apply_battle_outcome(true)

	assert_eq(GameManager.battle_result_summary.kills_by_type, {tr("battle.enemy.goblin"): 1})


func test_a_victorious_battle_reports_total_and_per_member_xp_to_the_summary() -> void:
	var battlefield := _setup_goblin_camp_battle()
	var units := _stage_a_killing_blow(battlefield)
	battlefield.grid.try_attack_selected_unit(units.enemy.grid_position)

	battlefield._apply_battle_outcome(true)

	assert_eq(
		GameManager.battle_result_summary.total_xp, 15.0,
		"5 goblin kill XP + 10 goblin camp clear XP"
	)
	assert_eq(GameManager.battle_result_summary.party_member_count, 1)


func test_a_victorious_battle_with_no_level_up_reports_an_empty_leveled_up_list() -> void:
	var battlefield := _setup_goblin_camp_battle()

	battlefield._apply_battle_outcome(true)

	assert_eq(GameManager.battle_result_summary.leveled_up_ids, [])


## Regression test: the battle store (GameSession.battle_reward/battle_
## mana_crystals/battle_gear) holds only the current battle's own loot,
## separate from the party's own running totals (pending_reward/pending_
## mana_crystals/pending_gear) until the player leaves the summary screen
## (see GameSession.merge_battle_loot_into_party()) -- so a party's second
## victory in one deployment must not report the first battle's already-
## carried loot alongside its own in the summary, and must not touch the
## party's own totals at all until that merge happens.
func test_a_second_victory_in_one_deployment_reports_only_its_own_loot() -> void:
	var battlefield := _setup_goblin_camp_battle()
	# Simulate an earlier battle's loot already merged into the party's own
	# store this deployment (see GameManager.go_to_world_map() ->
	# GameSession.merge_battle_loot_into_party()), not yet deposited back at
	# the settlement.
	GameSession.pending_reward = 50
	GameSession.pending_mana_crystals = {1: 3}
	GameSession.pending_gear = {"dagger_iron": 1, "buckler_wood": 1}
	GameSession.loot_gold_roll = func(min_value: int, _max_value: int) -> int: return min_value
	GameSession.loot_gear_roll = func() -> float: return 0.0

	battlefield._apply_battle_outcome(true)

	# Goblin camp's single goblin: gold_min 1 * multiplier 1, one mana
	# crystal, and (since loot_gear_roll always rolls below GEAR_DROP_CHANCE
	# here) one gear drop -- this battle's own loot, freshly rolled into the
	# battle store and reported straight from there.
	assert_eq(
		GameManager.battle_result_summary.loot_gold, 19,
		"Only this battle's own gold, not the 50 already carried over"
	)

	assert_eq(
		GameManager.battle_result_summary.loot_mana_crystal_counts, {1: 1},
		"Only this battle's own mana crystal, not the 3 already carried over"
	)
	assert_eq(
		GameManager.battle_result_summary.loot_gear_counts, {"shortsword_iron": 1},
		"Only this battle's own gear, not the 2 pieces already carried over"
	)
	# The battle store and the party's own store stay separate until the
	# player leaves the summary screen for the World Map -- so the
	# pre-seeded party totals above must still read exactly as seeded.
	assert_eq(GameSession.pending_reward, 50)
	assert_eq(GameSession.pending_mana_crystals, {1: 3})
	assert_eq(GameSession.pending_gear, {"dagger_iron": 1, "buckler_wood": 1})


func test_leveled_up_ids_accumulate_across_kill_and_clear_xp_and_reach_the_summary() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 19.0)
	GameSession.depart_selected_party()
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield._apply_battle_outcome(true)
	assert_true(battlefield.level_up.visible, "sanity check: this setup crosses the level-2 threshold")
	battlefield.level_up.continue_button.emit_signal("pressed")

	assert_eq(GameManager.battle_result_summary.leveled_up_ids, ["warrior_001"])


func test_multiple_kills_in_one_battle_are_tallied_by_type_not_overwritten() -> void:
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
	battlefield.grid.try_attack_selected_unit(second_enemy.grid_position)

	battlefield._apply_battle_outcome(true)
	# This fixture's 2 kill-XP awards (5 each) plus the Orc Outpost's 20 clear
	# XP total 30, crossing the level-2 threshold (20) — deferring
	# _finish_victory() until the level-up modal resolves, same as
	# test_leveled_up_ids_accumulate_across_kill_and_clear_xp_and_reach_the_summary.
	# Dismiss it exactly as a player would so the summary actually gets built.
	if battlefield.level_up.visible:
		battlefield.level_up.continue_button.emit_signal("pressed")

	assert_eq(GameManager.battle_result_summary.kills_by_type, {tr("battle.enemy.goblin"): 2})


func test_targeting_failure_updates_status_message() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var attacker = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	var enemy = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	battlefield.grid.selected_unit = attacker

	# Out of range click
	battlefield.grid._handle_tile_click(enemy.grid_position)
	assert_eq(battlefield.status.text, tr("battle.feedback.out_of_range"))

	# Insufficient AP click
	enemy.grid_position = attacker.grid_position + Vector2i(1, 0)
	attacker.action_points_remaining = 2
	battlefield.grid._handle_tile_click(enemy.grid_position)
	assert_eq(
		battlefield.status.text,
		tr("battle.feedback.not_enough_ap") % BattleControllerScript.BASIC_ATTACK_ACTION_POINT_COST
	)

