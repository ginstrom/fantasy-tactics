extends GutTest

const BattlefieldScene := preload("res://scenes/battle/battlefield.tscn")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const UnitScript := preload("res://scripts/battle/unit.gd")
const PortraitPanelScript := preload("res://scripts/battle/portrait_panel.gd")
const TEST_AUDIO_SETTINGS_PATH := "user://test_battlefield_audio_settings.json"


## The mute-parity tests below call AudioManager.set_bus_mute(), which
## persists to disk (see AudioManager's own doc comment on why this is a
## standalone user:// file, not CampaignSnapshot) -- point that write at a
## throwaway path for this file's whole run, the same way test_game_menu.gd
## points GameManager.save_repository at a throwaway save path, so no test
## run ever touches the real audio-settings.json on the machine running it.
func before_each() -> void:
	AudioManager.settings_path = TEST_AUDIO_SETTINGS_PATH


func after_each() -> void:
	GameManager.close_game_menu()
	GameManager.battle_result_summary = {}
	GameSession.reset_injectable_rolls()
	GameSession.loot_gold_roll = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
	GameSession.loot_gear_roll = func() -> float: return randf()
	AudioManager.reset()
	AudioManager.settings_path = AudioManager.DEFAULT_SETTINGS_PATH
	if FileAccess.file_exists(TEST_AUDIO_SETTINGS_PATH):
		DirAccess.remove_absolute(TEST_AUDIO_SETTINGS_PATH)


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


## Step 2 of docs/plans/2026-08-18-critical-hits-and-flanking:
## try_attack_selected_unit() now includes a "critical" key on every attack
## step's result dictionary (see battle_controller.gd) -- a critical hit gets
## its own status line rather than the plain hit line.
func test_describe_step_reports_a_critical_hit_with_amplified_damage() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var attacker = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	var step := {"type": "attack", "attacker": attacker, "hit": true, "damage": 6, "critical": true}

	assert_eq(
		battlefield._describe_step(step),
		tr("battle.status.critical_hit") % [tr("battle.side.enemy"), 6]
	)


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


## --- Cleric spell ActionBar (Step 4) ---

func _setup_cleric_party() -> String:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var cleric := GameSession.get_default_cleric("cleric_test", "Test Cleric")
	GameSession.adventurers.append(cleric)
	GameSession.assign_adventurer_to_selected_party("cleric_test")
	return "cleric_test"


func test_action_bar_shows_heal_and_bless_and_mp_for_a_selected_cleric() -> void:
	var cleric_id := _setup_cleric_party()
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield.grid.select_unit_by_adventurer_id(cleric_id)
	battlefield._update_action_bar()

	assert_true(battlefield.heal_button.visible)
	assert_true(battlefield.bless_button.visible)
	assert_true(battlefield.mp_label.visible)
	assert_eq(battlefield.mp_label.text, tr("battle.mp") % [3, 3])


func test_action_bar_hides_spell_buttons_when_a_warrior_is_selected() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield._update_action_bar()

	assert_false(battlefield.heal_button.visible)
	assert_false(battlefield.bless_button.visible)
	assert_false(battlefield.mp_label.visible)


func test_action_bar_hides_spell_buttons_when_a_scout_is_selected() -> void:
	GameSession.reset()
	GameSession.create_party()
	var scout := GameSession.get_default_scout("scout_test", "Test Scout")
	GameSession.adventurers.append(scout)
	GameSession.assign_adventurer_to_selected_party("scout_test")
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield.grid.select_unit_by_adventurer_id("scout_test")
	battlefield._update_action_bar()

	assert_false(battlefield.heal_button.visible)
	assert_false(battlefield.bless_button.visible)
	assert_false(battlefield.mp_label.visible)


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


## Battle feedback (Hint, Status) lives in a bottom message panel beneath the
## battle map, matching the World Map HUD's own BottomPanel (see
## world_map.tscn/test_world_map.gd's
## test_hud_bottom_panel_is_a_panel_container_not_a_manually_offset_panel).
## As of Step 5, the enemy health list moved out of this bottom panel
## entirely (see test_enemy_health_list_lives_in_the_body_row_not_the_bottom_
## panel above) so the combat log can occupy the bottom panel's full width
## (see test_combat_log_spans_the_full_width_of_its_row below); Hint and
## Status remain here.
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


## Step 5: the enemy health list now lives in BodyRow (alongside the
## portrait panel and unit info panel) rather than stacked in the bottom
## message panel -- freeing BottomPanel's height budget for the full-width
## combat log (see test_combat_log_spans_the_full_width_of_its_row below).
func test_enemy_health_list_lives_in_the_body_row_not_the_bottom_panel() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(battlefield.enemy_health.get_parent().get_parent(), battlefield.portrait_panel.get_parent())


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


## Regression test for a real layout bug found via a real screenshot: a
## bottom panel that grows tall enough visibly covers the battle grid's
## bottom rows. As of Step 5, EnemyHealthScroll no longer shares this panel
## with LogScroll (see test_enemy_health_list_lives_in_the_body_row_not_the_
## bottom_panel above), which keeps this panel's height budget in check even
## with LogScroll spanning the full row width alone.
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
	battlefield.grid.crit_roll = func() -> float: return 1.0
	battlefield.grid.damage_roll = func(_min_value: int, _max_value: int) -> int: return 3

	battlefield.grid.try_attack_selected_unit(units.goblin.grid_position)
	battlefield._on_board_changed()

	assert_eq(battlefield.log_list.get_child_count(), 1)
	assert_eq(
		battlefield.log_list.get_child(0).text,
		tr("battle.log.hit") % [units.warrior.display_name, units.goblin.display_name, 3]
	)


func test_a_critical_hit_appends_a_critical_log_line_with_amplified_damage() -> void:
	GameSession.reset()
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var units := _stage_an_adjacent_pair(battlefield)
	battlefield.grid.hit_roll = func() -> float: return 0.0
	battlefield.grid.crit_roll = func() -> float: return 0.0
	battlefield.grid.damage_roll = func(_min_value: int, _max_value: int) -> int: return 4

	battlefield.grid.try_attack_selected_unit(units.goblin.grid_position)
	battlefield._on_board_changed()

	assert_eq(battlefield.log_list.get_child_count(), 1)
	assert_eq(
		battlefield.log_list.get_child(0).text,
		# round(4 * 1.5) = 6 damage on a critical hit (see battle_controller.gd's
		# critical_damage_multiplier).
		tr("battle.log.critical_hit") % [units.warrior.display_name, units.goblin.display_name, 6]
	)


## --- Mute Parity (Task 5, docs/plans/2026-08-18-core-loop-and-engagement/
## 08-audio-system-and-soundscape.md) --- proves the audio and visual/log
## feedback paths are structurally independent, not merely coincidentally
## both working: battle_controller.gd's _spawn_combat_text() calls
## combat_text_spawned.emit() and AudioManager.play_sfx() as two
## unconditional, back-to-back statements (neither gated on the other, and
## neither gated on AudioManager's mute state -- see that function's own
## doc comment). Muting Master (which also silences the SFX bus it sends
## to) must never suppress the combat log line or the floating-text signal.

func test_combat_log_and_floating_text_still_fire_when_the_master_bus_is_muted() -> void:
	GameSession.reset()
	AudioManager.set_bus_mute("Master", true)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var units := _stage_an_adjacent_pair(battlefield)
	battlefield.grid.hit_roll = func() -> float: return 0.0
	battlefield.grid.crit_roll = func() -> float: return 1.0
	battlefield.grid.damage_roll = func(_min_value: int, _max_value: int) -> int: return 3
	watch_signals(battlefield.grid)

	battlefield.grid.try_attack_selected_unit(units.goblin.grid_position)
	battlefield._on_board_changed()

	assert_true(AudioManager.is_bus_muted("Master"), "Sanity check: the bus must actually be muted for this proof")
	assert_eq(battlefield.log_list.get_child_count(), 1, "The combat log must still record the hit while muted")
	assert_eq(
		battlefield.log_list.get_child(0).text,
		tr("battle.log.hit") % [units.warrior.display_name, units.goblin.display_name, 3]
	)
	assert_signal_emitted(battlefield.grid, "combat_text_spawned", "Floating text must still fire while muted")
	# The SFX call itself is still made (structurally proving audio isn't
	# what visual feedback depends on) -- AudioServer, not this call site,
	# is what silences it.
	assert_eq(AudioManager.last_sfx_id, "sfx_hit_impact")


func test_combat_log_and_floating_text_still_fire_when_every_bus_is_muted() -> void:
	GameSession.reset()
	AudioManager.set_bus_mute("Master", true)
	AudioManager.set_bus_mute("Music", true)
	AudioManager.set_bus_mute("SFX", true)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var units := _stage_an_adjacent_pair(battlefield)
	battlefield.grid.hit_roll = func() -> float: return 0.99  # force a miss

	battlefield.grid.try_attack_selected_unit(units.goblin.grid_position)
	battlefield._on_board_changed()

	assert_eq(battlefield.log_list.get_child_count(), 1, "A miss must still be logged while every bus is muted")
	assert_eq(
		battlefield.log_list.get_child(0).text,
		tr("battle.log.miss") % [units.warrior.display_name, units.goblin.display_name]
	)
	assert_eq(AudioManager.last_sfx_id, "sfx_miss")


## --- Flanking combat log presentation (docs/plans/2026-08-18-critical-hits-
## and-flanking/03-flanking-tactics-and-combat-resolution.md) ---
##
## _stage_an_adjacent_pair() always places the goblin directly east of the
## warrior; the default goblin facing (LEFT, toward the warrior) is the
## front-attack case the tests above already cover. Re-facing the goblin
## while keeping that same layout produces a side or rear flank without
## needing a new rig: UP/DOWN put the attack on the goblin's flank, RIGHT
## turns the goblin's back to the attacker.

func test_a_side_flank_hit_appends_the_side_flank_log_line() -> void:
	GameSession.reset()
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var units := _stage_an_adjacent_pair(battlefield)
	units.goblin.facing = Vector2i.UP
	battlefield.grid.hit_roll = func() -> float: return 0.0
	battlefield.grid.crit_roll = func() -> float: return 1.0
	battlefield.grid.damage_roll = func(_min_value: int, _max_value: int) -> int: return 3

	battlefield.grid.try_attack_selected_unit(units.goblin.grid_position)
	battlefield._on_board_changed()

	assert_eq(battlefield.log_list.get_child_count(), 1)
	assert_eq(
		battlefield.log_list.get_child(0).text,
		tr("battle.log.flank.side") % [units.warrior.display_name, units.goblin.display_name, 3]
	)


func test_a_side_flank_critical_hit_appends_the_side_flank_critical_log_line() -> void:
	GameSession.reset()
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var units := _stage_an_adjacent_pair(battlefield)
	units.goblin.facing = Vector2i.UP
	battlefield.grid.hit_roll = func() -> float: return 0.0
	battlefield.grid.crit_roll = func() -> float: return 0.0
	battlefield.grid.damage_roll = func(_min_value: int, _max_value: int) -> int: return 4

	battlefield.grid.try_attack_selected_unit(units.goblin.grid_position)
	battlefield._on_board_changed()

	assert_eq(battlefield.log_list.get_child_count(), 1)
	assert_eq(
		battlefield.log_list.get_child(0).text,
		# round(4 * 1.5) = 6 damage on a critical hit (see battle_controller.gd's
		# critical_damage_multiplier).
		tr("battle.log.flank.side_crit") % [units.warrior.display_name, units.goblin.display_name, 6]
	)


func test_a_rear_flank_hit_appends_the_rear_flank_log_line() -> void:
	GameSession.reset()
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var units := _stage_an_adjacent_pair(battlefield)
	units.goblin.facing = Vector2i.RIGHT
	battlefield.grid.hit_roll = func() -> float: return 0.0
	battlefield.grid.crit_roll = func() -> float: return 1.0
	battlefield.grid.damage_roll = func(_min_value: int, _max_value: int) -> int: return 3

	battlefield.grid.try_attack_selected_unit(units.goblin.grid_position)
	battlefield._on_board_changed()

	assert_eq(battlefield.log_list.get_child_count(), 1)
	assert_eq(
		battlefield.log_list.get_child(0).text,
		tr("battle.log.flank.rear") % [units.warrior.display_name, units.goblin.display_name, 3]
	)


func test_a_rear_flank_critical_hit_appends_the_rear_flank_critical_log_line() -> void:
	GameSession.reset()
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var units := _stage_an_adjacent_pair(battlefield)
	units.goblin.facing = Vector2i.RIGHT
	battlefield.grid.hit_roll = func() -> float: return 0.0
	battlefield.grid.crit_roll = func() -> float: return 0.0
	battlefield.grid.damage_roll = func(_min_value: int, _max_value: int) -> int: return 4

	battlefield.grid.try_attack_selected_unit(units.goblin.grid_position)
	battlefield._on_board_changed()

	assert_eq(battlefield.log_list.get_child_count(), 1)
	assert_eq(
		battlefield.log_list.get_child(0).text,
		tr("battle.log.flank.rear_crit") % [units.warrior.display_name, units.goblin.display_name, 6]
	)


## A killing blow on a flanked attack must still append the shared
## "is defeated!" suffix regardless of which log key rendered the base line
## -- _describe_log_entry() appends it once, after picking the flank-aware
## key, so this guards that ordering.
func test_a_rear_flank_killing_blow_still_appends_the_defeated_suffix() -> void:
	GameSession.reset()
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var units := _stage_an_adjacent_pair(battlefield)
	units.goblin.facing = Vector2i.RIGHT
	units.goblin.health = 1
	battlefield.grid.hit_roll = func() -> float: return 0.0
	battlefield.grid.crit_roll = func() -> float: return 1.0

	battlefield.grid.try_attack_selected_unit(units.goblin.grid_position)
	battlefield._on_board_changed()

	assert_string_contains(
		battlefield.log_list.get_child(0).text,
		tr("battle.log.defeated") % units.goblin.display_name
	)


## Proves try_attack_selected_unit() records the resolved flank/effective_*
## values it computed for this exact attack, not just that the keys exist --
## goblins are always unarmored (defense 0, see BattleController._ready()),
## so a rear flank's guard penalty has nothing to reduce and effective_defense
## stays 0; effective_hit_chance therefore equals the attacker's raw hit
## chance unmodified, isolating the crit-bonus half of the formula (0.05 base
## + the configured 0.50 rear bonus) as the case's real assertion.
func test_last_attack_result_records_the_resolved_flank_and_effective_values() -> void:
	GameSession.reset()
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var units := _stage_an_adjacent_pair(battlefield)
	units.goblin.facing = Vector2i.RIGHT
	battlefield.grid.hit_roll = func() -> float: return 0.0
	battlefield.grid.crit_roll = func() -> float: return 1.0

	battlefield.grid.try_attack_selected_unit(units.goblin.grid_position)

	var result: Dictionary = battlefield.grid.last_attack_result
	assert_eq(result.flank, "rear")
	assert_eq(result.effective_defense, 0, "The goblin is unarmored, so a rear flank has no guard left to reduce")
	assert_almost_eq(result.effective_hit_chance, units.warrior.hit_chance, 0.0001)
	assert_almost_eq(result.effective_crit_chance, 0.55, 0.0001, "0.05 base + the configured 0.50 rear crit bonus")


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
	battlefield.grid.crit_roll = func() -> float: return 1.0
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


func test_hud_round_label_and_action_points_label_share_the_top_right_stack() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(battlefield.round_label.get_parent(), battlefield.action_points_label.get_parent())


## Step 5: End Turn now sits in the bottom ActionBar alongside Move, Attack,
## and the item actions (per the Baldur's Gate inspired layout's bottom
## action row), not in the top header stack next to Round/AP.
func test_end_turn_button_shares_the_bottom_action_bar_row_with_move_and_attack() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(battlefield.end_turn_button.get_parent(), battlefield.move_button.get_parent().get_parent())


## Step 4: the right-side unit hover/click detail panel, which lives inside
## BodyRow next to PortraitPanel (see unit_info_panel.gd and battlefield.tscn),
## and now shows the hovered unit and the selected unit simultaneously in
## distinct sub-containers (HoveredSection / SelectedSection) rather than
## collapsing them into one shared set of labels.

## BattleController._ready() auto-selects the first living party member
## (selection ring shown on the board from turn one), so the unit-info
## panel's SelectedSection must reflect that same opening selection instead
## of showing its empty prompt despite a unit already being visibly selected.
func test_unit_info_panel_shows_the_auto_selected_unit_at_battle_start() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])

	var panel: Control = battlefield.unit_info_panel
	assert_false(panel.get_node("Content/EmptyLabel").visible)
	assert_true(panel.get_node("Content/SelectedSection").visible)
	assert_eq(panel.get_node("Content/SelectedSection/NameLabel").text, warrior.display_name)


func test_unit_info_panel_selected_section_shows_exact_hp_ap_name_class_level_and_weapon_for_a_player_unit() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])

	var panel: Control = battlefield.unit_info_panel
	assert_false(panel.get_node("Content/EmptyLabel").visible)
	assert_true(panel.get_node("Content/SelectedSection").visible)
	assert_eq(panel.get_node("Content/SelectedSection/NameLabel").text, "Warrior")
	assert_eq(panel.get_node("Content/SelectedSection/ClassLabel").text, tr("information.class") % "warrior")
	assert_eq(panel.get_node("Content/SelectedSection/LevelLabel").text, tr("information.level") % 1)
	assert_eq(panel.get_node("Content/SelectedSection/HpLabel").text, tr("battle.unit_info.hp") % [10, 10])
	assert_eq(
		panel.get_node("Content/SelectedSection/ApLabel").text,
		tr("battle.unit_info.ap") % [warrior.action_points_remaining, warrior.max_action_points]
	)
	assert_eq(panel.get_node("Content/SelectedSection/WeaponLabel").text, tr("battle.unit_info.weapon") % warrior.attack_name)
	assert_false(
		panel.get_node("Content/SelectedSection/WoundLabel").visible,
		"Enemies-only row must stay hidden for a player unit"
	)


## Facing is shown for both the selected and hovered sections (see
## unit_info_panel.gd's FacingLabel wiring) -- unlike class/HP/wound, it is
## never side-conditional, since Steps 2/3 of this plan (critical hits,
## flanking) make an enemy's facing just as tactically relevant as an ally's.
func test_unit_info_panel_selected_section_shows_the_selected_units_facing() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	warrior.facing = Vector2i.DOWN
	battlefield.grid._select_unit(warrior)

	var panel: Control = battlefield.unit_info_panel
	assert_eq(
		panel.get_node("Content/SelectedSection/FacingLabel").text,
		tr("battle.unit_info.facing") % tr("battle.facing.south")
	)


func test_unit_info_panel_hovered_section_shows_the_hovered_units_facing() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	goblin.facing = Vector2i.UP

	battlefield.grid._set_hovered_unit(goblin)

	var panel: Control = battlefield.unit_info_panel
	assert_eq(
		panel.get_node("Content/HoveredSection/FacingLabel").text,
		tr("battle.unit_info.facing") % tr("battle.facing.north")
	)


## Hovering an enemy while a player unit is selected is the panel's core new
## scenario: both halves must render at once, from two different units.
func test_unit_info_panel_shows_hovered_enemy_and_selected_player_simultaneously() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	goblin.health = int(goblin.max_health * 0.5)  # inside the "Wounded" band

	battlefield.grid._select_unit(warrior)
	battlefield.grid._set_hovered_unit(goblin)

	var panel: Control = battlefield.unit_info_panel
	assert_true(panel.get_node("Content/HoveredSection").visible)
	assert_eq(panel.get_node("Content/HoveredSection/NameLabel").text, goblin.display_name)
	assert_eq(panel.get_node("Content/HoveredSection/WoundLabel").text, tr("battle.unit_info.wounded"))
	assert_true(panel.get_node("Content/SelectedSection").visible)
	assert_eq(panel.get_node("Content/SelectedSection/NameLabel").text, "Warrior")
	assert_eq(
		panel.get_node("Content/SelectedSection/HpLabel").text,
		tr("battle.unit_info.hp") % [warrior.health, warrior.max_health]
	)
	assert_eq(
		panel.get_node("Content/SelectedSection/ApLabel").text,
		tr("battle.unit_info.ap") % [warrior.action_points_remaining, warrior.max_action_points]
	)
	assert_eq(panel.get_node("Content/SelectedSection/WeaponLabel").text, tr("battle.unit_info.weapon") % warrior.attack_name)


func test_unit_info_panel_hovered_section_shows_only_a_wound_tier_for_an_enemy_never_exact_hp() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])

	battlefield.grid._set_hovered_unit(goblin)

	var panel: Control = battlefield.unit_info_panel
	assert_true(panel.get_node("Content/HoveredSection").visible)
	assert_eq(panel.get_node("Content/HoveredSection/NameLabel").text, goblin.display_name)
	assert_true(panel.get_node("Content/HoveredSection/WoundLabel").visible)
	assert_eq(panel.get_node("Content/HoveredSection/WoundLabel").text, tr("battle.unit_info.healthy"))
	assert_false(panel.get_node("Content/HoveredSection/HpLabel").visible, "Player-only row must stay hidden for an enemy")


## Design Contract (index.md, "4. Dual Right-Hand Inspection Panel"): the
## hovered section shows "wound tier for enemies, HP/class for allies" -- so
## a hovered ally (not the selected unit) must show class alongside name/HP,
## unlike a hovered enemy which only ever shows a wound tier.
func test_unit_info_panel_hovered_section_shows_class_for_a_hovered_ally() -> void:
	_setup_two_member_party()
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var first_member = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	var second_member = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[1])

	battlefield.grid._select_unit(first_member)
	battlefield.grid._set_hovered_unit(second_member)

	var panel: Control = battlefield.unit_info_panel
	assert_true(panel.get_node("Content/HoveredSection").visible)
	assert_eq(panel.get_node("Content/HoveredSection/NameLabel").text, second_member.display_name)
	assert_true(panel.get_node("Content/HoveredSection/HpLabel").visible)
	assert_eq(
		panel.get_node("Content/HoveredSection/HpLabel").text,
		tr("battle.unit_info.hp") % [second_member.health, second_member.max_health]
	)
	assert_true(panel.get_node("Content/HoveredSection/ClassLabel").visible)
	var adventurer := GameSession.get_adventurer(second_member.adventurer_id)
	assert_eq(panel.get_node("Content/HoveredSection/ClassLabel").text, tr("information.class") % adventurer.get("class", ""))


func test_unit_info_panel_hovered_wound_tiers_match_the_health_percentage_thresholds() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	var panel: Control = battlefield.unit_info_panel

	goblin.health = goblin.max_health  # 100%
	battlefield.grid._set_hovered_unit(goblin)
	assert_eq(panel.get_node("Content/HoveredSection/WoundLabel").text, tr("battle.unit_info.healthy"))

	goblin.health = int(goblin.max_health * 0.5)  # 50%, inside the 34-66% band
	battlefield.grid._set_hovered_unit(null)
	battlefield.grid._set_hovered_unit(goblin)
	assert_eq(panel.get_node("Content/HoveredSection/WoundLabel").text, tr("battle.unit_info.wounded"))

	goblin.health = 1  # well under 33%
	battlefield.grid._set_hovered_unit(null)
	battlefield.grid._set_hovered_unit(goblin)
	assert_eq(panel.get_node("Content/HoveredSection/WoundLabel").text, tr("battle.unit_info.badly_wounded"))


## Hover ending must not disturb the pinned selection -- the SelectedSection
## keeps showing the actually-selected unit (grid.selected_unit) regardless
## of hover state; only the HoveredSection reacts to losing hover.
func test_unit_info_panel_hides_hovered_section_when_hover_ends_but_keeps_selected_section_pinned() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	battlefield.grid._set_hovered_unit(goblin)

	battlefield.grid._set_hovered_unit(null)

	var panel: Control = battlefield.unit_info_panel
	assert_false(panel.get_node("Content/HoveredSection").visible)
	assert_true(panel.get_node("Content/SelectedSection").visible)
	assert_eq(panel.get_node("Content/SelectedSection/NameLabel").text, warrior.display_name)


## AP spent on a move doesn't change which unit is focused (the mover stays
## selected), so this only reaches the panel via _on_board_changed()'s own
## update_panel() resync -- not via unit_focus_changed.
func test_unit_info_panel_selected_section_ap_updates_immediately_after_a_move() -> void:
	# Explicit single-member setup rather than relying on the no-party
	# fallback: a party left fielded by an earlier test in this file (e.g.
	# _setup_two_member_party()) would otherwise field a second unit at
	# PLAYER_START_POSITIONS[1] == (1, 0), the very tile this test moves
	# into, turning the intended move into a same-side reselect instead.
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	var starting_ap: int = warrior.action_points_remaining
	var panel: Control = battlefield.unit_info_panel

	battlefield.grid._handle_tile_click(warrior.grid_position + Vector2i(1, 0))

	assert_lt(warrior.action_points_remaining, starting_ap)
	assert_eq(
		panel.get_node("Content/SelectedSection/ApLabel").text,
		tr("battle.unit_info.ap") % [warrior.action_points_remaining, warrior.max_action_points]
	)


## Damage/healing on the selected unit must refresh its HP text immediately;
## on a hovered enemy it must refresh the wound tier immediately. Both go
## through battlefield._on_board_changed(), which every damage/heal path in
## this game already routes through (see e.g. _on_use_potion_pressed()).
func test_unit_info_panel_hp_and_wound_tier_update_immediately_on_damage() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	var panel: Control = battlefield.unit_info_panel

	warrior.health = maxi(1, warrior.max_health - 3)
	battlefield.grid._set_hovered_unit(goblin)
	goblin.health = int(goblin.max_health * 0.5)
	battlefield._on_board_changed()

	assert_eq(
		panel.get_node("Content/SelectedSection/HpLabel").text,
		tr("battle.unit_info.hp") % [warrior.health, warrior.max_health]
	)
	assert_eq(panel.get_node("Content/HoveredSection/WoundLabel").text, tr("battle.unit_info.wounded"))


func test_unit_info_panel_shows_empty_hint_when_nothing_selected_or_hovered() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield.grid._select_unit(null)

	var panel: Control = battlefield.unit_info_panel
	assert_true(panel.get_node("Content/EmptyLabel").visible)
	assert_false(panel.get_node("Content/HoveredSection").visible)
	assert_false(panel.get_node("Content/SelectedSection").visible)


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


## --- Music State Transitions (Task 3, docs/plans/2026-08-18-core-loop-and-
## engagement/08-audio-system-and-soundscape.md) --- entering a battle scene
## requests the tactical combat track (or the boss track for the Ogre fight);
## resolving the battle requests victory/defeat music. AudioManager.play_music()
## itself is exercised directly in tests/unit/test_audio_manager.gd -- these
## only prove Battlefield calls it with the right track id at the right time.

func test_entering_a_battle_requests_the_tactical_combat_music() -> void:
	GameSession.reset()
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()

	add_child_autofree(battlefield)

	assert_true(AudioManager.is_music_playing("music_battle"))


func test_entering_the_ogre_boss_battle_requests_the_boss_music() -> void:
	GameSession.reset()
	GameSession.selected_encounter = "obj_boss_borderlands_ogre"
	var battlefield: Node2D = BattlefieldScene.instantiate()

	add_child_autofree(battlefield)

	assert_true(AudioManager.is_music_playing("music_boss"))


func test_a_won_battle_requests_the_victory_music() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield._show_battle_result(true)

	assert_true(AudioManager.is_music_playing("music_victory"))


func test_a_lost_battle_requests_the_defeat_music() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield._show_battle_result(false)

	assert_true(AudioManager.is_music_playing("music_defeat"))


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


## MP write-back (docs/designs/campaign-loop.md: "battle aftermath writes the
## surviving Cleric's remaining MP back, clamped to cleric.mp_max"): a
## surviving Cleric's leftover battle MP overwrites its durable current MP,
## the same way health does above. A non-caster (Warrior) in the same party
## never gains an mp_current field from this write-back.
func test_victory_aftermath_persists_a_surviving_clerics_remaining_mp() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var cleric := GameSession.get_default_cleric("cleric_test", "Test Cleric")
	GameSession.adventurers.append(cleric)
	GameSession.assign_adventurer_to_selected_party("cleric_test")
	GameSession.depart_selected_party()
	GameSession.enter_encounter("goblin_camp")
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var cleric_unit = battlefield.grid._get_unit_by_adventurer_id("cleric_test")
	cleric_unit.mp_remaining = 1

	battlefield._apply_battle_outcome(true)

	assert_eq(GameSession.get_current_mp("cleric_test"), 1, "The surviving Cleric's leftover MP persists after victory")
	assert_false(
		GameSession.get_adventurer("warrior_001").has("mp_current"),
		"A non-caster survivor never gains an mp_current field from aftermath"
	)


## A dead Cleric owns no persisted MP record, the same as HP (docs/designs/
## campaign-loop.md): permadeath already erases the whole adventurer record
## (see resolve_battle_deaths()), so a Cleric reduced to 0 HP by battle's end
## must not resurrect an mp_current field anywhere -- the id is simply gone.
func test_a_dead_clerics_mp_does_not_survive_permadeath() -> void:
	GameSession.reset()
	GameSession.create_party()
	var cleric := GameSession.get_default_cleric("cleric_test", "Test Cleric")
	GameSession.adventurers.append(cleric)
	GameSession.assign_adventurer_to_selected_party("cleric_test")
	GameSession.depart_selected_party()
	GameSession.enter_encounter("goblin_camp")
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var cleric_unit = battlefield.grid._get_unit_by_adventurer_id("cleric_test")
	cleric_unit.mp_remaining = 1
	cleric_unit.health = 0

	battlefield._apply_battle_outcome(false)

	assert_true(GameSession.get_adventurer("cleric_test").is_empty(), "A 0 HP Cleric is permanently removed")
	assert_eq(GameSession.get_current_mp("cleric_test"), 0, "An unknown id's MP reads as 0, never an error")


## Superseded by permadeath (docs/plans/2026-08-18-core-loop-and-engagement/
## 02-permadeath-retreat-and-economy-floor.md): a unit reduced to 0 HP by
## battle's end is no longer floored back up to 1 -- it is permanently
## removed from the roster. is_battle_lost() (which _apply_battle_outcome(false)
## always follows in real play) requires every player unit to already be
## dead, so a defeat with a single-member party is always a full wipe.
func test_defeat_aftermath_permanently_removes_a_unit_that_reached_zero_health() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	GameSession.enter_encounter("goblin_camp")
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	battlefield.grid.units[0].health = 0

	battlefield._apply_battle_outcome(false)

	assert_true(
		GameSession.get_adventurer("warrior_001").is_empty(),
		"A unit reduced to 0 HP is permanently removed from the roster, not downed to 1 HP"
	)
	assert_eq(GameSession.get_selected_party().member_ids, [] as Array[String])


## The same permadeath rule holds for a unit that actually dies to a real
## enemy attack mid-battle, not just one whose health a test sets directly --
## regression coverage for the fact that try_attack_selected_unit() erases a
## defeated unit from grid.units immediately (see BattleController.
## defeated_player_health_by_id), so _persist_battle_aftermath() must still
## be able to learn about it from there.
func test_a_player_unit_killed_in_real_combat_is_permanently_removed_after_the_battle_resolves() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	var goblin = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	goblin.grid_position = warrior.grid_position + Vector2i(1, 0)
	goblin.damage_min = 999
	goblin.damage_max = 999
	battlefield.grid.selected_unit = goblin
	battlefield.grid.active_side = BattleControllerScript.Side.ENEMY
	battlefield.grid.hit_roll = func() -> float: return 0.0

	assert_true(battlefield.grid.try_attack_selected_unit(warrior.grid_position), "Test setup must actually land the kill")
	battlefield._apply_battle_outcome(false)

	assert_true(
		GameSession.get_adventurer("warrior_001").is_empty(),
		"A unit killed in real combat must be permanently removed once the battle resolves"
	)


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

	var perk_option: Button = battlefield.level_up.perk_options_container.get_node(
		"PerkOption_%s" % GameSession.WARRIOR_JUGGERNAUT_PERK_ID
	)
	perk_option.emit_signal("pressed")
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


## --- Step 3: action modes and action bar ------------------------------


func test_action_bar_contains_move_and_attack_buttons() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_true(battlefield.has_node("HUD/Margin/VBox/BottomPanel/BottomContent/BottomActionsRow/ActionBar"))
	# The Button.text scene property holds the untranslated key (matching
	# every other button/label in this scene, e.g. EndTurnButton's
	# "battle.end_turn") -- Godot's Control auto-translation resolves it to
	# the display string at render time, not eagerly on this raw property.
	assert_eq(battlefield.move_button.text, "battle.action.move")
	assert_eq(battlefield.attack_button.text, "battle.action.attack")
	assert_eq(
		battlefield.move_button.get_parent(), battlefield.attack_button.get_parent(),
		"Move and Attack buttons must share the ActionBar container"
	)


## Step 2 of docs/plans/2026-08-18-core-loop-and-engagement: the Retreat
## button sits to the left of Move/Attack on the same ActionBar and, through
## the real .tscn signal wiring (not a direct method call), invokes
## BattleController.try_retreat().
func test_action_bar_contains_a_retreat_button_left_of_move_and_attack() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(battlefield.retreat_button.text, "battle.action.retreat")
	assert_eq(
		battlefield.retreat_button.get_parent(), battlefield.move_button.get_parent(),
		"Retreat must share the ActionBar container with Move/Attack"
	)
	var action_bar: Node = battlefield.retreat_button.get_parent()
	var children := action_bar.get_children()
	assert_lt(
		children.find(battlefield.retreat_button), children.find(battlefield.move_button),
		"Retreat must be positioned to the left of Move"
	)
	assert_lt(
		children.find(battlefield.move_button), children.find(battlefield.attack_button),
		"Move must stay to the left of Attack"
	)


func test_clicking_retreat_button_invokes_try_retreat_through_the_real_signal_wiring() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var retreated: Array = []
	battlefield.grid.retreat_resolved.connect(func(results: Array) -> void: retreated.append(results))

	battlefield.retreat_button.emit_signal("pressed")

	assert_eq(retreated.size(), 1, "The real button-press wiring must invoke try_retreat()")


func test_clicking_move_button_activates_move_mode_and_highlights_it() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield.move_button.emit_signal("pressed")

	assert_eq(battlefield.grid.action_mode, BattleControllerScript.ActionMode.MOVE)
	assert_true(battlefield.move_button.button_pressed, "The Move button must visually highlight when active")
	assert_false(battlefield.attack_button.button_pressed)


func test_clicking_attack_button_activates_attack_mode_and_highlights_it() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield.attack_button.emit_signal("pressed")

	assert_eq(battlefield.grid.action_mode, BattleControllerScript.ActionMode.ATTACK)
	assert_true(battlefield.attack_button.button_pressed, "The Attack button must visually highlight when active")
	assert_false(battlefield.move_button.button_pressed)


## Mirrors what Godot's BaseButton actually does for a toggle_mode button on
## a real click: flip button_pressed unconditionally, then fire "pressed" --
## unlike the tests above, which call emit_signal("pressed") alone and so
## never exercise the native flip. That distinction matters here: repeat-
## clicking an already-active toggle button flips button_pressed back to
## false even though the app's own state (action_mode) does not change, and
## a naive handler that only resyncs on an actual mode change would leave
## that flip uncorrected. See _on_move_button_pressed()/_on_attack_button_
## pressed() in battlefield.gd.
func _native_toggle_click(button: Button) -> void:
	button.button_pressed = not button.button_pressed
	button.emit_signal("pressed")


func test_repeat_clicking_the_active_move_button_stays_highlighted() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	_native_toggle_click(battlefield.move_button)
	assert_eq(battlefield.grid.action_mode, BattleControllerScript.ActionMode.MOVE)
	assert_true(battlefield.move_button.button_pressed)

	# Godot's native toggle flips button_pressed back to false on this second
	# click. The action mode is already MOVE, so set_action_mode() itself
	# would no-op -- the button must still resync to highlighted regardless.
	_native_toggle_click(battlefield.move_button)

	assert_eq(
		battlefield.grid.action_mode, BattleControllerScript.ActionMode.MOVE,
		"A repeat click on the already-active Move button must not change the mode"
	)
	assert_true(
		battlefield.move_button.button_pressed,
		"The Move button must resync to highlighted even when set_action_mode() was a no-op"
	)


func test_repeat_clicking_the_active_attack_button_stays_highlighted() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	_native_toggle_click(battlefield.attack_button)
	assert_eq(battlefield.grid.action_mode, BattleControllerScript.ActionMode.ATTACK)
	assert_true(battlefield.attack_button.button_pressed)

	_native_toggle_click(battlefield.attack_button)

	assert_eq(
		battlefield.grid.action_mode, BattleControllerScript.ActionMode.ATTACK,
		"A repeat click on the already-active Attack button must not change the mode"
	)
	assert_true(
		battlefield.attack_button.button_pressed,
		"The Attack button must resync to highlighted even when set_action_mode() was a no-op"
	)


func test_selecting_a_unit_resets_the_action_bar_to_contextual() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	battlefield.attack_button.emit_signal("pressed")
	var warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])

	battlefield.grid._select_unit(warrior)

	assert_eq(battlefield.grid.action_mode, BattleControllerScript.ActionMode.CONTEXTUAL)
	assert_false(battlefield.move_button.button_pressed)
	assert_false(battlefield.attack_button.button_pressed)


func test_starting_a_new_turn_resets_the_action_bar_to_contextual() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	battlefield.enemy_turn_beat_seconds = 0.0
	add_child_autofree(battlefield)
	battlefield.grid.set_action_mode(BattleControllerScript.ActionMode.MOVE)

	battlefield._on_end_turn_pressed()
	while battlefield._enemy_turn_in_progress:
		await get_tree().process_frame

	assert_eq(battlefield.grid.action_mode, BattleControllerScript.ActionMode.CONTEXTUAL)
	assert_false(battlefield.move_button.button_pressed)


func test_move_and_attack_buttons_are_disabled_when_input_is_locked() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	battlefield._set_enemy_turn_in_progress(true)

	assert_true(battlefield.move_button.disabled)
	assert_true(battlefield.attack_button.disabled)

	battlefield._set_enemy_turn_in_progress(false)

	assert_false(battlefield.move_button.disabled)
	assert_false(battlefield.attack_button.disabled)


func test_attack_button_is_disabled_when_the_selected_unit_lacks_enough_ap() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.selected_unit
	warrior.action_points_remaining = 2
	battlefield._on_board_changed()

	assert_true(battlefield.attack_button.disabled, "2 AP is below the 3 AP basic-attack cost")
	assert_false(battlefield.move_button.disabled, "2 AP is still enough to move")


func test_move_button_is_disabled_when_the_selected_unit_has_no_action_points_left() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var warrior = battlefield.grid.selected_unit
	warrior.action_points_remaining = 0
	battlefield._on_board_changed()

	assert_true(battlefield.move_button.disabled)
	assert_true(battlefield.attack_button.disabled)


func test_move_mode_and_attack_mode_clicks_update_the_status_message() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var attacker = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
	var enemy = battlefield.grid.get_unit_at(BattleControllerScript.ENEMY_START_POSITIONS[0])
	enemy.grid_position = attacker.grid_position + Vector2i(1, 0)
	battlefield.grid.selected_unit = attacker
	battlefield.grid.set_action_mode(BattleControllerScript.ActionMode.MOVE)

	battlefield.grid._handle_tile_click(enemy.grid_position)

	assert_eq(battlefield.status.text, tr("battle.feedback.move_mode"))
	assert_eq(
		attacker.grid_position, BattleControllerScript.PLAYER_START_POSITIONS[0],
		"Move mode must not attack the enemy"
	)

	battlefield.grid.selected_unit = attacker
	battlefield.grid.set_action_mode(BattleControllerScript.ActionMode.ATTACK)
	battlefield.grid._handle_tile_click(Vector2i(5, 5))

	assert_eq(battlefield.status.text, tr("battle.feedback.attack_mode"))


## Step 5: top header title bar, full-width auto-scrolling log, and the
## Baldur's Gate inspired TopRow/BodyRow/BottomPanel layout integration.


func test_battle_title_shows_the_goblin_camp_encounter_name() -> void:
	GameSession.reset()
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(battlefield.get_node("%BattleTitleLabel").text, "Goblin Camp Battle")


func test_battle_title_shows_the_orc_outpost_encounter_name() -> void:
	GameSession.reset()
	GameSession.enter_encounter(GameSession.ORC_OUTPOST_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	assert_eq(battlefield.get_node("%BattleTitleLabel").text, "Orc Outpost Battle")


func test_battle_title_label_lives_in_the_top_row() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	var title_label: Label = battlefield.get_node("%BattleTitleLabel")
	assert_eq(title_label.get_parent(), battlefield.round_label.get_parent().get_parent())


## LogScroll must be the only child of its row so it stretches to the row's
## full width, matching the design contract's "Combat log spans full width
## above the action bar" acceptance criterion -- rather than splitting the
## row with a sibling (see test_enemy_health_list_lives_in_the_body_row_not_
## the_bottom_panel above for where that sibling went).
func test_combat_log_spans_the_full_width_of_its_row() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	var log_row: Node = battlefield.log_scroll.get_parent()
	assert_eq(
		log_row.get_child_count(), 1,
		"LogScroll must be the only child of its row so it spans the full bottom width"
	)


func test_appending_a_log_line_scrolls_the_log_to_the_bottom() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	for i in range(20):
		battlefield._append_log_line("Log line %d" % i)

	await get_tree().process_frame
	await get_tree().process_frame

	var scroll_bar: ScrollBar = battlefield.log_scroll.get_v_scroll_bar()
	assert_gt(scroll_bar.max_value, 0.0, "The log must actually overflow for this test to be meaningful")
	# A Range's scrollable ceiling is max_value minus its visible page (not
	# max_value itself, which is the full content height) -- Range's own
	# value setter already clamps to that, so this is the true "scrolled to
	# the bottom" position.
	assert_eq(
		battlefield.log_scroll.scroll_vertical,
		int(scroll_bar.max_value - scroll_bar.page),
		"Adding a log entry must auto-scroll LogScroll to the bottom"
	)


## Regression coverage for the full Step 5 layout migration: the header row
## (containing the new title) and the bottom panel (containing the now
## full-width log) must both stay clear of the 6x6 battle grid after at
## least one layout frame, at the project's supported viewport size.
func test_header_and_bottom_panel_never_overlap_the_battle_grid() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	await get_tree().process_frame
	await get_tree().process_frame

	var top_row: Control = battlefield.get_node("%BattleTitleLabel").get_parent()
	var bottom_panel: Control = battlefield.hint.get_parent().get_parent()
	var grid_top_edge: float = battlefield.grid.position.y
	var grid_bottom_edge: float = (
		battlefield.grid.position.y
		+ BattleControllerScript.GRID_HEIGHT * BattleControllerScript.TILE_SIZE
	)

	assert_true(
		top_row.get_global_rect().position.y + top_row.get_global_rect().size.y <= grid_top_edge,
		"The top header row must never grow tall enough to cover the battle grid"
	)
	assert_true(
		bottom_panel.get_global_rect().position.y >= grid_bottom_edge,
		"The bottom HUD panel must never grow tall enough to cover the battle grid"
	)


## Regression test: BottomContent is a VBoxContainer, where child file/tree
## order is rendering (top-to-bottom) order. The design contract (index.md's
## ASCII layout and its "Combat log spans full width above the action bar"
## acceptance criterion, plus this step's own plan) requires the log row
## above the action bar row, not below it.
func test_combat_log_row_sits_above_the_action_bar_row() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)

	var log_row: Node = battlefield.log_scroll.get_parent()
	var action_bar_row: Node = battlefield.move_button.get_parent().get_parent()

	assert_eq(
		log_row.get_parent(), action_bar_row.get_parent(),
		"LogScroll's row and the action bar row must be siblings within BottomContent"
	)
	assert_lt(
		log_row.get_index(), action_bar_row.get_index(),
		"The combat log row must sit above (render before) the action bar row in BottomContent"
	)


## Regression test: EnemyHealthScroll (a BodyRow column with no plan-specified
## slot -- see test_enemy_health_list_lives_in_the_body_row_not_the_bottom_
## panel above) must have a real width ceiling rather than growing with its
## content, since BodyRow's only flexible member is Spacer (Grid itself sits
## outside the HUD tree at a fixed position, so it never moves on its own).
## An unbounded EnemyHealthScroll steals width from Spacer; measured directly
## (see the debug instrumentation this test's assertions replace), that first
## shows up as UnitInfoPanel's left edge sliding into the grid's footprint --
## EnemyHealthScroll itself, being the rightmost column, only follows once
## the squeeze is severe enough. Checking that Spacer's rect still fully
## contains Grid's rect is the general invariant that actually guards against
## any BodyRow column (EnemyHealthScroll included) overrunning its budget, so
## that -- plus EnemyHealthScroll's own edge -- is what's asserted here.
## Forces content on the extreme end of what this column's fixed
## "%s: %d/%d HP" template can produce (very wide HP figures), deliberately
## far past any realistic in-game value, so the assertion exercises the
## column's actual configured ceiling rather than just today's real content.
func test_enemy_health_column_never_overlaps_the_battle_grid_even_with_wide_content() -> void:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	for unit in battlefield.grid.units:
		if unit.side == BattleControllerScript.Side.ENEMY:
			unit.max_health = 999999999
			unit.health = 999999999
	battlefield._update_health_labels()
	await get_tree().process_frame
	await get_tree().process_frame

	var enemy_health_scroll: Control = battlefield.enemy_health.get_parent()
	var spacer: Control = battlefield.portrait_panel.get_parent().get_node("Spacer")
	var grid_left_edge: float = battlefield.grid.position.x
	var grid_right_edge: float = (
		battlefield.grid.position.x
		+ BattleControllerScript.GRID_WIDTH * BattleControllerScript.TILE_SIZE
	)

	assert_true(
		spacer.get_global_rect().position.x <= grid_left_edge
		and spacer.get_global_rect().position.x + spacer.get_global_rect().size.x >= grid_right_edge,
		"BodyRow's flexible Spacer must still fully cover the grid's footprint -- if a fixed-width " +
		"column like EnemyHealthScroll grows unbounded, Spacer shrinks below the grid's width and " +
		"the columns after it (UnitInfoPanel, EnemyHealthScroll) slide left into the grid"
	)
	assert_true(
		enemy_health_scroll.get_global_rect().position.x >= grid_right_edge,
		"The enemy health column must never grow wide enough to encroach on the battle grid"
	)


## Step 2 of docs/plans/2026-08-18-core-loop-and-engagement: end-to-end
## Retreat aftermath. Follows testing.md's "waiting for a fire-and-forget
## coroutine" pattern -- enemy_turn_beat_seconds is zeroed and GameSession.
## selected_encounter (cleared only once GameManager.retreat_from_battle()
## -> GameSession.abandon_current_encounter() actually runs) is the settle
## sentinel.

func test_a_survived_retreat_persists_hp_loss_discards_loot_and_stays_on_the_encounter_tile() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	var encounter_position: Vector2i = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID).position
	GameSession.set_deployed_party_position(encounter_position)
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	battlefield.enemy_turn_beat_seconds = 0.0
	add_child_autofree(battlefield)
	# Fresh battle start positions put the lone warrior and the goblin at
	# Chebyshev distance 5 (the "mid" bucket): a 0.30 roll lands in
	# [0.20, 0.70) -> a 10% HP loss (1 of 10 max HP).
	battlefield.grid.retreat_roll = func() -> float: return 0.30

	battlefield.grid.try_retreat()
	var settle_frames := 0
	while GameSession.selected_encounter != "" and settle_frames < 30:
		await get_tree().process_frame
		settle_frames += 1

	assert_eq(GameSession.get_current_health("warrior_001"), 9, "10% of 10 max HP is 1 lost")
	assert_false(GameSession.is_encounter_complete(GameSession.GOBLIN_CAMP_ID), "Retreat leaves the encounter unconquered")
	assert_true(GameSession.has_deployed_party(), "A survived retreat keeps the party deployed, not sent home")
	assert_eq(GameSession.get_deployed_party_position(), encounter_position, "The party stays on the encounter tile")
	assert_eq(GameSession.battle_reward, 0, "Unbanked battle loot is discarded")


func test_a_full_wipe_from_retreats_own_risk_roll_routes_home_and_forfeits_gold_and_loot() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()
	GameSession.enter_encounter(GameSession.GOBLIN_CAMP_ID)
	var battlefield: Node2D = BattlefieldScene.instantiate()
	battlefield.enemy_turn_beat_seconds = 0.0
	add_child_autofree(battlefield)
	GameSession.gold = 40
	# 0.99 lands in the death region of every distance bucket.
	battlefield.grid.retreat_roll = func() -> float: return 0.99

	battlefield.grid.try_retreat()
	var settle_frames := 0
	while GameSession.selected_encounter != "" and settle_frames < 30:
		await get_tree().process_frame
		settle_frames += 1

	assert_true(
		GameSession.get_adventurer("warrior_001").is_empty(), "The unit died from the retreat's own risk roll"
	)
	assert_false(GameSession.has_deployed_party(), "A full wipe from retreat routes the party home")
	assert_eq(
		GameSession.get_deployed_party_position(), GameSession.STARTING_SETTLEMENT_WORLD_POSITION,
		"An undeployed party's position reads back as the settlement"
	)
	assert_eq(GameSession.gold, 0, "A wipe forfeits all gold")

