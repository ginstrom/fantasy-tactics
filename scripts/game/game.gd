extends Node2D

const HINT_IDLE := "Click a unit to select it. Esc: main menu."
const HINT_SELECTED := "Click a highlighted tile to move, or select another unit."

@onready var hint: Label = $HUD/Hint
@onready var battlefield: Node2D = $Battlefield


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.go_to_main_menu()


func _on_board_changed() -> void:
	hint.text = HINT_SELECTED if battlefield.selected_unit != null else HINT_IDLE
