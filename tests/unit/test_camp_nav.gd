extends GutTest

const CampNavScene := preload("res://scenes/ui/camp_nav.tscn")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()


func _make_nav() -> Control:
	var nav: Control = CampNavScene.instantiate()
	add_child_autofree(nav)
	return nav


func test_shows_all_six_destinations() -> void:
	var nav := _make_nav()

	assert_eq(nav.get_node("VBox/EncampmentButton").text, "encampment.title")
	assert_eq(nav.get_node("VBox/UnitsButton").text, "encampment.units")
	assert_eq(nav.get_node("VBox/BuildingsButton").text, "encampment.buildings")
	assert_eq(nav.get_node("VBox/TradeButton").text, "encampment.trade")
	assert_eq(nav.get_node("VBox/DeployPartyButton").text, "encampment.deploy_party")
	assert_eq(nav.get_node("VBox/WorldMapButton").text, "camp_nav.world_map")


func test_trade_button_is_enabled() -> void:
	var nav := _make_nav()

	assert_false(nav.get_node("VBox/TradeButton").disabled)


func test_trade_button_routes_via_game_manager() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/camp_nav.gd")
	assert_string_contains(source, "GameManager.go_to_trade()")


func test_deploy_party_is_disabled_until_a_deployable_party_exists() -> void:
	var nav := _make_nav()
	assert_true(nav.get_node("VBox/DeployPartyButton").disabled)

	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	nav.refresh()

	assert_false(nav.get_node("VBox/DeployPartyButton").disabled)


func test_deploy_party_becomes_disabled_again_once_no_deployable_party_remains() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var nav := _make_nav()
	assert_false(nav.get_node("VBox/DeployPartyButton").disabled)

	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	nav.refresh()

	assert_true(nav.get_node("VBox/DeployPartyButton").disabled)


func test_encampment_button_routes_via_game_manager() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/camp_nav.gd")
	assert_string_contains(source, "GameManager.go_to_encampment()")


func test_units_button_routes_via_game_manager() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/camp_nav.gd")
	assert_string_contains(source, "GameManager.go_to_units()")


func test_buildings_button_routes_via_game_manager() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/camp_nav.gd")
	assert_string_contains(source, "GameManager.go_to_buildings()")


func test_deploy_party_button_routes_via_game_manager() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/camp_nav.gd")
	assert_string_contains(source, "GameManager.go_to_deploy_party()")


func test_world_map_button_routes_via_game_manager() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/camp_nav.gd")
	assert_string_contains(source, "GameManager.go_to_world_map()")
