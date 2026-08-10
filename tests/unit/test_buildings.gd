extends GutTest

const BuildingsScene := preload("res://scenes/ui/buildings.tscn")
const UiTestHelpers := preload("res://tests/unit/ui_test_helpers.gd")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()


func test_buildings_shows_the_title_and_the_back_action() -> void:
	var screen: Control = BuildingsScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/Title").text, "buildings.title")
	assert_eq(screen.get_node("Body/Center/VBox/BackButton").text, "ui.back")


func test_back_button_returns_to_the_encampment() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/buildings.gd")
	assert_string_contains(source, "GameManager.go_to_encampment()")


## Column titles are resolved via tr() (see buildings.gd) to the real
## English copy in translations/en.tres (Name — see the design doc), and the
## table has rows for Guild Hall and Blacksmith.
func test_buildings_table_uses_the_documented_columns_and_has_building_rows() -> void:
	var screen: Control = BuildingsScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/BuildingTable/Tree")

	assert_eq(tree.columns, 1)
	assert_eq(tree.get_column_title(0), "Name")
	assert_eq(UiTestHelpers.tree_row_values(tree, 0), ["Guild Hall", "Blacksmith"])


func test_activating_the_guild_hall_row_routes_via_game_manager() -> void:
	var screen: Control = BuildingsScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/BuildingTable/Tree")
	tree.get_root().get_first_child().select(0)

	tree.emit_signal("item_activated")

	var source := FileAccess.get_file_as_string("res://scripts/ui/buildings.gd")
	assert_string_contains(source, "GameManager.go_to_guild_hall()")
	assert_string_contains(source, "GameManager.go_to_blacksmith()")


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	var screen: Control = BuildingsScene.instantiate()
	add_child_autofree(screen)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)


func test_buildings_contains_the_camp_nav() -> void:
	var screen: Control = BuildingsScene.instantiate()
	add_child_autofree(screen)

	assert_not_null(screen.get_node("Body/CampNav"))
