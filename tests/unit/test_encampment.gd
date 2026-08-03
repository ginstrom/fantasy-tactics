extends GutTest

const EncampmentScene := preload("res://scenes/ui/encampment.tscn")


func test_encampment_has_a_manage_party_action() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Center/VBox/ManagePartyButton").text, "encampment.manage_party")


func test_encampment_disables_depart_until_party_has_a_member() -> void:
	GameSession.reset()
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	assert_true(screen.get_node("Center/VBox/DepartButton").disabled)
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	screen.refresh()
	assert_false(screen.get_node("Center/VBox/DepartButton").disabled)


func test_escape_opens_the_game_menu() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/encampment.gd")
	assert_string_contains(source, "GameManager.open_game_menu()")
