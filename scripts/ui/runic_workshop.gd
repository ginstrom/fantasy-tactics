extends Control

@onready var level_label: Label = $Body/Center/VBox/LevelLabel
@onready var build_button: Button = $Body/Center/VBox/BuildButton
@onready var upgrade_button: Button = $Body/Center/VBox/UpgradeButton
@onready var craft_status_label: Label = $Body/Center/VBox/CraftStatusLabel
@onready var armor_option: OptionButton = $Body/Center/VBox/ArmorOption
@onready var craft_button: Button = $Body/Center/VBox/CraftButton


func _ready() -> void:
	refresh()


func refresh() -> void:
	var built := GameSession.runic_workshop_level > 0
	level_label.visible = built
	level_label.text = tr("runic_workshop.level") % GameSession.runic_workshop_level
	build_button.visible = not built
	build_button.disabled = not GameSession.can_build_runic_workshop()
	build_button.text = tr("runic_workshop.build") % GameSession.RUNIC_WORKSHOP_BUILD_COST
	upgrade_button.visible = built and GameSession.runic_workshop_level < GameSession.RUNIC_WORKSHOP_MAX_LEVEL
	upgrade_button.disabled = not GameSession.can_upgrade_runic_workshop()
	upgrade_button.text = tr("runic_workshop.upgrade") % [GameSession.runic_workshop_level + 1, GameSession.RUNIC_WORKSHOP_UPGRADE_COST]
	craft_status_label.visible = built
	craft_status_label.text = _job_text()
	_refresh_craft_controls(built)


func _job_text() -> String:
	if GameSession.runic_craft_job.is_empty():
		return tr("runic_workshop.no_job")
	return tr("runic_workshop.socketing") % GameSession.get_runic_job_turns_remaining()


func _refresh_craft_controls(built: bool) -> void:
	armor_option.clear()
	if not built or not GameSession.runic_craft_job.is_empty():
		armor_option.visible = false
		craft_button.visible = false
		return
	for instance_id in GameSession.owned_item_instances:
		var item: Dictionary = GameSession.get_item_definition(instance_id)
		if str(item.get("slot", "")) != "armor":
			continue
		armor_option.add_item(tr(item.name_key))
		armor_option.set_item_metadata(armor_option.item_count - 1, instance_id)
	armor_option.visible = armor_option.item_count > 0
	craft_button.visible = armor_option.visible
	craft_button.text = tr("runic_workshop.socket") % GameSession.THORN_RUNE_GOLD_COST
	craft_button.disabled = GameSession.gold < GameSession.THORN_RUNE_GOLD_COST


func _on_build_button_pressed() -> void:
	GameSession.build_runic_workshop()
	refresh()


func _on_upgrade_button_pressed() -> void:
	GameSession.upgrade_runic_workshop()
	refresh()


func _on_craft_button_pressed() -> void:
	GameSession.start_runic_craft(str(armor_option.get_selected_metadata()))
	refresh()


func _on_back_pressed() -> void:
	GameManager.go_to_buildings()
