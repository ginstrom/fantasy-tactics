extends GutTest

const InformationPanelScene := preload("res://scenes/ui/information_panel.tscn")


func before_each() -> void:
	GameSession.reset()


func _make_panel() -> Control:
	var panel: Control = InformationPanelScene.instantiate()
	add_child_autofree(panel)
	return panel


func test_refresh_always_shows_player_name_and_banked_gold() -> void:
	GameSession.player_name = "Aria"
	GameSession.gold = 25
	var panel := _make_panel()

	panel.refresh()

	assert_eq(panel.get_node("Content/Title").text, "information.title")
	assert_eq(panel.get_node("Content/PlayerName").text, tr("information.player") % "Aria")
	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)


func test_refresh_hides_the_party_and_adventurer_sections() -> void:
	GameSession.create_party()
	var panel := _make_panel()

	panel.refresh()

	assert_false(panel.get_node("Content/PartyName").visible)
	assert_false(panel.get_node("Content/PartyMembers").visible)
	assert_false(panel.get_node("Content/PendingReward").visible)
	assert_false(panel.get_node("Content/PartyViewButton").visible)
	assert_false(panel.get_node("Content/AdventurerName").visible)
	assert_false(panel.get_node("Content/AdventurerClass").visible)
	assert_false(panel.get_node("Content/AdventurerLevel").visible)
	assert_false(panel.get_node("Content/AdventurerViewButton").visible)


func test_refresh_party_shows_the_party_name_member_count_and_view_button() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.gold = 25
	var panel := _make_panel()

	panel.refresh_party(GameSession.FIRST_PARTY_ID)

	assert_eq(
		panel.get_node("Content/PlayerName").text,
		tr("information.player") % GameSession.player_name,
		"The permanent player row must still render alongside the party summary"
	)
	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)
	assert_true(panel.get_node("Content/PartyName").visible)
	assert_eq(panel.get_node("Content/PartyName").text, tr("information.party") % "Party 1")
	assert_true(panel.get_node("Content/PartyMembers").visible)
	assert_eq(panel.get_node("Content/PartyMembers").text, tr("information.members") % 1)
	assert_true(panel.get_node("Content/PartyViewButton").visible)
	assert_eq(panel.get_node("Content/PartyViewButton").text, tr("information.view_party"))


func test_refresh_party_shows_the_pending_reward_row_when_given_a_positive_amount() -> void:
	GameSession.create_party()
	var panel := _make_panel()

	panel.refresh_party(GameSession.FIRST_PARTY_ID, 15)

	assert_true(panel.get_node("Content/PendingReward").visible)
	assert_eq(
		panel.get_node("Content/PendingReward").text, tr("information.pending_reward") % 15
	)


func test_refresh_party_hides_the_pending_reward_row_when_the_amount_is_zero() -> void:
	GameSession.create_party()
	var panel := _make_panel()

	panel.refresh_party(GameSession.FIRST_PARTY_ID)

	assert_false(panel.get_node("Content/PendingReward").visible)


func test_a_bare_refresh_hides_the_pending_reward_row_again() -> void:
	GameSession.create_party()
	var panel := _make_panel()
	panel.refresh_party(GameSession.FIRST_PARTY_ID, 15)
	assert_true(panel.get_node("Content/PendingReward").visible)

	panel.refresh()

	assert_false(panel.get_node("Content/PendingReward").visible)


func test_refresh_party_with_an_unknown_id_clears_optional_content_without_hiding_player_or_gold() -> void:
	GameSession.gold = 25
	var panel := _make_panel()

	panel.refresh_party("no_such_party")

	assert_eq(
		panel.get_node("Content/PlayerName").text,
		tr("information.player") % GameSession.player_name
	)
	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)
	assert_false(panel.get_node("Content/PartyName").visible)
	assert_false(panel.get_node("Content/PartyMembers").visible)
	assert_false(panel.get_node("Content/PartyViewButton").visible)


func test_refresh_adventurer_shows_the_name_class_level_and_view_button() -> void:
	GameSession.gold = 25
	var panel := _make_panel()

	panel.refresh_adventurer(GameSession.WARRIOR_ID)

	assert_eq(
		panel.get_node("Content/PlayerName").text,
		tr("information.player") % GameSession.player_name,
		"The permanent player row must still render alongside the adventurer summary"
	)
	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)
	assert_true(panel.get_node("Content/AdventurerName").visible)
	assert_eq(panel.get_node("Content/AdventurerName").text, "Warrior")
	assert_true(panel.get_node("Content/AdventurerClass").visible)
	assert_eq(panel.get_node("Content/AdventurerClass").text, tr("information.class") % "warrior")
	assert_true(panel.get_node("Content/AdventurerLevel").visible)
	assert_eq(panel.get_node("Content/AdventurerLevel").text, tr("information.level") % 1)
	assert_true(panel.get_node("Content/AdventurerViewButton").visible)


func test_refresh_adventurer_with_an_unknown_id_clears_optional_content_without_hiding_player_or_gold() -> void:
	GameSession.gold = 25
	var panel := _make_panel()

	panel.refresh_adventurer("no_such_adventurer")

	assert_eq(
		panel.get_node("Content/PlayerName").text,
		tr("information.player") % GameSession.player_name
	)
	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)
	assert_false(panel.get_node("Content/AdventurerName").visible)
	assert_false(panel.get_node("Content/AdventurerClass").visible)
	assert_false(panel.get_node("Content/AdventurerLevel").visible)
	assert_false(panel.get_node("Content/AdventurerViewButton").visible)


func test_refresh_party_then_refresh_adventurer_hides_the_stale_party_section() -> void:
	GameSession.create_party()
	var panel := _make_panel()
	panel.refresh_party(GameSession.FIRST_PARTY_ID)

	panel.refresh_adventurer(GameSession.WARRIOR_ID)

	assert_false(panel.get_node("Content/PartyName").visible)
	assert_false(panel.get_node("Content/PartyMembers").visible)
	assert_false(panel.get_node("Content/PartyViewButton").visible)


func test_the_party_view_button_emits_party_selected_with_the_party_id_instead_of_changing_scenes() -> void:
	GameSession.create_party()
	var panel := _make_panel()
	panel.refresh_party(GameSession.FIRST_PARTY_ID)
	watch_signals(panel)

	panel.get_node("Content/PartyViewButton").emit_signal("pressed")

	assert_signal_emitted_with_parameters(panel, "party_selected", [GameSession.FIRST_PARTY_ID])


func test_the_adventurer_view_button_emits_adventurer_selected_with_the_adventurer_id_instead_of_changing_scenes() -> void:
	var panel := _make_panel()
	panel.refresh_adventurer(GameSession.WARRIOR_ID)
	watch_signals(panel)

	panel.get_node("Content/AdventurerViewButton").emit_signal("pressed")

	assert_signal_emitted_with_parameters(panel, "adventurer_selected", [GameSession.WARRIOR_ID])
