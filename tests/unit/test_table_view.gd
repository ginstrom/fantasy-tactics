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


## Regression test: the original button icon was a single stretched pixel,
## nearly invisible against the Tree's dark theme. It must now be large
## enough, and high-contrast enough, to read as a real button at a glance.
func test_button_icon_is_a_visibly_sized_high_contrast_chip_not_a_tiny_dot() -> void:
	var table: Variant = await _make_table()

	var icon_size: Vector2 = table._button_icon.get_size()
	assert_true(icon_size.x >= 32, "Button icon must be wide enough to read as a real button")
	assert_true(icon_size.y >= 16, "Button icon must be tall enough to read as a real button")

	var image: Image = table._button_icon.get_image()
	var fill_color: Color = image.get_pixel(int(icon_size.x / 2.0), int(icon_size.y / 2.0))
	var border_color: Color = image.get_pixel(0, 0)
	assert_true(fill_color.a > 0.9, "The chip's fill must be fully opaque, not a faint tint")
	assert_ne(fill_color, border_color, "The border must contrast with the fill so the chip's edges read clearly")


func test_button_visible_callable_hides_the_button_on_rows_it_rejects() -> void:
	var table: Variant = await _make_table()
	var action_column := TableColumnDescriptor.new(&"action", "Action", TableColumnDescriptor.Type.BUTTON)
	action_column.button_visible = func(row: Dictionary) -> bool: return row.id != "borin"

	table.set_columns([action_column])
	table.set_rows([{"id": "alin", "action": ""}, {"id": "borin", "action": ""}])

	var tree: Tree = table.get_node("Tree")
	var first_item := tree.get_root().get_first_child()
	var second_item := first_item.get_next()
	assert_eq(first_item.get_button_count(0), 1)
	assert_eq(second_item.get_button_count(0), 0)


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


func test_selecting_a_rendered_row_emits_its_id_and_resolves_its_source_row() -> void:
	var table: Variant = await _make_table()
	var name_column := TableColumnDescriptor.new(&"name", "Name")
	table.set_columns([name_column])
	table.set_rows([
		{"id": "alin", "name": "Alin"},
		{"id": "borin", "name": "Borin"},
	])
	var tree: Tree = table.get_node("Tree")
	var borin_item := tree.get_root().get_first_child().get_next()
	watch_signals(table)

	borin_item.select(0)
	tree.emit_signal("item_selected")

	assert_signal_emitted_with_parameters(table, "row_selected", ["borin"])
	assert_signal_emitted_with_parameters(table, "selection_changed", [["borin"]])
	assert_eq(table.get_selected_row_ids(), ["borin"])
	assert_eq(table.get_selected_rows(), [{"id": "borin", "name": "Borin"}])


func test_activating_a_rendered_row_emits_its_stable_id() -> void:
	var table: Variant = await _make_table()
	var name_column := TableColumnDescriptor.new(&"name", "Name")
	table.set_columns([name_column])
	table.set_rows([{"id": "alin", "name": "Alin"}])
	var tree: Tree = table.get_node("Tree")
	watch_signals(table)

	tree.get_root().get_first_child().select(0)
	tree.emit_signal("item_activated")

	assert_signal_emitted_with_parameters(table, "row_activated", ["alin"])


func test_editing_an_integer_cell_emits_parsed_value_without_mutating_input_rows() -> void:
	var table: Variant = await _make_table()
	var name_column := TableColumnDescriptor.new(&"name", "Name")
	var level_column := TableColumnDescriptor.new(&"level", "Level", TableColumnDescriptor.Type.INTEGER)
	level_column.editable = true
	var rows: Array[Dictionary] = [{"id": "alin", "name": "Alin", "level": 4}]
	table.set_columns([name_column, level_column])
	table.set_rows(rows)
	var tree: Tree = table.get_node("Tree")
	var item := tree.get_root().get_first_child()
	watch_signals(table)

	item.set_text(1, "19")
	table._emit_cell_edited(item, 1)

	assert_signal_emitted_with_parameters(table, "cell_edited", ["alin", &"level", 19])
	assert_eq(rows, [{"id": "alin", "name": "Alin", "level": 4}])


func test_editing_text_float_and_boolean_cells_emits_typed_values() -> void:
	var table: Variant = await _make_table()
	var name_column := TableColumnDescriptor.new(&"name", "Name")
	name_column.editable = true
	var rating_column := TableColumnDescriptor.new(&"rating", "Rating", TableColumnDescriptor.Type.FLOAT)
	rating_column.editable = true
	var active_column := TableColumnDescriptor.new(&"active", "Active", TableColumnDescriptor.Type.BOOLEAN)
	active_column.editable = true
	table.set_columns([name_column, rating_column, active_column])
	table.set_rows([{"id": "alin", "name": "Alin", "rating": 1.25, "active": false}])
	var item := (table.get_node("Tree") as Tree).get_root().get_first_child()
	watch_signals(table)

	item.set_text(0, "Aline")
	table._emit_cell_edited(item, 0)
	item.set_text(1, "2.50")
	table._emit_cell_edited(item, 1)
	item.set_checked(2, true)
	table._emit_cell_edited(item, 2)

	assert_signal_emitted_with_parameters(table, "cell_edited", ["alin", &"name", "Aline"], 0)
	assert_signal_emitted_with_parameters(table, "cell_edited", ["alin", &"rating", 2.5], 1)
	assert_signal_emitted_with_parameters(table, "cell_edited", ["alin", &"active", true], 2)


func test_malformed_editable_numeric_values_emit_no_intent() -> void:
	var table: Variant = await _make_table()
	var level_column := TableColumnDescriptor.new(&"level", "Level", TableColumnDescriptor.Type.INTEGER)
	level_column.editable = true
	var rating_column := TableColumnDescriptor.new(&"rating", "Rating", TableColumnDescriptor.Type.FLOAT)
	rating_column.editable = true
	table.set_columns([level_column, rating_column])
	table.set_rows([{"id": "alin", "level": 4, "rating": 1.25}])
	var item := (table.get_node("Tree") as Tree).get_root().get_first_child()
	watch_signals(table)

	item.set_text(0, "four")
	table._emit_cell_edited(item, 0)
	item.set_text(1, "two point five")
	table._emit_cell_edited(item, 1)

	assert_signal_not_emitted(table, "cell_edited")


func test_non_editable_or_invalid_cell_edits_are_ignored() -> void:
	var table: Variant = await _make_table()
	var name_column := TableColumnDescriptor.new(&"name", "Name")
	table.set_columns([name_column])
	table.set_rows([{"id": "alin", "name": "Alin"}])
	var tree: Tree = table.get_node("Tree")
	var item := tree.get_root().get_first_child()
	watch_signals(table)

	item.set_text(0, "Changed")
	table._emit_cell_edited(item, 0)
	table._emit_cell_edited(item, -1)

	assert_signal_not_emitted(table, "cell_edited")


func test_button_click_emits_action_intent_without_changing_rows() -> void:
	var table: Variant = await _make_table()
	var action_column := TableColumnDescriptor.new(&"action", "Action", TableColumnDescriptor.Type.BUTTON)
	action_column.button_text = func(_row: Dictionary) -> String: return "View"
	var rows: Array[Dictionary] = [{"id": "alin", "action": ""}]
	table.set_columns([action_column])
	table.set_rows(rows)
	var tree: Tree = table.get_node("Tree")
	var item := tree.get_root().get_first_child()
	watch_signals(table)

	tree.emit_signal("button_clicked", item, 0, item.get_button_id(0, 0), MOUSE_BUTTON_LEFT)

	assert_signal_emitted_with_parameters(table, "action_pressed", ["alin", &"action"])
	assert_eq(rows, [{"id": "alin", "action": ""}])


func test_button_click_uses_source_descriptor_id_when_a_hidden_column_precedes_it() -> void:
	var table: Variant = await _make_table()
	var hidden_column := TableColumnDescriptor.new(&"internal", "Internal")
	hidden_column.visible = false
	var action_column := TableColumnDescriptor.new(&"action", "Action", TableColumnDescriptor.Type.BUTTON)
	action_column.button_text = func(_row: Dictionary) -> String: return "View"
	table.set_columns([hidden_column, action_column])
	table.set_rows([{"id": "alin", "internal": "hidden", "action": ""}])
	var tree: Tree = table.get_node("Tree")
	var item := tree.get_root().get_first_child()
	watch_signals(table)

	assert_eq(item.get_button_id(0, 0), 1)
	tree.emit_signal("button_clicked", item, 0, item.get_button_id(0, 0), MOUSE_BUTTON_LEFT)

	assert_signal_emitted_with_parameters(table, "action_pressed", ["alin", &"action"])


func test_sorting_emits_the_column_key_and_direction() -> void:
	var table: Variant = await _make_table()
	var name_column := TableColumnDescriptor.new(&"name", "Name")
	table.set_columns([name_column])
	table.set_rows([{"id": "alin", "name": "Alin"}])
	var tree: Tree = table.get_node("Tree")
	watch_signals(table)

	tree.emit_signal("column_title_clicked", 0, MOUSE_BUTTON_LEFT)
	tree.emit_signal("column_title_clicked", 0, MOUSE_BUTTON_LEFT)

	assert_signal_emitted_with_parameters(table, "sort_changed", [&"name", true], 0)
	assert_signal_emitted_with_parameters(table, "sort_changed", [&"name", false], 1)


func test_native_tree_edit_signal_is_connected_but_has_no_settable_headless_edit_context() -> void:
	var table: Variant = await _make_table()
	var level_column := TableColumnDescriptor.new(&"level", "Level", TableColumnDescriptor.Type.INTEGER)
	level_column.editable = true
	table.set_columns([level_column])
	table.set_rows([{"id": "alin", "level": 4}])
	var tree: Tree = table.get_node("Tree")
	watch_signals(table)

	# Tree exposes no setter for get_edited()/get_edited_column(), so headless
	# tests use _emit_cell_edited above for the typed edit contract.
	assert_true(tree.item_edited.is_connected(table._on_item_edited))
	tree.emit_signal("item_edited")
	assert_signal_not_emitted(table, "cell_edited")
