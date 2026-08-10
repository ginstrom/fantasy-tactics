extends PanelContainer

## Raised when the party View button is pressed. The panel never navigates
## itself; the owning screen (via GameManager) decides what happens next.
signal party_selected(party_id: String)

## Raised when the adventurer View button is pressed, for the same reason.
signal adventurer_selected(adventurer_id: String)

## Raised when the Recruit button is pressed. Like the two signals above,
## the panel never purchases by itself; the owning screen (via GameManager)
## decides what happens next (see recruitment.gd).
signal recruit_selected(candidate_id: String)

@onready var player_name_label: Label = $Content/PlayerName
@onready var gold_label: Label = $Content/Gold
@onready var party_name_label: Label = $Content/PartyName
@onready var party_members_label: Label = $Content/PartyMembers
@onready var party_gold_label: Label = $Content/PartyGold
@onready var party_view_button: Button = $Content/PartyViewButton
@onready var adventurer_name_label: Label = $Content/AdventurerName
@onready var adventurer_class_label: Label = $Content/AdventurerClass
@onready var adventurer_level_label: Label = $Content/AdventurerLevel
@onready var adventurer_view_button: Button = $Content/AdventurerViewButton
@onready var recruitment_name_label: Label = $Content/RecruitmentName
@onready var recruitment_class_label: Label = $Content/RecruitmentClass
@onready var recruitment_level_label: Label = $Content/RecruitmentLevel
@onready var recruitment_cost_label: Label = $Content/RecruitmentCost
@onready var recruit_button: Button = $Content/RecruitButton

var _selected_party_id: String = ""
var _selected_adventurer_id: String = ""
var _selected_recruitment_candidate_id: String = ""


func _ready() -> void:
	party_view_button.pressed.connect(_on_party_view_button_pressed)
	adventurer_view_button.pressed.connect(_on_adventurer_view_button_pressed)
	recruit_button.pressed.connect(_on_recruit_button_pressed)
	refresh()


## Renders only the permanent player/gold rows and hides any optional party,
## adventurer, or recruitment summary. Screens with no row selection (e.g.
## Encampment) call this directly.
func refresh() -> void:
	_refresh_permanent_rows()
	_clear_party_section()
	_clear_adventurer_section()
	_clear_recruitment_section()


## Shows the permanent rows plus the named party's name, member count, and a
## View action. An unknown party_id clears the optional section instead of
## raising an error, so a stale selection never leaves the panel broken.
## pending_reward is the caller's unbanked GameSession.pending_reward for this
## party (World Map is the only caller that has one to show); it renders as
## an extra row only when positive, and stays hidden otherwise.
func refresh_party(party_id: String, pending_reward: int = 0) -> void:
	_refresh_permanent_rows()
	_clear_adventurer_section()
	_clear_recruitment_section()

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
	party_gold_label.visible = pending_reward > 0
	if pending_reward > 0:
		party_gold_label.text = tr("information.party_gold") % pending_reward


## Shows the permanent rows plus the named adventurer's name, class, level,
## and a View action. An unknown adventurer_id clears the optional section
## safely.
func refresh_adventurer(adventurer_id: String) -> void:
	_refresh_permanent_rows()
	_clear_party_section()
	_clear_recruitment_section()

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


## Shows the permanent rows plus the named recruitment candidate's name,
## class, level, cost, and a Recruit action. An unknown candidate_id (already
## purchased, or otherwise stale) clears the optional section safely, same
## as refresh_party()/refresh_adventurer(). The Recruit action is re-derived
## from GameSession.gold on every call, so re-selecting the same candidate
## after gold changed always reflects the current affordability rather than
## an earlier refresh's state.
func refresh_recruitment_candidate(candidate_id: String) -> void:
	_refresh_permanent_rows()
	_clear_party_section()
	_clear_adventurer_section()

	var candidate := _find_recruitment_candidate(candidate_id)
	if candidate.is_empty():
		_clear_recruitment_section()
		return

	_selected_recruitment_candidate_id = candidate_id
	recruitment_name_label.text = candidate["name"]
	recruitment_class_label.text = tr("information.class") % candidate["class"]
	recruitment_level_label.text = tr("information.level") % candidate["level"]
	# information.recruitment_cost is substituted as the label VALUE here, not
	# used as the format string like every other row above/below (e.g.
	# tr("information.class") % ...). Keep its translation a plain label word
	# with no %d/%s of its own — the numeric placeholder already lives in
	# this line's "%s %d" template.
	recruitment_cost_label.text = "%s %d" % [tr(&"information.recruitment_cost"), candidate["cost"]]
	recruitment_name_label.visible = true
	recruitment_class_label.visible = true
	recruitment_level_label.visible = true
	recruitment_cost_label.visible = true
	recruit_button.visible = true
	recruit_button.disabled = GameSession.gold < int(candidate["cost"])


## Candidates are resolved fresh from GameSession.get_recruitment_candidates()
## rather than trusting anything cached locally, matching how refresh_party()/
## refresh_adventurer() always re-resolve their own ids.
func _find_recruitment_candidate(candidate_id: String) -> Dictionary:
	for candidate in GameSession.get_recruitment_candidates():
		if candidate.id == candidate_id:
			return candidate
	return {}


func _refresh_permanent_rows() -> void:
	player_name_label.text = tr("information.player") % GameSession.player_name
	gold_label.text = tr("information.gold") % GameSession.gold


func _clear_party_section() -> void:
	_selected_party_id = ""
	party_name_label.visible = false
	party_members_label.visible = false
	party_view_button.visible = false
	party_gold_label.visible = false


func _clear_adventurer_section() -> void:
	_selected_adventurer_id = ""
	adventurer_name_label.visible = false
	adventurer_class_label.visible = false
	adventurer_level_label.visible = false
	adventurer_view_button.visible = false


## Disabled here in addition to hidden, so the Recruit action always starts
## (or falls back to) disabled-by-default rather than merely invisible.
func _clear_recruitment_section() -> void:
	_selected_recruitment_candidate_id = ""
	recruitment_name_label.visible = false
	recruitment_class_label.visible = false
	recruitment_level_label.visible = false
	recruitment_cost_label.visible = false
	recruit_button.visible = false
	recruit_button.disabled = true


func _on_party_view_button_pressed() -> void:
	party_selected.emit(_selected_party_id)


func _on_adventurer_view_button_pressed() -> void:
	adventurer_selected.emit(_selected_adventurer_id)


func _on_recruit_button_pressed() -> void:
	recruit_selected.emit(_selected_recruitment_candidate_id)
