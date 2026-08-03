extends GutTest

const StartingSettlementScene := preload("res://scenes/local/starting_settlement.tscn")


func test_settlement_has_an_encampment_action() -> void:
	var settlement: Control = StartingSettlementScene.instantiate()
	add_child_autofree(settlement)

	assert_eq(
		settlement.get_node("Center/VBox/EncampmentButton").text,
		"settlement.encampment"
	)


func test_escape_opens_the_game_menu() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/local/starting_settlement.gd")
	assert_string_contains(source, "GameManager.open_game_menu()")
