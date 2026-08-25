extends Control

## Reusable Battle Outcome modal dialog (Information Design §2).
## Shows outcome, kills, total and each XP, queued loot, and any level ups.
## Each leveled adventurer provides a View action that opens their level-up modal;
## closing it returns to this Battle Outcome modal.

signal dismissed

@onready var dim_rect: ColorRect = $Dim
@onready var title_label: Label = $Center/Panel/Margin/VBox/Title
@onready var kills_label: Label = $Center/Panel/Margin/VBox/KillsLabel
@onready var xp_label: Label = $Center/Panel/Margin/VBox/XpLabel
@onready var level_up_section: VBoxContainer = $Center/Panel/Margin/VBox/LevelUpSection
@onready var level_up_list: VBoxContainer = $Center/Panel/Margin/VBox/LevelUpSection/LevelUpList
@onready var gold_label: Label = $Center/Panel/Margin/VBox/GoldLabel
@onready var loot_table: Control = $Center/Panel/Margin/VBox/LootTable
@onready var ok_button: Button = $Center/Panel/Margin/VBox/ButtonContainer/OkButton
@onready var level_up: Control = $LevelUp

var summary: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	dim_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	loot_table.configure(false, false)
	ok_button.pressed.connect(_on_ok_pressed)
	level_up.resolved.connect(_on_level_up_resolved)
	if not GameManager.battle_result_summary.is_empty() and summary.is_empty():
		show_summary(GameManager.battle_result_summary)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or level_up.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_ok_pressed()


func show_summary(summary_data: Dictionary) -> void:
	summary = summary_data
	_refresh()
	open()


func open() -> void:
	visible = true
	ok_button.grab_focus()


func close() -> void:
	visible = false


func _refresh() -> void:
	kills_label.text = _format_kills(summary.get("kills_by_type", {}))

	var total_xp: float = summary.get("total_xp", 0.0)
	var member_count: int = maxi(summary.get("party_member_count", 1), 1)
	var each_xp: float = total_xp / member_count
	xp_label.text = tr("battle_result.xp") % [int(round(total_xp)), int(round(each_xp))]

	gold_label.text = tr("battle_result.gold") % summary.get("loot_gold", 0)
	loot_table.set_rows(GameSession.build_loot_rows(
		summary.get("loot_gear_counts", {}), summary.get("loot_mana_crystal_counts", {})
	))
	_refresh_level_ups()


func _refresh_level_ups() -> void:
	for child in level_up_list.get_children():
		level_up_list.remove_child(child)
		child.queue_free()

	var leveled_up_ids: Array = summary.get("leveled_up_ids", [])
	level_up_section.visible = not leveled_up_ids.is_empty()
	for adventurer_id in leveled_up_ids:
		var row := HBoxContainer.new()
		row.name = "Row_%s" % adventurer_id
		row.add_theme_constant_override("separation", 8)

		var name_label := Label.new()
		name_label.name = "NameLabel_%s" % adventurer_id
		var adv := GameSession.get_adventurer(adventurer_id)
		var adv_name: String = adv.get("name", "")
		name_label.text = tr("battle_result.leveled_up") % adv_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var view_button := Button.new()
		view_button.name = "ViewButton_%s" % adventurer_id
		view_button.text = tr("battle_result.view")
		view_button.pressed.connect(_on_view_pressed.bind(adventurer_id))
		row.add_child(view_button)

		level_up_list.add_child(row)


func _on_view_pressed(adventurer_id: String) -> void:
	var health_before: int = int(summary.get("health_before_by_id", {}).get(adventurer_id, 0))
	level_up.show_for_adventurer(adventurer_id, health_before)


func _on_level_up_resolved() -> void:
	level_up.hide()
	ok_button.grab_focus()


func _format_kills(kills_by_type: Dictionary) -> String:
	if kills_by_type.is_empty():
		return tr("battle_result.no_kills")
	var parts: Array = []
	for type_name in kills_by_type:
		parts.append("%s x%d" % [type_name, kills_by_type[type_name]])
	return tr("battle_result.kills") % ", ".join(parts)


func _on_ok_pressed() -> void:
	close()
	dismissed.emit()
	GameManager.battle_result_summary = {}
