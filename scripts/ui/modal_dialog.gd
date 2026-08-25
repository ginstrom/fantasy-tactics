class_name ModalDialog
extends Control

## Reusable full-screen blocking modal shell (Information Design §2).
## Presents a full-screen dim backdrop, centered content panel, focus
## handling, and explicit button / Escape dismissal. Owns no game state.

signal dismissed

@export var allow_cancel: bool = true

@onready var dim_rect: ColorRect = $Dim
@onready var title_label: Label = %TitleLabel
@onready var message_label: Label = %MessageLabel
@onready var content_container: VBoxContainer = %ContentContainer
@onready var button_container: HBoxContainer = %ButtonContainer
@onready var dismiss_button: Button = %DismissButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	dim_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	dismiss_button.pressed.connect(_on_dismiss_pressed)
	if visible:
		grab_initial_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if allow_cancel:
			dismiss()


func setup(
	title_text: String,
	message_text: String = "",
	button_text: String = "",
	cancel_allowed: bool = true
) -> void:
	allow_cancel = cancel_allowed
	if is_node_ready():
		_apply_content(title_text, message_text, button_text)
	else:
		ready.connect(
			func(): _apply_content(title_text, message_text, button_text),
			CONNECT_ONE_SHOT
		)


func _apply_content(title_text: String, message_text: String, button_text: String) -> void:
	title_label.text = tr(title_text)
	title_label.visible = not title_text.is_empty()
	message_label.text = tr(message_text)
	message_label.visible = not message_text.is_empty()
	if not button_text.is_empty():
		dismiss_button.text = tr(button_text)
	else:
		dismiss_button.text = tr("ui.dismiss")


func open() -> void:
	visible = true
	grab_initial_focus()


func close() -> void:
	visible = false


func dismiss() -> void:
	close()
	dismissed.emit()


func grab_initial_focus() -> void:
	if dismiss_button.is_inside_tree() and dismiss_button.visible and not dismiss_button.disabled:
		dismiss_button.grab_focus()


func _on_dismiss_pressed() -> void:
	dismiss()
