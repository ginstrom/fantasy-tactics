extends GutTest

const UnitDetailsScene := preload("res://scenes/ui/unit_details.tscn")


func before_each() -> void:
	GameSession.reset()
	GameManager.route_context_id = ""
	GameManager.unit_details_origin = ""
	GameManager.add_member_return_party_id = ""


func after_each() -> void:
	GameManager.close_game_menu()
	GameManager.route_context_id = ""
	GameManager.unit_details_origin = ""
	GameManager.add_member_return_party_id = ""


func _open_unit_details(adventurer_id: String) -> Control:
	GameManager.route_context_id = adventurer_id
	GameManager.unit_details_origin = ""
	var screen: Control = UnitDetailsScene.instantiate()
	add_child_autofree(screen)
	return screen


func _open_unit_details_from_roster(adventurer_id: String) -> Control:
	GameManager.route_context_id = adventurer_id
	GameManager.unit_details_origin = GameManager.UNIT_DETAILS_ORIGIN_ROSTER
	var screen: Control = UnitDetailsScene.instantiate()
	add_child_autofree(screen)
	return screen


func _open_unit_details_from_add_member(adventurer_id: String, party_id: String) -> Control:
	GameManager.route_context_id = adventurer_id
	GameManager.unit_details_origin = GameManager.UNIT_DETAILS_ORIGIN_ADD_MEMBER
	GameManager.add_member_return_party_id = party_id
	var screen: Control = UnitDetailsScene.instantiate()
	add_child_autofree(screen)
	return screen


func _open_unit_details_from_party_details(adventurer_id: String, party_id: String) -> Control:
	GameManager.route_context_id = adventurer_id
	GameManager.unit_details_origin = GameManager.UNIT_DETAILS_ORIGIN_PARTY_DETAILS
	GameManager.add_member_return_party_id = party_id
	var screen: Control = UnitDetailsScene.instantiate()
	add_child_autofree(screen)
	return screen


## Extracts a single top-level function's own source (from "func <name>(" up
## to the next top-level "func ", or end of file) so a source-string
## assertion can target that function's branches specifically. A whole-file
## substring search is too weak here: both GameManager.go_to_roster() and
## GameManager.go_to_parties() are called from more than one place in
## unit_details.gd (e.g. go_to_roster() is also the Add-to-Party success
## route), so a plain assert_string_contains(source, ...) against the whole
## file would still pass even if _on_back_pressed()'s two branches were
## swapped.
func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start == -1:
		return ""
	var next_func := source.find("\nfunc ", start + 1)
	return source.substr(start) if next_func == -1 else source.substr(start, next_func - start)


func test_unit_details_shows_the_title_and_the_back_action() -> void:
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	assert_eq(screen.get_node("Body/Center/VBox/Title").text, "unit_details.title")
	assert_eq(screen.get_node("Body/Center/VBox/BackButton").text, "ui.back")


func test_shows_the_permanent_player_and_gold_rows() -> void:
	GameSession.player_name = "Aria"
	GameSession.gold = 25
	var screen := _open_unit_details(GameSession.WARRIOR_ID)
	var panel: Control = screen.get_node("%InformationPanel")

	assert_true(panel.get_node("Content/PlayerName").visible)
	assert_eq(panel.get_node("Content/PlayerName").text, tr("information.player") % "Aria")
	assert_true(panel.get_node("Content/Gold").visible)
	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)


func test_reads_the_unit_id_from_route_context() -> void:
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	assert_eq(screen.unit_id, GameSession.WARRIOR_ID)


func test_renders_name_class_level_and_availability_status() -> void:
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	assert_eq(screen.get_node("Body/Center/VBox/NameLabel").text, "Warrior")
	assert_eq(screen.get_node("Body/Center/VBox/ClassLabel").text, tr("information.class") % "Warrior")
	assert_eq(screen.get_node("Body/Center/VBox/LevelLabel").text, tr("information.level") % 1)
	assert_eq(
		screen.get_node("Body/Center/VBox/StatusLabel").text, tr("unit_details.status") % tr("availability.available")
	)


func test_renders_status_for_a_non_available_unit() -> void:
	GameSession.adventurers[0]["availability_status"] = "unavailable"
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	assert_eq(
		screen.get_node("Body/Center/VBox/StatusLabel").text, tr("unit_details.status") % tr("availability.unavailable")
	)


func test_unit_details_uses_the_sessions_availability_query_not_a_private_predicate() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/unit_details.gd")
	assert_false(source.contains("func _is_adventurer_unassigned"))
	assert_string_contains(source, "GameSession.is_adventurer_available")


## Task 3: real progression data replaces the old TBD placeholders — see
## GameSession.get_default_warrior() / get_adventurer() for the exact dict shape
## (stats.attack, progression.xp/skill_points/perks) these labels read.
##
## Step 5 (docs/plans/2026-08-21-stage-2-party-readiness/
## 05-shared-tactical-profile-migration.md): this line previously mislabeled
## Guard (effective_defense) as "Damage resistance" and Resistance
## (effective_resistance) as "Magic resistance" -- see unit_details.gd's own
## doc comment on this exact line. Values are unchanged (a default Warrior's
## Guard and Resistance are both still 10%); only the labels are corrected.
func test_stats_label_shows_xp_raw_and_effective_attack_and_health() -> void:
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	assert_eq(
		screen.get_node("Body/Center/VBox/StatsLabel").text,
		"XP: 0 / 20 — Hit points: 10 / 10 — Action points: 6 — Guard: 10% — Resistance: 10% — Effects: None"
	)
	assert_true(screen.get_node("Body/Center/VBox/StatsLabel").visible)


func test_stats_label_reflects_leveling_xp_attack_and_health_changes() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 25.5)
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	assert_true(screen.get_node("Body/Center/VBox/StatsLabel").text.contains("XP: 25 / 50"))


func test_equipment_label_shows_the_equipped_weapon_and_armor() -> void:
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	assert_eq(
		screen.get_node("Body/Center/VBox/EquipmentLabel").text,
		tr("unit_details.equipment") % ["Iron Longsword", 1, 8, "1", "Leather Armor", 10, 10],
		"A fresh Warrior wears the default Iron Longsword (1-8 damage, range 1) and Leather Armor (10% defense / 10% resistance)"
	)
	assert_true(screen.get_node("Body/Center/VBox/EquipmentLabel").visible)


func test_equipment_label_reflects_a_changed_weapon() -> void:
	GameSession.banked_gear = {"dagger_steel": 1}
	GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "dagger_steel")
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	assert_eq(
		screen.get_node("Body/Center/VBox/EquipmentLabel").text,
		tr("unit_details.equipment") % ["Steel Dagger", 2, 5, "1", "Leather Armor", 10, 10]
	)


func test_weapons_list_shows_the_lone_carried_weapon_as_equipped_with_no_action_buttons() -> void:
	var screen := _open_unit_details(GameSession.WARRIOR_ID)
	var weapons_list: VBoxContainer = screen.get_node("Body/Center/VBox/WeaponsList")

	assert_eq(weapons_list.get_child_count(), 1)
	var row := weapons_list.get_child(0)
	assert_eq(row.get_node("NameLabel").text, tr("unit_details.equipped_marker") % "Iron Longsword")
	assert_null(row.get_node_or_null("ActivateButton"))
	assert_null(row.get_node_or_null("UnequipButton"))


func test_armor_list_shows_the_lone_carried_armor_as_equipped_with_no_action_buttons() -> void:
	var screen := _open_unit_details(GameSession.WARRIOR_ID)
	var armor_list: VBoxContainer = screen.get_node("Body/Center/VBox/ArmorList")

	assert_eq(armor_list.get_child_count(), 1)
	var row := armor_list.get_child(0)
	assert_eq(row.get_node("NameLabel").text, tr("unit_details.equipped_marker") % "Leather Armor")
	assert_null(row.get_node_or_null("ActivateButton"))


func test_weapons_list_shows_a_non_active_carried_weapon_with_activate_and_unequip() -> void:
	GameSession.banked_gear = {"dagger_steel": 1}
	GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "dagger_steel")
	var screen := _open_unit_details(GameSession.WARRIOR_ID)
	var weapons_list: VBoxContainer = screen.get_node("Body/Center/VBox/WeaponsList")

	assert_eq(weapons_list.get_child_count(), 2)
	var inactive_row := weapons_list.get_child(0)
	assert_eq(inactive_row.get_node("NameLabel").text, "Iron Longsword")
	assert_not_null(inactive_row.get_node_or_null("ActivateButton"))
	assert_not_null(inactive_row.get_node_or_null("UnequipButton"))
	var active_row := weapons_list.get_child(1)
	assert_eq(active_row.get_node("NameLabel").text, tr("unit_details.equipped_marker") % "Steel Dagger")
	assert_null(active_row.get_node_or_null("ActivateButton"))
	assert_null(active_row.get_node_or_null("UnequipButton"))


func test_pressing_activate_switches_the_active_weapon_and_refreshes_the_screen() -> void:
	GameSession.banked_gear = {"dagger_steel": 1}
	GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "dagger_steel")
	var screen := _open_unit_details(GameSession.WARRIOR_ID)
	var weapons_list: VBoxContainer = screen.get_node("Body/Center/VBox/WeaponsList")
	var activate_button: Button = weapons_list.get_child(0).get_node("ActivateButton")

	activate_button.emit_signal("pressed")

	assert_eq(GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment.weapon, "longsword_iron")
	assert_eq(
		screen.get_node("Body/Center/VBox/WeaponsList").get_child(0).get_node("NameLabel").text,
		tr("unit_details.equipped_marker") % "Iron Longsword",
		"The screen must refresh in place to show the new active item"
	)


func test_pressing_unequip_returns_the_item_to_the_bank_and_refreshes_the_list() -> void:
	GameSession.banked_gear = {"dagger_steel": 1}
	GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "dagger_steel")
	var screen := _open_unit_details(GameSession.WARRIOR_ID)
	var weapons_list: VBoxContainer = screen.get_node("Body/Center/VBox/WeaponsList")
	var unequip_button: Button = weapons_list.get_child(0).get_node("UnequipButton")

	unequip_button.emit_signal("pressed")

	assert_eq(GameSession.banked_gear.longsword_iron, 1)
	assert_eq(
		screen.get_node("Body/Center/VBox/WeaponsList").get_child_count(), 1,
		"The list must refresh in place after unequipping"
	)


func test_weapons_and_armor_lists_are_hidden_for_an_unknown_unit() -> void:
	GameManager.route_context_id = "no_such_id"
	var screen: Control = UnitDetailsScene.instantiate()
	add_child_autofree(screen)

	assert_false(screen.get_node("Body/Center/VBox/WeaponsList").visible)
	assert_false(screen.get_node("Body/Center/VBox/ArmorList").visible)
	assert_false(screen.get_node("Body/Center/VBox/WeaponsLabel").visible)
	assert_false(screen.get_node("Body/Center/VBox/ArmorLabel").visible)


func test_skills_label_shows_class_skills_and_growth_tiers() -> void:
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	var expected_skills := "Skills:\n   Melee: 60%\n   Missile: 60%\n   Guard: 0%\n   Might: 0%"
	assert_eq(screen.get_node("Body/Center/VBox/SkillsLabel").text, expected_skills)
	assert_true(screen.get_node("Body/Center/VBox/SkillsLabel").visible)


## Step 5 (docs/plans/2026-08-21-stage-2-party-readiness/
## 05-shared-tactical-profile-migration.md): a spellcasting class (Cleric
## today) gets a Spellcasting row appended to the same Skills list, reading
## adventurer.stats.spellcasting -- the exact stat CLASS_DEFINITIONS.cleric.
## base_stats already carries (see game_session.gd's own doc comment on that
## key). A non-spellcasting class (see the Warrior test just above, whose
## exact-match assertion already has no such row) never gets this row at
## all, not a "Spellcasting: 0%" placeholder.
func test_skills_label_appends_spellcasting_for_a_cleric() -> void:
	GameSession.adventurers.append(GameSession.get_default_cleric("cleric_test", "Test Cleric"))
	var screen := _open_unit_details("cleric_test")

	var expected_skills := "Skills:\n   Melee: 45%\n   Missile: 30%\n   Guard: 10%\n   Might: 1%\n   Spellcasting: 55%"
	assert_eq(screen.get_node("Body/Center/VBox/SkillsLabel").text, expected_skills)


## Stage 5 D3: this whole row is already fully generic (adventurer.stats.
## has("spellcasting")), so Mage's own base_stats.spellcasting (20) shows
## with zero code change -- this test locks that in. Melee/Guard/Might show
## as their base values (n/a for Mage means never GROWS, not that the row
## disappears -- unlike Spellcasting, which is conditional on the class
## carrying the key at all).
func test_skills_label_shows_missile_and_spellcasting_for_a_mage() -> void:
	GameSession.adventurers.append(GameSession.get_default_mage("mage_test", "Test Mage"))
	var screen := _open_unit_details("mage_test")

	var expected_skills := "Skills:\n   Melee: 15%\n   Missile: 25%\n   Guard: 0%\n   Might: 0%\n   Spellcasting: 20%"
	assert_eq(screen.get_node("Body/Center/VBox/SkillsLabel").text, expected_skills)


func test_perks_label_shows_none_before_any_perk_is_chosen() -> void:
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	assert_eq(
		screen.get_node("Body/Center/VBox/PerksLabel").text,
		"Perks: None"
	)
	assert_true(screen.get_node("Body/Center/VBox/PerksLabel").visible)


## Step 2 (docs/plans/2026-08-21-stage-2-party-readiness/
## 02-class-progression-and-perks.md): a chosen class-owned perk shows both
## its localized name and its effect, read fresh from GameSession's own
## perk-metadata readers (get_perk_display_name()/get_perk_effect_
## description()) rather than any copy hard-coded in unit_details.gd.
func test_perks_label_shows_a_chosen_class_perk_with_its_effect() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 50.0)
	GameSession.choose_perk(GameSession.WARRIOR_ID, GameSession.WARRIOR_JUGGERNAUT_PERK_ID)
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	assert_eq(
		screen.get_node("Body/Center/VBox/PerksLabel").text,
		"Perks:\n* %s (%s)" % [
			tr("perk.warrior_juggernaut.name"),
			tr("perk.warrior_juggernaut.effect") % GameSession.WARRIOR_JUGGERNAUT_HP_PERCENT,
		]
	)


## choose_perk() no longer accepts bonus_move as a new choice (it is retired
## -- see GameSession.choose_perk()'s doc comment), so a legacy holder is
## simulated the same way GameSession's own migration tests do: direct
## progression.perks mutation, standing in for a pre-Stage-2 save. It must
## still render with its own name and effect, exactly like any other perk.
func test_perks_label_shows_a_legacy_bonus_move_perk_with_its_effect() -> void:
	GameSession.adventurers[0].progression.perks.append(GameSession.BONUS_MOVE_PERK_ID)
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	assert_eq(
		screen.get_node("Body/Center/VBox/PerksLabel").text,
		"Perks:\n* %s (%s)" % [tr("perk.bonus_move.name"), tr("perk.bonus_move.effect")]
	)


## --- Knight specialization promotion (Stage 5 D4) ---------------------------

func test_no_promote_button_shows_before_both_root_perks_are_chosen() -> void:
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	var container: VBoxContainer = screen.get_node("Body/Center/VBox/PromotionOptionsContainer")
	assert_false(container.visible)
	assert_eq(container.get_child_count(), 0)


## The decision-contract shape task 1 of the step file asks for, at the UI
## layer: promotion is unavailable (no button) until both root perks are
## chosen, becomes available (a button appears) once they are, and pressing
## it actually promotes through GameSession.promote_adventurer() -- never
## deciding eligibility itself (this screen re-reads GameSession.get_
## available_specializations() fresh every refresh(), same as every other
## section on this screen).
func test_promote_button_appears_once_eligible_and_promotes_on_press() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 200.0)  # level 6
	GameSession.choose_perk(GameSession.WARRIOR_ID, GameSession.WARRIOR_JUGGERNAUT_PERK_ID)
	GameSession.choose_perk(GameSession.WARRIOR_ID, GameSession.WARRIOR_BULWARK_PERK_ID)
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	var container: VBoxContainer = screen.get_node("Body/Center/VBox/PromotionOptionsContainer")
	assert_true(container.visible)
	assert_eq(container.get_child_count(), 1)
	var button: Button = container.get_node("PromoteButton_knight")
	assert_eq(button.text, tr("unit_details.promote_button") % tr("class.knight"))

	button.pressed.emit()

	assert_eq(GameSession.get_adventurer_specialization(GameSession.WARRIOR_ID), "knight")
	assert_false(container.visible, "Already promoted -- the button disappears on refresh")
	assert_eq(container.get_child_count(), 0)


func test_class_label_shows_the_specialization_once_promoted() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 200.0)
	GameSession.choose_perk(GameSession.WARRIOR_ID, GameSession.WARRIOR_JUGGERNAUT_PERK_ID)
	GameSession.choose_perk(GameSession.WARRIOR_ID, GameSession.WARRIOR_BULWARK_PERK_ID)
	GameSession.promote_adventurer(GameSession.WARRIOR_ID, "knight")
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	assert_eq(
		screen.get_node("Body/Center/VBox/ClassLabel").text,
		tr("information.class") % (tr("unit_details.class_specialized") % [tr("class.warrior"), tr("class.knight")])
	)


## Knight's own two perks (Shield Bash/Chain Blow) render through the exact
## same generic Perks list every other class's perks already use -- no
## unit_details.gd code change was needed for this once GameSession's own
## get_available_perks()/choose_perk() were extended to include a promoted
## adventurer's specialization perks (see PerksLabel's existing rendering).
func test_perks_label_shows_a_chosen_knight_perk_with_its_effect() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 200.0)
	GameSession.choose_perk(GameSession.WARRIOR_ID, GameSession.WARRIOR_JUGGERNAUT_PERK_ID)
	GameSession.choose_perk(GameSession.WARRIOR_ID, GameSession.WARRIOR_BULWARK_PERK_ID)
	GameSession.promote_adventurer(GameSession.WARRIOR_ID, "knight")
	GameSession.choose_perk(GameSession.WARRIOR_ID, GameSession.KNIGHT_SHIELD_BASH_PERK_ID)
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	assert_string_contains(
		screen.get_node("Body/Center/VBox/PerksLabel").text,
		"* %s (%s)" % [
			tr("perk.knight_shield_bash.name"),
			tr("perk.knight_shield_bash.effect") % GameSession.OFF_BALANCE_GUARD_PENALTY,
		]
	)


## --- Durable MP row and "Heal party member" (docs/plans/2026-08-21-
## stage-2-party-readiness/03-persistent-mp-temple-and-details-healing.md) ---

func test_mp_row_is_hidden_for_a_non_caster() -> void:
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	assert_false(screen.get_node("Body/Center/VBox/MpLabel").visible)


func test_mp_row_shows_current_and_max_mp_for_a_mage() -> void:
	GameSession.adventurers.append(GameSession.get_default_mage("mage_test", "Test Mage"))
	GameSession.set_adventurer_mp("mage_test", 2)
	var screen := _open_unit_details("mage_test")

	var mp_label: Label = screen.get_node("Body/Center/VBox/MpLabel")
	assert_true(mp_label.visible)
	assert_eq(mp_label.text, tr("unit_details.mp") % [2, 3])


## Stage 5 D3 fix: a Mage now carries the same MP-shaped resource this Heal
## section keys off (effective_max_mp > 0), but Mage's class knows no "heal"
## spell -- the section must stay hidden, not offer a Heal action a Mage
## doesn't have (see GameSession.get_legal_heal_targets()'s own class-spell
## gate, which this screen's _refresh_heal_section() reads through).
func test_heal_section_stays_hidden_for_a_mage_despite_carrying_mp() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var mage: Dictionary = GameSession.get_default_mage("mage_test", "Test Mage")
	GameSession.adventurers.append(mage)
	GameSession.assign_adventurer_to_selected_party("mage_test")
	GameSession.depart_selected_party()
	GameSession.set_adventurer_health("warrior_001", 2)
	var screen := _open_unit_details("mage_test")

	assert_false(screen.get_node("Body/Center/VBox/HealButton").visible)
	assert_false(screen.get_node("Body/Center/VBox/HealTargetPicker").visible)


func test_mp_row_shows_current_and_max_mp_for_a_cleric() -> void:
	GameSession.adventurers.append(GameSession.get_default_cleric("cleric_test", "Test Cleric"))
	GameSession.set_adventurer_mp("cleric_test", 1)
	var screen := _open_unit_details("cleric_test")

	var mp_label: Label = screen.get_node("Body/Center/VBox/MpLabel")
	assert_true(mp_label.visible)
	assert_eq(mp_label.text, tr("unit_details.mp") % [1, 3])


func test_heal_section_is_hidden_for_a_non_caster() -> void:
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	assert_false(screen.get_node("Body/Center/VBox/HealTargetPicker").visible)
	assert_false(screen.get_node("Body/Center/VBox/HealButton").visible)
	assert_false(screen.get_node("Body/Center/VBox/HealExplanationLabel").visible)


## The target picker lists only a legal, damaged target -- a full-health
## party member is excluded entirely, never offered as a doomed pick (see
## GameSession.get_legal_heal_targets()'s own doc comment).
func test_heal_target_picker_lists_only_a_legal_damaged_party_member() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.adventurers.append(GameSession.get_default_cleric("cleric_test", "Test Cleric"))
	GameSession.assign_adventurer_to_selected_party("cleric_test")
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	GameSession.set_adventurer_health(GameSession.WARRIOR_ID, 2)
	var screen := _open_unit_details("cleric_test")

	var picker: OptionButton = screen.get_node("Body/Center/VBox/HealTargetPicker")
	var button: Button = screen.get_node("Body/Center/VBox/HealButton")
	assert_true(picker.visible)
	assert_eq(picker.item_count, 1)
	assert_eq(picker.get_item_text(0), "Warrior")
	assert_eq(picker.get_item_metadata(0), GameSession.WARRIOR_ID)
	assert_true(button.visible)
	assert_false(button.disabled)
	assert_false(screen.get_node("Body/Center/VBox/HealExplanationLabel").visible)


## Pressing Heal invokes GameSession.heal_party_member() through the button
## signal -- this screen never assigns health or MP itself -- and refreshes
## both the target's HP row and the caster's own MP row in place.
## The Cleric heals itself here (a legal target, see GameSession.
## _is_legal_heal_target()) so both of this screen's own rows -- its HP
## (StatsLabel) and its MP (MpLabel) -- are observable on the very page the
## button lives on, proving refresh() re-reads both after the transaction
## rather than either being stale until a later navigation.
func test_pressing_heal_invokes_the_transaction_and_refreshes_both_rows() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.adventurers.append(GameSession.get_default_cleric("cleric_test", "Test Cleric"))
	GameSession.assign_adventurer_to_selected_party("cleric_test")
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	GameSession.set_adventurer_health("cleric_test", 2)
	GameSession.heal_amount_roll = func(_min_value: int, _max_value: int) -> int: return 5
	var screen := _open_unit_details("cleric_test")
	var picker: OptionButton = screen.get_node("Body/Center/VBox/HealTargetPicker")
	assert_eq(picker.get_item_metadata(0), "cleric_test", "The damaged Cleric is its own only legal, useful target here")
	var button: Button = screen.get_node("Body/Center/VBox/HealButton")

	button.emit_signal("pressed")

	assert_eq(GameSession.get_current_health("cleric_test"), 7)
	assert_eq(GameSession.get_current_mp("cleric_test"), 2)
	assert_eq(
		screen.get_node("Body/Center/VBox/MpLabel").text, tr("unit_details.mp") % [2, 3],
		"The MP row must refresh in place after healing"
	)
	assert_true(
		screen.get_node("Body/Center/VBox/StatsLabel").text.contains("Hit points: 7 / 12"),
		"The healed caster's own HP row must refresh in place after healing"
	)
	GameSession.reset_injectable_rolls()


## No legal, affordable target exists (the sole party member is already at
## full HP) -- the action must disable itself and explain why rather than
## offering a target guaranteed to do nothing.
func test_heal_action_is_disabled_and_explained_when_no_legal_target_exists() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.adventurers.append(GameSession.get_default_cleric("cleric_test", "Test Cleric"))
	GameSession.assign_adventurer_to_selected_party("cleric_test")
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	var screen := _open_unit_details("cleric_test")

	var picker: OptionButton = screen.get_node("Body/Center/VBox/HealTargetPicker")
	var button: Button = screen.get_node("Body/Center/VBox/HealButton")
	var explanation: Label = screen.get_node("Body/Center/VBox/HealExplanationLabel")
	assert_false(picker.visible)
	assert_true(button.visible, "The disabled action itself must still be present, not merely absent")
	assert_true(button.disabled)
	assert_true(explanation.visible)
	assert_eq(explanation.text, "unit_details.heal_unavailable")


## Same disabled-and-explained outcome when the Cleric simply has no MP left,
## even though a legal, damaged target does exist.
func test_heal_action_is_disabled_and_explained_when_the_caster_lacks_mp() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.adventurers.append(GameSession.get_default_cleric("cleric_test", "Test Cleric"))
	GameSession.assign_adventurer_to_selected_party("cleric_test")
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	GameSession.set_adventurer_health(GameSession.WARRIOR_ID, 2)
	GameSession.set_adventurer_mp("cleric_test", 0)
	var screen := _open_unit_details("cleric_test")

	var button: Button = screen.get_node("Body/Center/VBox/HealButton")
	assert_true(button.disabled)
	assert_true(screen.get_node("Body/Center/VBox/HealExplanationLabel").visible)


func test_an_unknown_unit_id_shows_a_not_found_message_and_hides_detail_rows() -> void:
	var screen := _open_unit_details("no_such_adventurer")

	assert_true(screen.get_node("Body/Center/VBox/NotFoundLabel").visible)
	assert_eq(screen.get_node("Body/Center/VBox/NotFoundLabel").text, "unit_details.not_found")
	assert_false(screen.get_node("Body/Center/VBox/NameLabel").visible)
	assert_false(screen.get_node("Body/Center/VBox/ClassLabel").visible)
	assert_false(screen.get_node("Body/Center/VBox/LevelLabel").visible)
	assert_false(screen.get_node("Body/Center/VBox/StatusLabel").visible)
	assert_false(screen.get_node("Body/Center/VBox/SkillsLabel").visible)
	assert_false(screen.get_node("Body/Center/VBox/PerksLabel").visible)
	assert_false(screen.get_node("Body/Center/VBox/StatsLabel").visible)
	assert_false(screen.get_node("Body/Center/VBox/EquipmentLabel").visible)
	assert_false(screen.get_node("Body/Center/VBox/MpLabel").visible)
	assert_false(screen.get_node("Body/Center/VBox/HealTargetPicker").visible)
	assert_false(screen.get_node("Body/Center/VBox/HealButton").visible)
	assert_false(screen.get_node("Body/Center/VBox/HealExplanationLabel").visible)


func test_an_unknown_unit_id_still_has_a_safe_working_back_button() -> void:
	var screen := _open_unit_details("no_such_adventurer")

	assert_false(screen.get_node("Body/Center/VBox/BackButton").disabled)
	screen.get_node("Body/Center/VBox/BackButton").emit_signal("pressed")

	assert_eq(GameManager.route_context_id, "")


func test_back_button_returns_to_parties() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/unit_details.gd")

	assert_string_contains(source, "GameManager.go_to_parties()")


func test_back_button_clears_only_the_ui_route_context() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	screen.get_node("Body/Center/VBox/BackButton").emit_signal("pressed")

	assert_eq(GameManager.route_context_id, "")
	assert_false(GameSession.has_deployed_party(), "Back must never deploy or otherwise mutate the party")
	assert_eq(GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids, [GameSession.WARRIOR_ID])


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	var screen := _open_unit_details(GameSession.WARRIOR_ID)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)


func test_assignment_section_is_hidden_when_not_opened_via_roster() -> void:
	GameSession.create_party()
	var screen := _open_unit_details(GameSession.WARRIOR_ID)

	assert_false(screen.get_node("Body/Center/VBox/PartyPicker").visible)
	assert_false(screen.get_node("Body/Center/VBox/AddToPartyButton").visible)
	assert_false(screen.get_node("Body/Center/VBox/AssignmentExplanationLabel").visible)


func test_roster_origin_shows_an_enabled_picker_and_action_for_an_available_unassigned_unit() -> void:
	GameSession.create_party()
	var screen := _open_unit_details_from_roster(GameSession.WARRIOR_ID)

	var picker: OptionButton = screen.get_node("Body/Center/VBox/PartyPicker")
	var add_button: Button = screen.get_node("Body/Center/VBox/AddToPartyButton")
	assert_true(picker.visible)
	assert_true(add_button.visible)
	assert_false(add_button.disabled)
	assert_false(screen.get_node("Body/Center/VBox/AssignmentExplanationLabel").visible)
	assert_eq(picker.item_count, 1)
	assert_eq(picker.get_item_text(0), "Party 1")
	assert_eq(picker.get_item_metadata(0), GameSession.FIRST_PARTY_ID)


func test_roster_origin_with_no_encamped_party_shows_a_disabled_explained_action() -> void:
	var screen := _open_unit_details_from_roster(GameSession.WARRIOR_ID)

	var picker: OptionButton = screen.get_node("Body/Center/VBox/PartyPicker")
	var add_button: Button = screen.get_node("Body/Center/VBox/AddToPartyButton")
	assert_false(picker.visible)
	assert_true(add_button.visible, "The disabled action itself should still be present, not merely absent")
	assert_true(add_button.disabled)
	assert_true(screen.get_node("Body/Center/VBox/AssignmentExplanationLabel").visible)
	assert_eq(
		screen.get_node("Body/Center/VBox/AssignmentExplanationLabel").text, "unit_details.no_eligible_party"
	)


func test_roster_origin_hides_the_assignment_section_for_an_assigned_unit() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var screen := _open_unit_details_from_roster(GameSession.WARRIOR_ID)

	assert_false(screen.get_node("Body/Center/VBox/PartyPicker").visible)
	assert_false(screen.get_node("Body/Center/VBox/AddToPartyButton").visible)
	assert_false(screen.get_node("Body/Center/VBox/AssignmentExplanationLabel").visible)


func test_roster_origin_hides_the_assignment_section_for_an_unavailable_unit() -> void:
	GameSession.create_party()
	GameSession.adventurers[0]["availability_status"] = "unavailable"
	var screen := _open_unit_details_from_roster(GameSession.WARRIOR_ID)

	assert_false(screen.get_node("Body/Center/VBox/PartyPicker").visible)
	assert_false(screen.get_node("Body/Center/VBox/AddToPartyButton").visible)


## The seeded Warrior itself never joins this party — it stays unassigned and
## available so it remains eligible to open from Roster — but the sole
## encamped party is filled to the level-1 cap by four other adventurers.
## Just like the existing "no encamped party" case, a Roster-origin unit with
## no room to join anywhere shows the disabled, explained action rather than
## an empty-but-technically-present picker (see
## test_roster_origin_with_no_encamped_party_shows_a_disabled_explained_action).
func test_roster_origin_excludes_a_full_party_and_shows_a_disabled_explained_action() -> void:
	GameSession.create_party()
	# Fill the party to the level-1 cap with four adventurers other than the
	# seeded Warrior: the three other starting warriors plus one recruit.
	GameSession.assign_adventurer_to_selected_party(GameSession.adventurers[1].id)
	GameSession.assign_adventurer_to_selected_party(GameSession.adventurers[2].id)
	GameSession.assign_adventurer_to_selected_party(GameSession.adventurers[3].id)
	GameSession.recruit_adventurer()
	GameSession.assign_adventurer_to_selected_party(GameSession.adventurers.back().id)
	var screen := _open_unit_details_from_roster(GameSession.WARRIOR_ID)

	var picker: OptionButton = screen.get_node("Body/Center/VBox/PartyPicker")
	var add_button: Button = screen.get_node("Body/Center/VBox/AddToPartyButton")
	assert_false(picker.visible)
	assert_true(add_button.visible, "The disabled action itself should still be present, not merely absent")
	assert_true(add_button.disabled)
	assert_true(screen.get_node("Body/Center/VBox/AssignmentExplanationLabel").visible)
	assert_eq(
		screen.get_node("Body/Center/VBox/AssignmentExplanationLabel").text, "unit_details.no_eligible_party"
	)


func test_pressing_add_to_party_assigns_the_chosen_party_and_routes_to_roster() -> void:
	GameSession.create_party()
	var screen := _open_unit_details_from_roster(GameSession.WARRIOR_ID)
	var add_button: Button = screen.get_node("Body/Center/VBox/AddToPartyButton")

	add_button.emit_signal("pressed")

	assert_eq(GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids, [GameSession.WARRIOR_ID])
	assert_eq(GameManager.route_context_id, "")
	assert_eq(GameManager.unit_details_origin, "")


func test_a_stale_party_selection_fails_safely_and_refreshes_in_place() -> void:
	GameSession.create_party()
	var screen := _open_unit_details_from_roster(GameSession.WARRIOR_ID)
	var add_button: Button = screen.get_node("Body/Center/VBox/AddToPartyButton")
	# The chosen party stops being eligible while the screen is still open.
	GameSession.parties[0].deployed = true

	add_button.emit_signal("pressed")

	assert_eq(GameSession.get_party(GameSession.FIRST_PARTY_ID).member_ids, [] as Array[String])
	assert_eq(GameManager.route_context_id, GameSession.WARRIOR_ID, "A stale selection must not navigate away")
	assert_true(
		screen.get_node("Body/Center/VBox/AssignmentExplanationLabel").visible,
		"No encamped party remains, so the disabled explanation should show"
	)
	assert_true(screen.get_node("Body/Center/VBox/AddToPartyButton").disabled)


## A whole-file search for "GameManager.go_to_roster()" would also match the
## Add-to-Party success path, so this scopes the assertion to
## _on_back_pressed()'s own source and checks each branch of its single
## if/else independently: the branch guarded by the Roster-origin check must
## route to Roster, and the other branch must route to Parties. This fails
## if the two branches are ever swapped, unlike a plain substring search.
func test_back_button_routes_to_roster_for_roster_origin_and_to_parties_otherwise() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/unit_details.gd")
	var back_pressed_source := _function_source(source, "_on_back_pressed")
	var branches := back_pressed_source.split("else", true, 1)

	assert_eq(
		branches.size(),
		2,
		"_on_back_pressed must branch once on origin (if/else) for this test to discriminate the branches"
	)
	assert_string_contains(
		branches[0],
		"UNIT_DETAILS_ORIGIN_ROSTER",
		"The first branch must be the one guarded by the Roster-origin check"
	)
	assert_string_contains(
		branches[0],
		"GameManager.go_to_roster()",
		"The Roster-origin branch specifically must route to Roster"
	)
	assert_string_contains(
		branches[1], "GameManager.go_to_parties()", "Every other origin must route to Parties"
	)


func test_back_button_from_roster_origin_routes_to_roster_and_clears_context() -> void:
	var screen := _open_unit_details_from_roster(GameSession.WARRIOR_ID)

	screen.get_node("Body/Center/VBox/BackButton").emit_signal("pressed")

	assert_eq(GameManager.route_context_id, "")
	assert_eq(GameManager.unit_details_origin, "")


func test_back_from_add_member_returns_to_the_same_partys_candidate_list() -> void:
	GameSession.create_party()
	var screen := _open_unit_details_from_add_member(GameSession.WARRIOR_ID, GameSession.FIRST_PARTY_ID)

	screen.get_node("Body/Center/VBox/BackButton").emit_signal("pressed")

	assert_eq(GameManager.route_context_id, GameSession.FIRST_PARTY_ID)
	assert_eq(GameManager.unit_details_origin, "")
	assert_eq(GameManager.add_member_return_party_id, "")


func test_back_from_add_member_with_a_stale_party_falls_back_to_parties() -> void:
	GameSession.create_party()
	var screen := _open_unit_details_from_add_member(GameSession.WARRIOR_ID, GameSession.FIRST_PARTY_ID)
	GameSession.reset()

	screen.get_node("Body/Center/VBox/BackButton").emit_signal("pressed")

	assert_eq(GameManager.route_context_id, "")
	assert_eq(GameManager.unit_details_origin, "")
	assert_eq(GameManager.add_member_return_party_id, "")


func test_back_from_a_deployed_partys_member_returns_to_that_party_details() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	var screen := _open_unit_details_from_party_details(GameSession.WARRIOR_ID, GameSession.FIRST_PARTY_ID)

	screen.get_node("Body/Center/VBox/BackButton").emit_signal("pressed")

	assert_eq(GameManager.route_context_id, GameSession.FIRST_PARTY_ID)
	assert_eq(GameManager.unit_details_origin, "")
