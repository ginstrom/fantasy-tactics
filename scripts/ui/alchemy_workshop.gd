extends Control

## Presents the single alchemy job owned by GameSession. World Map Turns are
## the only way its seven-turn craft timer advances.

@onready var level_label: Label = $Body/Center/VBox/LevelLabel
@onready var build_button: Button = $Body/Center/VBox/BuildButton
@onready var upgrade_button: Button = $Body/Center/VBox/UpgradeButton
@onready var craft_status_label: Label = $Body/Center/VBox/CraftStatusLabel
@onready var craft_item_option: OptionButton = $Body/Center/VBox/CraftItemOption
@onready var craft_button: Button = $Body/Center/VBox/CraftButton


func _ready() -> void:
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	var built := GameSession.alchemy_workshop_level > 0
	level_label.visible = built
	level_label.text = tr("alchemy_workshop.level") % GameSession.alchemy_workshop_level
	build_button.visible = not built
	build_button.disabled = not GameSession.can_build_alchemy_workshop()
	build_button.text = tr("alchemy_workshop.build") % GameSession.ALCHEMY_WORKSHOP_BUILD_COST
	upgrade_button.visible = built and GameSession.alchemy_workshop_level < GameSession.ALCHEMY_WORKSHOP_MAX_LEVEL
	upgrade_button.disabled = not GameSession.can_upgrade_alchemy_workshop()
	upgrade_button.text = tr("alchemy_workshop.upgrade") % [GameSession.alchemy_workshop_level + 1, GameSession.ALCHEMY_WORKSHOP_UPGRADE_COST]
	craft_status_label.visible = built
	craft_status_label.text = _job_text()
	_refresh_craft_controls(built)


func _job_text() -> String:
	if GameSession.alchemy_craft_job.is_empty():
		return tr("alchemy_workshop.no_job")
	var item: Dictionary = GameSession.get_item_definition(str(GameSession.alchemy_craft_job.item_id))
	return tr("alchemy_workshop.crafting") % [tr(item.name_key), GameSession.get_alchemy_job_turns_remaining()]


func _refresh_craft_controls(built: bool) -> void:
	var selected_item_id := _selected_option_metadata(craft_item_option)
	craft_item_option.clear()
	if not built or not GameSession.alchemy_craft_job.is_empty():
		craft_item_option.visible = false
		craft_button.visible = false
		return
	for item_id in GameSession.POTIONS:
		var item: Dictionary = GameSession.get_item_definition(item_id)
		if int(item.required_level) > GameSession.alchemy_workshop_level:
			continue
		craft_item_option.add_item(tr(item.name_key))
		craft_item_option.set_item_metadata(craft_item_option.item_count - 1, item_id)
		if item_id == selected_item_id:
			craft_item_option.select(craft_item_option.item_count - 1)
	craft_item_option.visible = craft_item_option.item_count > 0
	craft_button.visible = craft_item_option.visible
	if not craft_item_option.visible:
		return
	var item_id: String = str(craft_item_option.get_selected_metadata())
	var item: Dictionary = GameSession.get_item_definition(item_id)
	craft_button.text = tr("alchemy_workshop.craft") % int(item.gold_cost)
	craft_button.disabled = GameSession.gold < int(item.gold_cost)


func _selected_option_metadata(option: OptionButton) -> String:
	return "" if option.item_count == 0 else str(option.get_selected_metadata())


func _on_build_button_pressed() -> void:
	GameSession.build_alchemy_workshop()
	refresh()


func _on_upgrade_button_pressed() -> void:
	GameSession.upgrade_alchemy_workshop()
	refresh()


func _on_craft_item_option_item_selected(_index: int) -> void:
	refresh()


func _on_craft_button_pressed() -> void:
	GameSession.start_alchemy_craft(str(craft_item_option.get_selected_metadata()))
	refresh()


func _on_back_pressed() -> void:
	GameManager.go_to_buildings()
