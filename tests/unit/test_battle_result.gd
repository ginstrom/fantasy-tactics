extends GutTest

const BattleResultScene := preload("res://scenes/ui/battle_result.tscn")
const UiTestHelpers := preload("res://tests/unit/ui_test_helpers.gd")


func _escape_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event


func before_each() -> void:
	GameSession.reset()
	GameManager.battle_result_summary = {}


func after_each() -> void:
	GameManager.battle_result_summary = {}


func _open_battle_result(summary: Dictionary) -> Variant:
	GameManager.battle_result_summary = summary
	var scene: PackedScene = load("res://scenes/ui/battle_result.tscn")
	var screen = scene.instantiate()
	add_child_autofree(screen)
	return screen


func test_shows_kills_grouped_by_type() -> void:
	var screen = _open_battle_result({
		"kills_by_type": {"Goblin": 2, "Orc": 1}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": [],
	})

	assert_true(
		screen.kills_label.text.contains("Goblin x2")
		and screen.kills_label.text.contains("Orc x1")
	)


func test_shows_no_kills_message_when_nothing_was_killed() -> void:
	var screen = _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": [],
	})

	assert_eq(screen.kills_label.text, tr("battle_result.no_kills"))


func test_shows_total_and_per_member_xp() -> void:
	var screen = _open_battle_result({
		"kills_by_type": {}, "total_xp": 20.0, "party_member_count": 2, "leveled_up_ids": [],
	})

	assert_eq(screen.xp_label.text, tr("battle_result.xp") % [20, 10])


func test_hides_the_leveled_up_section_when_nobody_leveled_up() -> void:
	var screen = _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": [],
	})

	assert_false(screen.level_up_section.visible)


func test_shows_the_leveled_up_members_with_view_action_when_present() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen = _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1,
		"leveled_up_ids": [GameSession.WARRIOR_ID],
	})

	assert_true(screen.level_up_section.visible)
	var view_button: Button = screen.level_up_list.get_node_or_null("Row_%s/ViewButton_%s" % [GameSession.WARRIOR_ID, GameSession.WARRIOR_ID])
	assert_not_null(view_button, "Each leveled adventurer must have a View button")
	assert_eq(view_button.text, tr("battle_result.view"))


func test_view_button_opens_the_selected_level_up_modal() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen = _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1,
		"leveled_up_ids": [GameSession.WARRIOR_ID],
	})

	var view_button: Button = screen.level_up_list.get_node("Row_%s/ViewButton_%s" % [GameSession.WARRIOR_ID, GameSession.WARRIOR_ID])
	view_button.emit_signal("pressed")

	assert_true(screen.level_up.visible, "View button must open the LevelUp modal")
	assert_eq(screen.level_up.adventurer_id, GameSession.WARRIOR_ID)


func test_required_perk_selection_gates_level_up_continue_and_resolving_returns_to_outcome() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 49.0)
	assert_true(GameSession.is_perk_choice_pending(GameSession.WARRIOR_ID))

	var screen = _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1,
		"leveled_up_ids": [GameSession.WARRIOR_ID],
	})

	var view_button: Button = screen.level_up_list.get_node("Row_%s/ViewButton_%s" % [GameSession.WARRIOR_ID, GameSession.WARRIOR_ID])
	view_button.emit_signal("pressed")

	assert_true(screen.level_up.visible)
	assert_true(screen.level_up.continue_button.disabled, "Continue must stay disabled while perk choice is pending")

	# Escape should also be refused when perk is pending
	screen.level_up._unhandled_input(_escape_event())
	assert_true(screen.level_up.visible, "Escape must not dismiss LevelUp while perk is pending")

	var perk_option: Button = screen.level_up.perk_options_container.get_node(
		"PerkOption_%s" % GameSession.WARRIOR_JUGGERNAUT_PERK_ID
	)
	perk_option.emit_signal("pressed")

	assert_false(screen.level_up.continue_button.disabled, "Continue must enable once perk is chosen")
	screen.level_up.continue_button.emit_signal("pressed")

	assert_false(screen.level_up.visible, "Resolving LevelUp modal must close it")
	assert_true(screen.visible, "Closing LevelUp modal must return to Battle Outcome modal")


func test_shows_the_battles_gold() -> void:
	var screen = _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": [],
		"loot_gold": 5,
	})

	assert_eq(screen.gold_label.text, tr("battle_result.gold") % 5)


func test_shows_this_battles_loot_as_a_table() -> void:
	var screen = _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": [],
		"loot_gear_counts": {"shortsword_iron": 1}, "loot_mana_crystal_counts": {1: 2},
	})
	var tree: Tree = screen.loot_table.get_node("Content/Table/Tree")

	assert_eq(UiTestHelpers.tree_row_values(tree, 0), ["Iron Shortsword", "Mana Crystal (Tier 1)"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 2), ["1", "2"])


## Columns with show_sell=false, show_equip=false: name=0, type=1,
## count=2, price=3 -- 4 total, no Sell or Equip column exists.
func test_loot_table_has_neither_a_sell_nor_an_equip_action() -> void:
	var screen = _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": [],
		"loot_gear_counts": {"shortsword_iron": 1},
	})
	var tree: Tree = screen.loot_table.get_node("Content/Table/Tree")
	var item := tree.get_root().get_first_child()
	item.select(0)
	tree.emit_signal("item_selected")
	screen.loot_table.get_node("Content/ViewButton").emit_signal("pressed")

	var detail_panel: Control = screen.loot_table.get_node("LootDetailPanel")
	assert_true(detail_panel.visible)
	assert_false(detail_panel.get_node("Content/ButtonRow/EquipButton").visible)
	assert_false(detail_panel.get_node("Content/ButtonRow/SellButton").visible)


func test_ok_button_emits_dismissed_signal_and_clears_summary() -> void:
	var screen = _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": [],
	})
	watch_signals(screen)

	screen.ok_button.emit_signal("pressed")

	assert_signal_emit_count(screen, "dismissed", 1, "OK button must emit dismissed signal")
	assert_false(screen.visible, "OK button must close the modal")
	assert_eq(GameManager.battle_result_summary, {}, "OK button must clear the summary")


func test_escape_dismisses_the_outcome_modal() -> void:
	var screen = _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": [],
	})
	watch_signals(screen)

	screen._unhandled_input(_escape_event())

	assert_signal_emit_count(screen, "dismissed", 1, "ui_cancel must emit dismissed signal")
	assert_false(screen.visible, "ui_cancel must close the modal")
