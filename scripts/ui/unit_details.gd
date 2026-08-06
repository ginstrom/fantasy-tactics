extends Control

## Renders a single adventurer's real fields (name/class/level/availability)
## from GameManager.route_context_id. Skills, perks, and stats have no real
## data yet (see GameSession.DEFAULT_WARRIOR's stats/progression placeholders)
## so they are only ever labelled TBD here, never invented. An unknown id
## still leaves a working Back path.
##
## Opened via the Roster route (GameManager.unit_details_origin, captured
## once into `origin` below), an available and unassigned adventurer
## additionally sees a party picker and an Add to Party action — see
## _refresh_assignment_section. That section stays hidden entirely for
## every other entry path (e.g. from Party Details) and for an assigned or
## unavailable adventurer, so the screen's pre-Roster behavior is preserved
## exactly when not opened from Roster.

@onready var name_label: Label = $Center/VBox/NameLabel
@onready var class_label: Label = $Center/VBox/ClassLabel
@onready var level_label: Label = $Center/VBox/LevelLabel
@onready var status_label: Label = $Center/VBox/StatusLabel
@onready var skills_label: Label = $Center/VBox/SkillsLabel
@onready var perks_label: Label = $Center/VBox/PerksLabel
@onready var stats_label: Label = $Center/VBox/StatsLabel
@onready var not_found_label: Label = $Center/VBox/NotFoundLabel
@onready var assignment_explanation_label: Label = $Center/VBox/AssignmentExplanationLabel
@onready var party_picker: OptionButton = $Center/VBox/PartyPicker
@onready var add_to_party_button: Button = $Center/VBox/AddToPartyButton
@onready var information_panel: PanelContainer = $InformationPanel

var unit_id: String = ""
var origin: String = ""
var add_member_return_party_id: String = ""


func _ready() -> void:
	unit_id = GameManager.route_context_id
	origin = GameManager.unit_details_origin
	add_member_return_party_id = GameManager.add_member_return_party_id
	information_panel.refresh()
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	var adventurer := GameSession.get_adventurer(unit_id)
	if adventurer.is_empty():
		_show_not_found()
		return
	_show_adventurer(adventurer)
	_refresh_assignment_section(adventurer)


func _show_adventurer(adventurer: Dictionary) -> void:
	not_found_label.visible = false

	name_label.text = adventurer["name"]
	class_label.text = tr("information.class") % adventurer["class"]
	level_label.text = tr("information.level") % adventurer["level"]
	status_label.text = tr("unit_details.status") % tr("availability.%s" % adventurer["availability_status"])

	for label in [name_label, class_label, level_label, status_label, skills_label, perks_label, stats_label]:
		label.visible = true


func _show_not_found() -> void:
	not_found_label.visible = true
	for label in [name_label, class_label, level_label, status_label, skills_label, perks_label, stats_label]:
		label.visible = false
	_hide_assignment_section()


## Shown only when this screen was opened via Roster for an adventurer that
## is both available and not already a member of any party — an assigned or
## unavailable unit, or any other entry path, hides this section entirely
## rather than showing it disabled. A Roster unit with no eligible encamped
## party to join still shows the section, but as a disabled, explained
## action rather than an empty picker.
func _refresh_assignment_section(adventurer: Dictionary) -> void:
	var eligible_for_assignment: bool = (
		origin == GameManager.UNIT_DETAILS_ORIGIN_ROSTER
		and GameSession.is_adventurer_available(adventurer["id"])
	)
	if not eligible_for_assignment:
		_hide_assignment_section()
		return

	var encamped_parties: Array[Dictionary] = GameSession.get_encamped_parties()
	party_picker.clear()
	for party in encamped_parties:
		party_picker.add_item(party.name)
		party_picker.set_item_metadata(party_picker.item_count - 1, party.id)

	var has_eligible_party := not encamped_parties.is_empty()
	assignment_explanation_label.visible = not has_eligible_party
	party_picker.visible = has_eligible_party
	add_to_party_button.visible = true
	add_to_party_button.disabled = not has_eligible_party


func _hide_assignment_section() -> void:
	assignment_explanation_label.visible = false
	party_picker.visible = false
	party_picker.clear()
	add_to_party_button.visible = false


## Party ids come from the picker's item metadata (never its display text),
## mirroring how TableView stores row_id_key in TreeItem metadata rather
## than trusting displayed text. A stale/invalid choice (the chosen party
## stopped being eligible while this screen was open) fails assignment
## safely and this screen just refreshes the section in place instead of
## navigating anywhere, matching add_member.gd/deploy_party.gd.
func _on_add_to_party_pressed() -> void:
	var selected_index := party_picker.get_selected()
	if selected_index < 0:
		refresh()
		return
	var party_id: String = party_picker.get_item_metadata(selected_index)
	if GameManager.assign_adventurer_to_party(party_id, unit_id) == OK:
		GameManager.go_to_roster()
		return
	refresh()


## Returns to Roster when this screen was reached from there, and to
## Parties otherwise — the same "reachable from more than one place, so
## remember how we got here" pattern party_details.gd uses for a deployed
## vs. encamped party, applied here to route origin instead.
func _on_back_pressed() -> void:
	if (
		origin == GameManager.UNIT_DETAILS_ORIGIN_ADD_MEMBER
		and not GameSession.get_party(add_member_return_party_id).is_empty()
	):
		GameManager.go_to_add_member(add_member_return_party_id)
	elif origin == GameManager.UNIT_DETAILS_ORIGIN_ROSTER:
		GameManager.go_to_roster()
	else:
		GameManager.go_to_parties()
