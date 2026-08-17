extends PanelContainer

const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")

const HEALTHY_THRESHOLD := 0.66
const WOUNDED_THRESHOLD := 0.33

@onready var empty_label: Label = $Content/EmptyLabel
@onready var hovered_section: VBoxContainer = $Content/HoveredSection
@onready var hovered_name_label: Label = $Content/HoveredSection/NameLabel
@onready var hovered_hp_label: Label = $Content/HoveredSection/HpLabel
@onready var hovered_wound_label: Label = $Content/HoveredSection/WoundLabel
@onready var selected_section: VBoxContainer = $Content/SelectedSection
@onready var selected_name_label: Label = $Content/SelectedSection/NameLabel
@onready var selected_class_label: Label = $Content/SelectedSection/ClassLabel
@onready var selected_level_label: Label = $Content/SelectedSection/LevelLabel
@onready var selected_hp_label: Label = $Content/SelectedSection/HpLabel
@onready var selected_ap_label: Label = $Content/SelectedSection/ApLabel
@onready var selected_weapon_label: Label = $Content/SelectedSection/WeaponLabel
@onready var selected_wound_label: Label = $Content/SelectedSection/WoundLabel
@onready var selected_status_label: Label = $Content/SelectedSection/StatusLabel


## Drives both halves of the panel from a single call so a spent AP value (or
## a damage tick) on the still-selected unit updates immediately, even while
## the hovered unit itself hasn't changed -- see battlefield.gd's
## _on_board_changed()/_on_unit_focus_changed(), which both call this with
## grid.hovered_unit/grid.selected_unit rather than the older single
## get_focused_unit() result.
func update_panel(hovered_unit, selected_unit) -> void:
	# A unit hovering itself (hovered_unit == selected_unit) would otherwise
	# duplicate the same details in both halves of the panel -- only show the
	# HoveredSection for a genuinely different unit.
	var show_hovered: bool = hovered_unit != null and hovered_unit != selected_unit
	hovered_section.visible = show_hovered
	if show_hovered:
		_populate_hovered(hovered_unit)

	var show_selected: bool = selected_unit != null
	selected_section.visible = show_selected
	if show_selected:
		_populate_selected(selected_unit)

	empty_label.visible = not show_hovered and not show_selected


func clear() -> void:
	update_panel(null, null)


func _populate_hovered(unit) -> void:
	hovered_name_label.text = unit.display_name

	var is_player: bool = unit.side == BattleControllerScript.Side.PLAYER
	hovered_hp_label.visible = is_player
	hovered_wound_label.visible = not is_player

	if is_player:
		hovered_hp_label.text = tr("battle.unit_info.hp") % [unit.health, unit.max_health]
	else:
		hovered_wound_label.text = tr(_wound_tier_key(unit))


func _populate_selected(unit) -> void:
	selected_name_label.text = unit.display_name

	var is_player: bool = unit.side == BattleControllerScript.Side.PLAYER
	selected_class_label.visible = is_player
	selected_level_label.visible = is_player
	selected_wound_label.visible = not is_player

	if is_player:
		var adventurer := GameSession.get_adventurer(unit.adventurer_id)
		selected_class_label.text = tr("information.class") % adventurer.get("class", "")
		selected_level_label.text = tr("information.level") % adventurer.get("level", 0)
	else:
		selected_wound_label.text = tr(_wound_tier_key(unit))

	selected_hp_label.text = tr("battle.unit_info.hp") % [unit.health, unit.max_health]
	selected_ap_label.text = tr("battle.unit_info.ap") % [unit.action_points_remaining, unit.max_action_points]
	selected_weapon_label.text = tr("battle.unit_info.weapon") % unit.attack_name

	var status_names: Array[String] = []
	for status_id in unit.statuses:
		status_names.append(String(status_id).capitalize())
	selected_status_label.visible = not status_names.is_empty()
	if not status_names.is_empty():
		selected_status_label.text = ", ".join(status_names)


func _wound_tier_key(unit) -> String:
	if unit.max_health <= 0:
		return "battle.unit_info.badly_wounded"
	var health_percent: float = float(unit.health) / float(unit.max_health)
	if health_percent > HEALTHY_THRESHOLD:
		return "battle.unit_info.healthy"
	if health_percent > WOUNDED_THRESHOLD:
		return "battle.unit_info.wounded"
	return "battle.unit_info.badly_wounded"
