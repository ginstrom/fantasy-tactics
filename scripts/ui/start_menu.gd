extends Control

@onready var continue_button: Button = $Center/VBox/ContinueButton
@onready var load_button: Button = $Center/VBox/LoadButton


func _ready() -> void:
	continue_button.disabled = not GameManager.has_saved_game
	load_button.disabled = not GameManager.has_saved_game


func _on_continue_pressed() -> void:
	# No save system yet, so Continue starts a new game like New Game does.
	# This becomes real resume-from-save logic once save/load exists.
	GameManager.go_to_game()


func _on_new_game_pressed() -> void:
	GameManager.go_to_game()


func _on_quit_pressed() -> void:
	GameManager.quit_game()
