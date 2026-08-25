extends GutTest

const CardNavigatorScene := preload("res://scenes/ui/card_navigator.tscn")


func _escape_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event


func test_navigator_blocks_underlying_mouse_input() -> void:
	var root := Control.new()
	root.custom_minimum_size = Vector2(1280, 720)
	root.size = Vector2(1280, 720)
	add_child_autofree(root)

	var underlying_button := Button.new()
	underlying_button.position = Vector2(100, 100)
	underlying_button.size = Vector2(120, 40)
	root.add_child(underlying_button)

	var clicked := false
	underlying_button.pressed.connect(func(): clicked = true)

	var navigator: CardNavigator = CardNavigatorScene.instantiate()
	root.add_child(navigator)

	assert_eq(navigator.mouse_filter, Control.MOUSE_FILTER_STOP, "CardNavigator root must block mouse input")
	var dim: ColorRect = navigator.get_node("Dim")
	assert_eq(dim.mouse_filter, Control.MOUSE_FILTER_STOP, "Dim backdrop must block mouse input")

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(110, 110)
	root.get_viewport().push_input(click, true)

	assert_false(clicked, "Navigator backdrop must intercept clicks and prevent underlying button from receiving input")


func test_navigator_panel_is_centered() -> void:
	var navigator: CardNavigator = CardNavigatorScene.instantiate()
	add_child_autofree(navigator)

	var center: CenterContainer = navigator.get_node_or_null("Center")
	assert_not_null(center, "CardNavigator must contain a CenterContainer")
	var panel: PanelContainer = center.get_node_or_null("Panel")
	assert_not_null(panel, "CenterContainer must contain a centered Panel")
	assert_eq(panel.mouse_filter, Control.MOUSE_FILTER_STOP, "Centered panel must stop mouse input")


func test_open_with_valid_snapshot_emits_initial_card_and_updates_count() -> void:
	var navigator: CardNavigator = CardNavigatorScene.instantiate()
	add_child_autofree(navigator)
	watch_signals(navigator)

	var success: bool = navigator.open(["a", "b", "c"], "a")
	assert_true(success, "open() with valid IDs must return true")
	assert_true(navigator.visible, "open() must make navigator visible")
	assert_signal_emit_count(navigator, "card_changed", 1, "open() must emit card_changed once")
	assert_signal_emitted_with_parameters(navigator, "card_changed", ["a"])

	var count_label: Label = navigator.get_node("%CountLabel")
	assert_eq(count_label.text, "1 of 3", "Count label must read '1 of 3'")

	var prev_button: Button = navigator.get_node("%PrevButton")
	var next_button: Button = navigator.get_node("%NextButton")
	assert_false(prev_button.disabled, "Prev button must be enabled for multi-item snapshot")
	assert_false(next_button.disabled, "Next button must be enabled for multi-item snapshot")


func test_previous_wraps_to_last_item() -> void:
	var navigator: CardNavigator = CardNavigatorScene.instantiate()
	add_child_autofree(navigator)

	navigator.open(["a", "b", "c"], "a")
	watch_signals(navigator)

	var prev_button: Button = navigator.get_node("%PrevButton")
	prev_button.emit_signal("pressed")

	assert_signal_emit_count(navigator, "card_changed", 1)
	assert_signal_emitted_with_parameters(navigator, "card_changed", ["c"])

	var count_label: Label = navigator.get_node("%CountLabel")
	assert_eq(count_label.text, "3 of 3", "Count label must read '3 of 3'")
	assert_eq(navigator.get_current_id(), "c")


func test_next_wraps_from_last_item_to_first_item() -> void:
	var navigator: CardNavigator = CardNavigatorScene.instantiate()
	add_child_autofree(navigator)

	navigator.open(["a", "b", "c"], "c")
	watch_signals(navigator)

	var next_button: Button = navigator.get_node("%NextButton")
	next_button.emit_signal("pressed")

	assert_signal_emit_count(navigator, "card_changed", 1)
	assert_signal_emitted_with_parameters(navigator, "card_changed", ["a"])

	var count_label: Label = navigator.get_node("%CountLabel")
	assert_eq(count_label.text, "1 of 3", "Count label must read '1 of 3'")
	assert_eq(navigator.get_current_id(), "a")


func test_single_item_snapshot_disables_both_arrows() -> void:
	var navigator: CardNavigator = CardNavigatorScene.instantiate()
	add_child_autofree(navigator)

	var success: bool = navigator.open(["only_one"], "only_one")
	assert_true(success)

	var prev_button: Button = navigator.get_node("%PrevButton")
	var next_button: Button = navigator.get_node("%NextButton")
	var count_label: Label = navigator.get_node("%CountLabel")

	assert_true(prev_button.disabled, "Prev button must be disabled for single-item snapshot")
	assert_true(next_button.disabled, "Next button must be disabled for single-item snapshot")
	assert_eq(count_label.text, "1 of 1", "Count label must read '1 of 1'")


func test_open_refuses_empty_snapshot() -> void:
	var navigator: CardNavigator = CardNavigatorScene.instantiate()
	add_child_autofree(navigator)
	watch_signals(navigator)

	var success: bool = navigator.open([], "")
	assert_false(success, "open() must return false on empty snapshot")
	assert_false(navigator.visible, "Navigator must not become visible on empty snapshot")
	assert_signal_not_emitted(navigator, "card_changed", "card_changed must not emit on empty snapshot")


func test_open_refuses_id_not_in_snapshot() -> void:
	var navigator: CardNavigator = CardNavigatorScene.instantiate()
	add_child_autofree(navigator)
	watch_signals(navigator)

	var success: bool = navigator.open(["a", "b"], "c")
	assert_false(success, "open() must return false when initial ID is not in snapshot")
	assert_false(navigator.visible, "Navigator must not become visible when initial ID is invalid")
	assert_signal_not_emitted(navigator, "card_changed", "card_changed must not emit when initial ID is invalid")


func test_close_emits_closed_with_last_id_and_hides() -> void:
	var navigator: CardNavigator = CardNavigatorScene.instantiate()
	add_child_autofree(navigator)

	navigator.open(["a", "b", "c"], "a")
	navigator.next()
	assert_eq(navigator.get_current_id(), "b")

	watch_signals(navigator)
	var close_button: Button = navigator.get_node("%CloseButton")
	close_button.emit_signal("pressed")

	assert_signal_emit_count(navigator, "closed", 1, "closed signal must be emitted once")
	assert_signal_emitted_with_parameters(navigator, "closed", ["b"])
	assert_false(navigator.visible, "close() must hide navigator")


func test_ui_cancel_escape_closes_navigator() -> void:
	var navigator: CardNavigator = CardNavigatorScene.instantiate()
	add_child_autofree(navigator)

	navigator.open(["a", "b", "c"], "a")
	watch_signals(navigator)

	navigator._unhandled_input(_escape_event())

	assert_signal_emit_count(navigator, "closed", 1, "Escape must emit closed signal")
	assert_signal_emitted_with_parameters(navigator, "closed", ["a"])
	assert_false(navigator.visible, "Escape must hide navigator")


func test_focus_handling_focuses_card_first_focusable_or_close() -> void:
	var navigator: CardNavigator = CardNavigatorScene.instantiate()
	add_child_autofree(navigator)

	var card: VBoxContainer = autoqfree(VBoxContainer.new())
	var card_button := Button.new()
	card.add_child(card_button)

	navigator.set_card_content(card)
	navigator.open(["a", "b"], "a")

	assert_true(card_button.has_focus(), "Opening navigator should focus first focusable child in card content")

	# Test fallback to Close button when card has no focusable controls
	var card_no_focus: VBoxContainer = autoqfree(VBoxContainer.new())
	var card_label := Label.new()
	card_no_focus.add_child(card_label)

	navigator.set_card_content(card_no_focus)
	navigator.open(["a", "b"], "a")

	var close_button: Button = navigator.get_node("%CloseButton")
	assert_true(close_button.has_focus(), "Opening navigator should focus CloseButton when card has no focusable controls")


func test_focus_restoration_target_restored_on_close() -> void:
	var root := Control.new()
	add_child_autofree(root)

	var origin_button := Button.new()
	root.add_child(origin_button)

	var navigator: CardNavigator = CardNavigatorScene.instantiate()
	root.add_child(navigator)

	navigator.open(["a", "b"], "a", origin_button)
	navigator.close()

	assert_true(origin_button.has_focus(), "Closing navigator must restore focus to caller-supplied restoration target")


func test_set_card_content_replaces_previous_child() -> void:
	var navigator: CardNavigator = CardNavigatorScene.instantiate()
	add_child_autofree(navigator)

	var content_container: Container = navigator.get_node("%ContentContainer")

	var child1: Control = autoqfree(Control.new())
	navigator.set_card_content(child1)
	assert_eq(content_container.get_child_count(), 1)
	assert_eq(content_container.get_child(0), child1)

	var child2: Control = autoqfree(Control.new())
	navigator.set_card_content(child2)
	assert_eq(content_container.get_child_count(), 1)
	assert_eq(content_container.get_child(0), child2)


func test_navigator_does_not_touch_game_session() -> void:
	GameSession.reset()
	var initial_gold: int = GameSession.gold
	var initial_adventurers_count: int = GameSession.adventurers.size()

	var navigator: CardNavigator = CardNavigatorScene.instantiate()
	add_child_autofree(navigator)

	navigator.open(["a", "b", "c"], "a")
	navigator.next()
	navigator.previous()
	navigator.close()

	assert_eq(GameSession.gold, initial_gold, "Navigator must not alter GameSession gold")
	assert_eq(GameSession.adventurers.size(), initial_adventurers_count, "Navigator must not alter GameSession adventurers")
