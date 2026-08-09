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
	assert_false(panel.get_node("Content/RecruitmentName").visible)
	assert_false(panel.get_node("Content/RecruitmentClass").visible)
	assert_false(panel.get_node("Content/RecruitmentLevel").visible)
	assert_false(panel.get_node("Content/RecruitmentCost").visible)
	assert_false(panel.get_node("Content/RecruitButton").visible)
	assert_true(
		panel.get_node("Content/RecruitButton").disabled,
		"The Recruit action must be disabled by default, not just hidden"
	)


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


func test_refresh_recruitment_candidate_shows_name_class_level_cost_and_the_recruit_action() -> void:
	GameSession.gold = 25
	var panel := _make_panel()

	panel.refresh_recruitment_candidate("warrior_002")

	assert_eq(
		panel.get_node("Content/PlayerName").text,
		tr("information.player") % GameSession.player_name,
		"The permanent player row must still render alongside the recruitment summary"
	)
	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)
	assert_true(panel.get_node("Content/RecruitmentName").visible)
	assert_eq(panel.get_node("Content/RecruitmentName").text, "Warrior 2")
	assert_true(panel.get_node("Content/RecruitmentClass").visible)
	assert_eq(panel.get_node("Content/RecruitmentClass").text, tr("information.class") % "warrior")
	assert_true(panel.get_node("Content/RecruitmentLevel").visible)
	assert_eq(panel.get_node("Content/RecruitmentLevel").text, tr("information.level") % 1)
	assert_true(panel.get_node("Content/RecruitmentCost").visible)
	assert_eq(
		panel.get_node("Content/RecruitmentCost").text,
		"%s %d" % [tr(&"information.recruitment_cost"), 10]
	)
	assert_true(panel.get_node("Content/RecruitButton").visible)


func test_refresh_recruitment_candidate_disables_the_recruit_action_when_gold_is_insufficient() -> void:
	GameSession.gold = 0
	var panel := _make_panel()

	panel.refresh_recruitment_candidate("warrior_002")

	assert_true(panel.get_node("Content/RecruitButton").disabled)


func test_refresh_recruitment_candidate_enables_the_recruit_action_when_affordable() -> void:
	GameSession.gold = 10
	var panel := _make_panel()

	panel.refresh_recruitment_candidate("warrior_002")

	assert_false(panel.get_node("Content/RecruitButton").disabled)


## A re-selection of the same candidate after gold changed underneath it must
## flip the Recruit action back to disabled rather than leaving it enabled
## from an earlier, richer refresh.
func test_refresh_recruitment_candidate_re_disables_the_recruit_action_when_gold_drops() -> void:
	GameSession.gold = 10
	var panel := _make_panel()
	panel.refresh_recruitment_candidate("warrior_002")
	assert_false(panel.get_node("Content/RecruitButton").disabled)

	GameSession.gold = 0
	panel.refresh_recruitment_candidate("warrior_002")

	assert_true(panel.get_node("Content/RecruitButton").disabled)


func test_refresh_recruitment_candidate_with_an_unknown_id_clears_optional_content_without_hiding_player_or_gold() -> void:
	GameSession.gold = 25
	var panel := _make_panel()

	panel.refresh_recruitment_candidate("no_such_candidate")

	assert_eq(
		panel.get_node("Content/PlayerName").text,
		tr("information.player") % GameSession.player_name
	)
	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)
	assert_false(panel.get_node("Content/RecruitmentName").visible)
	assert_false(panel.get_node("Content/RecruitmentClass").visible)
	assert_false(panel.get_node("Content/RecruitmentLevel").visible)
	assert_false(panel.get_node("Content/RecruitmentCost").visible)
	assert_false(panel.get_node("Content/RecruitButton").visible)
	assert_true(panel.get_node("Content/RecruitButton").disabled)


func test_refresh_party_hides_the_stale_recruitment_section() -> void:
	GameSession.create_party()
	GameSession.gold = 25
	var panel := _make_panel()
	panel.refresh_recruitment_candidate("warrior_002")

	panel.refresh_party(GameSession.FIRST_PARTY_ID)

	assert_false(panel.get_node("Content/RecruitmentName").visible)
	assert_true(panel.get_node("Content/RecruitButton").disabled)


func test_refresh_adventurer_hides_the_stale_recruitment_section() -> void:
	GameSession.gold = 25
	var panel := _make_panel()
	panel.refresh_recruitment_candidate("warrior_002")

	panel.refresh_adventurer(GameSession.WARRIOR_ID)

	assert_false(panel.get_node("Content/RecruitmentName").visible)
	assert_true(panel.get_node("Content/RecruitButton").disabled)


func test_the_recruit_button_emits_recruit_selected_with_the_candidate_id_instead_of_purchasing() -> void:
	GameSession.gold = 25
	var panel := _make_panel()
	panel.refresh_recruitment_candidate("warrior_002")
	watch_signals(panel)

	panel.get_node("Content/RecruitButton").emit_signal("pressed")

	assert_signal_emitted_with_parameters(panel, "recruit_selected", ["warrior_002"])
	assert_eq(GameSession.gold, 25, "The panel must never purchase by itself")
	assert_eq(
		GameSession.get_recruitment_candidates().size(),
		1,
		"The panel must never remove the candidate by itself"
	)


func test_refresh_party_shows_carried_loot_when_pending_loot_exists() -> void:
	GameSession.create_party()
	GameSession.pending_mana_crystals = {1: 2, 2: 1}
	GameSession.pending_gear = {"shortsword_iron": 2, "dagger_iron": 1}
	var panel: PanelContainer = InformationPanelScene.instantiate()
	add_child_autofree(panel)

	panel.refresh_party(GameSession.FIRST_PARTY_ID)

	var label: Label = panel.get_node("Content/CarriedLoot")
	assert_true(label.visible)
	assert_eq(label.text, tr("information.carried_loot") % [3, 3], "3 mana crystals (2+1) and 3 gear pieces")


func test_refresh_party_hides_carried_loot_when_there_is_none() -> void:
	GameSession.create_party()
	var panel: PanelContainer = InformationPanelScene.instantiate()
	add_child_autofree(panel)

	panel.refresh_party(GameSession.FIRST_PARTY_ID)

	assert_false(panel.get_node("Content/CarriedLoot").visible)


func test_a_bare_refresh_hides_carried_loot_too() -> void:
	GameSession.pending_gear = {"dagger_iron": 1}
	var panel: PanelContainer = InformationPanelScene.instantiate()
	add_child_autofree(panel)

	panel.refresh()

	assert_false(panel.get_node("Content/CarriedLoot").visible)
