extends PanelContainer
## Audio Settings Panel (Technical Design §5, docs/plans/2026-08-18-core-
## loop-and-engagement/08-audio-system-and-soundscape.md): Master/Music/SFX
## volume sliders and per-bus mute toggles, all driving AudioManager
## directly -- this script never touches AudioServer or the filesystem
## itself, matching every other UI script's "GameManager/AudioManager owns
## the mechanics, this only relays intents" convention. Self-contained so it
## can be instanced from anywhere audio controls are wanted (today: embedded
## in game_menu.tscn); refresh() re-syncs every control from AudioManager's
## current state, the same "call once on _ready(), and again whenever the
## parent reopens this panel" pattern game_menu.gd's own refresh() uses.

@onready var master_slider: HSlider = $VBox/MasterRow/MasterSlider
@onready var master_mute_button: CheckButton = $VBox/MasterRow/MasterMuteButton
@onready var music_slider: HSlider = $VBox/MusicRow/MusicSlider
@onready var music_mute_button: CheckButton = $VBox/MusicRow/MusicMuteButton
@onready var sfx_slider: HSlider = $VBox/SFXRow/SFXSlider
@onready var sfx_mute_button: CheckButton = $VBox/SFXRow/SFXMuteButton


func _ready() -> void:
	refresh()


func refresh() -> void:
	master_slider.value = AudioManager.get_bus_volume("Master")
	master_mute_button.button_pressed = AudioManager.is_bus_muted("Master")
	music_slider.value = AudioManager.get_bus_volume("Music")
	music_mute_button.button_pressed = AudioManager.is_bus_muted("Music")
	sfx_slider.value = AudioManager.get_bus_volume("SFX")
	sfx_mute_button.button_pressed = AudioManager.is_bus_muted("SFX")


func _on_master_slider_value_changed(value: float) -> void:
	AudioManager.set_bus_volume("Master", value)


func _on_master_mute_toggled(pressed: bool) -> void:
	AudioManager.set_bus_mute("Master", pressed)


func _on_music_slider_value_changed(value: float) -> void:
	AudioManager.set_bus_volume("Music", value)


func _on_music_mute_toggled(pressed: bool) -> void:
	AudioManager.set_bus_mute("Music", pressed)


## SFX slider changes also play a preview click so the player can hear the
## level they just set (see the step doc's manual-verification script:
## "Move SFX slider and confirm button click sound adjusts in volume").
func _on_sfx_slider_value_changed(value: float) -> void:
	AudioManager.set_bus_volume("SFX", value)
	AudioManager.play_sfx("sfx_ui_click")


func _on_sfx_mute_toggled(pressed: bool) -> void:
	AudioManager.set_bus_mute("SFX", pressed)


func _on_close_pressed() -> void:
	visible = false
