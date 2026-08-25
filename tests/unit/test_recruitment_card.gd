extends GutTest

const RecruitmentCardScene := preload("res://scenes/ui/recruitment_card.tscn")


func before_each() -> void:
	GameSession.reset()


func _open_card(candidate_id: String) -> Control:
	var card: Control = RecruitmentCardScene.instantiate()
	add_child_autofree(card)
	card.set_candidate_id(candidate_id)
	return card


func test_recruitment_card_displays_candidate_name_class_and_level() -> void:
	var candidate := GameSession.get_recruitment_candidates()[0]
	var card := _open_card(candidate.id)

	var name_label: Label = card.get_node("%NameLabel")
	var class_label: Label = card.get_node("%ClassLabel")
	var level_label: Label = card.get_node("%LevelLabel")

	assert_eq(name_label.text, candidate.name)
	assert_eq(class_label.text, tr("information.class") % tr("class.%s" % candidate["class"]))
	assert_eq(level_label.text, tr("information.level") % candidate.level)


func test_recruitment_card_displays_cost_and_equipment() -> void:
	var candidate := GameSession.get_recruitment_candidates()[0]
	var card := _open_card(candidate.id)

	var cost_label: Label = card.get_node("%CostLabel")
	var equipment_label: Label = card.get_node("%EquipmentLabel")

	assert_string_contains(cost_label.text, str(candidate.cost))
	var weapon_name := tr(GameSession.get_item_definition(candidate.equipment.weapon).name_key)
	var armor_name := tr(GameSession.get_item_definition(candidate.equipment.armor).name_key)
	assert_string_contains(equipment_label.text, weapon_name)
	assert_string_contains(equipment_label.text, armor_name)


func test_recruitment_card_displays_base_stats() -> void:
	var candidate := GameSession.get_recruitment_candidates()[0]
	var card := _open_card(candidate.id)

	var stats_label: Label = card.get_node("%StatsLabel")
	assert_true(stats_label.visible)
	assert_string_contains(stats_label.text, str(candidate.stats.get("melee", 0)))
	assert_string_contains(stats_label.text, str(candidate.stats.get("missile", 0)))


func test_recruitment_card_displays_mp_for_spellcasters() -> void:
	var offer: Dictionary = GameSession._make_overflow_recruitment_offer("mage")
	offer["cost"] = 10
	GameSession.recruitment_candidates.append(offer)

	var card := _open_card(offer.id)
	var mp_label: Label = card.get_node("%MpLabel")
	assert_true(mp_label.visible)
	assert_string_contains(mp_label.text, "3")


func test_recruit_button_is_disabled_when_gold_is_insufficient() -> void:
	GameSession.gold = 0
	var candidate := GameSession.get_recruitment_candidates()[0]
	var card := _open_card(candidate.id)

	var recruit_button: Button = card.get_node("%RecruitButton")
	assert_true(recruit_button.disabled)


func test_recruit_button_is_enabled_when_gold_is_sufficient() -> void:
	GameSession.gold = 20
	var candidate := GameSession.get_recruitment_candidates()[0]
	var card := _open_card(candidate.id)

	var recruit_button: Button = card.get_node("%RecruitButton")
	assert_false(recruit_button.disabled)


func test_pressing_recruit_button_emits_recruit_requested_signal() -> void:
	GameSession.gold = 20
	var candidate := GameSession.get_recruitment_candidates()[0]
	var card := _open_card(candidate.id)
	watch_signals(card)

	var recruit_button: Button = card.get_node("%RecruitButton")
	recruit_button.emit_signal("pressed")

	assert_signal_emitted_with_parameters(card, "recruit_requested", [candidate.id])


func test_not_found_label_shown_when_candidate_does_not_exist() -> void:
	var card := _open_card("non_existent_candidate_id")

	var not_found_label: Label = card.get_node("%NotFoundLabel")
	var recruit_button: Button = card.get_node("%RecruitButton")

	assert_true(not_found_label.visible)
	assert_false(recruit_button.visible)
