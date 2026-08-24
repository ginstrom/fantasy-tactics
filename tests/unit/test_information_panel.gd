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


## Stage 5 D5, docs/designs/world-map-and-encounters.md's "Future multi-party
## model": "Selecting a party shows its destination and remaining travel time
## in the right information panel." Resolved entirely from GameSession's own
## records (route destination -> a live encounter/authored-node name, or the
## Encampment) rather than needing world_map.gd to pass anything extra in.
func test_refresh_party_shows_the_deployed_partys_destination_and_turns_remaining() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.depart_selected_party()
	var goblin_camp: Dictionary = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID)
	# Settlement (3, 3) -> Goblin Camp (4, 4) is not a single cardinal step;
	# build a real two-step Manhattan route, matching build_route()'s own
	# horizontal-then-vertical convention.
	var route: Array[Vector2i] = [Vector2i(4, 3), goblin_camp.position]
	GameSession.set_deployed_party_route(route)
	var panel := _make_panel()

	panel.refresh_party(GameSession.FIRST_PARTY_ID)

	assert_true(panel.get_node("Content/PartyDestination").visible)
	assert_eq(
		panel.get_node("Content/PartyDestination").text,
		tr("information.party_destination") % [tr(goblin_camp.name_key), 2]
	)


func test_refresh_party_hides_destination_when_the_party_has_no_route() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.depart_selected_party()
	var panel := _make_panel()

	panel.refresh_party(GameSession.FIRST_PARTY_ID)

	assert_false(panel.get_node("Content/PartyDestination").visible)


func test_refresh_party_hides_destination_for_an_encamped_party() -> void:
	GameSession.create_party()
	var panel := _make_panel()

	panel.refresh_party(GameSession.FIRST_PARTY_ID)

	assert_false(panel.get_node("Content/PartyDestination").visible)


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


## Regression for a Step 2 review finding: world_map.gd's real
## _refresh_information_panel() calls refresh_encounter() (legacy
## Scout-in-range) and then refresh_encounter_intel() (Stage 5 Intelligence)
## back-to-back for the same hovered encounter every refresh. When a
## deployed Scout is within the legacy binary range of an encounter AND the
## new accumulating-intel system has already learned the same facts (e.g.
## via a Watchtower or a Guild Hall quest), both used to render their own
## Danger/Enemies row, showing each fact twice in one panel. The new
## Intelligence system must be the single source of truth once it has
## learned a fact, so exactly one row per fact may render here.
func test_refresh_encounter_then_refresh_encounter_intel_never_duplicates_the_danger_or_enemies_row() -> void:
	var goblin_camp: Dictionary = GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID)
	_deploy_party_with_scout_at(goblin_camp.position)
	# Both conditions true at once: the legacy Scout-in-range reveal (set up
	# above) AND a populated Stage 5 encounter_intel record that already
	# knows the main monster (which also implies Tier level is known, since
	# INTEL_TIER_MAIN_MONSTER > INTEL_TIER_LEVEL).
	GameSession.encounter_intel[GameSession.GOBLIN_CAMP_ID] = {
		"discovered": true, "known_tier": GameSession.INTEL_TIER_MAIN_MONSTER, "quest_id": "",
	}
	var panel := _make_panel()

	# Matches world_map.gd's own _refresh_information_panel() call order.
	panel.refresh_encounter(GameSession.FIRST_PARTY_ID, GameSession.GOBLIN_CAMP_ID)
	panel.refresh_encounter_intel(GameSession.GOBLIN_CAMP_ID)

	var danger_label: Label = panel.get_node("Content/EncounterDanger")
	var intel_tier_label: Label = panel.get_node("Content/EncounterIntelTier")
	var danger_rows_visible := int(danger_label.visible) + int(intel_tier_label.visible)
	assert_eq(danger_rows_visible, 1, "Exactly one Danger row must be visible, never zero or both")
	assert_true(intel_tier_label.visible, "The Stage 5 Intelligence row is the single source of truth once it has learned the tier")
	assert_false(danger_label.visible, "The legacy Scout-range row must be suppressed once the new system already knows the same fact")

	var enemies_label: Label = panel.get_node("Content/EncounterEnemies")
	var intel_enemies_label: Label = panel.get_node("Content/EncounterIntelEnemies")
	var enemies_rows_visible := int(enemies_label.visible) + int(intel_enemies_label.visible)
	assert_eq(enemies_rows_visible, 1, "Exactly one Enemies row must be visible, never zero or both")
	assert_true(intel_enemies_label.visible, "The Stage 5 Intelligence row is the single source of truth once it has learned the main monster")
	assert_false(enemies_label.visible, "The legacy Scout-range row must be suppressed once the new system already knows the same fact")


## --- Intelligence system rows (Stage 5 Step 2, docs/designs/intelligence.md) ---
## Deliberately exercised through refresh_encounter_intel() alone (never
## refresh_encounter(), the pre-existing Scout-in-range path above) so these
## tests can never accidentally depend on -- or be satisfied by -- the
## legacy reveal.


func test_refresh_encounter_intel_hides_every_row_for_an_undiscovered_encounter() -> void:
	var panel := _make_panel()

	panel.refresh_encounter_intel(GameSession.GOBLIN_CAMP_ID)

	assert_false(panel.get_node("Content/EncounterIntelTier").visible)
	assert_false(panel.get_node("Content/EncounterIntelEnemies").visible)
	assert_false(panel.get_node("Content/EncounterIntelQuest").visible)


## World Map exposes only known details: Tier level known alone shows the
## star row but withholds the enemy row entirely.
func test_refresh_encounter_intel_shows_only_the_tier_stars_once_tier_level_is_known() -> void:
	GameSession.encounter_intel[GameSession.GOBLIN_CAMP_ID] = {
		"discovered": true, "known_tier": GameSession.INTEL_TIER_LEVEL, "quest_id": "",
	}
	var panel := _make_panel()

	panel.refresh_encounter_intel(GameSession.GOBLIN_CAMP_ID)

	assert_true(panel.get_node("Content/EncounterIntelTier").visible)
	assert_eq(
		panel.get_node("Content/EncounterIntelTier").text,
		tr("information.encounter_danger") % "★".repeat(GameSession.get_threat_stars(GameSession.GOBLIN_CAMP_ID))
	)
	assert_false(panel.get_node("Content/EncounterIntelEnemies").visible, "Enemy composition is not known until Main monster")
	assert_false(panel.get_node("Content/EncounterIntelQuest").visible)


## Main monster known shows the enemy type with no count yet.
func test_refresh_encounter_intel_shows_the_enemy_type_without_a_count_at_main_monster_tier() -> void:
	GameSession.encounter_intel[GameSession.GOBLIN_CAMP_ID] = {
		"discovered": true, "known_tier": GameSession.INTEL_TIER_MAIN_MONSTER, "quest_id": "",
	}
	var panel := _make_panel()

	panel.refresh_encounter_intel(GameSession.GOBLIN_CAMP_ID)

	assert_true(panel.get_node("Content/EncounterIntelEnemies").visible)
	assert_eq(
		panel.get_node("Content/EncounterIntelEnemies").text,
		tr("information.encounter_enemy_type_only") % tr("battle.enemy.goblin")
	)


## Monster counts known shows the full "type x count" breakdown.
func test_refresh_encounter_intel_shows_enemy_counts_once_the_monster_counts_tier_is_known() -> void:
	GameSession.encounter_intel[GameSession.GOBLIN_CAMP_ID] = {
		"discovered": true, "known_tier": GameSession.INTEL_TIER_MONSTER_COUNTS, "quest_id": "",
	}
	var panel := _make_panel()

	panel.refresh_encounter_intel(GameSession.GOBLIN_CAMP_ID)

	assert_eq(
		panel.get_node("Content/EncounterIntelEnemies").text,
		tr("information.encounter_enemies") % [tr("battle.enemy.goblin"), 1]
	)


## Stage 5 D5 (Step 6): the new "turns until next threat star" counter mirrors
## the tier-stars row's own visibility threshold (known_tier >=
## INTEL_TIER_LEVEL) and reads GameSession.get_turns_until_next_threat_star()
## directly rather than re-deriving the interval math.
func test_refresh_encounter_intel_shows_turns_until_next_threat_star_once_tier_level_is_known() -> void:
	GameSession.encounter_intel[GameSession.GOBLIN_CAMP_ID] = {
		"discovered": true, "known_tier": GameSession.INTEL_TIER_LEVEL, "quest_id": "",
	}
	var panel := _make_panel()

	panel.refresh_encounter_intel(GameSession.GOBLIN_CAMP_ID)

	assert_true(panel.get_node("Content/EncounterEscalation").visible)
	assert_eq(
		panel.get_node("Content/EncounterEscalation").text,
		tr("information.turns_until_next_threat_star") % GameSession.get_turns_until_next_threat_star(GameSession.GOBLIN_CAMP_ID)
	)


## Once an encounter's threat is already clamped at 5 stars, there is no
## further escalation left to count down to -- the counter must not claim a
## next star is coming (see GameSession.get_turns_until_next_threat_star()'s
## own -1 "capped" sentinel).
func test_refresh_encounter_intel_hides_the_escalation_counter_once_threat_is_capped_at_five() -> void:
	GameSession.world_turn = 1 + GameSession.THREAT_TURN_INTERVAL * 20
	GameSession.encounter_intel[GameSession.GOBLIN_CAMP_ID] = {
		"discovered": true, "known_tier": GameSession.INTEL_TIER_LEVEL, "quest_id": "",
	}
	var panel := _make_panel()

	panel.refresh_encounter_intel(GameSession.GOBLIN_CAMP_ID)

	assert_eq(GameSession.get_turns_until_next_threat_star(GameSession.GOBLIN_CAMP_ID), -1)
	assert_false(panel.get_node("Content/EncounterEscalation").visible)


func test_refresh_encounter_intel_hides_the_escalation_counter_below_tier_level() -> void:
	GameSession.encounter_intel[GameSession.GOBLIN_CAMP_ID] = {
		"discovered": true, "known_tier": GameSession.INTEL_TIER_NONE, "quest_id": "",
	}
	var panel := _make_panel()

	panel.refresh_encounter_intel(GameSession.GOBLIN_CAMP_ID)

	assert_false(panel.get_node("Content/EncounterEscalation").visible)


## Send Party (Stage 5 D5, docs/designs/world-map-and-encounters.md's "Future
## multi-party model"): a strictly additive third call alongside refresh_
## encounter()/refresh_encounter_intel() -- see that pair's own doc comments
## for why Send Party's eligibility (any deployed party at all) is
## independent of Scout intel, so it must not be gated behind refresh_
## encounter()'s own "no intel" early clear. The button only appears once
## there is at least one deployed party eligible to be redirected, and never
## navigates or mutates anything itself -- it only forwards the encounter id
## up to the owning screen (world_map.gd), the same signal-forwarding pattern
## party_selected/adventurer_selected/recruit_selected already use.
func test_send_party_button_appears_once_a_party_is_deployed_and_emits_the_encounter_id() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.depart_selected_party()
	var panel := _make_panel()
	watch_signals(panel)

	panel.refresh_encounter_send_party(GameSession.GOBLIN_CAMP_ID)

	assert_true(panel.get_node("Content/SendPartyButton").visible)
	panel.get_node("Content/SendPartyButton").emit_signal("pressed")
	assert_signal_emitted_with_parameters(panel, "send_party_requested", [GameSession.GOBLIN_CAMP_ID])


func test_send_party_button_stays_hidden_without_any_deployed_party() -> void:
	var panel := _make_panel()

	panel.refresh_encounter_send_party(GameSession.GOBLIN_CAMP_ID)

	assert_false(panel.get_node("Content/SendPartyButton").visible)


## refresh_encounter()'s own "no Scout intel" early clear must not suppress a
## Send Party affordance a later refresh_encounter_send_party() call already
## set -- mirrors world_map.gd's own call order (refresh_encounter(), then
## refresh_encounter_intel(), then refresh_encounter_send_party()).
func test_send_party_button_survives_a_no_intel_refresh_encounter_call_that_follows_it() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.depart_selected_party()
	var panel := _make_panel()

	panel.refresh_encounter_send_party(GameSession.GOBLIN_CAMP_ID)
	panel.refresh_encounter(GameSession.selected_party_id, GameSession.ORC_OUTPOST_ID)
	panel.refresh_encounter_send_party(GameSession.ORC_OUTPOST_ID)

	assert_true(panel.get_node("Content/SendPartyButton").visible)


## Accepting a quest reveals only its documented initial information (Tier
## level + Main monster) -- driven end-to-end through GameSession.accept_quest(),
## not a hand-built intel record.
func test_an_accepted_quests_row_reveals_only_tier_level_and_main_monster() -> void:
	GameSession.quest_posting_roll = func() -> float: return 0.0
	GameSession.reset()
	var quest_id: String = String(GameSession.encounter_intel[GameSession.GOBLIN_CAMP_ID].quest_id)
	GameSession.accept_quest(quest_id)
	var panel := _make_panel()

	panel.refresh_encounter_intel(GameSession.GOBLIN_CAMP_ID)

	assert_true(panel.get_node("Content/EncounterIntelTier").visible)
	assert_true(panel.get_node("Content/EncounterIntelEnemies").visible)
	assert_eq(
		panel.get_node("Content/EncounterIntelEnemies").text,
		tr("information.encounter_enemy_type_only") % tr("battle.enemy.goblin"),
		"Accepting reveals the main monster's type only, never its count"
	)
	assert_true(panel.get_node("Content/EncounterIntelQuest").visible)
	assert_eq(
		panel.get_node("Content/EncounterIntelQuest").text,
		tr("information.encounter_quest") % [tr("guild_hall.quests.status.active"), int(GameSession.get_quest(quest_id).reward_gold)]
	)


## Expired quests remain visible but reward nothing: the quest row keeps
## showing "Expired" rather than disappearing, and its target's own info
## tiers stay exactly as they were at expiry (no reward-related side effect
## on intel).
func test_an_expired_quests_row_stays_visible_with_an_expired_status() -> void:
	GameSession.quest_posting_roll = func() -> float: return 0.0
	GameSession.reset()
	var quest_id: String = String(GameSession.encounter_intel[GameSession.GOBLIN_CAMP_ID].quest_id)
	GameSession.accept_quest(quest_id)
	for _turn in GameSession.QUEST_DURATION_TURNS_PER_TIER + 1:
		GameSession.end_world_turn()
	assert_eq(GameSession.get_quest(quest_id).status, GameSession.QUEST_STATUS_EXPIRED, "Setup: the quest must have expired")
	var panel := _make_panel()

	panel.refresh_encounter_intel(GameSession.GOBLIN_CAMP_ID)

	assert_true(panel.get_node("Content/EncounterIntelQuest").visible, "An expired quest must remain visible, not disappear")
	assert_eq(
		panel.get_node("Content/EncounterIntelQuest").text,
		tr("information.encounter_quest") % [tr("guild_hall.quests.status.expired"), int(GameSession.get_quest(quest_id).reward_gold)]
	)


func test_refresh_encounter_intel_hides_the_quest_row_when_the_encounter_has_no_quest() -> void:
	GameSession.quest_posting_roll = func() -> float: return 100.0  # no quest posts
	GameSession.reset()
	var panel := _make_panel()

	panel.refresh_encounter_intel(GameSession.GOBLIN_CAMP_ID)

	assert_false(panel.get_node("Content/EncounterIntelQuest").visible)


func test_a_bare_refresh_hides_the_stale_intel_section() -> void:
	GameSession.encounter_intel[GameSession.GOBLIN_CAMP_ID] = {
		"discovered": true, "known_tier": GameSession.INTEL_TIER_MONSTER_COUNTS, "quest_id": "",
	}
	var panel := _make_panel()
	panel.refresh_encounter_intel(GameSession.GOBLIN_CAMP_ID)
	assert_true(panel.get_node("Content/EncounterIntelTier").visible)

	panel.refresh()

	assert_false(panel.get_node("Content/EncounterIntelTier").visible)
	assert_false(panel.get_node("Content/EncounterIntelEnemies").visible)
	assert_false(panel.get_node("Content/EncounterIntelQuest").visible)


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
