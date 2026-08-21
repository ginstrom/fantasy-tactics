extends Control

## Renders a single adventurer's real fields (name/class/level/availability,
## and — see _show_adventurer() — XP, raw/effective Attack, effective max
## health, unspent skill points, and Bonus Move perk status) from
## GameManager.route_context_id. Every value is read fresh from
## GameSession.get_adventurer()/its effective_* getters; this screen never
## invents or caches progression data of its own. An unknown id still leaves
## a working Back path.
##
## Opened via the Roster route (GameManager.unit_details_origin, captured
## once into `origin` below), an available and unassigned adventurer
## additionally sees a party picker and an Add to Party action — see
## _refresh_assignment_section. That section stays hidden entirely for
## every other entry path (e.g. from Party Details) and for an assigned or
## unavailable adventurer, so the screen's pre-Roster behavior is preserved
## exactly when not opened from Roster.

@onready var name_label: Label = $Body/Center/VBox/NameLabel
@onready var class_label: Label = $Body/Center/VBox/ClassLabel
@onready var level_label: Label = $Body/Center/VBox/LevelLabel
@onready var status_label: Label = $Body/Center/VBox/StatusLabel
@onready var skills_label: Label = $Body/Center/VBox/SkillsLabel
@onready var perks_label: Label = $Body/Center/VBox/PerksLabel
@onready var stats_label: Label = $Body/Center/VBox/StatsLabel
@onready var mp_label: Label = $Body/Center/VBox/MpLabel
@onready var equipment_label: Label = $Body/Center/VBox/EquipmentLabel
@onready var weapons_label: Label = $Body/Center/VBox/WeaponsLabel
@onready var weapons_list: VBoxContainer = $Body/Center/VBox/WeaponsList
@onready var armor_label: Label = $Body/Center/VBox/ArmorLabel
@onready var armor_list: VBoxContainer = $Body/Center/VBox/ArmorList
@onready var not_found_label: Label = $Body/Center/VBox/NotFoundLabel
@onready var heal_explanation_label: Label = $Body/Center/VBox/HealExplanationLabel
@onready var heal_target_picker: OptionButton = $Body/Center/VBox/HealTargetPicker
@onready var heal_button: Button = $Body/Center/VBox/HealButton
@onready var assignment_explanation_label: Label = $Body/Center/VBox/AssignmentExplanationLabel
@onready var party_picker: OptionButton = $Body/Center/VBox/PartyPicker
@onready var add_to_party_button: Button = $Body/Center/VBox/AddToPartyButton
@onready var information_panel: PanelContainer = %InformationPanel

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
	class_label.text = tr("information.class") % tr("class.%s" % adventurer["class"])
	level_label.text = tr("information.level") % adventurer["level"]
	status_label.text = tr("unit_details.status") % tr("availability.%s" % adventurer["availability_status"])

	var adventurer_id: String = adventurer["id"]
	# xp is stored as a float; floor it for this display-only row and never
	# write the floored value back (see GameSession.DEFAULT_WARRIOR).
	var xp_display: int = int(floor(adventurer.progression.xp))
	var xp_to_next_level: int = int(GameSession.get_level_xp_threshold(adventurer["level"] + 1))
	var current_health: int = GameSession.get_current_health(adventurer_id)
	var effective_max_health: int = GameSession.get_effective_max_health(adventurer_id)
	var effective_defense: int = GameSession.get_effective_defense(adventurer_id)
	var effective_resistance: int = GameSession.get_effective_resistance(adventurer_id)
	# Guard (effective_defense -- hit-chance subtraction) and Resistance
	# (effective_resistance -- post-hit damage reduction) are two distinct
	# shared tactical attributes (docs/designs/class-system.md's "Shared
	# tactical attributes" section); this line previously mislabeled Guard
	# as "Damage resistance" and Resistance as "Magic resistance" (Step 5's
	# "shared tactical profile migration" -- see that step's own doc
	# comment about not inventing a stat that means something else). Magic
	# Resistance itself is omitted here rather than shown as an always-0
	# placeholder -- no class has a magic-resistance source yet (see
	# GameSession.get_effective_magic_resistance()) -- and Spellcasting gets
	# its own conditional row in the Skills list below instead, the same
	# "don't expose a missing stat as real" rule applied the other way.
	stats_label.text = (
		"XP: %d / %d — Hit points: %d / %d — Action points: 6 — Guard: %d%% — Resistance: %d%% — Effects: None"
		% [xp_display, xp_to_next_level, current_health, effective_max_health, effective_defense, effective_resistance]
	)

	# MP row (durable, docs/designs/campaign-loop.md's "Cleric current MP is
	# durable adventurer state" paragraph): shown only for a class that
	# actually carries an MP resource (Cleric today) -- a Warrior/Scout's
	# get_effective_max_mp() is always 0, so this row simply stays hidden for
	# them rather than showing a meaningless "0 / 0".
	var effective_max_mp: int = GameSession.get_effective_max_mp(adventurer_id)
	mp_label.visible = effective_max_mp > 0
	if effective_max_mp > 0:
		mp_label.text = tr("unit_details.mp") % [GameSession.get_current_mp(adventurer_id), effective_max_mp]

	var weapon_damage_range: Vector2i = GameSession.get_effective_weapon_damage_range(adventurer_id)
	var weapon_attack_range: Vector2i = GameSession.get_effective_weapon_attack_range(adventurer_id)
	var weapon_range_text := (
		str(weapon_attack_range.x)
		if weapon_attack_range.x == weapon_attack_range.y
		else "%d–%d" % [weapon_attack_range.x, weapon_attack_range.y]
	)
	equipment_label.text = (
		tr("unit_details.equipment")
		% [
			GameSession.get_effective_weapon_name(adventurer_id), weapon_damage_range.x, weapon_damage_range.y,
			weapon_range_text,
			GameSession.get_effective_armor_name(adventurer_id),
			GameSession.get_effective_defense(adventurer_id), GameSession.get_effective_resistance(adventurer_id),
		]
	)

	var skills_lines: Array[String] = ["Skills:"]
	for skill in ["melee", "missile", "guard", "might"]:
		skills_lines.append("   %s: %d%%" % [skill.capitalize(), adventurer.stats.get(skill, 0)])
	# Spellcasting only ever appears for a class whose stats actually carry
	# it (Cleric today) -- unlike melee/missile/guard/might above, which
	# every class has, showing "Spellcasting: 0%" for a Warrior/Scout would
	# expose a stat that class doesn't own as though it were real (see this
	# function's stats_label doc comment just above for the same rule).
	if adventurer.stats.has("spellcasting"):
		skills_lines.append("   Spellcasting: %d%%" % adventurer.stats.spellcasting)
	skills_label.text = "\n".join(skills_lines)

	var perks: Array = adventurer.progression.get("perks", [])
	if perks.is_empty():
		perks_label.text = "Perks: None"
	else:
		var perk_lines: Array[String] = ["Perks:"]
		for perk_id in perks:
			perk_lines.append("* %s" % _get_perk_display_name(perk_id))
		perks_label.text = "\n".join(perk_lines)

	_refresh_equipment_sections(adventurer)
	_refresh_heal_section(adventurer_id, effective_max_mp)


	for label in [
		name_label, class_label, level_label, status_label, skills_label, perks_label, stats_label,
		equipment_label, weapons_label, weapons_list, armor_label, armor_list,
	]:
		label.visible = true


func _show_not_found() -> void:
	not_found_label.visible = true
	for label in [
		name_label, class_label, level_label, status_label, skills_label, perks_label, stats_label,
		equipment_label, weapons_label, weapons_list, armor_label, armor_list,
	]:
		label.visible = false
	mp_label.visible = false
	_hide_heal_section()
	_hide_assignment_section()


## Rebuilds one slot's row list from scratch on every refresh — item_ids is
## typically 1-4 entries, so a full rebuild is simpler and cheap enough
## compared to diffing against the previous render. Each row is a plain
## HBoxContainer (not TableView/Tree), because Tree's per-row buttons are
## icon-only — see LootDetailPanel in scripts/ui/loot_detail_panel.gd for
## the same constraint solved the same way. Node names (NameLabel/
## ActivateButton/UnequipButton) are fixed so tests can address rows by
## path; ActivateButton/UnequipButton are omitted entirely (not merely
## hidden) on the active row, since there's nothing to activate and it
## can't be unequipped until another item takes its place.
func _refresh_equipment_sections(adventurer: Dictionary) -> void:
	var equipment: Dictionary = adventurer.equipment
	_populate_inventory_list(weapons_list, equipment.weapon_inventory, equipment.weapon, "weapon")
	_populate_inventory_list(armor_list, equipment.armor_inventory, equipment.armor, "armor")


func _populate_inventory_list(
	list_container: VBoxContainer, item_ids: Array, active_item_id: String, slot: String
) -> void:
	# remove_child() (not just queue_free()) so a synchronous re-refresh (e.g.
	# a test pressing Activate/Unequip, which calls refresh() with no frame
	# in between) never counts stale rows still parented under
	# list_container — queue_free() alone only detaches at end of frame, the
	# same gotcha documented in portrait_panel.gd/battlefield.gd.
	for child in list_container.get_children():
		list_container.remove_child(child)
		child.queue_free()

	for item_id in item_ids:
		var row := HBoxContainer.new()
		var is_active: bool = item_id == active_item_id
		var item := GameSession.get_item_definition(item_id)
		var item_name: String = tr(item.name_key) if not item.is_empty() else item_id

		var name_label := Label.new()
		name_label.name = "NameLabel"
		name_label.text = tr("unit_details.equipped_marker") % item_name if is_active else item_name
		row.add_child(name_label)

		if not is_active:
			var activate_button := Button.new()
			activate_button.name = "ActivateButton"
			activate_button.text = tr("unit_details.activate")
			activate_button.pressed.connect(_on_activate_pressed.bind(slot, item_id))
			row.add_child(activate_button)

			var unequip_button := Button.new()
			unequip_button.name = "UnequipButton"
			unequip_button.text = tr("unit_details.unequip")
			unequip_button.pressed.connect(_on_unequip_pressed.bind(slot, item_id))
			row.add_child(unequip_button)

		list_container.add_child(row)


func _on_activate_pressed(slot: String, item_id: String) -> void:
	GameSession.activate_carried_item(unit_id, slot, item_id)
	refresh()


func _on_unequip_pressed(slot: String, item_id: String) -> void:
	GameSession.unequip_to_bank(unit_id, slot, item_id)
	refresh()


## "Heal party member" (docs/designs/campaign-loop.md's Healer paragraph):
## shown only when this adventurer is itself a spellcaster (effective_max_mp
## > 0, Cleric today) -- every other class simply never carries this section.
## The target picker lists only GameSession.get_legal_heal_targets(), which
## already excludes anything a real heal_party_member() call would reject or
## waste (wrong party, dead, already at full HP) -- an empty result disables
## the whole action and shows why, rather than offering a target the
## transaction is guaranteed to no-op on. This screen only ever calls the
## transaction through the button signal (_on_heal_button_pressed) and
## re-reads state via refresh() afterward; it never assigns health or MP
## itself.
func _refresh_heal_section(adventurer_id: String, effective_max_mp: int) -> void:
	if effective_max_mp <= 0:
		_hide_heal_section()
		return

	var target_ids: Array[String] = GameSession.get_legal_heal_targets(adventurer_id)
	heal_target_picker.clear()
	for target_id in target_ids:
		var target := GameSession.get_adventurer(target_id)
		heal_target_picker.add_item(target.get("name", target_id))
		heal_target_picker.set_item_metadata(heal_target_picker.item_count - 1, target_id)

	var can_heal: bool = (
		GameSession.get_current_mp(adventurer_id) >= GameSession.DETAILS_HEAL_MP_COST and not target_ids.is_empty()
	)
	heal_target_picker.visible = can_heal
	heal_button.visible = true
	heal_button.disabled = not can_heal
	heal_explanation_label.visible = not can_heal


func _hide_heal_section() -> void:
	heal_target_picker.visible = false
	heal_target_picker.clear()
	heal_button.visible = false
	heal_explanation_label.visible = false


## Party id/target id both come from picker item metadata, never displayed
## text -- same convention as _on_add_to_party_pressed(). A stale/invalid
## selection (nothing chosen, or the picker is empty) just re-refreshes in
## place rather than calling the transaction with a meaningless target.
func _on_heal_button_pressed() -> void:
	var selected_index := heal_target_picker.get_selected()
	if selected_index < 0:
		refresh()
		return
	var target_id: String = heal_target_picker.get_item_metadata(selected_index)
	GameSession.heal_party_member(unit_id, target_id)
	refresh()


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

	# get_encamped_parties() intentionally includes a full-but-encamped party
	# (it's still a valid unit-assignment target from GameSession's point of
	# view — see its docstring); this screen filters those out itself so it
	# never offers a party assignment that would fail for capacity reasons.
	var encamped_parties: Array[Dictionary] = []
	for party in GameSession.get_encamped_parties():
		if party.member_ids.size() < GameSession.get_max_party_size():
			encamped_parties.append(party)
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
	elif (
		origin == GameManager.UNIT_DETAILS_ORIGIN_PARTY_DETAILS
		and not GameSession.get_party(add_member_return_party_id).is_empty()
	):
		GameManager.go_to_party_details(add_member_return_party_id)
	elif origin == GameManager.UNIT_DETAILS_ORIGIN_ROSTER:
		GameManager.go_to_roster()
	else:
		GameManager.go_to_parties()


## Delegates to GameSession's own perk metadata readers (get_perk_display_
## name()/get_perk_effect_description()) rather than inventing display copy
## here -- the same source level_up.gd's option buttons render from, so an
## owned perk's name and effect read identically in both places. A perk with
## no effect description (should not happen for any id GameSession actually
## grants) still shows its bare name rather than a dangling "()" suffix.
func _get_perk_display_name(perk_id: String) -> String:
	var perk_name := GameSession.get_perk_display_name(perk_id)
	var effect := GameSession.get_perk_effect_description(perk_id)
	return "%s (%s)" % [perk_name, effect] if not effect.is_empty() else perk_name

