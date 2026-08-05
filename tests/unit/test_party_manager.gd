extends GutTest

# party_manager no longer hosts party management directly (Parties, reached
# from Units, replaced it). The scene and script are retained only as a
# testable redirect so the existing debug-menu "party_manager" scenario and
# GameManager.open_party_manager() route keep working without dead-ending on
# a second management UI.


func test_party_manager_defers_and_redirects_to_the_parties_screen() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/party_manager.gd")

	assert_true(
		source.contains("call_deferred"),
		"change_scene_to_file cannot run while the tree is still building this node"
	)
	assert_string_contains(source, "GameManager.go_to_parties()")


func test_party_manager_route_still_available_on_game_manager() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/game_manager.gd")

	assert_string_contains(source, "res://scenes/ui/party_manager.tscn")
	assert_string_contains(source, "func open_party_manager()")
