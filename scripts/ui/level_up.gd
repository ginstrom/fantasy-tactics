extends PanelContainer

## An immediate, modal level-up overlay for exactly one adventurer. Battlefield
## (its owner) instances this once, queues one call to show_for_adventurer()
## per leveled party member, and reacts to `resolved` to advance that queue
## or resume battle/result routing — this control never routes to another
## screen or scene by itself, and it owns no campaign data: every mutation
## goes through GameSession's validated spend_attack_points()/choose_perk()
## APIs.

## Emitted once the player has dismissed this level-up (a required perk, if
## any, has already been chosen). The owner reacts to this to show the next
## queued level-up, or to resume whatever was waiting on this one.
signal resolved

@onready var name_label: Label = $Content/NameLabel
@onready var xp_label: Label = $Content/XPLabel
@onready var level_label: Label = $Content/LevelLabel
@onready var health_gain_label: Label = $Content/HealthGainLabel
@onready var attack_label: Label = $Content/AttackLabel
@onready var skill_points_label: Label = $Content/SkillPointsLabel
@onready var attack_minus_button: Button = $Content/AttackRow/AttackMinusButton
@onready var attack_plus_button: Button = $Content/AttackRow/AttackPlusButton
@onready var perk_label: Label = $Content/PerkLabel
@onready var choose_bonus_move_button: Button = $Content/ChooseBonusMoveButton
@onready var continue_button: Button = $Content/ContinueButton

var adventurer_id: String = ""
var _health_before: int = 0


func _ready() -> void:
	attack_plus_button.pressed.connect(_on_attack_plus_pressed)
	attack_minus_button.pressed.connect(_on_attack_minus_pressed)
	choose_bonus_move_button.pressed.connect(_on_choose_bonus_move_pressed)
	continue_button.pressed.connect(_on_continue_pressed)


## The owner calls this once per queued level-up. health_before is the
## effective max health the adventurer had immediately before this level (the
## owner must capture it before calling GameSession.award_party_xp(), since
## that call already applies the increase) so the health-gain row can show the
## delta even though GameSession has already mutated the stored value.
func show_for_adventurer(id: String, health_before: int) -> void:
	adventurer_id = id
	_health_before = health_before
	refresh()
	show()


## Re-reads GameSession fresh rather than caching anything locally, so every
## button handler below can simply mutate GameSession and call this again.
func refresh() -> void:
	var adventurer := GameSession.get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return

	name_label.text = adventurer["name"]
	# xp is stored as a float; floor it for this display-only row and never
	# write the floored value back.
	xp_label.text = tr("level_up.xp") % int(floor(adventurer.progression.xp))
	level_label.text = tr("level_up.level") % adventurer["level"]

	var max_health: int = GameSession.get_effective_max_health(adventurer_id)
	health_gain_label.text = tr("level_up.health_gain") % [max_health, max_health - _health_before]

	var raw_attack: int = adventurer.stats.attack
	var hit_chance_percent := int(round(GameSession.get_effective_hit_chance(adventurer_id) * 100.0))
	attack_label.text = tr("level_up.attack") % [raw_attack, hit_chance_percent]

	var unspent_points: int = adventurer.progression.skill_points
	skill_points_label.text = tr("level_up.skill_points") % unspent_points
	attack_plus_button.disabled = unspent_points <= 0

	var pending := GameSession.is_perk_choice_pending(adventurer_id)
	perk_label.visible = pending
	if pending:
		perk_label.text = tr("level_up.perk_pending")
	choose_bonus_move_button.visible = pending
	continue_button.disabled = pending


func _on_attack_plus_pressed() -> void:
	GameSession.spend_attack_points(adventurer_id, 1)
	refresh()


## GameSession's spend_attack_points() only ever adds to Attack — there is no
## unspend/refund API to call here (and this task must not invent one; see
## the campaign progression design doc's ownership rules). This control stays
## present but permanently disabled, matching this codebase's existing
## "show a disabled action rather than hide it" convention (e.g.
## unit_details.gd's AddToPartyButton).
func _on_attack_minus_pressed() -> void:
	pass


func _on_choose_bonus_move_pressed() -> void:
	GameSession.choose_perk(adventurer_id, GameSession.BONUS_MOVE_PERK_ID)
	refresh()


func _on_continue_pressed() -> void:
	if GameSession.is_perk_choice_pending(adventurer_id):
		return
	hide()
	resolved.emit()
