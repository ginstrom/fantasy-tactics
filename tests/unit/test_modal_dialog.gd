extends GutTest

const ModalDialogScene := preload("res://scenes/ui/modal_dialog.tscn")


func _escape_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	return event


func test_modal_blocks_underlying_mouse_input() -> void:
	var root := Control.new()
	root.custom_minimum_size = Vector2(1280, 720)
	root.size = Vector2(1280, 720)
	add_child_autofree(root)

	var underlying_button := Button.new()
	underlying_button.position = Vector2(100, 100)
	underlying_button.size = Vector2(120, 40)
	root.add_child(underlying_button)

	var clicked := false
	underlying_button.pressed.connect(func(): clicked = true)

	var modal: Control = ModalDialogScene.instantiate()
	root.add_child(modal)

	assert_eq(modal.mouse_filter, Control.MOUSE_FILTER_STOP, "Modal root must block mouse input")
	var dim: ColorRect = modal.get_node("Dim")
	assert_eq(dim.mouse_filter, Control.MOUSE_FILTER_STOP, "Modal backdrop must block mouse input")

	# Dispatch a click on the backdrop area over the underlying button
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(110, 110)
	root.get_viewport().push_input(click, true)

	assert_false(clicked, "Modal backdrop must intercept clicks and prevent underlying button from receiving input")


func test_modal_dismiss_button_emits_dismissed_signal_once_and_closes() -> void:
	var modal: Control = ModalDialogScene.instantiate()
	add_child_autofree(modal)
	watch_signals(modal)

	var dismiss_button: Button = modal.get_node("%DismissButton")
	dismiss_button.emit_signal("pressed")

	assert_signal_emit_count(modal, "dismissed", 1, "Dismiss button must emit dismissed signal exactly once")
	assert_false(modal.visible, "Dismissing must hide the modal")


func test_modal_ui_cancel_emits_dismissed_signal_when_cancel_allowed() -> void:
	var modal: Control = ModalDialogScene.instantiate()
	add_child_autofree(modal)
	watch_signals(modal)

	modal.allow_cancel = true
	modal._unhandled_input(_escape_event())

	assert_signal_emit_count(modal, "dismissed", 1, "ui_cancel must emit dismissed signal once when cancel is allowed")
	assert_false(modal.visible, "ui_cancel must hide the modal when cancel is allowed")


func test_modal_refuses_ui_cancel_when_cancel_not_allowed() -> void:
	var modal: Control = ModalDialogScene.instantiate()
	add_child_autofree(modal)
	watch_signals(modal)

	modal.allow_cancel = false
	modal._unhandled_input(_escape_event())

	assert_signal_not_emitted(modal, "dismissed", "ui_cancel must not dismiss a required modal with allow_cancel=false")
	assert_true(modal.visible, "Modal must stay visible when ui_cancel is refused")


func test_modal_focus_handling_focuses_dismiss_button_on_open() -> void:
	var modal: Control = ModalDialogScene.instantiate()
	add_child_autofree(modal)

	modal.open()
	var dismiss_button: Button = modal.get_node("%DismissButton")
	assert_true(dismiss_button.has_focus(), "Opening the modal must give focus to the dismiss button")


func test_modal_setup_configures_presentation_fields() -> void:
	var modal: Control = ModalDialogScene.instantiate()
	add_child_autofree(modal)

	modal.setup("menu.title", "menu.quit", "ui.cancel", false)

	var title_label: Label = modal.get_node("%TitleLabel")
	var message_label: Label = modal.get_node("%MessageLabel")
	var dismiss_button: Button = modal.get_node("%DismissButton")

	assert_eq(title_label.text, tr("menu.title"))
	assert_eq(message_label.text, tr("menu.quit"))
	assert_eq(dismiss_button.text, tr("ui.cancel"))
	assert_false(modal.allow_cancel)
