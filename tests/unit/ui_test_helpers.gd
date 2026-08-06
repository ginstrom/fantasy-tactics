class_name UiTestHelpers
extends RefCounted


static func tree_row_values(tree: Tree, column: int) -> Array[String]:
	var values: Array[String] = []
	var item := tree.get_root().get_first_child()
	while item != null:
		values.append(item.get_text(column))
		item = item.get_next()
	return values
