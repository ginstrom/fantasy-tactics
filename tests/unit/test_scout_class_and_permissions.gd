extends GutTest


func before_each() -> void:
	GameSession.reset()


func test_get_default_scout_returns_a_valid_equipped_adventurer() -> void:
	var scout: Dictionary = GameSession.get_default_scout("scout_001", "Scout")

	assert_eq(scout.id, "scout_001")
	assert_eq(scout.name, "Scout")
	assert_eq(scout.class, "scout")
	assert_eq(scout.equipment.weapon, "shortbow_iron")
	assert_eq(scout.equipment.armor, "leather_armor")
	assert_eq(scout.stats, {"max_health": 12, "attack": 65, "move_range": 3})
	GameSession.adventurers.append(scout)
	assert_eq(GameSession.get_effective_defense("scout_001"), 10)
	assert_eq(GameSession.get_effective_resistance("scout_001"), 10)


func test_weapon_catalog_includes_bows_with_their_range_and_category() -> void:
	assert_eq(
		GameSession.WEAPONS.shortbow_iron,
		{"name_key": "item.shortbow_iron", "slot": "weapon", "category": "bow", "damage_min": 1, "damage_max": 6, "min_range": 1, "max_range": 3, "price": 30}
	)
	assert_eq(
		GameSession.WEAPONS.hunting_bow_steel,
		{"name_key": "item.hunting_bow_steel", "slot": "weapon", "category": "bow", "damage_min": 2, "damage_max": 7, "min_range": 1, "max_range": 4, "price": 75}
	)


func test_scout_allows_bows_and_daggers_but_not_two_handed_swords() -> void:
	GameSession.adventurers.append(GameSession.get_default_scout("scout_001", "Scout"))

	assert_true(GameSession.can_adventurer_equip_item("scout_001", "shortbow_iron"))
	assert_true(GameSession.can_adventurer_equip_item("scout_001", "dagger_iron"))
	assert_false(GameSession.can_adventurer_equip_item("scout_001", "two_handed_sword_iron"))
	assert_true(GameSession.can_adventurer_equip_item("scout_001", "leather_armor"))


func test_warrior_equip_from_bank_rejects_a_bow_without_mutating_state() -> void:
	GameSession.banked_gear = {"shortbow_iron": 1}
	var equipment_before: Dictionary = GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment.duplicate(true)

	assert_false(GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "shortbow_iron"))
	assert_eq(GameSession.banked_gear, {"shortbow_iron": 1})
	assert_eq(GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment, equipment_before)


func test_warrior_cannot_activate_a_carried_bow_without_mutating_state() -> void:
	GameSession.adventurers[0].equipment.weapon_inventory.append("shortbow_iron")
	var equipment_before: Dictionary = GameSession.adventurers[0].equipment.duplicate(true)

	assert_false(GameSession.activate_carried_item(GameSession.WARRIOR_ID, "weapon", "shortbow_iron"))
	assert_eq(GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment, equipment_before)


func test_transfer_rejects_base_and_owned_bows_for_a_warrior_without_mutation() -> void:
	GameSession.adventurers.append(GameSession.get_default_scout("scout_001", "Scout"))
	GameSession.adventurers[1].equipment.weapon_inventory.append("dagger_iron")
	GameSession.adventurers[1].equipment.weapon = "dagger_iron"
	var base_state_before: Array = GameSession.adventurers.duplicate(true)

	assert_false(GameSession.transfer_carried_item("scout_001", GameSession.WARRIOR_ID, "shortbow_iron"))
	assert_eq(GameSession.adventurers, base_state_before)

	GameSession.banked_gear = {"shortbow_iron": 1}
	assert_true(GameSession.materialize_banked_item_instance("shortbow_iron", "gear_00042"))
	assert_true(GameSession.equip_item_from_bank("scout_001", "gear_00042"))
	assert_true(GameSession.activate_carried_item("scout_001", "weapon", "dagger_iron"))
	var instance_state_before: Array = GameSession.adventurers.duplicate(true)

	assert_false(GameSession.transfer_carried_item("scout_001", GameSession.WARRIOR_ID, "gear_00042"))
	assert_eq(GameSession.adventurers, instance_state_before)


func test_import_rejects_class_incompatible_base_and_owned_weapons_without_mutating_state() -> void:
	GameSession.adventurers.append(GameSession.get_default_scout("scout_001", "Scout"))
	var base_snapshot := GameSession.export_campaign_snapshot()
	base_snapshot.adventurers[1].equipment.weapon_inventory = ["two_handed_sword_iron"]
	base_snapshot.adventurers[1].equipment.weapon = "two_handed_sword_iron"
	var before := GameSession.export_campaign_snapshot()

	var base_result := GameSession.import_campaign_snapshot(base_snapshot)

	assert_false(base_result.ok)
	assert_string_contains(base_result.error, "class incompatible")
	assert_eq(GameSession.export_campaign_snapshot(), before)

	GameSession.banked_gear = {"shortbow_iron": 1}
	assert_true(GameSession.materialize_banked_item_instance("shortbow_iron", "gear_00042"))
	var instance_snapshot := GameSession.export_campaign_snapshot()
	instance_snapshot.banked_item_instance_ids = []
	instance_snapshot.adventurers[0].equipment.weapon_inventory.append("gear_00042")
	instance_snapshot.adventurers[0].equipment.weapon = "gear_00042"
	before = GameSession.export_campaign_snapshot()

	var instance_result := GameSession.import_campaign_snapshot(instance_snapshot)

	assert_false(instance_result.ok)
	assert_string_contains(instance_result.error, "class incompatible")
	assert_eq(GameSession.export_campaign_snapshot(), before)


func test_localization_keys_resolve_in_english() -> void:
	assert_eq(tr("item.shortbow_iron"), "Iron Shortbow")
	assert_eq(tr("item.hunting_bow_steel"), "Steel Hunting Bow")
	assert_eq(tr("class.scout"), "Scout")
