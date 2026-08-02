extends Node2D

const SIDE_NAMES := {0: "Player", 1: "Enemy"}

@onready var hint: Label = $HUD/Hint
@onready var battlefield: Node2D = $Battlefield


func _ready() -> void:
	_on_board_changed()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.go_to_main_menu()


func _on_complete_battle_pressed() -> void:
	GameManager.complete_battle()


func _on_board_changed() -> void:
	var side_name: String = SIDE_NAMES[battlefield.active_side]
	var selected_unit = battlefield.selected_unit

	if selected_unit == null:
		hint.text = "%s turn. Click a unit to select it. Esc: main menu." % side_name
	elif selected_unit.has_moved:
		hint.text = "%s turn. This unit has already moved. Select another unit." % side_name
	else:
		hint.text = "%s turn. Click a highlighted tile to move, or select another unit." % side_name
