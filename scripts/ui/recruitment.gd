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

@onready var recruitment_table: TableView = $Body/Center/VBox/RecruitmentTable
@onready var empty_label: Label = $Body/Center/VBox/EmptyLabel
@onready var information_panel: PanelContainer = %InformationPanel

var selected_candidate_id: String = ""


func _ready() -> void:
	information_panel.recruit_selected.connect(_on_information_panel_recruit_selected)
	recruitment_table.row_selected.connect(_on_row_selected)
	recruitment_table.set_columns(_build_columns())
	information_panel.refresh()
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	var rows := _build_rows()
	recruitment_table.set_rows(rows)
	empty_label.visible = rows.is_empty()
	_refresh_selection()


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
			"class": candidate["class"],
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


## The only real purchase path: routes to Roster only once GameManager.
## purchase_recruit() reports success. A failed purchase (stale/removed
## candidate, or insufficient funds re-checked at the boundary) clears the
## current selection and refreshes in place instead of navigating, mirroring
## deploy_party.gd/add_member.gd/unit_details.gd's existing
## refresh-in-place convention.
func _on_information_panel_recruit_selected(candidate_id: String) -> void:
	if GameManager.purchase_recruit(candidate_id) == OK:
		GameManager.go_to_roster()
		return
	selected_candidate_id = ""
	refresh()


func _on_back_pressed() -> void:
	GameManager.go_to_units()
