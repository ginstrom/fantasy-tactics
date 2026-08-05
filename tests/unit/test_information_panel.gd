extends GutTest

const InformationPanelScene := preload("res://scenes/ui/information_panel.tscn")


func before_each() -> void:
	GameSession.reset()


func test_information_panel_displays_the_player_name_and_banked_gold_total() -> void:
	GameSession.player_name = "Aria"
	GameSession.gold = 25
	var panel: Control = InformationPanelScene.instantiate()
	add_child_autofree(panel)

	panel.refresh()

	assert_eq(panel.get_node("Content/Title").text, "information.title")
	assert_eq(panel.get_node("Content/PlayerName").text, tr("information.player") % "Aria")
	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)


func test_information_panel_hides_party_name_and_gold_by_default() -> void:
	GameSession.create_party()
	var panel: Control = InformationPanelScene.instantiate()
	add_child_autofree(panel)

	panel.refresh()

	assert_false(panel.get_node("Content/PartyName").visible)
	assert_false(panel.get_node("Content/PartyGoldMargin").visible)


func test_information_panel_shows_party_name_and_party_gold_when_active_and_a_party_is_selected() -> void:
	GameSession.create_party()
	GameSession.gold = 25
	GameSession.pending_reward = 10
	var panel: Control = InformationPanelScene.instantiate()
	add_child_autofree(panel)

	panel.refresh(true)

	assert_true(panel.get_node("Content/PartyName").visible)
	assert_eq(panel.get_node("Content/PartyName").text, tr("information.party") % "Party 1")
	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)
	assert_true(panel.get_node("Content/PartyGoldMargin").visible)
	assert_eq(
		panel.get_node("Content/PartyGoldMargin/PartyGold").text, tr("information.gold") % 10
	)


func test_information_panel_hides_party_name_and_gold_when_active_but_no_party_exists() -> void:
	var panel: Control = InformationPanelScene.instantiate()
	add_child_autofree(panel)

	panel.refresh(true)

	assert_false(
		panel.get_node("Content/PartyName").visible,
		"World Map passes true only once a party marker is selected, but a party must still exist"
	)
	assert_false(panel.get_node("Content/PartyGoldMargin").visible)
