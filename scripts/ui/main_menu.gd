extends Control


func _on_new_game_pressed() -> void:
	GameManager.go_to_game()


func _on_quit_pressed() -> void:
	GameManager.quit_game()
