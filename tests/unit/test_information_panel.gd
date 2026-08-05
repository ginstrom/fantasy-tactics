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
