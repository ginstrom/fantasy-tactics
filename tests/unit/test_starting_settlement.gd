extends GutTest

const StartingSettlementScene := preload("res://scenes/local/starting_settlement.tscn")


func after_each() -> void:
	GameManager.close_game_menu()


func test_settlement_has_an_encampment_action() -> void:
	var settlement: Control = StartingSettlementScene.instantiate()
	add_child_autofree(settlement)

	assert_eq(
		settlement.get_node("Center/VBox/EncampmentButton").text,
		"settlement.encampment"
	)


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	var settlement: Control = StartingSettlementScene.instantiate()
	add_child_autofree(settlement)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	settlement._unhandled_input(escape_event)

	assert_true(settlement.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)
