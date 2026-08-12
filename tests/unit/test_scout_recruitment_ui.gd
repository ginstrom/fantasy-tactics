extends GutTest

const UnitDetailsScene := preload("res://scenes/ui/unit_details.tscn")


func before_each() -> void:
	GameSession.reset()
	GameManager.route_context_id = ""
	GameManager.unit_details_origin = ""
	GameManager.add_member_return_party_id = ""


func after_each() -> void:
	GameManager.close_game_menu()
	GameSession.reset_injectable_rolls()
	GameManager.route_context_id = ""
	GameManager.unit_details_origin = ""
	GameManager.add_member_return_party_id = ""


func _next_scout_offer() -> Dictionary:
	GameSession.recruitment_class_roll = func() -> String: return "scout"
	return GameSession._spawn_next_recruitment_offer()


func test_recruitment_candidates_can_include_scouts() -> void:
	var scout_offer := _next_scout_offer()

	assert_eq(scout_offer["class"], "scout")
	assert_eq(scout_offer.equipment.weapon, "shortbow_iron")
	assert_eq(scout_offer.equipment.armor, "leather_armor")
	assert_eq(scout_offer.stats, {"max_health": 12, "attack": 65, "move_range": 3})


func test_recruitment_vacancies_follow_the_injected_scout_then_warrior_class_policy() -> void:
	var classes := ["scout", "warrior"]
	GameSession.recruitment_class_roll = func() -> String: return classes.pop_front()
	GameSession.vacancy_delay_roll = func(_minimum: int, _maximum: int) -> int: return 1
	GameSession.gold = 20

	assert_true(GameSession.purchase_recruit("warrior_002"))
	GameSession.end_world_turn()

	var candidates := GameSession.get_recruitment_candidates()
	assert_eq(candidates.size(), 1)
	assert_eq(candidates[0].id, "scout_002")
	assert_eq(candidates[0]["class"], "scout")
	assert_true(GameSession.purchase_recruit("scout_002"))
	GameSession.end_world_turn()

	candidates = GameSession.get_recruitment_candidates()
	assert_eq(candidates.size(), 1)
	assert_eq(candidates[0]["class"], "warrior")


func test_scout_policy_mints_a_scout_overflow_offer_after_the_fixed_scout_is_claimed() -> void:
	GameSession.recruitment_class_roll = func() -> String: return "scout"
	GameSession.adventurers.append(GameSession.get_default_scout("scout_002", "Scout 2"))
	GameSession.recruitment_candidates.clear()

	var offer := GameSession._spawn_next_recruitment_offer()

	assert_eq(offer["class"], "scout")
	assert_eq(offer.equipment.weapon, "shortbow_iron")
	assert_true(offer.id.begins_with("scout_"))


func test_scout_recruitment_purchases_valid_scout_adventurer() -> void:
	var scout_offer := _next_scout_offer()
	GameSession.recruitment_candidates = [scout_offer]
	GameSession.gold = scout_offer.cost

	assert_true(GameSession.purchase_recruit(scout_offer.id))
	var scout := GameSession.get_adventurer(scout_offer.id)
	assert_eq(GameSession.gold, 0)
	assert_eq(scout["class"], "scout")
	assert_eq(scout.equipment.weapon, "shortbow_iron")
	assert_eq(scout.equipment.armor, "leather_armor")


func test_unit_details_displays_scout_class_and_weapon_range() -> void:
	GameSession.adventurers.append(GameSession.get_default_scout("scout_001", "Scout"))
	GameManager.route_context_id = "scout_001"
	var screen: Control = UnitDetailsScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/ClassLabel").text, "Class: Scout")
	assert_string_contains(screen.get_node("Body/Center/VBox/EquipmentLabel").text, "Range: 1–3")


func test_assigning_scout_to_party_succeeds() -> void:
	GameSession.adventurers.append(GameSession.get_default_scout("scout_001", "Scout"))
	GameSession.create_party()

	assert_true(GameSession.assign_adventurer_to_party("party_001", "scout_001"))
	assert_true(GameSession.get_party("party_001").member_ids.has("scout_001"))
