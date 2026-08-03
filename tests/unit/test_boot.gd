extends GutTest


func test_boot_defers_start_menu_transition() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/boot/boot.gd")
	assert_true(
		source.contains("call_deferred"),
		"Boot must defer the start-menu transition; sync change_scene in _ready errors"
	)
