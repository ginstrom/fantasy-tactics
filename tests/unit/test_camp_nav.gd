extends GutTest

const CampNavScene := preload("res://scenes/ui/camp_nav.tscn")
const RosterScene := preload("res://scenes/ui/roster.tscn")
const BlacksmithScene := preload("res://scenes/ui/blacksmith.tscn")
const TempleScene := preload("res://scenes/ui/temple.tscn")
const StoresScene := preload("res://scenes/ui/stores.tscn")
const ShopScene := preload("res://scenes/ui/trading_post.tscn")


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


func test_category_renders_only_its_explicit_submenu_left_aligned_and_indented() -> void:
	var nav := _make_nav()

	nav.category = 1 # CampNav.Category.UNITS
	nav.refresh()

	assert_true(nav.get_node("VBox/UnitsSubmenuMargin").visible)
	assert_false(nav.get_node("VBox/BuildingsSubmenuMargin").visible)
	assert_false(nav.get_node("VBox/TradeSubmenuMargin").visible)
	assert_eq(nav.get_node("VBox/UnitsSubmenuMargin/Submenu/RosterButton").alignment, HORIZONTAL_ALIGNMENT_LEFT)
	assert_eq(nav.get_node("VBox/UnitsSubmenuMargin").get_theme_constant("margin_left"), 16)


func test_none_category_hides_every_submenu() -> void:
	var nav := _make_nav()

	nav.category = 0 # CampNav.Category.NONE
	nav.refresh()

	assert_false(nav.get_node("VBox/UnitsSubmenuMargin").visible)
	assert_false(nav.get_node("VBox/BuildingsSubmenuMargin").visible)
	assert_false(nav.get_node("VBox/TradeSubmenuMargin").visible)


func test_descendant_scenes_explicitly_select_their_camp_nav_category() -> void:
	var cases: Array[Array] = [
		[RosterScene, 1], # CampNav.Category.UNITS
		[BlacksmithScene, 2], # CampNav.Category.BUILDINGS
		[TempleScene, 2], # CampNav.Category.BUILDINGS
		[StoresScene, 3], # CampNav.Category.TRADE
		[ShopScene, 3], # CampNav.Category.TRADE
	]

	for scene in cases:
		var screen: Control = scene[0].instantiate()
		add_child_autofree(screen)
		assert_eq(screen.get_node("Body/CampNav").category, scene[1])


func test_submenu_buttons_route_to_every_listed_destination() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/camp_nav.gd")

	for route in [
		"GameManager.go_to_roster()",
		"GameManager.go_to_parties()",
		"GameManager.go_to_recruitment()",
		"GameManager.go_to_guild_hall()",
		"GameManager.go_to_temple()",
		"GameManager.go_to_blacksmith()",
		"GameManager.go_to_alchemy_workshop()",
		"GameManager.go_to_runic_workshop()",
		"GameManager.go_to_stores()",
		"GameManager.go_to_shop()",
	]:
		assert_string_contains(source, route)


func test_trade_button_routes_via_game_manager() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/camp_nav.gd")
	assert_string_contains(source, "GameManager.go_to_trade()")


func test_deploy_party_is_hidden_when_no_party_exists() -> void:
	var nav := _make_nav()

	assert_false(nav.get_node("VBox/DeployPartyButton").visible)


func test_deploy_party_is_visible_but_disabled_for_an_empty_party() -> void:
	GameSession.create_party()
	var nav := _make_nav()

	assert_true(nav.get_node("VBox/DeployPartyButton").visible)
	assert_true(nav.get_node("VBox/DeployPartyButton").disabled)


func test_deploy_party_is_visible_and_enabled_for_a_deployable_party() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var nav := _make_nav()

	assert_true(nav.get_node("VBox/DeployPartyButton").visible)

	assert_false(nav.get_node("VBox/DeployPartyButton").disabled)


func test_deploy_party_becomes_disabled_again_once_no_deployable_party_remains() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var nav := _make_nav()
	assert_false(nav.get_node("VBox/DeployPartyButton").disabled)

	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	nav.refresh()

	assert_true(nav.get_node("VBox/DeployPartyButton").visible)
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
