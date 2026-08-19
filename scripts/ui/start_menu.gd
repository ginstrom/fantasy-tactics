extends Control

@onready var continue_button: Button = $Center/VBox/ContinueButton
@onready var new_game_button: Button = $Center/VBox/NewGameButton
@onready var load_button: Button = $Center/VBox/LoadButton
@onready var quit_button: Button = $Center/VBox/QuitButton
@onready var name_entry: VBoxContainer = $Center/VBox/NameEntry
@onready var name_input: LineEdit = $Center/VBox/NameEntry/NameInput
@onready var random_button: Button = $Center/VBox/NameEntry/RandomButton
@onready var begin_button: Button = $Center/VBox/NameEntry/BeginButton
@onready var audio_settings: Control = $AudioSettings

const PLAYER_NAME_CHOICES := ["The Black Company", "Company of Saints"]


func _ready() -> void:
	continue_button.disabled = not GameManager.has_valid_save()
	load_button.disabled = not GameManager.has_valid_save()


## Continue and Load both resume the single persisted campaign -- there is
## only one save slot -- so both go through the same
## GameManager.go_to_loaded_campaign() decision. A failed load (missing,
## corrupt, or an incompatible format) never imports anything and never
## changes scene, so the Start Menu is simply left exactly as it was.
func _on_continue_pressed() -> void:
	GameManager.go_to_loaded_campaign()


func _on_new_game_pressed() -> void:
	continue_button.visible = false
	new_game_button.visible = false
	load_button.visible = false
	quit_button.visible = false
	name_entry.visible = true
	name_input.grab_focus()


func _on_name_input_text_changed(new_text: String) -> void:
	begin_button.disabled = new_text.strip_edges().is_empty()


func _on_name_input_text_submitted(_new_text: String) -> void:
	_on_begin_pressed()


func _on_random_button_pressed() -> void:
	name_input.text = PLAYER_NAME_CHOICES[randi() % PLAYER_NAME_CHOICES.size()]
	_on_name_input_text_changed(name_input.text)


func _on_load_pressed() -> void:
	GameManager.go_to_loaded_campaign()


## Toggles the same embedded Audio Settings panel game_menu.gd's own
## _on_audio_pressed() uses (see scenes/ui/audio_settings.tscn) -- reusing
## the one self-contained scene rather than duplicating it, so Audio Settings
## is reachable both from the Title Menu (here, before any campaign exists)
## and from the in-battle/pause Game Menu (Technical Design §5 calls for
## both entry points).
func _on_audio_pressed() -> void:
	audio_settings.visible = not audio_settings.visible
	if audio_settings.visible:
		audio_settings.refresh()


func _on_begin_pressed() -> void:
	var entered_name := name_input.text.strip_edges()
	if entered_name.is_empty():
		return
	GameManager.go_to_game(entered_name)


func _on_quit_pressed() -> void:
	GameManager.quit_game()
