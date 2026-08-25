extends Control

## An owner-neutral modal level-up overlay for exactly one adventurer (Information Design §2).
## Presents full-screen dim backdrop, centered panel, Escape/Continue dismissal, and perk
## selection. Owns no campaign data: every mutation goes through GameSession.

signal resolved

@onready var dim_rect: ColorRect = $Dim
@onready var name_label: Label = $Center/Panel/Margin/Content/NameLabel
@onready var xp_label: Label = $Center/Panel/Margin/Content/XPLabel
@onready var level_label: Label = $Center/Panel/Margin/Content/LevelLabel
@onready var health_gain_label: Label = $Center/Panel/Margin/Content/HealthGainLabel
@onready var skill_gains_label: Label = $Center/Panel/Margin/Content/SkillGainsLabel
@onready var perk_label: Label = $Center/Panel/Margin/Content/PerkLabel
@onready var perk_options_container: VBoxContainer = $Center/Panel/Margin/Content/PerkOptionsContainer
@onready var continue_button: Button = $Center/Panel/Margin/Content/ContinueButton

var adventurer_id: String = ""
var _health_before: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	dim_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	continue_button.pressed.connect(_on_continue_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if not GameSession.is_perk_choice_pending(adventurer_id):
			_on_continue_pressed()


## Shows the level-up modal for the named adventurer.
func show_for_adventurer(id: String, health_before: int = 0) -> void:
	adventurer_id = id
	_health_before = health_before
	refresh()
	show()
	_grab_initial_focus()


func _grab_initial_focus() -> void:
	for child in perk_options_container.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			return
	if continue_button.is_inside_tree() and continue_button.visible and not continue_button.disabled:
		continue_button.grab_focus()



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
##
## Stage 6 Step 4 (task 5, G3): ALSO renders a disabled row for any perk in
## the adventurer's own tree GameSession.get_perk_tree_status() reports as
## "locked" (prerequisites not yet met, e.g. Knight's Shield Bash/Chain Blow
## before Discipline is chosen) -- prerequisite fulfillment is visible up
## front rather than the child perk silently not existing yet. Every existing
## non-branching class's own perks are never "locked" (empty prerequisite_ids
## -- see PerkCatalogScript's own doc comment), so this is a pure no-op
## addition for them.
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


## Shared button-building for both a real choosable option and a disabled
## locked row above -- identical text/name shape either way, so a locked
## perk reads exactly like the real thing it will become once its
## prerequisite is chosen, distinguished by its "(Locked)" suffix and
## .disabled.
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
	resolved.emit()
