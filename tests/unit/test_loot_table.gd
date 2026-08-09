extends GutTest

const LootTableScene := preload("res://scenes/ui/loot_table.tscn")


func before_each() -> void:
	GameSession.reset()


func _open(show_sell: bool, show_equip: bool) -> Control:
	var loot_table: Control = LootTableScene.instantiate()
	add_child_autofree(loot_table)
	loot_table.configure(show_sell, show_equip)
	return loot_table


func test_empty_rows_shows_the_empty_label_and_hides_the_table() -> void:
	var loot_table := _open(true, true)

	loot_table.set_rows([] as Array[Dictionary])

	assert_true(loot_table.get_node("EmptyLabel").visible)
	assert_false(loot_table.get_node("Table").visible)


func test_rows_hide_the_empty_label_and_show_the_table() -> void:
	var loot_table := _open(false, false)

	loot_table.set_rows(GameSession.build_loot_rows({"shortsword_iron": 1}, {}))

	assert_false(loot_table.get_node("EmptyLabel").visible)
	assert_true(loot_table.get_node("Table").visible)


func test_equip_button_is_hidden_on_mana_crystal_rows_and_shown_on_gear_rows() -> void:
	var loot_table := _open(false, true)
	loot_table.set_rows(GameSession.build_loot_rows({"shortsword_iron": 1}, {1: 2}))

	var tree: Tree = loot_table.get_node("Table/Tree")
	var gear_item := tree.get_root().get_first_child()
	var crystal_item := gear_item.get_next()
	# Columns with show_sell=false, show_equip=true: name=0, type=1, count=2, price=3, equip=4.
	assert_eq(gear_item.get_button_count(4), 1)
	assert_eq(crystal_item.get_button_count(4), 0)


func test_equip_button_emits_equip_requested_with_the_item_id() -> void:
	var loot_table := _open(false, true)
	loot_table.set_rows(GameSession.build_loot_rows({"shortsword_iron": 1}, {}))
	watch_signals(loot_table)
	var tree: Tree = loot_table.get_node("Table/Tree")
	var item := tree.get_root().get_first_child()

	tree.emit_signal("button_clicked", item, 4, item.get_button_id(4, 0), MOUSE_BUTTON_LEFT)

	assert_signal_emitted_with_parameters(loot_table, "equip_requested", ["shortsword_iron"])


func test_sell_column_is_absent_without_a_trading_post_and_present_with_one() -> void:
	var loot_table := _open(true, false)
	loot_table.set_rows(GameSession.build_loot_rows({"shortsword_iron": 1}, {}))
	var tree: Tree = loot_table.get_node("Table/Tree")
	# Columns with show_sell=true, show_equip=false: name=0, type=1, count=2, price=3, sell=4.
	assert_eq(tree.get_root().get_first_child().get_button_count(4), 0, "No Trading Post yet")

	GameSession.has_trading_post = true
	loot_table.set_rows(GameSession.build_loot_rows({"shortsword_iron": 1}, {}))

	assert_eq(tree.get_root().get_first_child().get_button_count(4), 1)


func test_pressing_sell_on_a_single_unit_row_sells_it_immediately_without_a_dialog() -> void:
	GameSession.has_trading_post = true
	GameSession.banked_gear = {"shortsword_iron": 1}
	var loot_table := _open(true, false)
	loot_table.set_rows(GameSession.build_loot_rows(GameSession.banked_gear, {}))
	var tree: Tree = loot_table.get_node("Table/Tree")
	var item := tree.get_root().get_first_child()

	tree.emit_signal("button_clicked", item, 4, item.get_button_id(4, 0), MOUSE_BUTTON_LEFT)

	assert_eq(GameSession.banked_gear.shortsword_iron, 0)
	assert_eq(GameSession.gold, 10)
	assert_false(loot_table.get_node("SellQuantityDialog").visible)


func test_pressing_sell_on_a_multi_unit_row_opens_the_quantity_dialog_without_selling() -> void:
	GameSession.has_trading_post = true
	GameSession.banked_gear = {"shortsword_iron": 3}
	var loot_table := _open(true, false)
	loot_table.set_rows(GameSession.build_loot_rows(GameSession.banked_gear, {}))
	var tree: Tree = loot_table.get_node("Table/Tree")
	var item := tree.get_root().get_first_child()

	tree.emit_signal("button_clicked", item, 4, item.get_button_id(4, 0), MOUSE_BUTTON_LEFT)

	assert_eq(GameSession.banked_gear.shortsword_iron, 3, "Nothing sold until the dialog is confirmed")
	assert_true(loot_table.get_node("SellQuantityDialog").visible)


func test_confirming_the_quantity_dialog_sells_that_many_and_emits_sold() -> void:
	GameSession.has_trading_post = true
	GameSession.banked_gear = {"shortsword_iron": 3}
	var loot_table := _open(true, false)
	loot_table.set_rows(GameSession.build_loot_rows(GameSession.banked_gear, {}))
	var tree: Tree = loot_table.get_node("Table/Tree")
	var item := tree.get_root().get_first_child()
	tree.emit_signal("button_clicked", item, 4, item.get_button_id(4, 0), MOUSE_BUTTON_LEFT)
	watch_signals(loot_table)

	loot_table.get_node("SellQuantityDialog").confirmed.emit("shortsword_iron", 2)

	assert_eq(GameSession.banked_gear.shortsword_iron, 1)
	assert_eq(GameSession.gold, 20)
	assert_signal_emitted(loot_table, "sold")
