extends GutTest

const EncampmentScene := preload("res://scenes/ui/encampment.tscn")


func test_encampment_has_a_manage_party_action() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Center/VBox/ManagePartyButton").text, "encampment.manage_party")
