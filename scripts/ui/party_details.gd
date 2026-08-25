extends Control

## Shows the roster of a single party (read from GameManager.route_context_id)
## as a TableView row per member, keyed by stable adventurer id. Row activation
## and the panel's View button open the CardNavigator presenting UnitDetailCard
## with the current displayed party-member snapshot.

const TableColumnDescriptor := preload("res://scripts/ui/table_column.gd")
const UnitDetailCardScene := preload("res://scenes/ui/unit_detail_card.tscn")

@onready var party_name_label: Label = $Body/Center/VBox/PartyNameLabel
@onready var party_size_label: Label = $Body/Center/VBox/PartySizeLabel
@onready var gold_label: Label = $Body/Center/VBox/GoldLabel
@onready var loot_table: LootTable = $Body/Center/VBox/LootTable
@onready var member_table: TableView = $Body/Center/VBox/MemberTable
@onready var empty_label: Label = $Body/Center/VBox/EmptyLabel
@onready var remove_from_party_button: Button = $Body/Center/VBox/RemoveFromPartyButton
@onready var add_from_roster_button: Button = $Body/Center/VBox/AddFromRosterButton
@onready var recruit_button: Button = $Body/Center/VBox/RecruitButton
@onready var information_panel: PanelContainer = %InformationPanel
@onready var card_navigator: CardNavigator = $CardNavigator

var party_id: String = ""
var selected_adventurer_id: String = ""
var unit_detail_card: UnitDetailCard


func _ready() -> void:
	information_panel.adventurer_selected.connect(_on_information_panel_adventurer_selected)
	party_id = GameManager.route_context_id
	member_table.row_selected.connect(_on_row_selected)
	member_table.row_activated.connect(_on_row_activated)
	member_table.set_columns(_build_columns())
	loot_table.configure(false, true)
	loot_table.equip_requested.connect(_on_equip_requested)

	unit_detail_card = UnitDetailCardScene.instantiate()
	card_navigator.set_card_content(unit_detail_card)
	card_navigator.set_title("unit_details.title")
	card_navigator.card_changed.connect(_on_card_changed)
	card_navigator.closed.connect(_on_card_navigator_closed)

	unit_detail_card.promote_requested.connect(_on_card_promote_requested)
	unit_detail_card.activate_item_requested.connect(_on_card_activate_item_requested)
	unit_detail_card.unequip_item_requested.connect(_on_card_unequip_item_requested)
	unit_detail_card.heal_requested.connect(_on_card_heal_requested)

	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if card_navigator.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	var party := GameSession.get_party(party_id)
	party_name_label.text = "" if party.is_empty() else party.name
	var deployed: bool = party.get("deployed", false)
	var encamped: bool = not party.is_empty() and party.get("location_id", "") == GameSession.STARTING_SETTLEMENT_ID and not deployed
	party_size_label.text = "%d/%d" % [party.get("member_ids", []).size(), GameSession.get_max_party_size()]
	var carry := GameSession.get_party_carry(party_id)
	gold_label.text = tr("party_details.gold") % int(carry.get("gold", 0))
	loot_table.visible = deployed
	if deployed:
		loot_table.set_rows(GameSession.build_loot_rows(carry.get("gear", {}), carry.get("mana_crystals", {})))
	var rows := _build_rows(party)
	member_table.set_rows(rows)
	empty_label.visible = rows.is_empty()

	add_from_roster_button.visible = not deployed
	recruit_button.visible = not deployed
	add_from_roster_button.disabled = (
		GameSession.get_available_adventurers().is_empty()
		or party.get("member_ids", []).size() >= GameSession.get_max_party_size()
	)
	recruit_button.disabled = (
		GameSession.get_recruitment_candidates().is_empty()
		or party.get("member_ids", []).size() >= GameSession.get_max_party_size()
	)
	_refresh_selection()
	_update_remove_from_party_button(party, encamped)

	if card_navigator.visible:
		var cur_id: Variant = card_navigator.get_current_id()
		var member_ids: Array = party.get("member_ids", [])
		if cur_id == null or not str(cur_id) in member_ids:
			card_navigator.close()


func _build_columns() -> Array[TableColumn]:
	var name_column := TableColumnDescriptor.new(&"name", tr("party_details.column.name"))
	name_column.expand = true
	name_column.expand_ratio = 2
	var class_column := TableColumnDescriptor.new(&"class", tr("party_details.column.class"))
	var level_column := TableColumnDescriptor.new(
		&"level", tr("party_details.column.level"), TableColumnDescriptor.Type.INTEGER
	)
	var health_column := TableColumnDescriptor.new(&"health", tr("party_details.column.health"))
	return [name_column, class_column, level_column, health_column]


func _build_rows(party: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var member_ids: Array = party.get("member_ids", [])
	for adventurer_id in member_ids:
		var adventurer := GameSession.get_adventurer(adventurer_id)
		if adventurer.is_empty():
			continue
		var current_hp := GameSession.get_current_health(adventurer.id)
		var max_hp := GameSession.get_effective_max_health(adventurer.id)
		rows.append({
			"id": adventurer.id,
			"name": adventurer.name,
			"class": tr("class.%s" % adventurer["class"]),
			"level": adventurer.level,
			"health": "%d / %d" % [current_hp, max_hp],
		})
	return rows


func _refresh_selection() -> void:
	var party := GameSession.get_party(party_id)
	var member_ids: Array = party.get("member_ids", [])
	if selected_adventurer_id == "" or not selected_adventurer_id in member_ids:
		selected_adventurer_id = ""
		information_panel.refresh()
		return
	information_panel.refresh_adventurer(selected_adventurer_id)


func _update_remove_from_party_button(party: Dictionary, encamped: bool) -> void:
	var member_ids: Array = party.get("member_ids", [])
	remove_from_party_button.visible = encamped
	remove_from_party_button.disabled = selected_adventurer_id == "" or not selected_adventurer_id in member_ids


func _on_row_selected(row_id: Variant) -> void:
	selected_adventurer_id = str(row_id)
	_refresh_selection()
	var party := GameSession.get_party(party_id)
	_update_remove_from_party_button(
		party,
		not party.is_empty()
		and party.get("location_id", "") == GameSession.STARTING_SETTLEMENT_ID
		and not party.get("deployed", false)
	)


func _on_row_activated(row_id: Variant) -> void:
	_open_card_navigator(str(row_id))


func _on_information_panel_adventurer_selected(adventurer_id: String) -> void:
	_open_card_navigator(adventurer_id)


func _open_card_navigator(initial_id: String) -> void:
	var id_list := member_table.get_displayed_row_ids()
	if id_list.is_empty():
		return
	unit_detail_card.show_assignment = false
	var return_target: Control = information_panel.get_node_or_null("Content/AdventurerViewButton")
	card_navigator.open(id_list, initial_id, return_target)
	unit_detail_card.set_unit_id(str(card_navigator.get_current_id()))


func _on_card_changed(id: Variant) -> void:
	unit_detail_card.set_unit_id(str(id))


func _on_card_navigator_closed(last_id: Variant) -> void:
	if last_id != null and str(last_id) != "":
		selected_adventurer_id = str(last_id)
		member_table.select_row(selected_adventurer_id)
		_refresh_selection()


func _handle_card_mutation(current_id: String) -> void:
	refresh()
	if card_navigator.visible:
		var party := GameSession.get_party(party_id)
		var member_ids: Array = party.get("member_ids", [])
		if not current_id in member_ids:
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


func _on_add_from_roster_pressed() -> void:
	GameManager.go_to_add_member(party_id)


func _on_remove_from_party_pressed() -> void:
	if GameSession.remove_adventurer_from_party(party_id, selected_adventurer_id):
		refresh()


func _on_recruit_pressed() -> void:
	GameManager.go_to_recruitment_for_party(party_id)


func _on_equip_requested(item_id: String) -> void:
	GameManager.go_to_assign_equipment(item_id, party_id, GameManager.AssignEquipmentOrigin.PARTY_DETAILS)


func _on_back_pressed() -> void:
	var deployed: bool = GameSession.get_party(party_id).get("deployed", false)
	GameManager.route_context_id = ""
	if deployed:
		GameManager.go_to_world_map()
	else:
		GameManager.go_to_parties()
