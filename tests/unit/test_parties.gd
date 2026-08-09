extends GutTest

const PartiesScene := preload("res://scenes/ui/parties.tscn")
const UiTestHelpers := preload("res://tests/unit/ui_test_helpers.gd")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()
	GameManager.route_context_id = ""


func test_parties_shows_the_title_and_the_back_action() -> void:
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/Title").text, "parties.title")
	assert_eq(screen.get_node("Body/Center/VBox/BackButton").text, "ui.back")


func test_back_button_returns_to_the_encampment() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/parties.gd")
	assert_string_contains(source, "GameManager.go_to_encampment()")


func test_an_empty_party_list_shows_the_empty_state_without_errors() -> void:
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)

	assert_true(screen.get_node("Body/Center/VBox/EmptyLabel").visible)
	assert_eq(screen.get_node("Body/Center/VBox/EmptyLabel").text, "parties.empty")
	var tree: Tree = screen.get_node("Body/Center/VBox/PartyTable/Tree")
	assert_eq(UiTestHelpers.tree_row_values(tree, 0), [] as Array[String])
	assert_eq(screen.selected_party_id, "")


func test_create_party_action_creates_exactly_one_party_and_refreshes_the_table() -> void:
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)
	var create_button: Button = screen.get_node("Body/Center/VBox/CreatePartyButton")

	assert_true(create_button.visible)
	assert_false(create_button.disabled)
	create_button.emit_signal("pressed")
	screen.get_node("Body/Center/VBox/PartyNameEntry/NameRow/NameInput").text = "Party 1"
	screen.get_node("Body/Center/VBox/PartyNameEntry/NameRow/ConfirmButton").emit_signal("pressed")

	assert_eq(GameSession.parties.size(), 1)
	assert_eq(GameSession.selected_party_id, GameSession.FIRST_PARTY_ID)
	assert_eq(UiTestHelpers.tree_row_values(screen.get_node("Body/Center/VBox/PartyTable/Tree"), 0), ["Party 1"])
	assert_true(create_button.disabled)


func test_create_party_button_reveals_the_name_entry_instead_of_creating_immediately() -> void:
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)
	var create_button: Button = screen.get_node("Body/Center/VBox/CreatePartyButton")

	create_button.emit_signal("pressed")

	assert_eq(GameSession.parties.size(), 0)
	assert_true(screen.get_node("Body/Center/VBox/PartyNameEntry").visible)
	assert_false(create_button.visible)


func test_party_name_random_button_fills_the_name_field_with_one_of_the_two_choices() -> void:
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)
	screen.get_node("Body/Center/VBox/CreatePartyButton").emit_signal("pressed")

	screen._on_party_name_random_button_pressed()

	var name_input: LineEdit = screen.get_node("Body/Center/VBox/PartyNameEntry/NameRow/NameInput")
	assert_true(name_input.text in ["Party 1", "Alpha Party"])


func test_ok_button_starts_disabled_and_enables_once_a_name_is_entered() -> void:
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)
	screen.get_node("Body/Center/VBox/CreatePartyButton").emit_signal("pressed")
	var ok_button: Button = screen.get_node("Body/Center/VBox/PartyNameEntry/NameRow/ConfirmButton")
	assert_true(ok_button.disabled)

	screen._on_party_name_input_text_changed("Aria's Company")
	assert_false(ok_button.disabled)

	screen._on_party_name_input_text_changed("   ")
	assert_true(ok_button.disabled, "Whitespace-only input must not enable OK")


func test_random_button_also_enables_the_ok_button() -> void:
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)
	screen.get_node("Body/Center/VBox/CreatePartyButton").emit_signal("pressed")
	var ok_button: Button = screen.get_node("Body/Center/VBox/PartyNameEntry/NameRow/ConfirmButton")

	screen._on_party_name_random_button_pressed()

	assert_false(ok_button.disabled)


func test_submitting_the_name_field_confirms_like_pressing_ok() -> void:
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)
	screen.get_node("Body/Center/VBox/CreatePartyButton").emit_signal("pressed")
	var name_input: LineEdit = screen.get_node("Body/Center/VBox/PartyNameEntry/NameRow/NameInput")
	name_input.text = "Alpha Party"

	screen._on_party_name_input_text_submitted(name_input.text)

	assert_eq(GameSession.parties.size(), 1)
	assert_eq(GameSession.parties[0].name, "Alpha Party")


func test_confirming_the_party_name_creates_the_party_with_that_name_and_hides_the_entry() -> void:
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)
	screen.get_node("Body/Center/VBox/CreatePartyButton").emit_signal("pressed")
	var name_input: LineEdit = screen.get_node("Body/Center/VBox/PartyNameEntry/NameRow/NameInput")
	name_input.text = "Alpha Party"

	screen.get_node("Body/Center/VBox/PartyNameEntry/NameRow/ConfirmButton").emit_signal("pressed")

	assert_eq(GameSession.parties.size(), 1)
	assert_eq(GameSession.parties[0].name, "Alpha Party")
	assert_false(screen.get_node("Body/Center/VBox/PartyNameEntry").visible)


func test_cancelling_the_party_name_entry_creates_nothing_and_restores_the_button() -> void:
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)
	screen.get_node("Body/Center/VBox/CreatePartyButton").emit_signal("pressed")

	screen.get_node("Body/Center/VBox/PartyNameEntry/CancelButton").emit_signal("pressed")

	assert_eq(GameSession.parties.size(), 0)
	assert_false(screen.get_node("Body/Center/VBox/PartyNameEntry").visible)
	assert_true(screen.get_node("Body/Center/VBox/CreatePartyButton").visible)


## Column titles are resolved via tr() (see parties.gd) to the real English
## copy in translations/en.tres (Party/Members/Status — see the migration
## brief).
func test_parties_table_uses_the_documented_columns() -> void:
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/PartyTable/Tree")

	assert_eq(tree.columns, 3)
	assert_eq(tree.get_column_title(0), "Party")
	assert_eq(tree.get_column_title(1), "Members")
	assert_eq(tree.get_column_title(2), "Status")


func test_every_party_renders_as_a_row_with_name_members_and_status() -> void:
	GameSession.create_party()
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/PartyTable/Tree")

	assert_false(screen.get_node("Body/Center/VBox/EmptyLabel").visible)
	assert_eq(UiTestHelpers.tree_row_values(tree, 0), ["Party 1"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 1), ["0"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 2), ["Encamped"])


func test_selecting_a_party_row_stores_the_id_locally_and_refreshes_the_panel() -> void:
	GameSession.create_party()
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("%InformationPanel")
	var tree: Tree = screen.get_node("Body/Center/VBox/PartyTable/Tree")
	var item := tree.get_root().get_first_child()

	item.select(0)
	tree.emit_signal("item_selected")

	assert_eq(screen.selected_party_id, GameSession.FIRST_PARTY_ID)
	assert_true(panel.get_node("Content/PartyName").visible)
	assert_eq(panel.get_node("Content/PartyName").text, tr("information.party") % "Party 1")
	assert_eq(panel.get_node("Content/PartyMembers").text, tr("information.members") % 0)
	assert_true(panel.get_node("Content/PartyViewButton").visible)


func test_the_panels_view_button_asks_game_manager_to_open_party_details() -> void:
	GameSession.create_party()
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("%InformationPanel")
	var tree: Tree = screen.get_node("Body/Center/VBox/PartyTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")

	panel.get_node("Content/PartyViewButton").emit_signal("pressed")

	assert_eq(
		GameManager.route_context_id,
		GameSession.FIRST_PARTY_ID,
		"Pressing View must ask GameManager to route to that party's details"
	)


func test_activating_a_row_asks_game_manager_to_open_party_details() -> void:
	GameSession.create_party()
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/PartyTable/Tree")
	tree.get_root().get_first_child().select(0)

	tree.emit_signal("item_activated")

	assert_eq(GameManager.route_context_id, GameSession.FIRST_PARTY_ID)


func test_a_refresh_that_invalidates_the_selection_clears_it_and_falls_back_to_the_empty_state() -> void:
	GameSession.create_party()
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("%InformationPanel")
	var tree: Tree = screen.get_node("Body/Center/VBox/PartyTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")
	assert_eq(screen.selected_party_id, GameSession.FIRST_PARTY_ID)

	GameSession.reset()
	screen.refresh()

	assert_eq(screen.selected_party_id, "")
	assert_false(panel.get_node("Content/PartyName").visible)
	assert_true(screen.get_node("Body/Center/VBox/EmptyLabel").visible)


func test_entering_parties_clears_a_stale_route_context_id() -> void:
	GameManager.route_context_id = "stale_id"

	GameManager.go_to_parties()

	assert_eq(GameManager.route_context_id, "")


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	var screen: Control = PartiesScene.instantiate()
	add_child_autofree(screen)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)
