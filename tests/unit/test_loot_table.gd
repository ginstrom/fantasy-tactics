extends GutTest

const LootTableScene := preload("res://scenes/ui/loot_table.tscn")


func before_each() -> void:
	GameSession.reset()


func _open(show_sell: bool, show_equip: bool) -> Control:
	var loot_table: Control = LootTableScene.instantiate()
	add_child_autofree(loot_table)
	loot_table.configure(show_sell, show_equip)
	return loot_table


func _select_first_row(loot_table: Control) -> void:
	var tree: Tree = loot_table.get_node("Content/Table/Tree")
	var item := tree.get_root().get_first_child()
	item.select(0)
	tree.emit_signal("item_selected")


func test_empty_rows_shows_the_empty_label_and_hides_the_content() -> void:
	var loot_table := _open(true, true)

	loot_table.set_rows([] as Array[Dictionary])

	assert_true(loot_table.get_node("EmptyLabel").visible)
	assert_false(loot_table.get_node("Content").visible)


func test_rows_hide_the_empty_label_and_show_the_content() -> void:
	var loot_table := _open(false, false)

	loot_table.set_rows(GameSession.build_loot_rows({"shortsword_iron": 1}, {}))

	assert_false(loot_table.get_node("EmptyLabel").visible)
	assert_true(loot_table.get_node("Content").visible)


func test_view_button_starts_disabled_and_enables_once_a_row_is_selected() -> void:
	var loot_table := _open(true, true)
	loot_table.set_rows(GameSession.build_loot_rows({"shortsword_iron": 1}, {}))
	var view_button: Button = loot_table.get_node("Content/ViewButton")
	assert_true(view_button.disabled)

	_select_first_row(loot_table)

	assert_false(view_button.disabled)


func test_view_button_opens_the_detail_panel_for_the_selected_row() -> void:
	var loot_table := _open(true, true)
	loot_table.set_rows(GameSession.build_loot_rows({"shortsword_iron": 1}, {}))
	_select_first_row(loot_table)

	loot_table.get_node("Content/ViewButton").emit_signal("pressed")

	var detail_panel: Control = loot_table.get_node("LootDetailPanel")
	assert_true(detail_panel.visible)
	assert_eq(detail_panel.get_node("Content/NameLabel").text, "Iron Shortsword")


func test_double_clicking_a_row_opens_the_detail_panel_without_needing_view() -> void:
	var loot_table := _open(true, true)
	loot_table.set_rows(GameSession.build_loot_rows({"shortsword_iron": 1}, {}))
	var tree: Tree = loot_table.get_node("Content/Table/Tree")
	var item := tree.get_root().get_first_child()
	item.select(0)

	tree.emit_signal("item_activated")

	assert_true(loot_table.get_node("LootDetailPanel").visible)


func test_detail_panel_equip_button_hidden_on_mana_crystal_rows() -> void:
	var loot_table := _open(false, true)
	loot_table.set_rows(GameSession.build_loot_rows({}, {1: 2}))
	_select_first_row(loot_table)

	loot_table.get_node("Content/ViewButton").emit_signal("pressed")

	assert_false(loot_table.get_node("LootDetailPanel/Content/ButtonRow/EquipButton").visible)


func test_equip_requested_from_the_detail_panel_bubbles_up_with_the_item_id() -> void:
	var loot_table := _open(false, true)
	loot_table.set_rows(GameSession.build_loot_rows({"shortsword_iron": 1}, {}))
	_select_first_row(loot_table)
	loot_table.get_node("Content/ViewButton").emit_signal("pressed")
	watch_signals(loot_table)

	loot_table.get_node("LootDetailPanel/Content/ButtonRow/EquipButton").emit_signal("pressed")

	assert_signal_emitted_with_parameters(loot_table, "equip_requested", ["shortsword_iron"])


func test_sell_button_absent_without_a_trading_post_and_present_with_one_via_the_detail_panel() -> void:
	GameSession.banked_gear = {"shortsword_iron": 1}
	var loot_table := _open(true, false)
	loot_table.set_rows(GameSession.build_loot_rows(GameSession.banked_gear, {}))
	_select_first_row(loot_table)
	loot_table.get_node("Content/ViewButton").emit_signal("pressed")

	assert_false(loot_table.get_node("LootDetailPanel/Content/ButtonRow/SellButton").visible, "No Trading Post yet")

	GameSession.has_trading_post = true
	loot_table.get_node("LootDetailPanel")._on_close_button_pressed()
	loot_table.get_node("Content/ViewButton").emit_signal("pressed")

	assert_true(loot_table.get_node("LootDetailPanel/Content/ButtonRow/SellButton").visible)


func test_selling_a_single_unit_row_from_the_detail_panel_sells_it_immediately_without_a_dialog() -> void:
	GameSession.has_trading_post = true
	GameSession.banked_gear = {"shortsword_iron": 1}
	var loot_table := _open(true, false)
	loot_table.set_rows(GameSession.build_loot_rows(GameSession.banked_gear, {}))
	_select_first_row(loot_table)
	loot_table.get_node("Content/ViewButton").emit_signal("pressed")

	loot_table.get_node("LootDetailPanel/Content/ButtonRow/SellButton").emit_signal("pressed")

	assert_eq(GameSession.banked_gear.shortsword_iron, 0)
	assert_eq(GameSession.gold, 10)
	assert_false(loot_table.get_node("SellQuantityDialog").visible)


func test_selling_a_multi_unit_row_from_the_detail_panel_opens_the_quantity_dialog_without_selling() -> void:
	GameSession.has_trading_post = true
	GameSession.banked_gear = {"shortsword_iron": 3}
	var loot_table := _open(true, false)
	loot_table.set_rows(GameSession.build_loot_rows(GameSession.banked_gear, {}))
	_select_first_row(loot_table)
	loot_table.get_node("Content/ViewButton").emit_signal("pressed")

	loot_table.get_node("LootDetailPanel/Content/ButtonRow/SellButton").emit_signal("pressed")

	assert_eq(GameSession.banked_gear.shortsword_iron, 3, "Nothing sold until the dialog is confirmed")
	assert_true(loot_table.get_node("SellQuantityDialog").visible)


func test_confirming_the_quantity_dialog_sells_that_many_and_emits_sold() -> void:
	GameSession.has_trading_post = true
	GameSession.banked_gear = {"shortsword_iron": 3}
	var loot_table := _open(true, false)
	loot_table.set_rows(GameSession.build_loot_rows(GameSession.banked_gear, {}))
	_select_first_row(loot_table)
	loot_table.get_node("Content/ViewButton").emit_signal("pressed")
	loot_table.get_node("LootDetailPanel/Content/ButtonRow/SellButton").emit_signal("pressed")
	watch_signals(loot_table)

	loot_table.get_node("SellQuantityDialog").confirmed.emit("shortsword_iron", 2)

	assert_eq(GameSession.banked_gear.shortsword_iron, 1)
	assert_eq(GameSession.gold, 20)
	assert_signal_emitted(loot_table, "sold")


func test_a_selection_that_no_longer_exists_after_set_rows_disables_the_view_button() -> void:
	var loot_table := _open(true, true)
	loot_table.set_rows(GameSession.build_loot_rows({"shortsword_iron": 1}, {}))
	_select_first_row(loot_table)
	assert_false(loot_table.get_node("Content/ViewButton").disabled)

	loot_table.set_rows([] as Array[Dictionary])
	loot_table.set_rows(GameSession.build_loot_rows({"dagger_iron": 1}, {}))

	assert_true(loot_table.get_node("Content/ViewButton").disabled)
