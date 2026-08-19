extends GutTest

const InformationPanelScene := preload("res://scenes/ui/information_panel.tscn")


func before_each() -> void:
	GameSession.reset()


func _make_panel() -> Control:
	var panel: Control = InformationPanelScene.instantiate()
	add_child_autofree(panel)
	return panel


## Recruitment offers carry generated opaque ids (see GameSession
## _new_instance_id); tests discover the offer claiming a fixed template
## rather than hardcoding an id.
func _template_candidate(template_id: String) -> Dictionary:
	for candidate in GameSession.get_recruitment_candidates():
		if candidate.get("template_id", "") == template_id:
			return candidate
	return {}


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
	assert_false(panel.get_node("Content/PartyGold").visible)
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


func test_refresh_party_shows_the_party_gold_row_when_given_a_positive_amount() -> void:
	GameSession.create_party()
	var panel := _make_panel()

	panel.refresh_party(GameSession.FIRST_PARTY_ID, 15)

	assert_true(panel.get_node("Content/PartyGold").visible)
	assert_eq(
		panel.get_node("Content/PartyGold").text, tr("information.party_gold") % 15
	)


func test_refresh_party_hides_the_party_gold_row_when_the_amount_is_zero() -> void:
	GameSession.create_party()
	var panel := _make_panel()

	panel.refresh_party(GameSession.FIRST_PARTY_ID)

	assert_false(panel.get_node("Content/PartyGold").visible)


func test_a_bare_refresh_hides_the_party_gold_row_again() -> void:
	GameSession.create_party()
	var panel := _make_panel()
	panel.refresh_party(GameSession.FIRST_PARTY_ID, 15)
	assert_true(panel.get_node("Content/PartyGold").visible)

	panel.refresh()

	assert_false(panel.get_node("Content/PartyGold").visible)


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
	var candidate := _template_candidate("warrior_002")
	var panel := _make_panel()

	panel.refresh_recruitment_candidate(candidate.id)

	assert_eq(
		panel.get_node("Content/PlayerName").text,
		tr("information.player") % GameSession.player_name,
		"The permanent player row must still render alongside the recruitment summary"
	)
	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)
	assert_true(panel.get_node("Content/RecruitmentName").visible)
	assert_eq(panel.get_node("Content/RecruitmentName").text, candidate.name)
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

	panel.refresh_recruitment_candidate(_template_candidate("warrior_002").id)

	assert_true(panel.get_node("Content/RecruitButton").disabled)


func test_refresh_recruitment_candidate_enables_the_recruit_action_when_affordable() -> void:
	GameSession.gold = 10
	var panel := _make_panel()

	panel.refresh_recruitment_candidate(_template_candidate("warrior_002").id)

	assert_false(panel.get_node("Content/RecruitButton").disabled)


## A re-selection of the same candidate after gold changed underneath it must
## flip the Recruit action back to disabled rather than leaving it enabled
## from an earlier, richer refresh.
func test_refresh_recruitment_candidate_re_disables_the_recruit_action_when_gold_drops() -> void:
	GameSession.gold = 10
	var candidate_id: String = _template_candidate("warrior_002").id
	var panel := _make_panel()
	panel.refresh_recruitment_candidate(candidate_id)
	assert_false(panel.get_node("Content/RecruitButton").disabled)

	GameSession.gold = 0
	panel.refresh_recruitment_candidate(candidate_id)

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
	panel.refresh_recruitment_candidate(_template_candidate("warrior_002").id)

	panel.refresh_party(GameSession.FIRST_PARTY_ID)

	assert_false(panel.get_node("Content/RecruitmentName").visible)
	assert_true(panel.get_node("Content/RecruitButton").disabled)


func test_refresh_adventurer_hides_the_stale_recruitment_section() -> void:
	GameSession.gold = 25
	var panel := _make_panel()
	panel.refresh_recruitment_candidate(_template_candidate("warrior_002").id)

	panel.refresh_adventurer(GameSession.WARRIOR_ID)

	assert_false(panel.get_node("Content/RecruitmentName").visible)
	assert_true(panel.get_node("Content/RecruitButton").disabled)


## --- Encounter Scout intel (Step 5 review fixes) ---


func _deploy_party_with_scout_at(position: Vector2i) -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var scout := GameSession.get_default_scout("scout_test", "Test Scout")
	GameSession.adventurers.append(scout)
	GameSession.assign_adventurer_to_selected_party("scout_test")
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	GameSession.set_deployed_party_position(position)


## Regression for the Step 5 review's Finding 4: refresh_encounter() used to
## render the static intel.danger_tier, which stays frozen at the
## encounter's base difficulty forever, while world_map.gd's own marker
## renders GameSession.get_threat_stars()' dynamic rating -- the two
## surfaces would disagree once world_turn crosses a THREAT_TURN_INTERVAL
## boundary. Both must always agree.
func test_refresh_encounter_renders_the_same_dynamic_threat_stars_as_get_threat_stars() -> void:
	var goblin_camp: Dictionary = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID)
	_deploy_party_with_scout_at(goblin_camp.position)
	GameSession.world_turn = 1 + GameSession.THREAT_TURN_INTERVAL
	var panel := _make_panel()

	panel.refresh_encounter(GameSession.FIRST_PARTY_ID, GameSession.GOBLIN_CAMP_ID)

	var expected_stars := "★".repeat(GameSession.get_threat_stars(GameSession.GOBLIN_CAMP_ID))
	assert_eq(expected_stars, "★★", "Sanity: one threat interval elapsed should add one star over the base difficulty")
	assert_true(panel.get_node("Content/EncounterDanger").visible)
	assert_eq(
		panel.get_node("Content/EncounterDanger").text,
		tr("information.encounter_danger") % expected_stars,
		"The info panel's star count must track the same dynamic rating the World Map marker renders"
	)


## Regression for the Step 5 review's Finding 5: refresh_encounter() used to
## read only intel.enemy_types[0] while pairing it with the summed
## enemy_count, so a mixed authored formation (like the pre-boss Gatehouse's
## 2 Hobgoblin Elite / 2 Goblin Archer / 1 Kobold Swarmer) rendered as one
## type times the total instead of its real per-type breakdown.
func test_refresh_encounter_shows_the_full_per_type_breakdown_for_a_mixed_authored_formation() -> void:
	const GATEHOUSE_ID := "obj_preboss_1_borderlands_vanguard"
	var gatehouse: Dictionary = GameSession.get_expedition(GATEHOUSE_ID)
	_deploy_party_with_scout_at(gatehouse.position)
	var panel := _make_panel()

	panel.refresh_encounter(GameSession.FIRST_PARTY_ID, GATEHOUSE_ID)

	var intel := GameSession.get_party_scouting_intel(GameSession.FIRST_PARTY_ID, GATEHOUSE_ID)
	assert_eq(
		intel.enemy_types as Array,
		[tr("battle.enemy.hobgoblin_elite"), tr("battle.enemy.goblin_archer"), tr("battle.enemy.kobold")],
		"Sanity: the Gatehouse fields three distinct enemy groups"
	)
	assert_eq(intel.enemy_counts as Array, [2, 2, 1])
	var expected_text := "%s, %s, %s" % [
		tr("information.encounter_enemies") % [tr("battle.enemy.hobgoblin_elite"), 2],
		tr("information.encounter_enemies") % [tr("battle.enemy.goblin_archer"), 2],
		tr("information.encounter_enemies") % [tr("battle.enemy.kobold"), 1],
	]
	assert_true(panel.get_node("Content/EncounterEnemies").visible)
	assert_eq(
		panel.get_node("Content/EncounterEnemies").text,
		expected_text,
		"Each group must render its own type and count, not one type times the summed total"
	)


func test_the_recruit_button_emits_recruit_selected_with_the_candidate_id_instead_of_purchasing() -> void:
	GameSession.gold = 25
	var candidate_id: String = _template_candidate("warrior_002").id
	var panel := _make_panel()
	panel.refresh_recruitment_candidate(candidate_id)
	watch_signals(panel)

	panel.get_node("Content/RecruitButton").emit_signal("pressed")

	assert_signal_emitted_with_parameters(panel, "recruit_selected", [candidate_id])
	assert_eq(GameSession.gold, 25, "The panel must never purchase by itself")
	assert_eq(
		GameSession.get_recruitment_candidates().size(),
		4,
		"The panel must never remove the candidate by itself"
	)
