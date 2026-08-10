extends Control

## Presents Blacksmith state owned by GameSession. This screen only selects a
## catalog weapon and starts an already-validated durable job; World Map Turns
## are the sole way work advances.

@onready var level_label: Label = $Body/Center/VBox/LevelLabel
@onready var build_button: Button = $Body/Center/VBox/BuildButton
@onready var upgrade_button: Button = $Body/Center/VBox/UpgradeButton
@onready var craft_status_label: Label = $Body/Center/VBox/CraftStatusLabel
@onready var sharpening_status_label: Label = $Body/Center/VBox/SharpeningStatusLabel
@onready var craft_item_option: OptionButton = $Body/Center/VBox/CraftItemOption
@onready var craft_button: Button = $Body/Center/VBox/CraftButton
@onready var sharpen_item_option: OptionButton = $Body/Center/VBox/SharpenItemOption
@onready var sharpen_button: Button = $Body/Center/VBox/SharpenButton


func _ready() -> void:
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	var built := GameSession.blacksmith_level > 0
	level_label.visible = built
	level_label.text = tr("blacksmith.level") % GameSession.blacksmith_level
	build_button.visible = not built
	build_button.disabled = not GameSession.can_build_blacksmith()
	build_button.text = tr("blacksmith.build") % GameSession.BLACKSMITH_BUILD_COST
	upgrade_button.visible = built and GameSession.blacksmith_level < GameSession.BLACKSMITH_MAX_LEVEL
	upgrade_button.disabled = not GameSession.can_upgrade_blacksmith()
	upgrade_button.text = tr("blacksmith.upgrade") % [GameSession.blacksmith_level + 1, GameSession.get_blacksmith_upgrade_cost()]
	craft_status_label.visible = built
	sharpening_status_label.visible = built
	craft_status_label.text = _job_text("blacksmith.crafting", GameSession.blacksmith_craft_job)
	sharpening_status_label.text = _job_text("blacksmith.sharpening", GameSession.blacksmith_sharpening_job)
	_refresh_craft_controls(built)
	_refresh_sharpening_controls(built)


func _job_text(action_key: String, job: Dictionary) -> String:
	if job.is_empty():
		return tr("blacksmith.no_job")
	var item: Dictionary = GameSession.get_item_definition(str(job.item_id))
	return tr(action_key) % [tr(item.name_key), GameSession.get_blacksmith_job_turns_remaining(job)]


func _refresh_craft_controls(built: bool) -> void:
	var selected_item_id := _selected_option_metadata(craft_item_option)
	craft_item_option.clear()
	if not built or not GameSession.blacksmith_craft_job.is_empty():
		craft_item_option.visible = false
		craft_button.visible = false
		return
	for item_id in GameSession.WEAPONS:
		if GameSession._blacksmith_required_level_for_weapon(item_id) <= GameSession.blacksmith_level:
			var item: Dictionary = GameSession.get_item_definition(item_id)
			craft_item_option.add_item(tr(item.name_key))
			craft_item_option.set_item_metadata(craft_item_option.item_count - 1, item_id)
			if item_id == selected_item_id:
				craft_item_option.select(craft_item_option.item_count - 1)
	craft_item_option.visible = craft_item_option.item_count > 0
	craft_button.visible = craft_item_option.visible
	if not craft_item_option.visible:
		return
	var item_id: String = str(craft_item_option.get_selected_metadata())
	craft_button.text = tr("blacksmith.craft") % GameSession.get_blacksmith_craft_cost(item_id)
	craft_button.disabled = GameSession.gold < GameSession.get_blacksmith_craft_cost(item_id)


func _refresh_sharpening_controls(built: bool) -> void:
	var selected_item_id := _selected_option_metadata(sharpen_item_option)
	sharpen_item_option.clear()
	if not built or not GameSession.blacksmith_sharpening_job.is_empty():
		sharpen_item_option.visible = false
		sharpen_button.visible = false
		return
	for item_id in GameSession.WEAPONS:
		if GameSession.banked_gear.get(item_id, 0) > 0:
			var item: Dictionary = GameSession.get_item_definition(item_id)
			sharpen_item_option.add_item(tr(item.name_key))
			sharpen_item_option.set_item_metadata(sharpen_item_option.item_count - 1, item_id)
			if item_id == selected_item_id:
				sharpen_item_option.select(sharpen_item_option.item_count - 1)
	sharpen_item_option.visible = sharpen_item_option.item_count > 0
	sharpen_button.visible = sharpen_item_option.visible
	if not sharpen_item_option.visible:
		return
	var item_id: String = str(sharpen_item_option.get_selected_metadata())
	var cost := GameSession.get_item_sale_price(item_id) * 2
	sharpen_button.text = tr("blacksmith.sharpen") % cost
	sharpen_button.disabled = GameSession.gold < cost


func _selected_option_metadata(option: OptionButton) -> String:
	return "" if option.item_count == 0 else str(option.get_selected_metadata())


func _on_build_button_pressed() -> void:
	GameSession.build_blacksmith()
	refresh()


func _on_upgrade_button_pressed() -> void:
	GameSession.upgrade_blacksmith()
	refresh()


func _on_craft_item_option_item_selected(_index: int) -> void:
	refresh()


func _on_sharpen_item_option_item_selected(_index: int) -> void:
	refresh()


func _on_craft_button_pressed() -> void:
	GameSession.start_blacksmith_craft(str(craft_item_option.get_selected_metadata()))
	refresh()


func _on_sharpen_button_pressed() -> void:
	GameSession.start_sharpening(str(sharpen_item_option.get_selected_metadata()))
	refresh()


func _on_back_pressed() -> void:
	GameManager.go_to_buildings()
