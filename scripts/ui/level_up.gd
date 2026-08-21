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
@onready var skill_gains_label: Label = $Content/SkillGainsLabel
@onready var perk_label: Label = $Content/PerkLabel
@onready var perk_options_container: VBoxContainer = $Content/PerkOptionsContainer
@onready var continue_button: Button = $Content/ContinueButton

var adventurer_id: String = ""
var _health_before: int = 0


func _ready() -> void:
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

	var class_id: String = adventurer.get("class", "warrior")
	var class_def: Dictionary = GameSession.CLASS_DEFINITIONS.get(class_id, GameSession.CLASS_DEFINITIONS.warrior)
	var skills_def: Dictionary = class_def.get("skills", {})
	var gains_text: Array[String] = []
	for skill_name in ["melee", "missile", "guard", "might"]:
		if skills_def.has(skill_name):
			var val: int = adventurer.stats.get(skill_name, 0)
			var skill_info: Dictionary = skills_def[skill_name]
			var min_gain: int = skill_info.get("min_gain", 1)
			var max_gain: int = skill_info.get("max_gain", 2)
			var gain_str := "+%d" % min_gain if min_gain == max_gain else "+%d–%d" % [min_gain, max_gain]
			gains_text.append("%s: %d (%s)" % [skill_name.capitalize(), val, gain_str])
	skill_gains_label.text = "Gained Skills: " + " · ".join(gains_text)

	var pending := GameSession.is_perk_choice_pending(adventurer_id)
	perk_label.visible = pending
	if pending:
		perk_label.text = tr("level_up.perk_pending")
	_refresh_perk_options(pending)
	continue_button.disabled = pending


## Rebuilds the perk-choice buttons from scratch every refresh -- remove_
## child() (not just queue_free()) before re-populating, same as unit_
## details.gd's _populate_inventory_list(), so a synchronous re-refresh
## (pressing an option button calls refresh() with no frame in between)
## never counts a stale button still parented here. One button per
## GameSession.get_available_perks() entry -- dynamic, data-driven option
## controls rather than a class-name switch or a hard-coded second button --
## so a Warrior, Scout, or Cleric (one, two, or eventually more perks) all
## render correctly from this same code path. Renders nothing while no
## choice is pending, including once both of a class's perks are already
## chosen (get_available_perks() then returns [] and is_perk_choice_pending()
## is already permanently false -- no empty-tree state needed).
func _refresh_perk_options(pending: bool) -> void:
	for child in perk_options_container.get_children():
		perk_options_container.remove_child(child)
		child.queue_free()

	if not pending:
		return

	for perk_id in GameSession.get_available_perks(adventurer_id):
		var button := Button.new()
		button.name = "PerkOption_%s" % perk_id
		var effect := GameSession.get_perk_effect_description(perk_id)
		button.text = (
			"%s (%s)" % [GameSession.get_perk_display_name(perk_id), effect] if not effect.is_empty()
			else GameSession.get_perk_display_name(perk_id)
		)
		button.pressed.connect(_on_perk_option_pressed.bind(perk_id))
		perk_options_container.add_child(button)


func _on_perk_option_pressed(perk_id: String) -> void:
	GameSession.choose_perk(adventurer_id, perk_id)
	refresh()


func _on_continue_pressed() -> void:
	if GameSession.is_perk_choice_pending(adventurer_id):
		return
	hide()
	resolved.emit()
