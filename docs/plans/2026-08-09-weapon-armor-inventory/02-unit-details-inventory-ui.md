# Step 2: Unit Details — Carried-Items Lists

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Branch:** `weapon-armor-inventory-ui`

**Goal:** Unit Details shows two new sections, "Weapons" and "Armor",
listing everything that adventurer carries in each slot (from Step 1's
`equipment.weapon_inventory`/`armor_inventory`). The active item in each
list shows an "(equipped)" marker and no action buttons; every other row
shows real, text-labeled **[Activate]**/**[Unequip]** buttons that call
`GameSession.activate_carried_item`/`unequip_to_bank` and refresh the
screen. `EquipmentLabel` (the existing single-line active-weapon/active-
armor stat summary) is untouched — it already reads `equipment.weapon`/
`.armor`, unchanged by Step 1.

**Files:**
- Modify: `scenes/ui/unit_details.tscn`
- Modify: `scripts/ui/unit_details.gd`
- Modify: `translations/en.tres`
- Modify: `tests/unit/test_unit_details.gd`

## Step 1: Write the failing tests

Add to `tests/unit/test_unit_details.gd`, after
`test_equipment_label_reflects_a_changed_weapon` (search for that name):

```gdscript
func test_weapons_list_shows_the_lone_carried_weapon_as_equipped_with_no_action_buttons() -> void:
	var screen := _open_unit_details(GameSession.WARRIOR_ID)
	var weapons_list: VBoxContainer = screen.get_node("Body/Center/VBox/WeaponsList")

	assert_eq(weapons_list.get_child_count(), 1)
	var row := weapons_list.get_child(0)
	assert_eq(row.get_node("NameLabel").text, tr("unit_details.equipped_marker") % "Iron Longsword")
	assert_null(row.get_node_or_null("ActivateButton"))
	assert_null(row.get_node_or_null("UnequipButton"))


func test_armor_list_shows_the_lone_carried_armor_as_equipped_with_no_action_buttons() -> void:
	var screen := _open_unit_details(GameSession.WARRIOR_ID)
	var armor_list: VBoxContainer = screen.get_node("Body/Center/VBox/ArmorList")

	assert_eq(armor_list.get_child_count(), 1)
	var row := armor_list.get_child(0)
	assert_eq(row.get_node("NameLabel").text, tr("unit_details.equipped_marker") % "Leather Armor")
	assert_null(row.get_node_or_null("ActivateButton"))


func test_weapons_list_shows_a_non_active_carried_weapon_with_activate_and_unequip() -> void:
	GameSession.banked_gear = {"dagger_steel": 1}
	GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "dagger_steel")
	var screen := _open_unit_details(GameSession.WARRIOR_ID)
	var weapons_list: VBoxContainer = screen.get_node("Body/Center/VBox/WeaponsList")

	assert_eq(weapons_list.get_child_count(), 2)
	var inactive_row := weapons_list.get_child(0)
	assert_eq(inactive_row.get_node("NameLabel").text, "Iron Longsword")
	assert_not_null(inactive_row.get_node_or_null("ActivateButton"))
	assert_not_null(inactive_row.get_node_or_null("UnequipButton"))
	var active_row := weapons_list.get_child(1)
	assert_eq(active_row.get_node("NameLabel").text, tr("unit_details.equipped_marker") % "Steel Dagger")
	assert_null(active_row.get_node_or_null("ActivateButton"))
	assert_null(active_row.get_node_or_null("UnequipButton"))


func test_pressing_activate_switches_the_active_weapon_and_refreshes_the_screen() -> void:
	GameSession.banked_gear = {"dagger_steel": 1}
	GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "dagger_steel")
	var screen := _open_unit_details(GameSession.WARRIOR_ID)
	var weapons_list: VBoxContainer = screen.get_node("Body/Center/VBox/WeaponsList")
	var activate_button: Button = weapons_list.get_child(0).get_node("ActivateButton")

	activate_button.emit_signal("pressed")

	assert_eq(GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment.weapon, "longsword_iron")
	assert_eq(
		screen.get_node("Body/Center/VBox/WeaponsList").get_child(0).get_node("NameLabel").text,
		tr("unit_details.equipped_marker") % "Iron Longsword",
		"The screen must refresh in place to show the new active item"
	)


func test_pressing_unequip_returns_the_item_to_the_bank_and_refreshes_the_list() -> void:
	GameSession.banked_gear = {"dagger_steel": 1}
	GameSession.equip_item_from_bank(GameSession.WARRIOR_ID, "dagger_steel")
	var screen := _open_unit_details(GameSession.WARRIOR_ID)
	var weapons_list: VBoxContainer = screen.get_node("Body/Center/VBox/WeaponsList")
	var unequip_button: Button = weapons_list.get_child(0).get_node("UnequipButton")

	unequip_button.emit_signal("pressed")

	assert_eq(GameSession.banked_gear.longsword_iron, 1)
	assert_eq(
		screen.get_node("Body/Center/VBox/WeaponsList").get_child_count(), 1,
		"The list must refresh in place after unequipping"
	)


func test_weapons_and_armor_lists_are_hidden_for_an_unknown_unit() -> void:
	GameManager.route_context_id = "no_such_id"
	var screen: Control = UnitDetailsScene.instantiate()
	add_child_autofree(screen)

	assert_false(screen.get_node("Body/Center/VBox/WeaponsList").visible)
	assert_false(screen.get_node("Body/Center/VBox/ArmorList").visible)
	assert_false(screen.get_node("Body/Center/VBox/WeaponsLabel").visible)
	assert_false(screen.get_node("Body/Center/VBox/ArmorLabel").visible)
```

## Step 2: Run the tests to verify they fail

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_unit_details.gd -gexit
```

Expected: every new test FAILS —
`Body/Center/VBox/WeaponsList`/`ArmorList`/`WeaponsLabel`/`ArmorLabel`
don't exist in the scene yet.

## Step 3: Add the translation keys

In `translations/en.tres`, add next to the other `unit_details.*` keys
(search for `"unit_details.equipment"`):

```
"unit_details.weapons": "Weapons",
"unit_details.armor": "Armor",
"unit_details.equipped_marker": "%s (equipped)",
"unit_details.activate": "Activate",
"unit_details.unequip": "Unequip",
```

## Step 4: Add the new nodes to `scenes/ui/unit_details.tscn`

Insert four new nodes right after `EquipmentLabel` and before
`NotFoundLabel`:

```
[node name="WeaponsLabel" type="Label" parent="Body/Center/VBox"]
layout_mode = 2
visible = false
text = "unit_details.weapons"

[node name="WeaponsList" type="VBoxContainer" parent="Body/Center/VBox"]
layout_mode = 2
visible = false

[node name="ArmorLabel" type="Label" parent="Body/Center/VBox"]
layout_mode = 2
visible = false
text = "unit_details.armor"

[node name="ArmorList" type="VBoxContainer" parent="Body/Center/VBox"]
layout_mode = 2
visible = false
```

(No `script`/`connection` entries needed — rows and their button signals
are built and wired entirely in code, in Step 5, since the row count is
variable.)

## Step 5: Implement the lists in `scripts/ui/unit_details.gd`

Add the four new `@onready` node references next to the existing ones
(search for `@onready var equipment_label`):

```gdscript
@onready var weapons_label: Label = $Body/Center/VBox/WeaponsLabel
@onready var weapons_list: VBoxContainer = $Body/Center/VBox/WeaponsList
@onready var armor_label: Label = $Body/Center/VBox/ArmorLabel
@onready var armor_list: VBoxContainer = $Body/Center/VBox/ArmorList
```

In `_show_adventurer()`, find the existing `for label in [...]` visibility
loop near the bottom (search for `equipment_label]:`) and add the new
nodes to it, plus call the new refresh helper right before that loop:

```gdscript
	_refresh_equipment_sections(adventurer)

	for label in [
		name_label, class_label, level_label, status_label, skills_label, perks_label, stats_label,
		equipment_label, weapons_label, weapons_list, armor_label, armor_list,
	]:
		label.visible = true
```

In `_show_not_found()`, add the same four nodes to its own hiding loop
(search for the second `equipment_label]:`):

```gdscript
	for label in [
		name_label, class_label, level_label, status_label, skills_label, perks_label, stats_label,
		equipment_label, weapons_label, weapons_list, armor_label, armor_list,
	]:
		label.visible = false
```

Add the new methods anywhere among the other private helpers (e.g. right
after `_show_adventurer`):

```gdscript
func _refresh_equipment_sections(adventurer: Dictionary) -> void:
	var equipment: Dictionary = adventurer.equipment
	_populate_inventory_list(weapons_list, equipment.weapon_inventory, equipment.weapon, "weapon")
	_populate_inventory_list(armor_list, equipment.armor_inventory, equipment.armor, "armor")


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
func _populate_inventory_list(
	list_container: VBoxContainer, item_ids: Array, active_item_id: String, slot: String
) -> void:
	for child in list_container.get_children():
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
```

## Step 6: Run the tests to verify they pass

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_unit_details.gd -gexit
```

Expected: `N/N passed.`

## Full local verification

```
make check
```

Expected: `N/N passed.` and `---- All tests passed! ----`, exit 0.

## Manual verification

```
make play
```

1. Press **FN+F9**, choose **Stocked Trading Post + Stores**.
2. Trade → Trading Post → buy a second weapon (e.g. a Steel Dagger).
3. Trade → Stores → select the Steel Dagger → View → Equip.
4. Units → Roster → the Warrior → Unit Details. Confirm:
   - The existing Equipment summary line shows the Steel Dagger's stats.
   - A new **Weapons** section lists both the Iron Longsword and Steel
     Dagger; the Steel Dagger row shows "(equipped)" and no buttons; the
     Iron Longsword row shows real **[Activate]**/**[Unequip]** buttons.
   - A new **Armor** section lists just Leather Armor, marked "(equipped)"
     with no buttons (only one piece carried).
5. Click **[Activate]** on the Iron Longsword row — the Equipment summary
   line updates to show the Iron Longsword again, and the "(equipped)"
   marker moves to that row.
6. Click **[Unequip]** on the now-inactive Steel Dagger row — it
   disappears from the Weapons list, and Trade → Stores shows it back in
   the bank.

## Commit

```bash
git add scenes/ui/unit_details.tscn scripts/ui/unit_details.gd \
  translations/en.tres tests/unit/test_unit_details.gd
git commit -m "feat: show a unit's full weapon/armor inventory in Unit Details"
```

## Merge back to main

After user signoff on manual verification:

```bash
git checkout main
git merge weapon-armor-inventory-ui
git branch -d weapon-armor-inventory-ui
```
