extends PanelContainer

## Raised when the party View button is pressed. The panel never navigates
## itself; the owning screen (via GameManager) decides what happens next.
signal party_selected(party_id: String)

## Raised when the adventurer View button is pressed, for the same reason.
signal adventurer_selected(adventurer_id: String)

@onready var player_name_label: Label = $Content/PlayerName
@onready var gold_label: Label = $Content/Gold
@onready var party_name_label: Label = $Content/PartyName
@onready var party_members_label: Label = $Content/PartyMembers
@onready var party_view_button: Button = $Content/PartyViewButton
@onready var adventurer_name_label: Label = $Content/AdventurerName
@onready var adventurer_class_label: Label = $Content/AdventurerClass
@onready var adventurer_level_label: Label = $Content/AdventurerLevel
@onready var adventurer_view_button: Button = $Content/AdventurerViewButton

var _selected_party_id: String = ""
var _selected_adventurer_id: String = ""


func _ready() -> void:
	party_view_button.pressed.connect(_on_party_view_button_pressed)
	adventurer_view_button.pressed.connect(_on_adventurer_view_button_pressed)
	refresh()


## Renders only the permanent player/gold rows and hides any optional party or
## adventurer summary. Screens with no row selection (e.g. Encampment) call
## this directly.
func refresh() -> void:
	_refresh_permanent_rows()
	_clear_party_section()
	_clear_adventurer_section()


## Shows the permanent rows plus the named party's name, member count, and a
## View action. An unknown party_id clears the optional section instead of
## raising an error, so a stale selection never leaves the panel broken.
func refresh_party(party_id: String) -> void:
	_refresh_permanent_rows()
	_clear_adventurer_section()

	var party := GameSession.get_party(party_id)
	if party.is_empty():
		_clear_party_section()
		return

	_selected_party_id = party_id
	party_name_label.text = tr("information.party") % party["name"]
	party_members_label.text = tr("information.members") % party["member_ids"].size()
	party_view_button.text = tr("information.view_party")
	party_name_label.visible = true
	party_members_label.visible = true
	party_view_button.visible = true


## Shows the permanent rows plus the named adventurer's name, class, level,
## and a View action. An unknown adventurer_id clears the optional section
## safely.
func refresh_adventurer(adventurer_id: String) -> void:
	_refresh_permanent_rows()
	_clear_party_section()

	var adventurer := GameSession.get_adventurer(adventurer_id)
	if adventurer.is_empty():
		_clear_adventurer_section()
		return

	_selected_adventurer_id = adventurer_id
	adventurer_name_label.text = adventurer["name"]
	adventurer_class_label.text = tr("information.class") % adventurer["class"]
	adventurer_level_label.text = tr("information.level") % adventurer["level"]
	adventurer_name_label.visible = true
	adventurer_class_label.visible = true
	adventurer_level_label.visible = true
	adventurer_view_button.visible = true


func _refresh_permanent_rows() -> void:
	player_name_label.text = tr("information.player") % GameSession.player_name
	gold_label.text = tr("information.gold") % GameSession.gold


func _clear_party_section() -> void:
	_selected_party_id = ""
	party_name_label.visible = false
	party_members_label.visible = false
	party_view_button.visible = false


func _clear_adventurer_section() -> void:
	_selected_adventurer_id = ""
	adventurer_name_label.visible = false
	adventurer_class_label.visible = false
	adventurer_level_label.visible = false
	adventurer_view_button.visible = false


func _on_party_view_button_pressed() -> void:
	party_selected.emit(_selected_party_id)


func _on_adventurer_view_button_pressed() -> void:
	adventurer_selected.emit(_selected_adventurer_id)
