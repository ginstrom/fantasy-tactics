extends Control

## Renders a single adventurer's real fields (name/class/level/availability)
## from GameManager.route_context_id. Skills, perks, and stats have no real
## data yet (see GameSession.DEFAULT_WARRIOR's stats/progression placeholders)
## so they are only ever labelled TBD here, never invented. An unknown id
## still leaves a working Back path.

@onready var name_label: Label = $Center/VBox/NameLabel
@onready var class_label: Label = $Center/VBox/ClassLabel
@onready var level_label: Label = $Center/VBox/LevelLabel
@onready var status_label: Label = $Center/VBox/StatusLabel
@onready var skills_label: Label = $Center/VBox/SkillsLabel
@onready var perks_label: Label = $Center/VBox/PerksLabel
@onready var stats_label: Label = $Center/VBox/StatsLabel
@onready var not_found_label: Label = $Center/VBox/NotFoundLabel

var unit_id: String = ""


func _ready() -> void:
	unit_id = GameManager.route_context_id
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	var adventurer := GameSession.get_adventurer(unit_id)
	if adventurer.is_empty():
		_show_not_found()
		return
	_show_adventurer(adventurer)


func _show_adventurer(adventurer: Dictionary) -> void:
	not_found_label.visible = false

	name_label.text = adventurer["name"]
	class_label.text = tr("information.class") % adventurer["class"]
	level_label.text = tr("information.level") % adventurer["level"]
	status_label.text = tr("unit_details.status") % adventurer["availability_status"]

	for label in [name_label, class_label, level_label, status_label, skills_label, perks_label, stats_label]:
		label.visible = true


func _show_not_found() -> void:
	not_found_label.visible = true
	for label in [name_label, class_label, level_label, status_label, skills_label, perks_label, stats_label]:
		label.visible = false


func _on_back_pressed() -> void:
	GameManager.go_to_parties()
