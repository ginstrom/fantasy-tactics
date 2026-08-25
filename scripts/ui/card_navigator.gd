class_name CardNavigator
extends Control

## Reusable full-screen card navigator shell.
## Presents a full-screen dim backdrop, centered card panel, wrapping previous/next
## buttons, position indicator (%d of %d), close button, and focus management.
## Owns only the snapshot navigation session; domain state remains caller-owned.

signal card_changed(id: Variant)
signal closed(last_id: Variant)

var focus_restoration_target: Control = null

var _ids: Array = []
var _current_index: int = -1

@onready var dim_rect: ColorRect = $Dim
@onready var center_container: CenterContainer = $Center
@onready var panel_container: PanelContainer = $Center/Panel
@onready var title_label: Label = %TitleLabel
@onready var prev_button: Button = %PrevButton
@onready var count_label: Label = %CountLabel
@onready var next_button: Button = %NextButton
@onready var content_container: Container = %ContentContainer
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(dim_rect):
		dim_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(prev_button):
		prev_button.pressed.connect(_on_prev_pressed)
	if is_instance_valid(next_button):
		next_button.pressed.connect(_on_next_pressed)
	if is_instance_valid(close_button):
		close_button.pressed.connect(_on_close_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func open(id_list: Array, initial_id: Variant = null, return_target: Control = null) -> bool:
	return open_ids(id_list, initial_id, return_target)


func open_ids(id_list: Array, initial_id: Variant = null, return_target: Control = null) -> bool:
	if id_list.is_empty():
		return false
	if initial_id != null and str(initial_id) != "" and not id_list.has(initial_id):
		return false

	_ids = id_list.duplicate()
	if return_target != null:
		focus_restoration_target = return_target

	var target_id: Variant = initial_id if (initial_id != null and str(initial_id) != "") else _ids[0]
	_current_index = _ids.find(target_id)
	if _current_index == -1:
		_current_index = 0

	visible = true
	_update_nav_ui()
	card_changed.emit(get_current_id())
	grab_initial_focus()
	return true


func show_id(target_id: Variant) -> bool:
	if not _ids.has(target_id):
		return false
	_current_index = _ids.find(target_id)
	_update_nav_ui()
	card_changed.emit(get_current_id())
	grab_initial_focus()
	return true


func show_index(index: int) -> bool:
	if _ids.is_empty():
		return false
	_current_index = posmod(index, _ids.size())
	_update_nav_ui()
	card_changed.emit(get_current_id())
	grab_initial_focus()
	return true


func previous() -> void:
	if _ids.is_empty():
		return
	show_index(_current_index - 1)


func next() -> void:
	if _ids.is_empty():
		return
	show_index(_current_index + 1)


func close() -> Variant:
	if not visible and _ids.is_empty():
		return null
	visible = false
	var last_id: Variant = get_current_id()
	if is_instance_valid(focus_restoration_target) and focus_restoration_target.is_inside_tree() and focus_restoration_target.visible:
		if not (focus_restoration_target is BaseButton and focus_restoration_target.disabled):
			focus_restoration_target.grab_focus()
	closed.emit(last_id)
	return last_id


func get_current_id() -> Variant:
	if _current_index >= 0 and _current_index < _ids.size():
		return _ids[_current_index]
	return null


func get_ids() -> Array:
	return _ids.duplicate()


func set_card_content(control: Control) -> void:
	if not is_instance_valid(content_container):
		return
	for child in content_container.get_children():
		content_container.remove_child(child)
		child.queue_free()
	if control != null:
		content_container.add_child(control)


func set_content(control: Control) -> void:
	set_card_content(control)


func set_title(title_text: String) -> void:
	if is_instance_valid(title_label):
		title_label.text = tr(title_text)
		title_label.visible = not title_text.is_empty()


func grab_initial_focus() -> void:
	var target: Control = _find_first_focusable(content_container)
	if target != null:
		target.grab_focus()
	elif is_instance_valid(close_button) and close_button.is_inside_tree() and close_button.visible and not close_button.disabled:
		close_button.grab_focus()


func _update_nav_ui() -> void:
	var total: int = _ids.size()
	if is_instance_valid(prev_button) and is_instance_valid(next_button):
		if total <= 1:
			prev_button.disabled = true
			next_button.disabled = true
		else:
			prev_button.disabled = false
			next_button.disabled = false

	if is_instance_valid(count_label):
		if total > 0 and _current_index >= 0:
			count_label.text = tr("card_nav.count") % [_current_index + 1, total]
		else:
			count_label.text = ""


func _find_first_focusable(node: Node) -> Control:
	if node == null:
		return null
	for child in node.get_children():
		if not (child is Control) or not child.visible:
			continue
		if child.focus_mode != Control.FOCUS_NONE:
			if child is BaseButton and child.disabled:
				pass
			else:
				return child
		var nested: Control = _find_first_focusable(child)
		if nested != null:
			return nested
	return null


func _on_prev_pressed() -> void:
	previous()


func _on_next_pressed() -> void:
	next()


func _on_close_pressed() -> void:
	close()
