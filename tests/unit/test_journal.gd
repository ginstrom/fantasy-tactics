extends GutTest

const JournalScene := preload("res://scenes/ui/journal.tscn")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()


func _make_journal() -> Control:
	var screen: Control = JournalScene.instantiate()
	add_child_autofree(screen)
	return screen


func test_journal_initializes_with_camp_nav_and_default_view() -> void:
	var screen := _make_journal()

	assert_not_null(screen.get_node_or_null("Body/CampNav"))
	assert_eq(screen.get_node("Body/Center/VBox/Title").text, "journal.title")
	assert_eq(screen.get_node("Body/CampNav").category, CampNav.Category.NONE)


func test_quests_section_shows_explicit_accepted_quest_empty_state_when_no_accepted_quests() -> void:
	var screen := _make_journal()
	screen.select_section("quests")

	var empty_label: Label = screen.get_node("Body/Center/VBox/Sections/QuestsSection/QuestsEmptyLabel")
	var quest_list: Control = screen.get_node("Body/Center/VBox/Sections/QuestsSection/QuestList")

	assert_true(empty_label.visible)
	assert_eq(empty_label.text, "journal.quests.empty")
	assert_eq(quest_list.get_child_count(), 0)


func test_log_section_displays_chronological_entries() -> void:
	var id_1: String = GameSession.append_journal_entry("discovery", "journal.discovery.title", {"encounter_id": "goblin_camp"}, "log")
	var id_2: String = GameSession.append_journal_entry("battle", "journal.battle.title", {"outcome": "victory"}, "log")
	var id_3: String = GameSession.append_journal_entry("level_up", "journal.level_up.title", {"adventurer_id": "knight_001"}, "log")

	var screen := _make_journal()
	screen.select_section("log")

	var log_list: Control = screen.get_node("Body/Center/VBox/Sections/LogSection/LogList")
	assert_eq(log_list.get_child_count(), 3)

	var row_1: Control = log_list.get_node("Entry_%s" % id_1)
	var row_2: Control = log_list.get_node("Entry_%s" % id_2)
	var row_3: Control = log_list.get_node("Entry_%s" % id_3)

	assert_not_null(row_1)
	assert_not_null(row_2)
	assert_not_null(row_3)

	assert_eq(row_1.get_index(), 0)
	assert_eq(row_2.get_index(), 1)
	assert_eq(row_3.get_index(), 2)

	assert_true(row_1.get_node("Badge").visible)
	assert_true(row_2.get_node("Badge").visible)
	assert_true(row_3.get_node("Badge").visible)


func test_log_and_quests_badges_reflect_their_own_unread_items() -> void:
	var screen := _make_journal()

	var log_badge: Label = screen.get_node("Body/Center/VBox/SectionSelector/LogButton/Badge")
	var quests_badge: Label = screen.get_node("Body/Center/VBox/SectionSelector/QuestsButton/Badge")

	assert_false(log_badge.visible)
	assert_false(quests_badge.visible)

	var log_id: String = GameSession.append_journal_entry("discovery", "journal.discovery.title", {}, "log")
	assert_true(log_badge.visible)
	assert_false(quests_badge.visible)

	var quest_id: String = GameSession.append_journal_entry("quest", "journal.quest.title", {}, "quests")
	assert_true(log_badge.visible)
	assert_true(quests_badge.visible)

	GameSession.mark_journal_entry_read(log_id)
	assert_false(log_badge.visible)
	assert_true(quests_badge.visible)

	GameSession.mark_journal_entry_read(quest_id)
	assert_false(log_badge.visible)
	assert_false(quests_badge.visible)


func test_view_clears_one_log_item_only() -> void:
	var id_1: String = GameSession.append_journal_entry("discovery", "journal.discovery.title", {"encounter_id": "goblin_camp"}, "log")
	var id_2: String = GameSession.append_journal_entry("battle", "journal.battle.title", {"outcome": "victory"}, "log")

	var screen := _make_journal()
	screen.select_section("log")

	var log_badge: Label = screen.get_node("Body/Center/VBox/SectionSelector/LogButton/Badge")
	var row_1: Control = screen.get_node("Body/Center/VBox/Sections/LogSection/LogList/Entry_%s" % id_1)
	var row_2: Control = screen.get_node("Body/Center/VBox/Sections/LogSection/LogList/Entry_%s" % id_2)

	assert_true(log_badge.visible)
	assert_true(row_1.get_node("Badge").visible)
	assert_true(row_2.get_node("Badge").visible)

	screen.view_entry(id_1)

	assert_true(GameSession.get_journal_entry(id_1).read)
	assert_false(GameSession.get_journal_entry(id_2).read)

	var refreshed_row_1: Control = screen.get_node("Body/Center/VBox/Sections/LogSection/LogList/Entry_%s" % id_1)
	var refreshed_row_2: Control = screen.get_node("Body/Center/VBox/Sections/LogSection/LogList/Entry_%s" % id_2)

	assert_false(refreshed_row_1.get_node("Badge").visible)
	assert_true(refreshed_row_2.get_node("Badge").visible)
	assert_true(log_badge.visible)

	var detail_panel: Control = screen.get_node("DetailPanel")
	assert_true(detail_panel.visible)

	screen.close_detail()
	assert_false(detail_panel.visible)

	screen.view_entry(id_2)

	assert_true(GameSession.get_journal_entry(id_2).read)
	var final_row_2: Control = screen.get_node("Body/Center/VBox/Sections/LogSection/LogList/Entry_%s" % id_2)
	assert_false(final_row_2.get_node("Badge").visible)
	assert_false(log_badge.visible)


func test_back_button_routes_via_game_manager() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/journal.gd")
	assert_string_contains(source, "GameManager.go_to_encampment()")


func test_section_buttons_switch_active_section() -> void:
	var screen := _make_journal()

	screen.get_node("Body/Center/VBox/SectionSelector/QuestsButton").emit_signal("pressed")
	assert_eq(screen.get_active_section(), "quests")
	assert_true(screen.get_node("Body/Center/VBox/Sections/QuestsSection").visible)
	assert_false(screen.get_node("Body/Center/VBox/Sections/LogSection").visible)

	screen.get_node("Body/Center/VBox/SectionSelector/LogButton").emit_signal("pressed")
	assert_eq(screen.get_active_section(), "log")
	assert_false(screen.get_node("Body/Center/VBox/Sections/QuestsSection").visible)
	assert_true(screen.get_node("Body/Center/VBox/Sections/LogSection").visible)


func test_escape_closes_detail_panel_if_open() -> void:
	var id: String = GameSession.append_journal_entry("discovery", "journal.discovery.title", {}, "log")
	var screen := _make_journal()

	screen.view_entry(id)
	assert_true(screen.get_node("DetailPanel").visible)

	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_false(screen.get_node("DetailPanel").visible)
	assert_false(GameManager.is_game_menu_open())


func test_escape_opens_game_menu_if_detail_panel_closed() -> void:
	var screen := _make_journal()

	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)
