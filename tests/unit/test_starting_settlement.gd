extends GutTest

const StartingSettlementScene := preload("res://scenes/local/starting_settlement.tscn")


func test_settlement_has_an_encampment_action() -> void:
	var settlement: Control = StartingSettlementScene.instantiate()
	add_child_autofree(settlement)

	assert_eq(
		settlement.get_node("Center/VBox/EncampmentButton").text,
		"settlement.encampment"
	)
