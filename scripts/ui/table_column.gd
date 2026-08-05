class_name TableColumn
extends RefCounted

enum Type {
	TEXT,
	INTEGER,
	FLOAT,
	BOOLEAN,
	ICON,
	BUTTON,
}

var key: StringName
var title: String
var type: Type
var editable: bool = false
var sortable: bool = true
var visible: bool = true
var expand: bool = false
var expand_ratio: int = 1
var width: int = 0
var alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
var formatter: Callable = Callable()
var comparator: Callable = Callable()
var button_text: Callable = Callable()


func _init(column_key: StringName, column_title: String, column_type: Type = Type.TEXT) -> void:
	key = column_key
	title = column_title
	type = column_type
