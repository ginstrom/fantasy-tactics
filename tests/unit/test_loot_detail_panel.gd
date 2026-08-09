extends GutTest

const LootDetailPanelScene := preload("res://scenes/ui/loot_detail_panel.tscn")


func before_each() -> void:
	GameSession.reset()


func _open(show_sell: bool, show_equip: bool, row: Dictionary) -> Control:
	var panel: Control = LootDetailPanelScene.instantiate()
	add_child_autofree(panel)
	panel.show_for_row(row, show_sell, show_equip)
	return panel


func test_show_for_row_displays_name_and_detail_and_becomes_visible() -> void:
	var panel := _open(
		false, false, {"id": "shortsword_iron", "name": "Iron Shortsword", "type": "Weapon", "count": 3, "price": 10}
	)

	assert_true(panel.visible)
	assert_eq(panel.get_node("Content/NameLabel").text, "Iron Shortsword")
	assert_eq(panel.get_node("Content/DetailLabel").text, tr("loot_detail_panel.detail") % ["Weapon", 3, 10])


func test_sell_button_hidden_without_trading_post_and_shown_with_one() -> void:
	var row := {"id": "shortsword_iron", "name": "Iron Shortsword", "type": "Weapon", "count": 3, "price": 10}
	var panel := _open(true, false, row)
	assert_false(panel.get_node("Content/ButtonRow/SellButton").visible)

	GameSession.has_trading_post = true
	panel.show_for_row(row, true, false)

	assert_true(panel.get_node("Content/ButtonRow/SellButton").visible)


func test_sell_button_hidden_when_show_sell_is_false() -> void:
	GameSession.has_trading_post = true
	var panel := _open(
		false, true, {"id": "shortsword_iron", "name": "Iron Shortsword", "type": "Weapon", "count": 1, "price": 10}
	)

	assert_false(panel.get_node("Content/ButtonRow/SellButton").visible)


func test_equip_button_hidden_on_mana_crystal_rows() -> void:
	var panel := _open(
		false, true, {"id": "mana_crystal_1", "name": "Mana Crystal (Tier 1)", "type": "Mana Crystal", "count": 2, "price": 5}
	)

	assert_false(panel.get_node("Content/ButtonRow/EquipButton").visible)


func test_equip_button_shown_on_gear_rows_when_configured() -> void:
	var panel := _open(
		false, true, {"id": "shortsword_iron", "name": "Iron Shortsword", "type": "Weapon", "count": 1, "price": 10}
	)

	assert_true(panel.get_node("Content/ButtonRow/EquipButton").visible)


func test_pressing_sell_hides_the_panel_and_emits_sell_requested() -> void:
	GameSession.has_trading_post = true
	var panel := _open(
		true, false, {"id": "shortsword_iron", "name": "Iron Shortsword", "type": "Weapon", "count": 1, "price": 10}
	)
	watch_signals(panel)

	panel.get_node("Content/ButtonRow/SellButton").emit_signal("pressed")

	assert_false(panel.visible)
	assert_signal_emitted_with_parameters(panel, "sell_requested", ["shortsword_iron"])


func test_pressing_equip_hides_the_panel_and_emits_equip_requested() -> void:
	var panel := _open(
		false, true, {"id": "shortsword_iron", "name": "Iron Shortsword", "type": "Weapon", "count": 1, "price": 10}
	)
	watch_signals(panel)

	panel.get_node("Content/ButtonRow/EquipButton").emit_signal("pressed")

	assert_false(panel.visible)
	assert_signal_emitted_with_parameters(panel, "equip_requested", ["shortsword_iron"])


func test_pressing_close_hides_the_panel_and_emits_closed() -> void:
	var panel := _open(
		false, false, {"id": "shortsword_iron", "name": "Iron Shortsword", "type": "Weapon", "count": 1, "price": 10}
	)
	watch_signals(panel)

	panel.get_node("Content/CloseButton").emit_signal("pressed")

	assert_false(panel.visible)
	assert_signal_emitted(panel, "closed")
