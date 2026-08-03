extends Node2D

const SIDE_NAME_KEYS := {0: "battle.side.player", 1: "battle.side.enemy"}

@onready var hint: Label = $HUD/Hint
@onready var grid: Node2D = $Grid


func _ready() -> void:
	_on_board_changed()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.go_to_start_menu()


func _on_complete_battle_pressed() -> void:
	GameManager.complete_battle()


func _on_board_changed() -> void:
	var side_name: String = tr(SIDE_NAME_KEYS[grid.active_side])
	var selected_unit = grid.selected_unit

	if selected_unit == null:
		hint.text = tr("battle.hint.select_unit") % side_name
	elif selected_unit.has_moved:
		hint.text = tr("battle.hint.already_moved") % side_name
	else:
		hint.text = tr("battle.hint.select_destination") % side_name
