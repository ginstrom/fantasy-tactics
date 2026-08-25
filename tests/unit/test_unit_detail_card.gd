extends GutTest

const UnitDetailCardScene := preload("res://scenes/ui/unit_detail_card.tscn")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	pass


func _create_card(unit_id: String, show_assignment: bool = false) -> Control:
	var card: Control = UnitDetailCardScene.instantiate()
	card.unit_id = unit_id
	card.show_assignment = show_assignment
	add_child_autofree(card)
	return card


func test_renders_warrior_fields() -> void:
	var card := _create_card(GameSession.WARRIOR_ID)

	assert_eq(card.get_node("NameLabel").text, "Warrior")
	assert_eq(card.get_node("ClassLabel").text, tr("information.class") % "Warrior")
	assert_eq(card.get_node("LevelLabel").text, tr("information.level") % 1)
	assert_eq(card.get_node("StatusLabel").text, tr("unit_details.status") % tr("availability.available"))
	assert_eq(
		card.get_node("StatsLabel").text,
		"XP: 0 / 20 — Hit points: 10 / 10 — Action points: 6 — Guard: 10% — Resistance: 10% — Effects: None"
	)
	assert_false(card.get_node("MpLabel").visible)
	assert_eq(
		card.get_node("EquipmentLabel").text,
		tr("unit_details.equipment") % ["Iron Longsword", 1, 8, "1", "Leather Armor", 10, 10]
	)
	var expected_skills := "Skills:\n   Melee: 60%\n   Missile: 60%\n   Guard: 0%\n   Might: 0%"
	assert_eq(card.get_node("SkillsLabel").text, expected_skills)
	assert_eq(card.get_node("PerksLabel").text, "Perks: None")


func test_renders_scout_fields() -> void:
	GameSession.adventurers.append(GameSession.get_default_scout("scout_001", "Scout"))
	var card := _create_card("scout_001")

	assert_eq(card.get_node("NameLabel").text, "Scout")
	assert_eq(card.get_node("ClassLabel").text, tr("information.class") % "Scout")
	assert_eq(card.get_node("LevelLabel").text, tr("information.level") % 1)
	assert_false(card.get_node("MpLabel").visible)
	assert_eq(
		card.get_node("EquipmentLabel").text,
		tr("unit_details.equipment") % ["Iron Shortbow", 1, 6, "1–8", "Leather Armor", 10, 10]
	)
	var expected_skills := "Skills:\n   Melee: 65%\n   Missile: 65%\n   Guard: 0%\n   Might: 0%"
	assert_eq(card.get_node("SkillsLabel").text, expected_skills)


func test_renders_cleric_fields_and_mp() -> void:
	GameSession.adventurers.append(GameSession.get_default_cleric("cleric_001", "Cleric"))
	var card := _create_card("cleric_001")

	assert_eq(card.get_node("NameLabel").text, "Cleric")
	assert_eq(card.get_node("ClassLabel").text, tr("information.class") % "Cleric")
	assert_true(card.get_node("MpLabel").visible)
	assert_eq(card.get_node("MpLabel").text, tr("unit_details.mp") % [3, 3])
	var expected_skills := "Skills:\n   Melee: 45%\n   Missile: 30%\n   Guard: 10%\n   Might: 1%\n   Spellcasting: 55%"
	assert_eq(card.get_node("SkillsLabel").text, expected_skills)


func test_promote_button_emits_intent_signal_rather_than_mutating_session() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 200.0)
	GameSession.choose_perk(GameSession.WARRIOR_ID, GameSession.WARRIOR_JUGGERNAUT_PERK_ID)
	GameSession.choose_perk(GameSession.WARRIOR_ID, GameSession.WARRIOR_BULWARK_PERK_ID)
	var card := _create_card(GameSession.WARRIOR_ID)

	watch_signals(card)
	var container: VBoxContainer = card.get_node("PromotionOptionsContainer")
	assert_true(container.visible)
	assert_eq(container.get_child_count(), 2)
	var button: Button = container.get_node("PromoteButton_knight")
	button.emit_signal("pressed")

	assert_signal_emitted_with_parameters(card, "promote_requested", [GameSession.WARRIOR_ID, "knight"])
	assert_eq(GameSession.get_adventurer_specialization(GameSession.WARRIOR_ID), "", "Card must emit intent without mutating state")


func test_equipment_activate_and_unequip_emit_intent_signals() -> void:
	GameSession.banked_gear = {"dagger_steel": 1}
	GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "dagger_steel")
	var card := _create_card(GameSession.WARRIOR_ID)

	watch_signals(card)
	var weapons_list: VBoxContainer = card.get_node("WeaponsList")
	assert_eq(weapons_list.get_child_count(), 2)
	var inactive_row := weapons_list.get_child(0)
	var activate_button: Button = inactive_row.get_node("ActivateButton")
	var unequip_button: Button = inactive_row.get_node("UnequipButton")

	activate_button.emit_signal("pressed")
	assert_signal_emitted_with_parameters(card, "activate_item_requested", [GameSession.WARRIOR_ID, "weapon", "longsword_iron"])

	unequip_button.emit_signal("pressed")
	assert_signal_emitted_with_parameters(card, "unequip_item_requested", [GameSession.WARRIOR_ID, "weapon", "longsword_iron"])


func test_heal_button_emits_intent_signal() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.adventurers.append(GameSession.get_default_cleric("cleric_001", "Cleric"))
	GameSession.assign_adventurer_to_selected_party("cleric_001")
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	GameSession.set_adventurer_health(GameSession.WARRIOR_ID, 2)
	var card := _create_card("cleric_001")

	watch_signals(card)
	var picker: OptionButton = card.get_node("HealTargetPicker")
	var heal_button: Button = card.get_node("HealButton")
	assert_true(picker.visible)
	assert_false(heal_button.disabled)

	heal_button.emit_signal("pressed")
	assert_signal_emitted_with_parameters(card, "heal_requested", ["cleric_001", GameSession.WARRIOR_ID])


func test_add_to_party_button_emits_intent_signal() -> void:
	GameSession.create_party()
	var card := _create_card(GameSession.WARRIOR_ID, true)

	watch_signals(card)
	var picker: OptionButton = card.get_node("PartyPicker")
	var add_button: Button = card.get_node("AddToPartyButton")
	assert_true(picker.visible)
	assert_false(add_button.disabled)

	add_button.emit_signal("pressed")
	assert_signal_emitted_with_parameters(card, "add_to_party_requested", [GameSession.WARRIOR_ID, GameSession.FIRST_PARTY_ID])


func test_shows_not_found_for_unknown_unit_id() -> void:
	var card := _create_card("no_such_unit")

	assert_true(card.get_node("NotFoundLabel").visible)
	assert_false(card.get_node("NameLabel").visible)
	assert_false(card.get_node("ClassLabel").visible)
	assert_false(card.get_node("StatsLabel").visible)
