extends Control

## Shows the roster of a single party (read from GameManager.route_context_id)
## as a TableView row per member, keyed by stable adventurer id, and mirrors
## the selected row into the shared InformationPanel — the same selection
## pattern Parties uses for parties (see parties.gd), applied to this party's
## members instead. Row activation and the panel's View button both open the
## existing Unit Details screen. Add Member is hidden entirely for a deployed
## party, since you can't add a member to a party that's out in the field,
## and disabled for an encamped party with no available adventurer left to
## add.

const TableColumnDescriptor := preload("res://scripts/ui/table_column.gd")

@onready var party_name_label: Label = $Body/Center/VBox/PartyNameLabel
@onready var gold_label: Label = $Body/Center/VBox/GoldLabel
@onready var loot_label: Label = $Body/Center/VBox/LootLabel
@onready var member_table: TableView = $Body/Center/VBox/MemberTable
@onready var empty_label: Label = $Body/Center/VBox/EmptyLabel
@onready var add_member_button: Button = $Body/Center/VBox/AddMemberButton
@onready var information_panel: PanelContainer = %InformationPanel

var party_id: String = ""
var selected_adventurer_id: String = ""


func _ready() -> void:
	information_panel.adventurer_selected.connect(_on_information_panel_adventurer_selected)
	party_id = GameManager.route_context_id
	member_table.row_selected.connect(_on_row_selected)
	member_table.row_activated.connect(_on_row_activated)
	member_table.set_columns(_build_columns())
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	var party := GameSession.get_party(party_id)
	party_name_label.text = "" if party.is_empty() else party.name
	gold_label.text = tr("party_details.gold") % GameSession.gold
	loot_label.text = tr("party_details.loot") % [_banked_mana_crystal_count(), _banked_gear_count()]
	var rows := _build_rows(party)
	member_table.set_rows(rows)
	empty_label.visible = rows.is_empty()
	# A deployed party is out in the field; Add Member doesn't even make
	# sense to offer, so it disappears entirely rather than merely staying
	# disabled. An encamped party with nobody left to recruit keeps the
	# button visible but disabled, so its presence isn't a mystery.
	add_member_button.visible = not party.get("deployed", false)
	add_member_button.disabled = (
		GameSession.get_available_adventurers().is_empty()
		or party.get("member_ids", []).size() >= GameSession.get_max_party_size()
	)
	_refresh_selection()


func _build_columns() -> Array[TableColumn]:
	var name_column := TableColumnDescriptor.new(&"name", tr("party_details.column.name"))
	name_column.expand = true
	name_column.expand_ratio = 2
	var class_column := TableColumnDescriptor.new(&"class", tr("party_details.column.class"))
	var level_column := TableColumnDescriptor.new(
		&"level", tr("party_details.column.level"), TableColumnDescriptor.Type.INTEGER
	)
	return [name_column, class_column, level_column]


func _build_rows(party: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var member_ids: Array = party.get("member_ids", [])
	for adventurer_id in member_ids:
		var adventurer := GameSession.get_adventurer(adventurer_id)
		if adventurer.is_empty():
			continue
		rows.append({
			"id": adventurer.id,
			"name": adventurer.name,
			"class": adventurer["class"],
			"level": adventurer.level,
		})
	return rows


func _banked_mana_crystal_count() -> int:
	var total := 0
	for tier in GameSession.mana_crystals:
		total += GameSession.mana_crystals[tier]
	return total


func _banked_gear_count() -> int:
	var total := 0
	for item_id in GameSession.banked_gear:
		total += GameSession.banked_gear[item_id]
	return total


## A selection is only valid while it names a current member of this party
## (not merely an adventurer that still exists somewhere): the party may have
## been reset out from under this screen, or the member may have left the
## party. Either way this clears back to the safe, unselected empty state
## instead of leaving the panel pointed at a stale id.
func _refresh_selection() -> void:
	var party := GameSession.get_party(party_id)
	var member_ids: Array = party.get("member_ids", [])
	if selected_adventurer_id == "" or not selected_adventurer_id in member_ids:
		selected_adventurer_id = ""
		information_panel.refresh()
		return
	information_panel.refresh_adventurer(selected_adventurer_id)


func _on_row_selected(row_id: Variant) -> void:
	selected_adventurer_id = str(row_id)
	_refresh_selection()


func _on_row_activated(row_id: Variant) -> void:
	GameManager.go_to_unit_details_from_party_details(str(row_id), party_id)


func _on_information_panel_adventurer_selected(adventurer_id: String) -> void:
	GameManager.go_to_unit_details_from_party_details(adventurer_id, party_id)


func _on_add_member_pressed() -> void:
	GameManager.go_to_add_member(party_id)


## Reachable from both Parties (an encamped party) and, since World Map's
## View Party button was wired up, from World Map (a deployed party). Back
## must return to whichever of those the player actually came from instead
## of always landing on Parties — otherwise a deployed party visually
## "teleports" back to the Encampment. route_context_id is cleared here
## directly (rather than relying on the destination route to do it) because
## go_to_world_map() does not clear it the way go_to_parties() does.
func _on_back_pressed() -> void:
	var deployed: bool = GameSession.get_party(party_id).get("deployed", false)
	GameManager.route_context_id = ""
	if deployed:
		GameManager.go_to_world_map()
	else:
		GameManager.go_to_parties()
