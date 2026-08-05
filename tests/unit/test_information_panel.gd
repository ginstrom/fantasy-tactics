extends GutTest

const InformationPanelScene := preload("res://scenes/ui/information_panel.tscn")


func before_each() -> void:
	GameSession.reset()


func test_information_panel_displays_the_banked_gold_total() -> void:
	GameSession.gold = 25
	var panel: Control = InformationPanelScene.instantiate()
	add_child_autofree(panel)

	panel.refresh()

	assert_eq(panel.get_node("Content/Title").text, "information.title")
	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)


func test_information_panel_hides_party_name_when_no_party_exists() -> void:
	var panel: Control = InformationPanelScene.instantiate()
	add_child_autofree(panel)

	panel.refresh()

	assert_false(panel.get_node("Content/PartyName").visible)


func test_information_panel_shows_party_name_and_gold_when_a_party_is_selected() -> void:
	GameSession.create_party()
	GameSession.gold = 25
	var panel: Control = InformationPanelScene.instantiate()
	add_child_autofree(panel)

	panel.refresh()

	assert_true(panel.get_node("Content/PartyName").visible)
	assert_eq(panel.get_node("Content/PartyName").text, tr("information.party") % "Party 1")
	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)


func test_information_panel_hides_party_name_when_party_active_is_false() -> void:
	GameSession.create_party()
	var panel: Control = InformationPanelScene.instantiate()
	add_child_autofree(panel)

	panel.refresh(false)

	assert_false(
		panel.get_node("Content/PartyName").visible,
		"World Map passes false while no party marker is selected"
	)
