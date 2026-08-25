extends GutTest

const ItemDetailCardScene := preload("res://scenes/ui/item_detail_card.tscn")


func before_each() -> void:
	GameSession.reset()


func _open_card(item_id: String, row_data: Dictionary = {}, show_buy: bool = false, show_sell: bool = false, show_equip: bool = false) -> Control:
	var card: Control = ItemDetailCardScene.instantiate()
	add_child_autofree(card)
	card.configure(show_buy, show_sell, show_equip)
	card.set_item(item_id, row_data)
	return card


func test_item_detail_card_displays_weapon_stats() -> void:
	var card := _open_card("shortsword_iron", {"id": "shortsword_iron", "name": "Iron Shortsword", "type": "Weapon", "count": 1, "price": 10})

	var name_label: Label = card.get_node("%NameLabel")
	var stats_label: Label = card.get_node("%StatsLabel")
	var type_label: Label = card.get_node("%TypeLabel")

	assert_eq(name_label.text, "Iron Shortsword")
	assert_string_contains(stats_label.text, "1–6")
	assert_string_contains(type_label.text, "Weapon")


func test_item_detail_card_displays_armor_stats() -> void:
	var card := _open_card("leather_armor", {"id": "leather_armor", "name": "Leather Armor", "type": "Armor", "count": 1, "price": 5})

	var name_label: Label = card.get_node("%NameLabel")
	var stats_label: Label = card.get_node("%StatsLabel")

	assert_eq(name_label.text, "Leather Armor")
	assert_string_contains(stats_label.text, "10%")


func test_item_detail_card_displays_potion_stats() -> void:
	var card := _open_card("greater_healing_potion", {"id": "greater_healing_potion", "name": "Greater Healing Potion", "type": "Potion", "count": 1, "price": 0})

	var stats_label: Label = card.get_node("%StatsLabel")
	assert_string_contains(stats_label.text, "2–8")


func test_item_detail_card_displays_mana_crystal() -> void:
	var card := _open_card("mana_crystal_1", {"id": "mana_crystal_1", "name": "Mana Crystal (Tier 1)", "type": "Mana Crystal", "count": 2, "price": 5})

	var name_label: Label = card.get_node("%NameLabel")
	var type_label: Label = card.get_node("%TypeLabel")

	assert_eq(name_label.text, "Mana Crystal (Tier 1)")
	assert_string_contains(type_label.text, "Mana Crystal")


func test_buy_button_is_shown_in_buy_mode_and_enabled_when_affordable() -> void:
	GameSession.gold = 100
	var card := _open_card("shortsword_iron", {}, true, false, false)

	var buy_button: Button = card.get_node("%BuyButton")
	assert_true(buy_button.visible)
	assert_false(buy_button.disabled)


func test_buy_button_is_disabled_when_unaffordable() -> void:
	GameSession.gold = 0
	var card := _open_card("shortsword_iron", {}, true, false, false)

	var buy_button: Button = card.get_node("%BuyButton")
	assert_true(buy_button.visible)
	assert_true(buy_button.disabled)


func test_pressing_buy_button_emits_buy_requested() -> void:
	GameSession.gold = 100
	var card := _open_card("shortsword_iron", {}, true, false, false)
	watch_signals(card)

	var buy_button: Button = card.get_node("%BuyButton")
	buy_button.emit_signal("pressed")

	assert_signal_emitted_with_parameters(card, "buy_requested", ["shortsword_iron"])


func test_sell_button_is_shown_when_configured_and_emits_sell_requested() -> void:
	GameSession.has_trading_post = true
	GameSession.banked_gear = {"shortsword_iron": 1}
	var card := _open_card("shortsword_iron", {"id": "shortsword_iron", "name": "Iron Shortsword", "count": 1, "price": 10}, false, true, false)
	watch_signals(card)

	var sell_button: Button = card.get_node("%SellButton")
	assert_true(sell_button.visible)
	assert_false(sell_button.disabled)

	sell_button.emit_signal("pressed")
	assert_signal_emitted_with_parameters(card, "sell_requested", ["shortsword_iron"])



func test_equip_button_is_shown_on_gear_and_hidden_on_mana_crystals() -> void:
	var gear_card := _open_card("shortsword_iron", {"id": "shortsword_iron", "name": "Iron Shortsword"}, false, false, true)
	var gear_equip: Button = gear_card.get_node("%EquipButton")
	assert_true(gear_equip.visible)

	var crystal_card := _open_card("mana_crystal_1", {"id": "mana_crystal_1", "name": "Mana Crystal (Tier 1)"}, false, false, true)
	var crystal_equip: Button = crystal_card.get_node("%EquipButton")
	assert_false(crystal_equip.visible)


func test_pressing_equip_button_emits_equip_requested() -> void:
	var card := _open_card("shortsword_iron", {"id": "shortsword_iron", "name": "Iron Shortsword"}, false, false, true)
	watch_signals(card)

	var equip_button: Button = card.get_node("%EquipButton")
	equip_button.emit_signal("pressed")

	assert_signal_emitted_with_parameters(card, "equip_requested", ["shortsword_iron"])


func test_not_found_label_shown_for_invalid_item() -> void:
	var card := _open_card("unknown_item_id")

	var not_found_label: Label = card.get_node("%NotFoundLabel")
	var buy_button: Button = card.get_node("%BuyButton")

	assert_true(not_found_label.visible)
	assert_false(buy_button.visible)
