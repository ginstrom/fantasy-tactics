extends PanelContainer

const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")

const HEALTHY_THRESHOLD := 0.66
const WOUNDED_THRESHOLD := 0.33

@onready var empty_label: Label = $Content/EmptyLabel
@onready var name_label: Label = $Content/NameLabel
@onready var class_label: Label = $Content/ClassLabel
@onready var level_label: Label = $Content/LevelLabel
@onready var hp_label: Label = $Content/HpLabel
@onready var wound_label: Label = $Content/WoundLabel


func clear() -> void:
	empty_label.visible = true
	name_label.visible = false
	class_label.visible = false
	level_label.visible = false
	hp_label.visible = false
	wound_label.visible = false


func show_unit(unit) -> void:
	if unit == null:
		clear()
		return

	empty_label.visible = false
	name_label.visible = true
	name_label.text = unit.display_name

	var is_player: bool = unit.side == BattleControllerScript.Side.PLAYER
	class_label.visible = is_player
	level_label.visible = is_player
	hp_label.visible = is_player
	wound_label.visible = not is_player

	if is_player:
		var adventurer := GameSession.get_adventurer(unit.adventurer_id)
		class_label.text = tr("information.class") % adventurer.get("class", "")
		level_label.text = tr("information.level") % adventurer.get("level", 0)
		hp_label.text = tr("battle.unit_info.hp") % [unit.health, unit.max_health]
	else:
		wound_label.text = tr(_wound_tier_key(unit))


func _wound_tier_key(unit) -> String:
	if unit.max_health <= 0:
		return "battle.unit_info.badly_wounded"
	var health_percent: float = float(unit.health) / float(unit.max_health)
	if health_percent > HEALTHY_THRESHOLD:
		return "battle.unit_info.healthy"
	if health_percent > WOUNDED_THRESHOLD:
		return "battle.unit_info.wounded"
	return "battle.unit_info.badly_wounded"
