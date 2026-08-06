extends GutTest

const DeployPartyScene := preload("res://scenes/ui/deploy_party.tscn")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()
	GameManager.route_context_id = ""


func _ineligible_party(party_id: String) -> Dictionary:
	# A second party dict crafted directly (create_party only ever allows one
	# real party in this slice), deployed so it fails the eligibility check.
	return {
		"id": party_id,
		"member_ids": [] as Array[String],
		"location_id": GameSession.STARTING_SETTLEMENT_ID,
		"world_position": GameSession.STARTING_SETTLEMENT_WORLD_POSITION,
		"deployed": true,
		"travel_route": [] as Array[Vector2i],
		"movement_spent": false,
		"name": "Ineligible Party",
		"progression": {},
		"metadata": {},
	}


func _tree_row_values(tree: Tree, column: int) -> Array[String]:
	var values: Array[String] = []
	var item := tree.get_root().get_first_child()
	while item != null:
		values.append(item.get_text(column))
		item = item.get_next()
	return values


func test_deploy_party_shows_the_title_and_the_back_action() -> void:
	var screen: Control = DeployPartyScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Center/VBox/Title").text, "deploy_party.title")
	assert_eq(screen.get_node("Center/VBox/BackButton").text, "ui.back")


## Activation is the only affordance that deploys a row (see
## test_activating_a_row_deploys_...); this label is what tells the player
## that double-click/Enter is what does it.
func test_deploy_party_shows_the_activation_hint() -> void:
	var screen: Control = DeployPartyScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Center/VBox/HintLabel").text, "deploy_party.hint")


func test_shows_the_permanent_player_and_gold_rows() -> void:
	GameSession.player_name = "Aria"
	GameSession.gold = 25
	var screen: Control = DeployPartyScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("InformationPanel")

	assert_true(panel.get_node("Content/PlayerName").visible)
	assert_eq(panel.get_node("Content/PlayerName").text, tr("information.player") % "Aria")
	assert_true(panel.get_node("Content/Gold").visible)
	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)


func test_no_deployable_party_shows_the_empty_state_without_errors() -> void:
	var screen: Control = DeployPartyScene.instantiate()
	add_child_autofree(screen)

	assert_true(screen.get_node("Center/VBox/EmptyLabel").visible)
	assert_eq(screen.get_node("Center/VBox/EmptyLabel").text, "deploy_party.empty")
	var tree: Tree = screen.get_node("Center/VBox/PartyTable/Tree")
	assert_eq(_tree_row_values(tree, 0), [] as Array[String])


func test_deploy_party_uses_the_sessions_deployability_query_not_a_private_predicate() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/deploy_party.gd")
	assert_false(source.contains("func _is_party_deployable"))
	assert_string_contains(source, "GameSession.is_party_deployable")


## Column titles are resolved via tr() (see deploy_party.gd) to the real
## English copy in translations/en.tres (Party/Members/Status — see the
## migration brief).
func test_deploy_party_table_uses_the_documented_columns() -> void:
	var screen: Control = DeployPartyScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Center/VBox/PartyTable/Tree")

	assert_eq(tree.columns, 3)
	assert_eq(tree.get_column_title(0), "Party")
	assert_eq(tree.get_column_title(1), "Members")
	assert_eq(tree.get_column_title(2), "Status")


func test_lists_exactly_the_deployable_parties_not_every_party() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.parties.append(_ineligible_party("ineligible_party"))
	var screen: Control = DeployPartyScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Center/VBox/PartyTable/Tree")

	assert_false(screen.get_node("Center/VBox/EmptyLabel").visible)
	assert_eq(_tree_row_values(tree, 0), ["Party 1"])
	assert_eq(_tree_row_values(tree, 1), ["1"])
	assert_eq(_tree_row_values(tree, 2), ["Encamped"])


## Selection alone must never deploy — only activating a row (see
## test_activating_a_row_deploys_...) does that.
func test_selecting_a_row_stores_the_id_locally_and_shows_its_summary_in_the_panel() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen: Control = DeployPartyScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("InformationPanel")
	var tree: Tree = screen.get_node("Center/VBox/PartyTable/Tree")
	var item := tree.get_root().get_first_child()

	item.select(0)
	tree.emit_signal("item_selected")

	assert_eq(screen.selected_party_id, GameSession.FIRST_PARTY_ID)
	assert_true(panel.get_node("Content/PartyName").visible)
	assert_eq(panel.get_node("Content/PartyName").text, tr("information.party") % "Party 1")
	assert_true(panel.get_node("Content/PartyViewButton").visible)
	assert_false(GameSession.has_deployed_party(), "Selecting a row must not deploy it")


func test_the_panels_view_button_asks_game_manager_to_open_party_details() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen: Control = DeployPartyScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("InformationPanel")
	var tree: Tree = screen.get_node("Center/VBox/PartyTable/Tree")
	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_selected")

	panel.get_node("Content/PartyViewButton").emit_signal("pressed")

	assert_eq(
		GameManager.route_context_id,
		GameSession.FIRST_PARTY_ID,
		"Pressing View must ask GameManager to route to that party's details"
	)


func test_activating_a_row_deploys_that_exact_party() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen: Control = DeployPartyScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Center/VBox/PartyTable/Tree")
	tree.get_root().get_first_child().select(0)

	tree.emit_signal("item_activated")

	assert_true(GameSession.has_deployed_party())
	assert_eq(GameSession.selected_party_id, GameSession.FIRST_PARTY_ID)


func test_an_invalidated_selection_leaves_the_screen_in_place_and_refreshes_the_list() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen: Control = DeployPartyScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Center/VBox/PartyTable/Tree")
	tree.get_root().get_first_child().select(0)
	# The party becomes ineligible out from under the still-displayed row.
	GameSession.parties[0].deployed = true

	tree.emit_signal("item_activated")

	assert_false(
		GameSession.get_party(GameSession.FIRST_PARTY_ID).movement_spent,
		"Sanity: deploy_party must not have run its normal deployment side effects again"
	)
	assert_true(screen.get_node("Center/VBox/EmptyLabel").visible)
	assert_eq(_tree_row_values(tree, 0), [] as Array[String])


func test_back_button_returns_to_the_encampment() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/deploy_party.gd")
	assert_string_contains(source, "GameManager.go_to_encampment()")


func test_back_button_does_not_deploy_or_otherwise_mutate_the_party() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen: Control = DeployPartyScene.instantiate()
	add_child_autofree(screen)

	screen.get_node("Center/VBox/BackButton").emit_signal("pressed")

	assert_false(GameSession.has_deployed_party())
	assert_eq(GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids, [GameSession.WARRIOR_ID])


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	var screen: Control = DeployPartyScene.instantiate()
	add_child_autofree(screen)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)
