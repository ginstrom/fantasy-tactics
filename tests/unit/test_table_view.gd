extends GutTest

const TableColumnDescriptor := preload("res://scripts/ui/table_column.gd")
const TableViewControl := preload("res://scripts/ui/table_view.gd")


func _make_table():
	var table := TableViewControl.new()
	add_child_autofree(table)
	await get_tree().process_frame
	return table


func _tree_row_values(tree: Tree, column: int) -> Array[String]:
	var values: Array[String] = []
	var item := tree.get_root().get_first_child()
	while item != null:
		values.append(item.get_text(column))
		item = item.get_next()
	return values


func test_filter_renders_only_matching_rows_without_mutating_source_rows() -> void:
	var table: Variant = await _make_table()
	var name_column := TableColumnDescriptor.new(&"name", "Name")
	var level_column := TableColumnDescriptor.new(&"level", "Level", TableColumnDescriptor.Type.INTEGER)
	var rows: Array[Dictionary] = [
		{"id": "alin", "name": "Alin", "level": 4},
		{"id": "borin", "name": "Borin", "level": 12},
	]
	var original_rows := rows.duplicate(true)

	table.set_columns([name_column, level_column])
	table.set_rows(rows)
	table.set_filter("bOr")

	assert_eq(_tree_row_values(table.get_node("Tree"), 0), ["Borin"])
	assert_eq(rows, original_rows, "Filtering must not mutate the caller's array or dictionaries")


func test_integer_title_click_sorts_ascending_then_descending_stably() -> void:
	var table: Variant = await _make_table()
	var name_column := TableColumnDescriptor.new(&"name", "Name")
	var level_column := TableColumnDescriptor.new(&"level", "Level", TableColumnDescriptor.Type.INTEGER)

	table.set_columns([name_column, level_column])
	table.set_rows([
		{"id": "alin", "name": "Alin", "level": 12},
		{"id": "borin", "name": "Borin", "level": 4},
		{"id": "cato", "name": "Cato", "level": 12},
	])

	var tree: Tree = table.get_node("Tree")
	tree.emit_signal("column_title_clicked", 1, MOUSE_BUTTON_LEFT)
	assert_eq(_tree_row_values(tree, 0), ["Borin", "Alin", "Cato"])

	tree.emit_signal("column_title_clicked", 1, MOUSE_BUTTON_LEFT)
	assert_eq(_tree_row_values(tree, 0), ["Alin", "Cato", "Borin"])


func test_button_column_creates_a_native_tree_button_with_its_source_column_id() -> void:
	var table: Variant = await _make_table()
	var action_column := TableColumnDescriptor.new(&"action", "Action", TableColumnDescriptor.Type.BUTTON)
	action_column.button_text = func(_row: Dictionary) -> String: return "View"

	table.set_columns([action_column])
	table.set_rows([{"id": "alin", "action": ""}])

	var tree: Tree = table.get_node("Tree")
	var item := tree.get_root().get_first_child()
	assert_eq(item.get_button_count(0), 1)
	assert_eq(item.get_button_id(0, 0), 0)


func test_column_titles_and_layout_configuration_follow_the_descriptors() -> void:
	var table: Variant = await _make_table()
	var tree: Tree = table.get_node("Tree")
	assert_true(tree.column_titles_visible)
	var name_column := TableColumnDescriptor.new(&"name", "Character")
	name_column.width = 180
	name_column.expand = true
	name_column.expand_ratio = 3
	var level_column := TableColumnDescriptor.new(&"level", "Level", TableColumnDescriptor.Type.INTEGER)
	level_column.expand = true
	level_column.expand_ratio = 1
	var hidden_column := TableColumnDescriptor.new(&"hidden", "Hidden")
	hidden_column.visible = false

	table.show_column_titles = false
	table.set_columns([name_column, level_column, hidden_column])
	table.size = Vector2(600, 200)
	await get_tree().process_frame

	assert_false(tree.column_titles_visible)
	assert_eq(tree.columns, 2)
	assert_eq(tree.get_column_title(0), "Character")
	assert_gte(tree.get_column_width(0), 180)
	assert_gt(tree.get_column_width(0), tree.get_column_width(1))

	table.show_column_titles = true
	assert_true(tree.column_titles_visible)


func test_text_float_boolean_and_formatter_cells_render_display_values() -> void:
	var table: Variant = await _make_table()
	var name_column := TableColumnDescriptor.new(&"name", "Name")
	name_column.formatter = func(value: Variant, _row: Dictionary) -> String: return "Hero %s" % value
	var rating_column := TableColumnDescriptor.new(&"rating", "Rating", TableColumnDescriptor.Type.FLOAT)
	var active_column := TableColumnDescriptor.new(&"active", "Active", TableColumnDescriptor.Type.BOOLEAN)

	table.set_columns([name_column, rating_column, active_column])
	table.set_rows([{"id": "alin", "name": "Alin", "rating": 1.2, "active": true}])

	var item := (table.get_node("Tree") as Tree).get_root().get_first_child()
	assert_eq(item.get_text(0), "Hero Alin")
	assert_eq(item.get_text(1), "1.20")
	assert_eq(item.get_text(2), "True")


func test_filter_matches_integer_and_float_display_values() -> void:
	var table: Variant = await _make_table()
	var name_column := TableColumnDescriptor.new(&"name", "Name")
	var level_column := TableColumnDescriptor.new(&"level", "Level", TableColumnDescriptor.Type.INTEGER)
	var rating_column := TableColumnDescriptor.new(&"rating", "Rating", TableColumnDescriptor.Type.FLOAT)
	table.set_columns([name_column, level_column, rating_column])
	table.set_rows([
		{"id": "alin", "name": "Alin", "level": 4, "rating": 1.2},
		{"id": "borin", "name": "Borin", "level": 12, "rating": 2.5},
	])

	table.set_filter("12")
	assert_eq(_tree_row_values(table.get_node("Tree"), 0), ["Borin"])
	table.set_filter("2.50")
	assert_eq(_tree_row_values(table.get_node("Tree"), 0), ["Borin"])


func test_custom_three_way_comparator_controls_title_sort_order() -> void:
	var table: Variant = await _make_table()
	var name_column := TableColumnDescriptor.new(&"name", "Name")
	var rank_column := TableColumnDescriptor.new(&"rank", "Rank", TableColumnDescriptor.Type.INTEGER)
	rank_column.comparator = func(left: int, right: int) -> int: return right - left
	table.set_columns([name_column, rank_column])
	table.set_rows([
		{"id": "alin", "name": "Alin", "rank": 2},
		{"id": "borin", "name": "Borin", "rank": 3},
		{"id": "cato", "name": "Cato", "rank": 1},
	])

	var tree: Tree = table.get_node("Tree")
	tree.emit_signal("column_title_clicked", 1, MOUSE_BUTTON_LEFT)
	assert_eq(_tree_row_values(tree, 0), ["Borin", "Alin", "Cato"])


func test_rendered_item_metadata_keeps_the_configured_stable_row_id() -> void:
	var table: Variant = await _make_table()
	table.row_id_key = &"party_id"
	var name_column := TableColumnDescriptor.new(&"name", "Name")
	table.set_columns([name_column])
	table.set_rows([{"party_id": "party_001", "name": "First Party"}])

	var item := (table.get_node("Tree") as Tree).get_root().get_first_child()
	assert_eq(item.get_metadata(0), "party_001")
