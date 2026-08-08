extends CanvasLayer


func _ready() -> void:
	visible = false


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and event.keycode == KEY_F9:
		if GameManager.toggle_debug_menu() == OK:
			get_viewport().set_input_as_handled()


func _run(scenario_id: String) -> void:
	if GameManager.run_debug_scenario(scenario_id) == OK:
		visible = false


func _on_new_campaign_pressed() -> void:
	_run("new_campaign")


func _on_encampment_pressed() -> void:
	_run("encampment")


func _on_party_manager_pressed() -> void:
	_run("party_manager")


func _on_party_ready_pressed() -> void:
	_run("party_ready")


func _on_party_empty_pressed() -> void:
	_run("party_empty")


func _on_world_map_pressed() -> void:
	_run("world_map")


func _on_goblin_camp_pressed() -> void:
	_run("goblin_camp")


func _on_orc_outpost_pressed() -> void:
	_run("orc_outpost")


func _on_ruined_fortress_pressed() -> void:
	_run("ruined_fortress")


func _on_stocked_stores_pressed() -> void:
	_run("stocked_stores")


func _on_super_power_pressed() -> void:
	if GameManager.apply_super_power() == OK:
		visible = false


func _on_recruit_pressed() -> void:
	if GameManager.recruit_adventurer() == OK:
		visible = false
