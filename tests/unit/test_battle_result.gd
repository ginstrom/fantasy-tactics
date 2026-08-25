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


func test_view_button_opens_the_selected_level_up_card_navigator() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen = _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1,
		"leveled_up_ids": [GameSession.WARRIOR_ID],
	})

	var view_button: Button = screen.level_up_list.get_node("Row_%s/ViewButton_%s" % [GameSession.WARRIOR_ID, GameSession.WARRIOR_ID])
	view_button.emit_signal("pressed")

	assert_true(screen.card_navigator.visible, "View button must open the CardNavigator")
	assert_eq(screen.card_navigator.get_current_id(), GameSession.WARRIOR_ID)
	assert_eq(screen.level_up.adventurer_id, GameSession.WARRIOR_ID)


func test_multiple_leveled_units_wrap_through_card_navigator_and_perk_guards_ok_button() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var scout := GameSession.get_default_scout("scout_test", "Test Scout")
	GameSession.adventurers.append(scout)
	GameSession.assign_adventurer_to_selected_party("scout_test")

	# Award enough XP for both to reach level 2 (earns perk choice for both)
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 40.0)
	assert_true(GameSession.is_perk_choice_pending(GameSession.WARRIOR_ID))
	assert_true(GameSession.is_perk_choice_pending("scout_test"))

	var screen = _open_battle_result({
		"kills_by_type": {}, "total_xp": 40.0, "party_member_count": 2,
		"leveled_up_ids": [GameSession.WARRIOR_ID, "scout_test"],
	})

	# Outcome final OK button must be disabled because both units have pending perks
	assert_true(screen.ok_button.disabled, "OK button must be disabled while perk choices are pending")
	screen.ok_button.emit_signal("pressed")
	assert_true(screen.visible, "Battle outcome must not finish while required perks are pending")

	# Open the second unit's card directly
	var view_scout: Button = screen.level_up_list.get_node("Row_scout_test/ViewButton_scout_test")
	view_scout.emit_signal("pressed")

	assert_true(screen.card_navigator.visible)
	assert_eq(screen.card_navigator.get_current_id(), "scout_test")
	assert_eq(screen.card_navigator.count_label.text, "2 of 2")
	assert_eq(screen.level_up.name_label.text, "Test Scout")
	assert_true(screen.level_up.continue_button.disabled, "Continue must stay disabled while perk is pending")

	# Wrap next to warrior
	screen.card_navigator.next()
	assert_eq(screen.card_navigator.get_current_id(), GameSession.WARRIOR_ID, "Next wraps to first unit")
	assert_eq(screen.card_navigator.count_label.text, "1 of 2")
	assert_eq(screen.level_up.name_label.text, "Warrior")

	# Close navigator via Escape without choosing perk
	screen.card_navigator._unhandled_input(_escape_event())
	assert_false(screen.card_navigator.visible, "Escape closes card navigator")
	assert_true(screen.visible, "Returns to battle outcome modal")
	assert_true(screen.ok_button.disabled, "OK button still disabled because warrior & scout are unresolved")

	# Open warrior card and choose warrior's perk
	var view_warrior: Button = screen.level_up_list.get_node("Row_%s/ViewButton_%s" % [GameSession.WARRIOR_ID, GameSession.WARRIOR_ID])
	view_warrior.emit_signal("pressed")

	var warrior_perk_option: Button = screen.level_up.perk_options_container.get_node(
		"PerkOption_%s" % GameSession.WARRIOR_JUGGERNAUT_PERK_ID
	)
	warrior_perk_option.emit_signal("pressed")
	assert_false(screen.level_up.continue_button.disabled, "Continue enabled after perk choice")
	assert_false(GameSession.is_perk_choice_pending(GameSession.WARRIOR_ID))

	# Close navigator
	screen.card_navigator.close()
	assert_false(screen.card_navigator.visible)
	# Scout is STILL pending, so OK button must STILL be disabled
	assert_true(screen.ok_button.disabled, "OK button remains disabled while scout perk is pending")

	# Open scout, choose perk, and close
	view_scout.emit_signal("pressed")
	var scout_perk_option: Button = screen.level_up.perk_options_container.get_node(
		"PerkOption_%s" % GameSession.SCOUT_QUICKDRAW_PERK_ID
	)
	scout_perk_option.emit_signal("pressed")
	assert_false(GameSession.is_perk_choice_pending("scout_test"))
	screen.card_navigator.close()

	# Now BOTH are resolved! OK button must be enabled
	assert_false(screen.ok_button.disabled, "OK button must be enabled once all perks are resolved")

	watch_signals(screen)
	screen.ok_button.emit_signal("pressed")
	assert_signal_emitted(screen, "dismissed")
	assert_false(screen.visible)


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

	var navigator: CardNavigator = screen.loot_table.get_node("CardNavigator")
	assert_true(navigator.visible)
	var card: ItemDetailCard = navigator.content_container.get_child(0)
	assert_false(card.get_node("%EquipButton").visible)
	assert_false(card.get_node("%SellButton").visible)



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


func test_battle_result_level_up_card_navigator_closes_safely_if_leveled_id_removed() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen = _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1,
		"leveled_up_ids": [GameSession.WARRIOR_ID],
	})

	var view_button: Button = screen.level_up_list.get_node("Row_%s/ViewButton_%s" % [GameSession.WARRIOR_ID, GameSession.WARRIOR_ID])
	view_button.emit_signal("pressed")

	assert_true(screen.card_navigator.visible)

	screen.summary = {"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": []}
	screen._refresh()

	assert_false(screen.card_navigator.visible, "CardNavigator must close if active unit is no longer in leveled_up_ids")
