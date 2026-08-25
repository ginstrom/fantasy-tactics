extends Control

@onready var camp_nav: CampNav = $Body/CampNav
@onready var title: Label = $Body/Center/VBox/Title
@onready var log_button: Button = $Body/Center/VBox/SectionSelector/LogButton
@onready var log_badge: Label = $Body/Center/VBox/SectionSelector/LogButton/Badge
@onready var quests_button: Button = $Body/Center/VBox/SectionSelector/QuestsButton
@onready var quests_badge: Label = $Body/Center/VBox/SectionSelector/QuestsButton/Badge
@onready var log_section: VBoxContainer = $Body/Center/VBox/Sections/LogSection
@onready var log_empty_label: Label = $Body/Center/VBox/Sections/LogSection/LogEmptyLabel
@onready var log_list: VBoxContainer = $Body/Center/VBox/Sections/LogSection/LogList
@onready var quests_section: VBoxContainer = $Body/Center/VBox/Sections/QuestsSection
@onready var quests_empty_label: Label = $Body/Center/VBox/Sections/QuestsSection/QuestsEmptyLabel
@onready var quest_list: VBoxContainer = $Body/Center/VBox/Sections/QuestsSection/QuestList
@onready var back_button: Button = $Body/Center/VBox/BackButton
@onready var detail_panel: PanelContainer = %DetailPanel
@onready var detail_title: Label = %DetailTitle
@onready var detail_body: Label = %DetailBody
@onready var detail_close_button: Button = %DetailCloseButton

var active_section: String = GameSession.JOURNAL_SECTION_LOG


func _ready() -> void:
	if not GameSession.journal_updated.is_connected(_on_journal_updated):
		GameSession.journal_updated.connect(_on_journal_updated)
	GameSession.mark_all_journal_entries_read()
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if detail_panel.visible:
			close_detail()
		else:
			GameManager.open_game_menu()


func select_section(section: String) -> void:
	active_section = section if GameSession.JOURNAL_SECTIONS.has(section) else GameSession.JOURNAL_SECTION_LOG
	refresh()


func get_active_section() -> String:
	return active_section


func refresh() -> void:
	log_badge.visible = GameSession.has_unread_journal_entries(GameSession.JOURNAL_SECTION_LOG)
	quests_badge.visible = GameSession.has_unread_journal_entries(GameSession.JOURNAL_SECTION_QUESTS)

	log_section.visible = (active_section == GameSession.JOURNAL_SECTION_LOG)
	quests_section.visible = (active_section == GameSession.JOURNAL_SECTION_QUESTS)

	_refresh_log()
	_refresh_quests()


func _refresh_log() -> void:
	var entries := GameSession.get_journal_entries(GameSession.JOURNAL_SECTION_LOG)
	log_empty_label.visible = entries.is_empty()

	var existing_rows := {}
	for child in log_list.get_children():
		existing_rows[child.name] = child

	var current_row_names := {}
	for entry in entries:
		var row_name := "Entry_%s" % entry.id
		current_row_names[row_name] = true
		if existing_rows.has(row_name):
			var row: Control = existing_rows[row_name]
			var badge: Label = row.get_node_or_null("Badge")
			if badge:
				badge.visible = not bool(entry.get("read", false))
			var label: Label = row.get_node_or_null("Label")
			if label:
				label.text = tr(entry.get("title_key", ""))
		else:
			var new_row := _build_entry_row(entry)
			log_list.add_child(new_row)

	for row_name in existing_rows.keys():
		if not current_row_names.has(row_name):
			var old_row: Node = existing_rows[row_name]
			log_list.remove_child(old_row)
			old_row.queue_free()


func _refresh_quests() -> void:
	var entries := GameSession.get_journal_entries(GameSession.JOURNAL_SECTION_QUESTS)
	quests_empty_label.visible = entries.is_empty()

	var existing_rows := {}
	for child in quest_list.get_children():
		existing_rows[child.name] = child

	var current_row_names := {}
	for entry in entries:
		var row_name := "Entry_%s" % entry.id
		current_row_names[row_name] = true
		if existing_rows.has(row_name):
			var row: Control = existing_rows[row_name]
			var badge: Label = row.get_node_or_null("Badge")
			if badge:
				badge.visible = not bool(entry.get("read", false))
			var label: Label = row.get_node_or_null("Label")
			if label:
				label.text = tr(entry.get("title_key", ""))
		else:
			var new_row := _build_entry_row(entry)
			quest_list.add_child(new_row)

	for row_name in existing_rows.keys():
		if not current_row_names.has(row_name):
			var old_row: Node = existing_rows[row_name]
			quest_list.remove_child(old_row)
			old_row.queue_free()


func _build_entry_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.name = "Entry_%s" % entry.id
	row.add_theme_constant_override("separation", 8)

	var badge := Label.new()
	badge.name = "Badge"
	badge.text = "!"
	badge.visible = not bool(entry.get("read", false))
	row.add_child(badge)

	var label := Label.new()
	label.name = "Label"
	label.text = tr(entry.get("title_key", ""))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var view_button := Button.new()
	view_button.name = "ViewButton"
	view_button.text = tr("journal.view")
	view_button.pressed.connect(view_entry.bind(str(entry.id)))
	row.add_child(view_button)

	return row


func view_entry(entry_id: String) -> void:
	GameSession.mark_journal_entry_read(entry_id)
	var entry := GameSession.get_journal_entry(entry_id)
	if entry.is_empty():
		return

	detail_title.text = tr(entry.get("title_key", ""))
	var detail_dict: Dictionary = entry.get("detail", {})
	if detail_dict.is_empty():
		detail_body.text = tr(entry.get("title_key", ""))
	else:
		var lines: Array[String] = []
		for key in detail_dict.keys():
			lines.append("%s: %s" % [str(key).capitalize(), str(detail_dict[key])])
		detail_body.text = "\n".join(lines)
	detail_panel.visible = true


func close_detail() -> void:
	detail_panel.visible = false


func _on_journal_updated() -> void:
	refresh()


func _on_log_button_pressed() -> void:
	select_section(GameSession.JOURNAL_SECTION_LOG)


func _on_quests_button_pressed() -> void:
	select_section(GameSession.JOURNAL_SECTION_QUESTS)


func _on_detail_close_pressed() -> void:
	close_detail()


func _on_back_pressed() -> void:
	GameManager.go_to_encampment()
