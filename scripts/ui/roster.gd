extends Control

## Lists every GameSession adventurer as a TableView row, keyed by stable
## adventurer id (TableView's default row_id_key), and mirrors the selected
## row into the shared InformationPanel. Row activation and the panel's View
## button open the CardNavigator presenting UnitDetailCard with the current
## displayed adventurer snapshot.

const TableColumnDescriptor := preload("res://scripts/ui/table_column.gd")
const UnitDetailCardScene := preload("res://scenes/ui/unit_detail_card.tscn")

@onready var roster_table: TableView = $Body/Center/VBox/RosterTable
@onready var empty_label: Label = $Body/Center/VBox/EmptyLabel
@onready var information_panel: PanelContainer = %InformationPanel
@onready var card_navigator: CardNavigator = $CardNavigator

var selected_adventurer_id: String = ""
var unit_detail_card: UnitDetailCard


func _ready() -> void:
	information_panel.adventurer_selected.connect(_on_information_panel_adventurer_selected)
	roster_table.row_selected.connect(_on_row_selected)
	roster_table.row_activated.connect(_on_row_activated)
	roster_table.set_columns(_build_columns())

	unit_detail_card = UnitDetailCardScene.instantiate()
	card_navigator.set_card_content(unit_detail_card)
	card_navigator.set_title("unit_details.title")
	card_navigator.card_changed.connect(_on_card_changed)
	card_navigator.closed.connect(_on_card_navigator_closed)

	unit_detail_card.promote_requested.connect(_on_card_promote_requested)
	unit_detail_card.activate_item_requested.connect(_on_card_activate_item_requested)
	unit_detail_card.unequip_item_requested.connect(_on_card_unequip_item_requested)
	unit_detail_card.heal_requested.connect(_on_card_heal_requested)
	unit_detail_card.add_to_party_requested.connect(_on_card_add_to_party_requested)

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
	roster_table.set_rows(rows)
	empty_label.visible = rows.is_empty()
	_refresh_selection()
	if card_navigator.visible:
		var cur_id: Variant = card_navigator.get_current_id()
		if cur_id == null or GameSession.get_adventurer(str(cur_id)).is_empty():
			card_navigator.close()
		else:
			unit_detail_card.set_unit_id(str(cur_id))


func _build_columns() -> Array[TableColumn]:
	var name_column := TableColumnDescriptor.new(&"name", tr("roster.column.name"))
	name_column.expand = true
	name_column.expand_ratio = 2
	var class_column := TableColumnDescriptor.new(&"class", tr("roster.column.class"))
	var level_column := TableColumnDescriptor.new(
		&"level", tr("roster.column.level"), TableColumnDescriptor.Type.INTEGER
	)
	var status_column := TableColumnDescriptor.new(&"availability_status", tr("roster.column.status"))
	var party_column := TableColumnDescriptor.new(&"party_name", tr("roster.column.party"))
	party_column.expand = true
	return [name_column, class_column, level_column, status_column, party_column]


func _build_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for adventurer in GameSession.adventurers:
		rows.append({
			"id": adventurer.id,
			"name": adventurer.name,
			"class": tr("class.%s" % adventurer["class"]),
			"level": adventurer.level,
			"availability_status": tr("availability.%s" % adventurer.availability_status),
			"party_name": _party_name_for(adventurer.id),
		})
	return rows


func _party_name_for(adventurer_id: String) -> String:
	for party in GameSession.parties:
		if adventurer_id in party.member_ids:
			return party.name
	return tr("roster.unassigned")


func _refresh_selection() -> void:
	if selected_adventurer_id == "" or GameSession.get_adventurer(selected_adventurer_id).is_empty():
		selected_adventurer_id = ""
		information_panel.refresh()
		return
	information_panel.refresh_adventurer(selected_adventurer_id)


func _on_row_selected(row_id: Variant) -> void:
	selected_adventurer_id = str(row_id)
	_refresh_selection()


func _on_row_activated(row_id: Variant) -> void:
	_open_card_navigator(str(row_id))


func _on_information_panel_adventurer_selected(adventurer_id: String) -> void:
	_open_card_navigator(adventurer_id)


func _open_card_navigator(initial_id: String) -> void:
	var id_list := roster_table.get_displayed_row_ids()
	if id_list.is_empty():
		return
	unit_detail_card.show_assignment = true
	unit_detail_card.origin = GameManager.UNIT_DETAILS_ORIGIN_ROSTER
	var return_target: Control = information_panel.get_node_or_null("Content/AdventurerViewButton")
	card_navigator.open(id_list, initial_id, return_target)
	unit_detail_card.set_unit_id(str(card_navigator.get_current_id()))


func _on_card_changed(id: Variant) -> void:
	unit_detail_card.set_unit_id(str(id))


func _on_card_navigator_closed(last_id: Variant) -> void:
	if last_id != null and str(last_id) != "":
		selected_adventurer_id = str(last_id)
		roster_table.select_row(selected_adventurer_id)
		_refresh_selection()


func _handle_card_mutation(current_id: String) -> void:
	refresh()
	if GameSession.get_adventurer(current_id).is_empty():
		card_navigator.close()
	else:
		unit_detail_card.set_unit_id(current_id)


func _on_card_promote_requested(target_unit_id: String, specialization_id: String) -> void:
	GameSession.promote_adventurer(target_unit_id, specialization_id)
	_handle_card_mutation(target_unit_id)


func _on_card_activate_item_requested(target_unit_id: String, slot: String, item_id: String) -> void:
	GameSession.activate_carried_item(target_unit_id, slot, item_id)
	_handle_card_mutation(target_unit_id)


func _on_card_unequip_item_requested(target_unit_id: String, slot: String, item_id: String) -> void:
	GameSession.unequip_to_bank(target_unit_id, slot, item_id)
	_handle_card_mutation(target_unit_id)


func _on_card_heal_requested(caster_id: String, target_id: String) -> void:
	GameSession.heal_party_member(caster_id, target_id)
	_handle_card_mutation(caster_id)


func _on_card_add_to_party_requested(target_unit_id: String, party_id: String) -> void:
	GameManager.assign_adventurer_to_party(party_id, target_unit_id)
	_handle_card_mutation(target_unit_id)


func _on_back_pressed() -> void:
	GameManager.go_to_units()
