class_name LevelUp
extends VBoxContainer

## Card body / modal level-up for exactly one adventurer (Information Design §2).
## Presents adventurer name, XP, level, health gain, skill gains, and perk selection.
## Owns no campaign data: every mutation goes through GameSession.

signal resolved(unit_id: String)

@onready var name_label: Label = %NameLabel
@onready var xp_label: Label = %XPLabel
@onready var level_label: Label = %LevelLabel
@onready var health_gain_label: Label = %HealthGainLabel
@onready var skill_gains_label: Label = %SkillGainsLabel
@onready var perk_label: Label = %PerkLabel
@onready var perk_options_container: VBoxContainer = %PerkOptionsContainer
@onready var continue_button: Button = %ContinueButton

var adventurer_id: String = ""
var _health_before: int = 0


func _ready() -> void:
	if is_instance_valid(continue_button):
		continue_button.pressed.connect(_on_continue_pressed)
	refresh()


## Shows the level-up modal for the named adventurer.
func show_for_adventurer(id: String, health_before: int = 0) -> void:
	adventurer_id = id
	_health_before = health_before
	refresh()
	show()
	_grab_initial_focus()


func _grab_initial_focus() -> void:
	if not is_inside_tree() or not is_instance_valid(perk_options_container):
		return
	for child in perk_options_container.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			return
	if is_instance_valid(continue_button) and continue_button.is_inside_tree() and continue_button.visible and not continue_button.disabled:
		continue_button.grab_focus()


## Re-reads GameSession fresh rather than caching anything locally, so every
## button handler below can simply mutate GameSession and call this again.
func refresh() -> void:
	if not is_inside_tree() or not is_instance_valid(name_label):
		return
	var adventurer := GameSession.get_adventurer(adventurer_id)
	if adventurer.is_empty():
		return

	name_label.text = adventurer["name"]
	# xp is stored as a float; floor it for this display-only row and never
	# write the floored value back.
	xp_label.text = tr("level_up.xp") % int(floor(adventurer.progression.xp))
	level_label.text = tr("level_up.level") % adventurer["level"]

	var max_health: int = GameSession.get_effective_max_health(adventurer_id)
	var class_id: String = adventurer.get("class", "warrior")
	var class_def: Dictionary = GameSession.CLASS_DEFINITIONS.get(class_id, GameSession.CLASS_DEFINITIONS.warrior)
	var health_delta: int = max_health - _health_before if _health_before > 0 else class_def.get("health_gain_per_level", 2)
	health_gain_label.text = tr("level_up.health_gain") % [max_health, health_delta]
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


func _refresh_perk_options(pending: bool) -> void:
	for child in perk_options_container.get_children():
		perk_options_container.remove_child(child)
		child.queue_free()

	if not pending:
		return

	for perk_id in GameSession.get_available_perks(adventurer_id):
		var button := _perk_option_button(perk_id)
		button.pressed.connect(_on_perk_option_pressed.bind(perk_id))
		perk_options_container.add_child(button)

	for status in GameSession.get_perk_tree_status(adventurer_id):
		if status.state != "locked":
			continue
		var button := _perk_option_button(status.id)
		button.text = tr("level_up.perk_locked") % button.text
		button.disabled = true
		perk_options_container.add_child(button)


func _perk_option_button(perk_id: String) -> Button:
	var button := Button.new()
	button.name = "PerkOption_%s" % perk_id
	var effect := GameSession.get_perk_effect_description(perk_id)
	button.text = (
		"%s (%s)" % [GameSession.get_perk_display_name(perk_id), effect] if not effect.is_empty()
		else GameSession.get_perk_display_name(perk_id)
	)
	return button


func _on_perk_option_pressed(perk_id: String) -> void:
	GameSession.choose_perk(adventurer_id, perk_id)
	refresh()


func _on_continue_pressed() -> void:
	if GameSession.is_perk_choice_pending(adventurer_id):
		return
	hide()
	resolved.emit(adventurer_id)
