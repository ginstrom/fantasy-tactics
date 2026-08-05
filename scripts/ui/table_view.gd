class_name TableView
extends VBoxContainer

## A reusable table control that owns its Tree presentation. Callers provide
## column descriptors and row dictionaries; this control keeps its own copies
## so filtering and sorting never change caller-owned data.

signal row_selected(row_id: Variant)
signal row_activated(row_id: Variant)
signal selection_changed(row_ids: Array)
signal cell_edited(row_id: Variant, column_key: StringName, value: Variant)
signal action_pressed(row_id: Variant, column_key: StringName)
signal sort_changed(column_key: StringName, ascending: bool)

var row_id_key: StringName = &"id"
var _show_column_titles: bool = true
var show_column_titles: bool:
	get:
		return _show_column_titles
	set(value):
		_show_column_titles = value
		if is_instance_valid(_tree):
			_tree.column_titles_visible = value

var _tree: Tree
var _columns: Array[TableColumn] = []
var _source_rows: Array[Dictionary] = []
var _display_rows: Array[Dictionary] = []
var _filter_text: String = ""
var _sort_column_index: int = -1
var _sort_ascending: bool = true
var _item_to_row: Dictionary = {}
var _button_icon: ImageTexture


func _ready() -> void:
	_tree = Tree.new()
	_button_icon = _create_button_icon()
	_tree.name = "Tree"
	_tree.hide_root = true
	_tree.column_titles_visible = show_column_titles
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.column_title_clicked.connect(_on_column_title_clicked)
	_tree.item_selected.connect(_on_item_selected)
	_tree.item_activated.connect(_on_item_activated)
	_tree.item_edited.connect(_on_item_edited)
	_tree.button_clicked.connect(_on_button_clicked)
	add_child(_tree)
	refresh()


func set_columns(columns: Array) -> void:
	_columns.clear()
	for column in columns:
		if column is TableColumn:
			_columns.append(column)
	_sort_column_index = -1
	refresh()


func set_rows(rows: Array) -> void:
	_source_rows.clear()
	for row in rows:
		if row is Dictionary:
			_source_rows.append(row.duplicate(true))
	refresh()


func clear_rows() -> void:
	_source_rows.clear()
	refresh()


func set_filter(filter_text: String) -> void:
	_filter_text = filter_text.to_lower()
	refresh()


func clear_filter() -> void:
	_filter_text = ""
	refresh()


func get_selected_row_ids() -> Array:
	if not is_instance_valid(_tree):
		return []
	var selected_item := _tree.get_selected()
	if selected_item == null:
		return []
	var row_id: Variant = selected_item.get_metadata(0)
	return [] if row_id == null else [row_id]


func get_selected_rows() -> Array[Dictionary]:
	var selected_rows: Array[Dictionary] = []
	for row_id in get_selected_row_ids():
		for source_row in _source_rows:
			if source_row.get(row_id_key, null) == row_id:
				selected_rows.append(source_row.duplicate(true))
				break
	return selected_rows


func refresh() -> void:
	if not is_instance_valid(_tree):
		return
	_display_rows = _source_rows.duplicate(true)
	_apply_filter()
	_apply_sort()
	_render()


func _apply_filter() -> void:
	if _filter_text.is_empty():
		return

	var matching_rows: Array[Dictionary] = []
	for row in _display_rows:
		if _row_matches_filter(row):
			matching_rows.append(row)
	_display_rows = matching_rows


func _row_matches_filter(row: Dictionary) -> bool:
	for column in _columns:
		if column.type not in [TableColumn.Type.TEXT, TableColumn.Type.INTEGER, TableColumn.Type.FLOAT]:
			continue
		if _format_cell_value(column, row.get(column.key, null), row).to_lower().contains(_filter_text):
			return true
	return false


func _apply_sort() -> void:
	if _sort_column_index < 0 or _sort_column_index >= _columns.size():
		return

	for unsorted_index in range(1, _display_rows.size()):
		var row_to_insert := _display_rows[unsorted_index]
		var insertion_index := unsorted_index - 1
		while insertion_index >= 0:
			var comparison := _compare_rows(row_to_insert, _display_rows[insertion_index], _columns[_sort_column_index])
			if not _should_sort_before(comparison):
				break
			_display_rows[insertion_index + 1] = _display_rows[insertion_index]
			insertion_index -= 1
		_display_rows[insertion_index + 1] = row_to_insert


func _should_sort_before(comparison: int) -> bool:
	return comparison < 0 if _sort_ascending else comparison > 0


func _compare_rows(left_row: Dictionary, right_row: Dictionary, column: TableColumn) -> int:
	var left_value: Variant = left_row.get(column.key, null)
	var right_value: Variant = right_row.get(column.key, null)
	if column.comparator.is_valid():
		return int(column.comparator.call(left_value, right_value))

	match column.type:
		TableColumn.Type.INTEGER:
			return _compare_numbers(int(left_value) if left_value != null else 0, int(right_value) if right_value != null else 0)
		TableColumn.Type.FLOAT:
			return _compare_numbers(float(left_value) if left_value != null else 0.0, float(right_value) if right_value != null else 0.0)
		_:
			return _compare_strings(str(left_value) if left_value != null else "", str(right_value) if right_value != null else "")


func _compare_numbers(left_value: float, right_value: float) -> int:
	if left_value < right_value:
		return -1
	if left_value > right_value:
		return 1
	return 0


func _compare_strings(left_value: String, right_value: String) -> int:
	var comparison := left_value.naturalnocasecmp_to(right_value)
	if comparison < 0:
		return -1
	if comparison > 0:
		return 1
	return 0


func _render() -> void:
	_tree.clear()
	_item_to_row.clear()
	var visible_column_indices := _visible_column_indices()
	_tree.columns = maxi(1, visible_column_indices.size())
	for tree_column_index in visible_column_indices.size():
		var column_index := visible_column_indices[tree_column_index]
		_configure_column(tree_column_index, _columns[column_index])

	var root := _tree.create_item()
	for row in _display_rows:
		var item := _tree.create_item(root)
		for tree_column_index in visible_column_indices.size():
			var column_index := visible_column_indices[tree_column_index]
			var column := _columns[column_index]
			item.set_text(tree_column_index, _format_cell_value(column, row.get(column.key, null), row))
			item.set_text_alignment(tree_column_index, column.alignment)
			item.set_editable(tree_column_index, column.editable and column.type != TableColumn.Type.BUTTON)
			if column.type == TableColumn.Type.BOOLEAN and column.editable:
				item.set_cell_mode(tree_column_index, TreeItem.CELL_MODE_CHECK)
				item.set_checked(tree_column_index, bool(row.get(column.key, false)))
			if column.type == TableColumn.Type.BUTTON:
				item.add_button(tree_column_index, _button_icon, column_index, false, column.title)
		item.set_metadata(0, row.get(row_id_key, null))
		_item_to_row[item] = row


func _configure_column(column_index: int, column: TableColumn) -> void:
	_tree.set_column_title(column_index, column.title)
	_tree.set_column_expand(column_index, column.expand)
	_tree.set_column_expand_ratio(column_index, column.expand_ratio)
	_tree.set_column_custom_minimum_width(column_index, column.width)
	_tree.set_column_title_alignment(column_index, column.alignment)


func _visible_column_indices() -> Array[int]:
	var indices: Array[int] = []
	for column_index in _columns.size():
		if _columns[column_index].visible:
			indices.append(column_index)
	return indices


func _create_button_icon() -> ImageTexture:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func _format_cell_value(column: TableColumn, value: Variant, row: Dictionary) -> String:
	if column.formatter.is_valid():
		return str(column.formatter.call(value, row))
	if value == null:
		return ""

	match column.type:
		TableColumn.Type.FLOAT:
			return "%.2f" % float(value)
		TableColumn.Type.BOOLEAN:
			return "True" if bool(value) else "False"
		TableColumn.Type.ICON:
			return ""
		TableColumn.Type.BUTTON:
			return str(column.button_text.call(row)) if column.button_text.is_valid() else str(value)
		_:
			return str(value)


func _on_column_title_clicked(column_index: int, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	var visible_column_indices := _visible_column_indices()
	if column_index < 0 or column_index >= visible_column_indices.size():
		return
	column_index = visible_column_indices[column_index]
	if not _columns[column_index].sortable:
		return

	if _sort_column_index == column_index:
		_sort_ascending = not _sort_ascending
	else:
		_sort_column_index = column_index
		_sort_ascending = true
	refresh()
	sort_changed.emit(_columns[column_index].key, _sort_ascending)


func _on_item_selected() -> void:
	var row_ids := get_selected_row_ids()
	if row_ids.is_empty():
		return
	row_selected.emit(row_ids[0])
	selection_changed.emit(row_ids)


func _on_item_activated() -> void:
	var row_ids := get_selected_row_ids()
	if not row_ids.is_empty():
		row_activated.emit(row_ids[0])


func _on_item_edited() -> void:
	var item := _tree.get_edited()
	var tree_column_index := _tree.get_edited_column()
	if item == null or tree_column_index < 0:
		return
	_emit_cell_edited(item, tree_column_index)


func _emit_cell_edited(item: TreeItem, tree_column_index: int) -> void:
	var visible_column_indices := _visible_column_indices()
	if tree_column_index < 0 or tree_column_index >= visible_column_indices.size():
		return
	var column := _columns[visible_column_indices[tree_column_index]]
	if not column.editable:
		return
	var row_id: Variant = item.get_metadata(0)
	if row_id == null:
		return
	var parsed_value: Variant = _parse_cell_value(column, item, tree_column_index)
	if parsed_value == null:
		return
	cell_edited.emit(row_id, column.key, parsed_value)


func _parse_cell_value(column: TableColumn, item: TreeItem, tree_column_index: int) -> Variant:
	var text := item.get_text(tree_column_index).strip_edges()
	match column.type:
		TableColumn.Type.INTEGER:
			return text.to_int() if text.is_valid_int() else null
		TableColumn.Type.FLOAT:
			return text.to_float() if text.is_valid_float() else null
		TableColumn.Type.BOOLEAN:
			return item.is_checked(tree_column_index)
		TableColumn.Type.TEXT:
			return text
	return null


func _on_button_clicked(item: TreeItem, tree_column_index: int, button_id: int, _mouse_button_index: int) -> void:
	if item == null or button_id < 0 or button_id >= _columns.size():
		return
	var visible_column_indices := _visible_column_indices()
	if tree_column_index < 0 or tree_column_index >= visible_column_indices.size():
		return
	var column := _columns[button_id]
	if column.type != TableColumn.Type.BUTTON:
		return
	var row_id: Variant = item.get_metadata(0)
	if row_id != null:
		action_pressed.emit(row_id, column.key)
