extends GutTest

const SellQuantityDialogScene := preload("res://scenes/ui/sell_quantity_dialog.tscn")


func _open(max_quantity: int, unit_price: int) -> Control:
	var dialog: Control = SellQuantityDialogScene.instantiate()
	add_child_autofree(dialog)
	dialog.show_for_item("shortsword_iron", "Iron Shortsword", max_quantity, unit_price)
	return dialog


func test_show_for_item_starts_at_quantity_one_and_is_visible() -> void:
	var dialog := _open(5, 10)

	assert_true(dialog.visible)
	assert_eq(dialog.get_node("Content/QuantityRow/QuantityInput").text, "1")
	assert_eq(dialog.get_node("Content/TotalLabel").text, tr("sell_quantity_dialog.total") % 10)


func test_plus_and_minus_buttons_adjust_quantity_and_clamp_to_the_stock_range() -> void:
	var dialog := _open(5, 10)

	dialog.get_node("Content/QuantityRow/PlusTenButton").emit_signal("pressed")
	assert_eq(dialog.get_node("Content/QuantityRow/QuantityInput").text, "5", "Clamped to max stock")

	dialog.get_node("Content/QuantityRow/MinusTenButton").emit_signal("pressed")
	assert_eq(dialog.get_node("Content/QuantityRow/QuantityInput").text, "1", "Clamped to a minimum of 1")

	dialog.get_node("Content/QuantityRow/PlusOneButton").emit_signal("pressed")
	assert_eq(dialog.get_node("Content/QuantityRow/QuantityInput").text, "2")

	dialog.get_node("Content/QuantityRow/MinusOneButton").emit_signal("pressed")
	assert_eq(dialog.get_node("Content/QuantityRow/QuantityInput").text, "1")


func test_all_button_sets_quantity_to_the_full_stock() -> void:
	var dialog := _open(5, 10)

	dialog.get_node("Content/AllButton").emit_signal("pressed")

	assert_eq(dialog.get_node("Content/QuantityRow/QuantityInput").text, "5")
	assert_eq(dialog.get_node("Content/TotalLabel").text, tr("sell_quantity_dialog.total") % 50)


func test_ok_emits_confirmed_with_the_item_id_and_chosen_quantity_then_hides() -> void:
	var dialog := _open(5, 10)
	dialog.get_node("Content/AllButton").emit_signal("pressed")
	watch_signals(dialog)

	dialog.get_node("Content/ButtonRow/OkButton").emit_signal("pressed")

	assert_signal_emitted_with_parameters(dialog, "confirmed", ["shortsword_iron", 5])
	assert_false(dialog.visible)


func test_cancel_hides_without_emitting_confirmed() -> void:
	var dialog := _open(5, 10)
	watch_signals(dialog)

	dialog.get_node("Content/ButtonRow/CancelButton").emit_signal("pressed")

	assert_signal_not_emitted(dialog, "confirmed")
	assert_false(dialog.visible)
