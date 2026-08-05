extends GutTest

const DeployPartyScene := preload("res://scenes/ui/deploy_party.tscn")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()


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


func test_deploy_party_shows_the_title_and_the_back_action() -> void:
	var screen: Control = DeployPartyScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Center/VBox/Title").text, "deploy_party.title")
	assert_eq(screen.get_node("Center/VBox/BackButton").text, "ui.back")


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
	assert_eq(screen.get_node("Center/VBox/PartyList").get_child_count(), 0)


func test_lists_exactly_the_deployable_parties_not_every_party() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.parties.append(_ineligible_party("ineligible_party"))
	var screen: Control = DeployPartyScene.instantiate()
	add_child_autofree(screen)

	assert_false(screen.get_node("Center/VBox/EmptyLabel").visible)
	assert_eq(screen.get_node("Center/VBox/PartyList").get_child_count(), 1)
	var row: Button = screen.get_node("Center/VBox/PartyList").get_child(0)
	assert_eq(row.text, tr("deploy_party.party_row") % ["Party 1", 1])


func test_selecting_a_row_deploys_that_exact_party() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen: Control = DeployPartyScene.instantiate()
	add_child_autofree(screen)
	var row: Button = screen.get_node("Center/VBox/PartyList").get_child(0)

	row.emit_signal("pressed")

	assert_true(GameSession.has_deployed_party())
	assert_eq(GameSession.selected_party_id, GameSession.FIRST_PARTY_ID)


func test_an_invalidated_selection_leaves_the_screen_in_place_and_refreshes_the_list() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen: Control = DeployPartyScene.instantiate()
	add_child_autofree(screen)
	var row: Button = screen.get_node("Center/VBox/PartyList").get_child(0)
	# The party becomes ineligible out from under the still-displayed row.
	GameSession.parties[0].deployed = true

	row.emit_signal("pressed")

	assert_false(
		GameSession.get_party(GameSession.FIRST_PARTY_ID).movement_spent,
		"Sanity: deploy_party must not have run its normal deployment side effects again"
	)
	assert_true(screen.get_node("Center/VBox/EmptyLabel").visible)
	assert_eq(screen.get_node("Center/VBox/PartyList").get_child_count(), 0)


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
