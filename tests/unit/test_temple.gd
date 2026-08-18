extends GutTest

## Temple hub: Level 1 ("consecrated") unlocks Cleric recruitment candidate
## generation only. No blessing action or persisted blessing state exists in
## this slice (see docs/plans/2026-08-18-core-loop-and-engagement/03-
## encampment-buildings-and-tier-model.md). Mirrors test_blacksmith.gd's
## build-then-refresh pattern.

const TempleScene := preload("res://scenes/ui/temple.tscn")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()


func test_temple_shows_the_title_and_the_back_action() -> void:
	var screen: Control = TempleScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/Title").text, "temple.title")
	assert_eq(screen.get_node("Body/Center/VBox/BackButton").text, "ui.back")


## Temple is reached from Buildings, one of the six top-level camp screens
## that all carry the persistent left-hand CampNav (see camp_nav.gd's doc
## comment).
func test_temple_contains_the_camp_nav() -> void:
	var screen: Control = TempleScene.instantiate()
	add_child_autofree(screen)

	assert_not_null(screen.get_node_or_null("Body/CampNav"))


func test_unbuilt_state_shows_the_build_button_and_hides_built_state() -> void:
	var screen: Control = TempleScene.instantiate()
	add_child_autofree(screen)

	assert_true(screen.get_node("Body/Center/VBox/BuildButton").visible)
	assert_eq(screen.get_node("Body/Center/VBox/BuildButton").text, tr("temple.build") % GameSession.TEMPLE_BUILD_COST)
	assert_false(screen.get_node("Body/Center/VBox/LevelLabel").visible)
	assert_false(screen.get_node("Body/Center/VBox/ClericPreviewLabel").visible)


func test_build_button_is_disabled_below_the_build_cost_and_enabled_at_it() -> void:
	var screen: Control = TempleScene.instantiate()
	add_child_autofree(screen)
	var build_button: Button = screen.get_node("Body/Center/VBox/BuildButton")

	assert_true(build_button.disabled, "No gold cannot afford the Temple")

	GameSession.gold = GameSession.TEMPLE_BUILD_COST
	screen.refresh()

	assert_false(build_button.disabled, "100 gold is exactly enough to build the Temple")


func test_pressing_build_constructs_the_temple_and_shows_the_cleric_preview() -> void:
	GameSession.gold = GameSession.TEMPLE_BUILD_COST
	var screen: Control = TempleScene.instantiate()
	add_child_autofree(screen)
	var build_button: Button = screen.get_node("Body/Center/VBox/BuildButton")

	build_button.emit_signal("pressed")

	assert_eq(GameSession.temple_level, 1)
	assert_false(screen.get_node("Body/Center/VBox/BuildButton").visible)
	assert_true(screen.get_node("Body/Center/VBox/LevelLabel").visible)
	assert_true(screen.get_node("Body/Center/VBox/ClericPreviewLabel").visible)


## The Temple's own contract this step is "Cleric recruitment candidate
## generation only" -- blessings and their state are explicitly deferred (a
## doc comment explaining that scope is fine; no blessing *node*, *signal
## handler*, or *GameSession call* may exist).
func test_temple_has_no_blessing_action_or_state() -> void:
	var screen: Control = TempleScene.instantiate()
	add_child_autofree(screen)
	assert_null(screen.find_child("*Blessing*", true, false), "no blessing-named node may exist in the Temple scene")

	var source := FileAccess.get_file_as_string("res://scripts/ui/temple.gd")
	var regex := RegEx.new()
	regex.compile("(?i)func\\s+\\w*blessing\\w*|GameSession\\.\\w*blessing")
	assert_null(regex.search(source), "no blessing handler or GameSession call may exist in temple.gd")


func test_back_button_returns_to_buildings() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/temple.gd")
	assert_string_contains(source, "GameManager.go_to_buildings()")


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	var screen: Control = TempleScene.instantiate()
	add_child_autofree(screen)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)
