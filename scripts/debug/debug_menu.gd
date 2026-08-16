extends CanvasLayer
## Renders F9 scenario buttons from DebugScenarios' active validated
## manifest (see docs/plans/2026-08-16-debug-menu-json-config), grouped by
## category in the manifest's own source order. Reload is safe: a valid
## edited manifest rebuilds the buttons; an invalid one leaves the current
## buttons exactly as they were and shows the loader's diagnostics instead.

@onready var _status_label: Label = $Panel/Rows/StatusLabel
@onready var _scenario_container: VBoxContainer = $Panel/Rows/ScrollContainer/ScenarioContainer

# Stable scenario id -> its rendered Button, rebuilt on every successful
# load. Exposed (not private in practice, despite the underscore -- see
# docs/dev/testing.md's "private methods are fair game") so tests can press
# a specific scenario's button without depending on tree layout.
var _scenario_buttons: Dictionary = {}


func _ready() -> void:
	visible = false
	_rebuild_scenario_buttons()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and event.keycode == KEY_F9:
		if GameManager.toggle_debug_menu() == OK:
			get_viewport().set_input_as_handled()


func _rebuild_scenario_buttons() -> void:
	for child in _scenario_container.get_children():
		child.queue_free()
	_scenario_buttons.clear()

	for category in DebugScenarios.get_scenarios_by_category():
		var header := Label.new()
		header.text = category.category
		_scenario_container.add_child(header)

		for scenario in category.scenarios:
			var scenario_id: String = scenario.id
			var button := Button.new()
			button.text = scenario.name_key
			button.pressed.connect(func() -> void: _run(scenario_id))
			_scenario_container.add_child(button)
			_scenario_buttons[scenario_id] = button


## Reloads the manifest at `path` (the real config/debug_scenarios.json by
## default; a test-injectable path otherwise -- same convention as
## DebugScenarios.load_scenarios() itself). Rebuilds the buttons only on
## success; a failed reload keeps the current buttons and surfaces the
## loader's diagnostics in _status_label instead of clearing the menu.
func _reload(path: String = DebugScenarios.DEFAULT_MANIFEST_PATH) -> Dictionary:
	var result: Dictionary = DebugScenarios.load_scenarios(path)
	if result.ok:
		_status_label.text = ""
		_rebuild_scenario_buttons()
	else:
		_status_label.text = "; ".join(result.errors)
	return result


func _on_reload_pressed() -> void:
	_reload()


func _run(scenario_id: String) -> void:
	if GameManager.run_debug_scenario(scenario_id) == OK:
		visible = false


func _on_super_power_pressed() -> void:
	if GameManager.apply_super_power() == OK:
		visible = false


func _on_recruit_pressed() -> void:
	if GameManager.recruit_adventurer() == OK:
		visible = false
