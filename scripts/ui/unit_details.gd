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
@onready var equipment_label: Label = $Body/Center/VBox/EquipmentLabel
@onready var weapons_label: Label = $Body/Center/VBox/WeaponsLabel
@onready var weapons_list: VBoxContainer = $Body/Center/VBox/WeaponsList
@onready var armor_label: Label = $Body/Center/VBox/ArmorLabel
@onready var armor_list: VBoxContainer = $Body/Center/VBox/ArmorList
@onready var not_found_label: Label = $Body/Center/VBox/NotFoundLabel
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
	class_label.text = tr("information.class") % adventurer["class"]
	level_label.text = tr("information.level") % adventurer["level"]
	status_label.text = tr("unit_details.status") % tr("availability.%s" % adventurer["availability_status"])

	var adventurer_id: String = adventurer["id"]
	# xp is stored as a float; floor it for this display-only row and never
	# write the floored value back (see GameSession.DEFAULT_WARRIOR).
	var xp_display: int = int(floor(adventurer.progression.xp))
	var xp_to_next_level: int = int(GameSession.get_level_xp_threshold(adventurer["level"] + 1))
	var raw_attack: int = adventurer.stats.attack
	var hit_chance_percent := int(round(GameSession.get_effective_hit_chance(adventurer_id) * 100.0))
	var effective_max_health: int = GameSession.get_effective_max_health(adventurer_id)
	stats_label.text = (
		tr("unit_details.stats")
		% [xp_display, xp_to_next_level, raw_attack, hit_chance_percent, effective_max_health]
	)

	var weapon_range: Vector2i = GameSession.get_effective_weapon_damage_range(adventurer_id)
	equipment_label.text = (
		tr("unit_details.equipment")
		% [
			GameSession.get_effective_weapon_name(adventurer_id), weapon_range.x, weapon_range.y,
			GameSession.get_effective_armor_name(adventurer_id),
			GameSession.get_effective_defense(adventurer_id), GameSession.get_effective_resistance(adventurer_id),
		]
	)

	skills_label.text = tr("unit_details.skills") % adventurer.progression.skill_points

	var has_bonus_move: bool = adventurer.progression.perks.has(GameSession.BONUS_MOVE_PERK_ID)
	var perk_status_key := (
		"unit_details.perk_status.learned" if has_bonus_move else "unit_details.perk_status.not_learned"
	)
	perks_label.text = tr("unit_details.perks") % tr(perk_status_key)

	_refresh_equipment_sections(adventurer)

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
