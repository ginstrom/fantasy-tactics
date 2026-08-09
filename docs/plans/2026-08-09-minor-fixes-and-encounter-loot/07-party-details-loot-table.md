# Step 7: World Map Party Details Loot Table

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Branch:** `party-details-loot-table`

**Goal:** Party Details (`party_details.tscn`, shared by both the Parties
list — an encamped party — and the World Map's View Party — a deployed
party) currently shows one aggregate `LootLabel` built from
`GameSession.banked_gear`/`mana_crystals` (Stores' *banked* inventory)
regardless of whether the party is encamped or deployed. That's backwards
for a deployed party — it should show what the party is *carrying*
(`GameSession.pending_gear`/`pending_mana_crystals`), itemized, not what's
already banked at home. Replace `LootLabel` with the `LootTable` component
(Step 4), visible only while deployed, reading the pending fields, with a
party-scoped `[Equip]` (Step 6's `assign_equipment_party_id`/
`assign_equipment_origin` plumbing, reused unchanged) and no `[Sell]`.
`GoldLabel` is untouched — see `index.md`'s design reference.

**Files:**
- Modify: `scripts/ui/party_details.gd`
- Modify: `scenes/ui/party_details.tscn`
- Modify: `translations/en.tres`
- Test: `tests/unit/test_party_details.gd`
- Test: `tests/unit/test_localization.gd`

## Step 1: Write the failing tests

In `tests/unit/test_party_details.gd`, replace
`test_party_details_shows_gold_and_banked_loot` and
`test_party_details_shows_zero_gold_and_loot_on_a_fresh_session`:

```gdscript
func test_party_details_shows_gold_and_banked_loot() -> void:
	GameSession.create_party()
	GameSession.gold = 250
	GameSession.mana_crystals = {1: 2, 2: 1}
	GameSession.banked_gear = {"dagger_iron": 1, "leather_armor": 2}
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	assert_eq(screen.get_node("Body/Center/VBox/GoldLabel").text, tr("party_details.gold") % 250)
	assert_eq(
		screen.get_node("Body/Center/VBox/LootLabel").text,
		tr("party_details.loot") % [3, 3],
		"3 mana crystals (2 tier-1 + 1 tier-2) and 3 gear pieces (1 dagger + 2 armor)"
	)


func test_party_details_shows_zero_gold_and_loot_on_a_fresh_session() -> void:
	GameSession.create_party()
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	assert_eq(screen.get_node("Body/Center/VBox/GoldLabel").text, tr("party_details.gold") % 0)
	assert_eq(screen.get_node("Body/Center/VBox/LootLabel").text, tr("party_details.loot") % [0, 0])
```

with:

```gdscript
func test_party_details_shows_gold_and_hides_the_loot_table_for_an_encamped_party() -> void:
	GameSession.create_party()
	GameSession.gold = 250
	# Banked (not pending) loot -- Stores' inventory, not this party's own.
	# An encamped party has already deposited everything it carried; the
	# loot table must not show Stores' inventory here at all.
	GameSession.mana_crystals = {1: 2, 2: 1}
	GameSession.banked_gear = {"dagger_iron": 1, "leather_armor": 2}
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	assert_eq(screen.get_node("Body/Center/VBox/GoldLabel").text, tr("party_details.gold") % 250)
	assert_false(
		screen.get_node("Body/Center/VBox/LootTable").visible,
		"Loot has already banked into Stores by the time a party is back at the Encampment"
	)


func test_party_details_shows_zero_gold_on_a_fresh_session() -> void:
	GameSession.create_party()
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	assert_eq(screen.get_node("Body/Center/VBox/GoldLabel").text, tr("party_details.gold") % 0)


func test_a_deployed_partys_loot_table_shows_everything_it_is_carrying() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	GameSession.pending_mana_crystals = {1: 2}
	GameSession.pending_gear = ["dagger_iron", "dagger_iron"]
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)
	var tree: Tree = screen.get_node("Body/Center/VBox/LootTable/Content/Table/Tree")

	assert_true(screen.get_node("Body/Center/VBox/LootTable").visible)
	assert_eq(UiTestHelpers.tree_row_values(tree, 0), ["Iron Dagger", "Mana Crystal (Tier 1)"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 2), ["2", "2"])


## LootTable no longer puts Sell/Equip in per-row Tree buttons -- selecting
## a row and clicking [View] (or double-clicking it) opens LootDetailPanel,
## a real PanelContainer with real, text-labeled Sell/Equip buttons (see
## scripts/ui/loot_table.gd/loot_detail_panel.gd; this redesign landed
## during Step 4's manual verification, after this step was originally
## drafted). configure(false, true) means the detail panel's Equip button
## shows for a gear row and its Sell button never does.
func test_deployed_loot_table_has_an_equip_action_but_no_sell_action() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	GameSession.pending_gear = ["dagger_iron"]
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)
	var tree: Tree = screen.get_node("Body/Center/VBox/LootTable/Content/Table/Tree")
	var item := tree.get_root().get_first_child()
	item.select(0)
	tree.emit_signal("item_selected")
	screen.get_node("Body/Center/VBox/LootTable/Content/ViewButton").emit_signal("pressed")

	var detail_panel: Control = screen.get_node("Body/Center/VBox/LootTable/LootDetailPanel")
	assert_true(detail_panel.visible)
	assert_true(detail_panel.get_node("Content/ButtonRow/EquipButton").visible)
	assert_false(detail_panel.get_node("Content/ButtonRow/SellButton").visible)


func test_equip_routes_via_game_manager_scoped_to_this_party() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/party_details.gd")
	assert_string_contains(source, "GameManager.go_to_assign_equipment(item_id, party_id")
	assert_string_contains(source, "GameManager.AssignEquipmentOrigin.PARTY_DETAILS")
```

## Step 2: Run the tests to verify they fail

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_party_details.gd -gexit
```

Expected: the new tests referencing `LootTable` FAIL (the node doesn't
exist yet); the old two tests you just replaced are gone, so they no
longer run at all.

## Step 3: Remove the now-dead translation key

In `translations/en.tres`, remove:

```
"party_details.loot": "Loot: %d mana crystals, %d gear",
```

In `tests/unit/test_localization.gd`, remove the line asserting it:

```gdscript
	assert_eq(tr("party_details.loot") % [3, 2], "Loot: 3 mana crystals, 2 gear")
```

## Step 4: Rewrite `scripts/ui/party_details.gd`

```gdscript
extends Control

## Shows the roster of a single party (read from GameManager.route_context_id)
## as a TableView row per member, keyed by stable adventurer id, and mirrors
## the selected row into the shared InformationPanel — the same selection
## pattern Parties uses for parties (see parties.gd), applied to this party's
## members instead. Row activation and the panel's View button both open the
## existing Unit Details screen. Add Member is hidden entirely for a deployed
## party, since you can't add a member to a party that's out in the field,
## and disabled for an encamped party with no available adventurer left to
## add.
##
## Loot: a deployed party's LootTable shows everything it's carrying
## (GameSession.pending_gear/pending_mana_crystals, itemized) with a
## party-scoped [Equip] and no [Sell]. An encamped party shows no loot
## table at all — deposit_pending_reward() has already moved that loot
## into GameSession.banked_gear/mana_crystals (Stores' inventory) by the
## time a party is back at the Encampment. GoldLabel always shows
## GameSession.gold (banked gold) regardless of deployment state — that's
## unchanged, pre-existing behavior this screen doesn't touch.

const TableColumnDescriptor := preload("res://scripts/ui/table_column.gd")

@onready var party_name_label: Label = $Body/Center/VBox/PartyNameLabel
@onready var gold_label: Label = $Body/Center/VBox/GoldLabel
@onready var loot_table: LootTable = $Body/Center/VBox/LootTable
@onready var member_table: TableView = $Body/Center/VBox/MemberTable
@onready var empty_label: Label = $Body/Center/VBox/EmptyLabel
@onready var add_member_button: Button = $Body/Center/VBox/AddMemberButton
@onready var information_panel: PanelContainer = %InformationPanel

var party_id: String = ""
var selected_adventurer_id: String = ""


func _ready() -> void:
	information_panel.adventurer_selected.connect(_on_information_panel_adventurer_selected)
	party_id = GameManager.route_context_id
	member_table.row_selected.connect(_on_row_selected)
	member_table.row_activated.connect(_on_row_activated)
	member_table.set_columns(_build_columns())
	loot_table.configure(false, true)
	loot_table.equip_requested.connect(_on_equip_requested)
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	var party := GameSession.get_party(party_id)
	party_name_label.text = "" if party.is_empty() else party.name
	gold_label.text = tr("party_details.gold") % GameSession.gold
	var deployed: bool = party.get("deployed", false)
	loot_table.visible = deployed
	if deployed:
		loot_table.set_rows(GameSession.build_loot_rows(_pending_gear_counts(), GameSession.pending_mana_crystals))
	var rows := _build_rows(party)
	member_table.set_rows(rows)
	empty_label.visible = rows.is_empty()
	# A deployed party is out in the field; Add Member doesn't even make
	# sense to offer, so it disappears entirely rather than merely staying
	# disabled. An encamped party with nobody left to recruit keeps the
	# button visible but disabled, so its presence isn't a mystery.
	add_member_button.visible = not deployed
	add_member_button.disabled = (
		GameSession.get_available_adventurers().is_empty()
		or party.get("member_ids", []).size() >= GameSession.get_max_party_size()
	)
	_refresh_selection()


func _build_columns() -> Array[TableColumn]:
	var name_column := TableColumnDescriptor.new(&"name", tr("party_details.column.name"))
	name_column.expand = true
	name_column.expand_ratio = 2
	var class_column := TableColumnDescriptor.new(&"class", tr("party_details.column.class"))
	var level_column := TableColumnDescriptor.new(
		&"level", tr("party_details.column.level"), TableColumnDescriptor.Type.INTEGER
	)
	return [name_column, class_column, level_column]


func _build_rows(party: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var member_ids: Array = party.get("member_ids", [])
	for adventurer_id in member_ids:
		var adventurer := GameSession.get_adventurer(adventurer_id)
		if adventurer.is_empty():
			continue
		rows.append({
			"id": adventurer.id,
			"name": adventurer.name,
			"class": adventurer["class"],
			"level": adventurer.level,
		})
	return rows


func _pending_gear_counts() -> Dictionary:
	var counts: Dictionary = {}
	for item_id in GameSession.pending_gear:
		counts[item_id] = counts.get(item_id, 0) + 1
	return counts


## A selection is only valid while it names a current member of this party
## (not merely an adventurer that still exists somewhere): the party may have
## been reset out from under this screen, or the member may have left the
## party. Either way this clears back to the safe, unselected empty state
## instead of leaving the panel pointed at a stale id.
func _refresh_selection() -> void:
	var party := GameSession.get_party(party_id)
	var member_ids: Array = party.get("member_ids", [])
	if selected_adventurer_id == "" or not selected_adventurer_id in member_ids:
		selected_adventurer_id = ""
		information_panel.refresh()
		return
	information_panel.refresh_adventurer(selected_adventurer_id)


func _on_row_selected(row_id: Variant) -> void:
	selected_adventurer_id = str(row_id)
	_refresh_selection()


func _on_row_activated(row_id: Variant) -> void:
	GameManager.go_to_unit_details_from_party_details(str(row_id), party_id)


func _on_information_panel_adventurer_selected(adventurer_id: String) -> void:
	GameManager.go_to_unit_details_from_party_details(adventurer_id, party_id)


func _on_add_member_pressed() -> void:
	GameManager.go_to_add_member(party_id)


func _on_equip_requested(item_id: String) -> void:
	GameManager.go_to_assign_equipment(item_id, party_id, GameManager.AssignEquipmentOrigin.PARTY_DETAILS)


## Reachable from both Parties (an encamped party) and, since World Map's
## View Party button was wired up, from World Map (a deployed party). Back
## must return to whichever of those the player actually came from instead
## of always landing on Parties — otherwise a deployed party visually
## "teleports" back to the Encampment. route_context_id is cleared here
## directly (rather than relying on the destination route to do it) because
## go_to_world_map() does not clear it the way go_to_parties() does.
func _on_back_pressed() -> void:
	var deployed: bool = GameSession.get_party(party_id).get("deployed", false)
	GameManager.route_context_id = ""
	if deployed:
		GameManager.go_to_world_map()
	else:
		GameManager.go_to_parties()
```

(Everything from `_refresh_selection()` through `_on_back_pressed()` is
unchanged from today's file — only `refresh()`'s body, the new
`_pending_gear_counts()` helper, and the new `_on_equip_requested()` are
new. The old `_banked_mana_crystal_count()`/`_banked_gear_count()` helpers
are deleted; nothing else calls them.)

## Step 5: Update `scenes/ui/party_details.tscn`

Change the `ext_resource` list to add `loot_table.tscn`, and replace the
`LootLabel` node with a `LootTable` instance in the same position:

```
[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://scripts/ui/party_details.gd" id="1_party_details"]
[ext_resource type="PackedScene" path="res://scenes/ui/information_panel.tscn" id="2_information_panel"]
[ext_resource type="Script" path="res://scripts/ui/table_view.gd" id="3_table_view"]
[ext_resource type="PackedScene" path="res://scenes/ui/camp_nav.tscn" id="4_camp_nav"]
[ext_resource type="PackedScene" path="res://scenes/ui/loot_table.tscn" id="5_loot_table"]

[node name="PartyDetails" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_party_details")

[node name="Body" type="HBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
theme_override_constants/separation = 16

[node name="CampNav" parent="Body" instance=ExtResource("4_camp_nav")]
layout_mode = 2

[node name="Center" type="CenterContainer" parent="Body"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 3

[node name="VBox" type="VBoxContainer" parent="Body/Center"]
layout_mode = 2
theme_override_constants/separation = 16

[node name="Title" type="Label" parent="Body/Center/VBox"]
layout_mode = 2
text = "party_details.title"
horizontal_alignment = 1

[node name="PartyNameLabel" type="Label" parent="Body/Center/VBox"]
layout_mode = 2
horizontal_alignment = 1

[node name="GoldLabel" type="Label" parent="Body/Center/VBox"]
layout_mode = 2
horizontal_alignment = 1

[node name="LootTable" parent="Body/Center/VBox" instance=ExtResource("5_loot_table")]
visible = false
layout_mode = 2
custom_minimum_size = Vector2(520, 160)

[node name="MembersLabel" type="Label" parent="Body/Center/VBox"]
layout_mode = 2
text = "party_details.members"

[node name="MemberTable" type="VBoxContainer" parent="Body/Center/VBox"]
layout_mode = 2
custom_minimum_size = Vector2(520, 280)
script = ExtResource("3_table_view")

[node name="EmptyLabel" type="Label" parent="Body/Center/VBox"]
layout_mode = 2
visible = false
text = "party_details.no_members"
horizontal_alignment = 1

[node name="AddMemberButton" type="Button" parent="Body/Center/VBox"]
layout_mode = 2
text = "party_details.add_member"

[node name="BackButton" type="Button" parent="Body/Center/VBox"]
layout_mode = 2
text = "ui.back"

[node name="InformationMargin" type="MarginContainer" parent="Body"]
layout_mode = 2
size_flags_vertical = 0
theme_override_constants/margin_top = 16
theme_override_constants/margin_right = 16
theme_override_constants/margin_bottom = 16

[node name="InformationPanel" parent="Body/InformationMargin" instance=ExtResource("2_information_panel")]
unique_name_in_owner = true
layout_mode = 2

[connection signal="pressed" from="Body/Center/VBox/AddMemberButton" to="." method="_on_add_member_pressed"]
[connection signal="pressed" from="Body/Center/VBox/BackButton" to="." method="_on_back_pressed"]
```

(`LootTable`'s scene-file `visible = false` is only the *initial* value
before `_ready()`/`refresh()` runs — `refresh()` sets it explicitly from
`deployed` every time, so this is just to match the scene's at-rest state
to what a freshly-instantiated, not-yet-`_ready()` node should show.)

## Step 6: Run the tests to verify they pass

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_party_details.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_localization.gd -gexit
```

Expected: `N/N passed.` for both files.

## Full local verification

```
make check
```

Expected: `N/N passed.` and `---- All tests passed! ----`, exit 0.

## Manual verification

```
make play
```

1. Press **FN+F9**, choose **Goblin Camp** (party already deployed at the
   Goblin Camp encounter). Defeat the Goblin, click OK on the victory
   summary to land on the World Map.
2. Click the party's marker, then **View Party** (or however this build
   currently exposes navigating to Party Details for a deployed party —
   check `information_panel`'s party view action if unsure). Confirm the
   loot table is visible and shows exactly what that one battle dropped
   (matching what the victory summary just showed), with an **[Equip]**
   button and no **[Sell]** button.
3. Click **[Equip]**, equip the item, confirm you land back on this same
   Party Details screen (not Stores).
4. Return to the Encampment (walk the party to the settlement tile, or use
   the pause menu's World Map/Return option), then open **Parties** →
   select the now-encamped party → **View**. Confirm the loot table is
   completely absent (not just empty) — Gold still shows.
5. Open **Trade → Stores** and confirm that same loot is now sitting in
   Stores' inventory (banked by `deposit_pending_reward()` on the way
   home).

## Commit

```bash
git add scripts/ui/party_details.gd scenes/ui/party_details.tscn translations/en.tres \
  tests/unit/test_party_details.gd tests/unit/test_localization.gd
git commit -m "feat: show a deployed party's carried loot as a LootTable"
```

## Merge back to main

After user signoff on manual verification:

```bash
git checkout main
git merge party-details-loot-table
git branch -d party-details-loot-table
```
