class_name UnitDetailCard
extends VBoxContainer

## Card body for an adventurer's details.
## Presents full progression, stats, skills, perks, equipment, promotion,
## healing, and assignment eligibility from GameSession.
## Emits intents rather than directly mutating domain routing or global state.

signal promote_requested(unit_id: String, specialization_id: String)
signal activate_item_requested(unit_id: String, slot: String, item_id: String)
signal unequip_item_requested(unit_id: String, slot: String, item_id: String)
signal heal_requested(caster_id: String, target_id: String)
signal add_to_party_requested(unit_id: String, party_id: String)

var unit_id: String = ""
var show_assignment: bool = false
var origin: String = ""

@onready var name_label: Label = %NameLabel
@onready var class_label: Label = %ClassLabel
@onready var level_label: Label = %LevelLabel
@onready var status_label: Label = %StatusLabel
@onready var skills_label: Label = %SkillsLabel
@onready var perks_label: Label = %PerksLabel
@onready var promotion_options_container: VBoxContainer = %PromotionOptionsContainer
@onready var stats_label: Label = %StatsLabel
@onready var mp_label: Label = %MpLabel
@onready var equipment_label: Label = %EquipmentLabel
@onready var weapons_label: Label = %WeaponsLabel
@onready var weapons_list: VBoxContainer = %WeaponsList
@onready var armor_label: Label = %ArmorLabel
@onready var armor_list: VBoxContainer = %ArmorList
@onready var not_found_label: Label = %NotFoundLabel
@onready var heal_explanation_label: Label = %HealExplanationLabel
@onready var heal_target_picker: OptionButton = %HealTargetPicker
@onready var heal_button: Button = %HealButton
@onready var assignment_explanation_label: Label = %AssignmentExplanationLabel
@onready var party_picker: OptionButton = %PartyPicker
@onready var add_to_party_button: Button = %AddToPartyButton


func _ready() -> void:
	if is_instance_valid(heal_button):
		heal_button.pressed.connect(_on_heal_button_pressed)
	if is_instance_valid(add_to_party_button):
		add_to_party_button.pressed.connect(_on_add_to_party_pressed)
	refresh()


func set_unit_id(id: String) -> void:
	unit_id = id
	refresh()


func refresh() -> void:
	if not is_inside_tree() or not is_instance_valid(name_label):
		return
	var adventurer := GameSession.get_adventurer(unit_id)
	if adventurer.is_empty():
		_show_not_found()
		return
	_show_adventurer(adventurer)
	_refresh_assignment_section(adventurer)


func _show_adventurer(adventurer: Dictionary) -> void:
	not_found_label.visible = false

	name_label.text = adventurer["name"]
	var specialization_id: String = GameSession.get_adventurer_specialization(str(adventurer["id"]))
	class_label.text = (
		tr("information.class") % (
			tr("unit_details.class_specialized") % [tr("class.%s" % adventurer["class"]), tr("class.%s" % specialization_id)]
		) if not specialization_id.is_empty()
		else tr("information.class") % tr("class.%s" % adventurer["class"])
	)
	level_label.text = tr("information.level") % adventurer["level"]
	status_label.text = tr("unit_details.status") % tr("availability.%s" % adventurer["availability_status"])

	var adventurer_id: String = adventurer["id"]
	var xp_display: int = int(floor(adventurer.progression.xp))
	var xp_to_next_level: int = int(GameSession.get_level_xp_threshold(adventurer["level"] + 1))
	var current_health: int = GameSession.get_current_health(adventurer_id)
	var effective_max_health: int = GameSession.get_effective_max_health(adventurer_id)
	var effective_defense: int = GameSession.get_effective_defense(adventurer_id)
	var effective_resistance: int = GameSession.get_effective_resistance(adventurer_id)

	stats_label.text = (
		"XP: %d / %d — Hit points: %d / %d — Action points: 6 — Guard: %d%% — Resistance: %d%% — Effects: None"
		% [xp_display, xp_to_next_level, current_health, effective_max_health, effective_defense, effective_resistance]
	)

	var effective_max_mp: int = GameSession.get_effective_max_mp(adventurer_id)
	mp_label.visible = effective_max_mp > 0
	if effective_max_mp > 0:
		mp_label.text = tr("unit_details.mp") % [GameSession.get_current_mp(adventurer_id), effective_max_mp]

	var weapon_damage_range: Vector2i = GameSession.get_effective_weapon_damage_range(adventurer_id)
	var weapon_attack_range: Vector2i = GameSession.get_effective_weapon_attack_range(adventurer_id)
	var weapon_range_text := (
		str(weapon_attack_range.x)
		if weapon_attack_range.x == weapon_attack_range.y
		else "%d–%d" % [weapon_attack_range.x, weapon_attack_range.y]
	)
	equipment_label.text = (
		tr("unit_details.equipment")
		% [
			GameSession.get_effective_weapon_name(adventurer_id), weapon_damage_range.x, weapon_damage_range.y,
			weapon_range_text,
			GameSession.get_effective_armor_name(adventurer_id),
			GameSession.get_effective_defense(adventurer_id), GameSession.get_effective_resistance(adventurer_id),
		]
	)

	var skills_lines: Array[String] = ["Skills:"]
	for skill in ["melee", "missile", "guard", "might"]:
		skills_lines.append("   %s: %d%%" % [skill.capitalize(), adventurer.stats.get(skill, 0)])
	if adventurer.stats.has("spellcasting"):
		skills_lines.append("   Spellcasting: %d%%" % adventurer.stats.spellcasting)
	skills_label.text = "\n".join(skills_lines)

	var perks: Array = adventurer.progression.get("perks", [])
	var excluded_ids: Array[String] = []
	for status in GameSession.get_perk_tree_status(adventurer_id):
		if status.state == "excluded":
			excluded_ids.append(status.id)
	if perks.is_empty() and excluded_ids.is_empty():
		perks_label.text = "Perks: None"
	else:
		var perk_lines: Array[String] = ["Perks:"]
		for perk_id in perks:
			perk_lines.append("* %s" % _get_perk_display_name(perk_id))
		for perk_id in excluded_ids:
			perk_lines.append("* %s" % (tr("unit_details.perk_excluded") % GameSession.get_perk_display_name(perk_id)))
		perks_label.text = "\n".join(perk_lines)

	_refresh_equipment_sections(adventurer)
	_refresh_heal_section(adventurer_id, effective_max_mp)
	_refresh_promotion_section(adventurer_id)

	for label in [
		name_label, class_label, level_label, status_label, skills_label, perks_label, stats_label,
		equipment_label, weapons_label, weapons_list, armor_label, armor_list,
	]:
		label.visible = true


func _show_not_found() -> void:
	not_found_label.visible = true
	for label in [
		name_label, class_label, level_label, status_label, skills_label, perks_label, stats_label,
		equipment_label, weapons_label, weapons_list, armor_label, armor_list,
	]:
		label.visible = false
	mp_label.visible = false
	_hide_heal_section()
	_hide_assignment_section()
	_hide_promotion_section()


func _refresh_promotion_section(adventurer_id: String) -> void:
	for child in promotion_options_container.get_children():
		promotion_options_container.remove_child(child)
		child.queue_free()

	var available: Array[String] = GameSession.get_available_specializations(adventurer_id)
	promotion_options_container.visible = not available.is_empty()
	for specialization_id in available:
		var button := Button.new()
		button.name = "PromoteButton_%s" % specialization_id
		button.text = tr("unit_details.promote_button") % tr("class.%s" % specialization_id)
		button.pressed.connect(func() -> void: promote_requested.emit(unit_id, specialization_id))
		promotion_options_container.add_child(button)


func _hide_promotion_section() -> void:
	promotion_options_container.visible = false
	for child in promotion_options_container.get_children():
		promotion_options_container.remove_child(child)
		child.queue_free()


func _refresh_equipment_sections(adventurer: Dictionary) -> void:
	var equipment: Dictionary = adventurer.equipment
	_populate_inventory_list(weapons_list, equipment.weapon_inventory, equipment.weapon, "weapon")
	_populate_inventory_list(armor_list, equipment.armor_inventory, equipment.armor, "armor")


func _populate_inventory_list(
	list_container: VBoxContainer, item_ids: Array, active_item_id: String, slot: String
) -> void:
	for child in list_container.get_children():
		list_container.remove_child(child)
		child.queue_free()

	for item_id in item_ids:
		var row := HBoxContainer.new()
		var is_active: bool = item_id == active_item_id
		var item := GameSession.get_item_definition(item_id)
		var item_name: String = tr(item.name_key) if not item.is_empty() else item_id

		var row_name_label := Label.new()
		row_name_label.name = "NameLabel"
		row_name_label.text = tr("unit_details.equipped_marker") % item_name if is_active else item_name
		row.add_child(row_name_label)

		if not is_active:
			var activate_button := Button.new()
			activate_button.name = "ActivateButton"
			activate_button.text = tr("unit_details.activate")
			activate_button.pressed.connect(func() -> void: activate_item_requested.emit(unit_id, slot, item_id))
			row.add_child(activate_button)

			var unequip_button := Button.new()
			unequip_button.name = "UnequipButton"
			unequip_button.text = tr("unit_details.unequip")
			unequip_button.pressed.connect(func() -> void: unequip_item_requested.emit(unit_id, slot, item_id))
			row.add_child(unequip_button)

		list_container.add_child(row)


func _refresh_heal_section(adventurer_id: String, effective_max_mp: int) -> void:
	if effective_max_mp <= 0 or not GameSession.adventurer_knows_spell(adventurer_id, "heal"):
		_hide_heal_section()
		return

	var target_ids: Array[String] = GameSession.get_legal_heal_targets(adventurer_id)
	heal_target_picker.clear()
	for target_id in target_ids:
		var target := GameSession.get_adventurer(target_id)
		heal_target_picker.add_item(target.get("name", target_id))
		heal_target_picker.set_item_metadata(heal_target_picker.item_count - 1, target_id)

	var can_heal: bool = (
		GameSession.get_current_mp(adventurer_id) >= GameSession.DETAILS_HEAL_MP_COST and not target_ids.is_empty()
	)
	heal_target_picker.visible = can_heal
	heal_button.visible = true
	heal_button.disabled = not can_heal
	heal_explanation_label.visible = not can_heal


func _hide_heal_section() -> void:
	heal_target_picker.visible = false
	heal_target_picker.clear()
	heal_button.visible = false
	heal_explanation_label.visible = false


func _on_heal_button_pressed() -> void:
	var selected_index := heal_target_picker.get_selected()
	if selected_index < 0:
		return
	var target_id: String = heal_target_picker.get_item_metadata(selected_index)
	heal_requested.emit(unit_id, target_id)


func _refresh_assignment_section(adventurer: Dictionary) -> void:
	var eligible_for_assignment: bool = (
		(show_assignment or origin == GameManager.UNIT_DETAILS_ORIGIN_ROSTER)
		and GameSession.is_adventurer_available(adventurer["id"])
	)
	if not eligible_for_assignment:
		_hide_assignment_section()
		return

	var encamped_parties: Array[Dictionary] = []
	for party in GameSession.get_encamped_parties():
		if party.member_ids.size() < GameSession.get_max_party_size():
			encamped_parties.append(party)
	party_picker.clear()
	for party in encamped_parties:
		party_picker.add_item(party.name)
		party_picker.set_item_metadata(party_picker.item_count - 1, party.id)

	var has_eligible_party := not encamped_parties.is_empty()
	assignment_explanation_label.visible = not has_eligible_party
	party_picker.visible = has_eligible_party
	add_to_party_button.visible = true
	add_to_party_button.disabled = not has_eligible_party


func _hide_assignment_section() -> void:
	assignment_explanation_label.visible = false
	party_picker.visible = false
	party_picker.clear()
	add_to_party_button.visible = false


func _on_add_to_party_pressed() -> void:
	var selected_index := party_picker.get_selected()
	if selected_index < 0:
		return
	var party_id: String = party_picker.get_item_metadata(selected_index)
	add_to_party_requested.emit(unit_id, party_id)


func _get_perk_display_name(perk_id: String) -> String:
	var perk_name := GameSession.get_perk_display_name(perk_id)
	var effect := GameSession.get_perk_effect_description(perk_id)
	return "%s (%s)" % [perk_name, effect] if not effect.is_empty() else perk_name
