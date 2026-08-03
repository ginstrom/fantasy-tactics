extends Control

@onready var status: Label = $Center/VBox/Status
@onready var depart_button: Button = $Center/VBox/DepartButton


func _ready() -> void:
	refresh()


func refresh() -> void:
	var can_depart := GameSession.can_depart_selected_party()
	depart_button.disabled = not can_depart
	status.text = "encampment.status.ready" if can_depart else "encampment.status.no_party"


func _on_manage_party_pressed() -> void:
	GameManager.open_party_manager()


func _on_depart_pressed() -> void:
	GameManager.depart_selected_party()
