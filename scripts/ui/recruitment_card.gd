class_name RecruitmentCard
extends VBoxContainer

## Card body for a recruitment candidate's details.
## Displays candidate name, class, level, cost, base stats, and starting gear.
## Emits recruit_requested(candidate_id) rather than mutating state directly.

signal recruit_requested(candidate_id: String)

var candidate_id: String = ""

@onready var name_label: Label = %NameLabel
@onready var class_label: Label = %ClassLabel
@onready var level_label: Label = %LevelLabel
@onready var cost_label: Label = %CostLabel
@onready var stats_label: Label = %StatsLabel
@onready var mp_label: Label = %MpLabel
@onready var equipment_label: Label = %EquipmentLabel
@onready var recruit_button: Button = %RecruitButton
@onready var not_found_label: Label = %NotFoundLabel


func _ready() -> void:
	if is_instance_valid(recruit_button):
		recruit_button.pressed.connect(_on_recruit_button_pressed)
	refresh()


func set_candidate_id(id: String) -> void:
	candidate_id = id
	refresh()


func refresh() -> void:
	if not is_inside_tree() or not is_instance_valid(name_label):
		return
	var candidate := _find_candidate(candidate_id)
	if candidate.is_empty():
		_show_not_found()
		return
	_show_candidate(candidate)


func _show_candidate(candidate: Dictionary) -> void:
	not_found_label.visible = false
	name_label.text = str(candidate.get("name", ""))
	class_label.text = tr("information.class") % tr("class.%s" % str(candidate.get("class", "")))
	level_label.text = tr("information.level") % int(candidate.get("level", 1))
	cost_label.text = "%s %d" % [tr("information.recruitment_cost"), int(candidate.get("cost", 0))]

	var stats: Dictionary = candidate.get("stats", {})
	var max_health: int = int(stats.get("max_health", 10))
	var melee: int = int(stats.get("melee", 0))
	var missile: int = int(stats.get("missile", 0))
	var guard: int = int(stats.get("guard", 0))
	var might: int = int(stats.get("might", 0))
	var spellcasting: int = int(stats.get("spellcasting", 0))

	var stats_parts: Array[String] = [
		"Hit points: %d" % max_health,
		"Melee: %d%%" % melee,
		"Missile: %d%%" % missile,
		"Guard: %d%%" % guard,
		"Might: %d%%" % might,
	]
	if spellcasting > 0:
		stats_parts.append("Spellcasting: %d%%" % spellcasting)
	stats_label.text = " — ".join(stats_parts)

	var class_id := str(candidate.get("class", ""))
	var class_def: Dictionary = GameSession.CLASS_DEFINITIONS.get(class_id, {})
	var mp_max: int = int(class_def.get("mp_max", 0))
	if stats.has("mp_max"):
		mp_max = int(stats.mp_max)
	mp_label.visible = mp_max > 0
	if mp_max > 0:
		mp_label.text = tr("recruitment_card.mp") % mp_max

	var equipment: Dictionary = candidate.get("equipment", {})
	var weapon_id: String = str(equipment.get("weapon", ""))
	var armor_id: String = str(equipment.get("armor", ""))
	var weapon_def := GameSession.get_item_definition(weapon_id)
	var armor_def := GameSession.get_item_definition(armor_id)
	var weapon_name: String = tr(weapon_def.get("name_key", weapon_id)) if not weapon_def.is_empty() else weapon_id
	var armor_name: String = tr(armor_def.get("name_key", armor_id)) if not armor_def.is_empty() else armor_id
	equipment_label.text = tr("recruitment_card.equipment") % [weapon_name, armor_name]

	var cost := int(candidate.get("cost", 0))
	recruit_button.text = tr("information.recruit")
	recruit_button.visible = true
	recruit_button.disabled = GameSession.gold < cost

	for label in [name_label, class_label, level_label, cost_label, stats_label, equipment_label]:
		label.visible = true


func _show_not_found() -> void:
	not_found_label.visible = true
	for label in [name_label, class_label, level_label, cost_label, stats_label, mp_label, equipment_label, recruit_button]:
		label.visible = false


func _find_candidate(id: String) -> Dictionary:
	if id.is_empty():
		return {}
	for candidate in GameSession.get_recruitment_candidates():
		if candidate.get("id", "") == id:
			return candidate
	return {}


func _on_recruit_button_pressed() -> void:
	if candidate_id != "":
		recruit_requested.emit(candidate_id)
