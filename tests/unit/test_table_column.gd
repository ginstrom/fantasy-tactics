extends GutTest

const TableColumn := preload("res://scripts/ui/table_column.gd")


func test_constructor_records_identity_type_and_presentation_defaults() -> void:
	var column := TableColumn.new(&"level", "Level", TableColumn.Type.INTEGER)

	assert_eq(column.key, &"level")
	assert_eq(column.title, "Level")
	assert_eq(column.type, TableColumn.Type.INTEGER)
	assert_false(column.editable)
	assert_true(column.sortable)
	assert_true(column.visible)
	assert_false(column.expand)
	assert_eq(column.expand_ratio, 1)
	assert_eq(column.width, 0)
	assert_eq(column.alignment, HORIZONTAL_ALIGNMENT_LEFT)
