extends Control

## Presents Temple state owned by GameSession. Level 1 ("consecrated")
## unlocks Cleric recruitment candidate generation only -- there is no
## blessing action or blessing state in this slice (see docs/plans/2026-08-
## 18-core-loop-and-engagement/03-encampment-buildings-and-tier-model.md).
## Mirrors blacksmith.gd's build-then-refresh pattern, minus any
## upgrade/craft controls -- the Temple has a single build step this step.

@onready var level_label: Label = $Body/Center/VBox/LevelLabel
@onready var build_button: Button = $Body/Center/VBox/BuildButton
@onready var cleric_preview_label: Label = $Body/Center/VBox/ClericPreviewLabel


func _ready() -> void:
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	var built := GameSession.temple_level > 0
	level_label.visible = built
	level_label.text = tr("temple.level") % GameSession.temple_level
	build_button.visible = not built
	build_button.disabled = not GameSession.can_build_temple()
	build_button.text = tr("temple.build") % GameSession.TEMPLE_BUILD_COST
	cleric_preview_label.visible = built
	cleric_preview_label.text = tr("temple.cleric_preview")


func _on_build_button_pressed() -> void:
	GameSession.build_temple()
	refresh()


func _on_back_pressed() -> void:
	GameManager.go_to_buildings()
