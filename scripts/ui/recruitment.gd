extends Control

## Lists the current recruitment candidates as a TableView row, keyed by
## stable candidate id, and mirrors the selected row into the shared
## InformationPanel's recruitment summary section — the same selection
## pattern Roster uses for adventurers (see roster.gd), applied to
## recruitment candidates instead. Selecting a row only shows the candidate's
## cost and a Recruit action; it never purchases by itself. Only the panel's
## Recruit action, routed through GameManager.purchase_recruit(), can spend
## gold (see _on_information_panel_recruit_selected).

const TableColumnDescriptor := preload("res://scripts/ui/table_column.gd")
const RecruitmentCardScene := preload("res://scenes/ui/recruitment_card.tscn")

@onready var recruitment_table: TableView = $Body/Center/VBox/RecruitmentTable
@onready var empty_label: Label = $Body/Center/VBox/EmptyLabel
@onready var information_panel: PanelContainer = %InformationPanel
@onready var card_navigator: CardNavigator = $CardNavigator

var selected_candidate_id: String = ""
var recruitment_card: RecruitmentCard


func _ready() -> void:
	information_panel.recruit_selected.connect(_on_information_panel_recruit_selected)
	recruitment_table.row_selected.connect(_on_row_selected)
	recruitment_table.row_activated.connect(_on_row_activated)
	recruitment_table.set_columns(_build_columns())

	recruitment_card = RecruitmentCardScene.instantiate()
	card_navigator.set_card_content(recruitment_card)
	card_navigator.set_title("recruitment_card.title")
	card_navigator.card_changed.connect(_on_card_changed)
	card_navigator.closed.connect(_on_card_navigator_closed)
	recruitment_card.recruit_requested.connect(_on_card_recruit_requested)

	information_panel.refresh()
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if card_navigator.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	var rows := _build_rows()
	recruitment_table.set_rows(rows)
	empty_label.visible = rows.is_empty()
	_refresh_selection()

	if card_navigator.visible:
		var cur_id: Variant = card_navigator.get_current_id()
		if cur_id == null or not GameSession.has_recruitment_candidate(str(cur_id)):
			card_navigator.close()
		else:
			recruitment_card.set_candidate_id(str(cur_id))


func _build_columns() -> Array[TableColumn]:
	var name_column := TableColumnDescriptor.new(&"name", tr("recruitment.column.name"))
	name_column.expand = true
	name_column.expand_ratio = 2
	var class_column := TableColumnDescriptor.new(&"class", tr("recruitment.column.class"))
	var level_column := TableColumnDescriptor.new(
		&"level", tr("recruitment.column.level"), TableColumnDescriptor.Type.INTEGER
	)
	var cost_column := TableColumnDescriptor.new(
		&"cost", tr("recruitment.column.cost"), TableColumnDescriptor.Type.INTEGER
	)
	cost_column.formatter = func(value: Variant, _row: Dictionary) -> String:
		# recruitment.column.cost_unit is substituted as the VALUE here, not
		# used as the format string. Keep its translation a plain unit word
		# with no %d/%s of its own — the numeric placeholder already lives
		# in this line's "%d %s" template.
		return "%d %s" % [int(value), tr(&"recruitment.column.cost_unit")]
	return [name_column, class_column, level_column, cost_column]


func _build_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for candidate in GameSession.get_recruitment_candidates():
		rows.append({
			"id": candidate.id,
			"name": candidate.name,
			"class": tr("class.%s" % candidate["class"]),
			"level": candidate.level,
			"cost": candidate.cost,
		})
	return rows


## Mirrors roster.gd's _refresh_selection: a selection that no longer names a
## current candidate (purchased, here or elsewhere) clears back to the safe,
## unselected empty state instead of leaving the panel pointed at a dead id.
func _refresh_selection() -> void:
	if selected_candidate_id == "" or not GameSession.has_recruitment_candidate(selected_candidate_id):
		selected_candidate_id = ""
		information_panel.refresh()
		return
	information_panel.refresh_recruitment_candidate(selected_candidate_id)


func _on_row_selected(row_id: Variant) -> void:
	selected_candidate_id = str(row_id)
	_refresh_selection()


func _on_row_activated(row_id: Variant) -> void:
	_open_card_navigator(str(row_id))


func _open_card_navigator(initial_id: String) -> void:
	var id_list := recruitment_table.get_displayed_row_ids()
	if id_list.is_empty():
		return
	var return_target: Control = information_panel.get_node_or_null("Content/RecruitButton")
	card_navigator.open(id_list, initial_id, return_target)
	recruitment_card.set_candidate_id(str(card_navigator.get_current_id()))


func _on_card_changed(id: Variant) -> void:
	recruitment_card.set_candidate_id(str(id))


func _on_card_navigator_closed(last_id: Variant) -> void:
	if last_id != null and str(last_id) != "":
		selected_candidate_id = str(last_id)
		recruitment_table.select_row(selected_candidate_id)
		_refresh_selection()


func _on_card_recruit_requested(target_candidate_id: String) -> void:
	_perform_recruitment(target_candidate_id)


func _on_information_panel_recruit_selected(candidate_id: String) -> void:
	_perform_recruitment(candidate_id)


func _perform_recruitment(candidate_id: String) -> void:
	if not GameSession.has_recruitment_candidate(candidate_id):
		selected_candidate_id = ""
		refresh()
		return
	if GameManager.recruitment_target_party_id != "":
		var target_id := GameManager.recruitment_target_party_id
		if GameManager.purchase_recruit_for_target_party(candidate_id) == OK:
			if card_navigator.visible:
				card_navigator.close()
			GameManager.go_to_party_details(target_id)
			return
	else:
		if GameManager.purchase_recruit(candidate_id) == OK:
			if card_navigator.visible:
				card_navigator.close()
			GameManager.go_to_roster()
			return
	selected_candidate_id = ""
	refresh()


func _on_view_roster_pressed() -> void:
	GameManager.go_to_roster()


func _on_back_pressed() -> void:
	GameManager.go_to_units()
