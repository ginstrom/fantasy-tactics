# Step 6: Victory Summary Loot Table

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Branch:** `victory-summary-loot-table`

**Goal:** The victory summary screen (`battle_result.tscn`) currently shows
loot as one aggregate-count sentence ("Loot: 5 gold, 2 mana crystals, 1
gear"). Replace the mana-crystal/gear part with the `LootTable` component
from Step 4 (no `[Sell]`, an `[Equip]` scoped to the party that fought this
battle), keeping gold as its own label alongside it. This step also adds
the `GameManager.assign_equipment_party_id`/`assign_equipment_origin`
plumbing that scopes Assign Equipment to one party and routes Back to
whichever screen sent it there — Step 7 reuses this unchanged.

**Files:**
- Modify: `scripts/autoload/game_manager.gd`
- Modify: `scripts/ui/assign_equipment.gd`
- Modify: `scripts/battle/battlefield.gd`
- Modify: `scripts/ui/battle_result.gd`
- Modify: `scenes/ui/battle_result.tscn`
- Modify: `translations/en.tres`
- Test: `tests/unit/test_game_manager.gd`
- Test: `tests/unit/test_assign_equipment.gd`
- Test: `tests/unit/test_battlefield.gd`
- Test: `tests/unit/test_battle_result.gd`

## Part A — party-scoped, origin-aware Assign Equipment

### Step A1: Write the failing tests

Add to `tests/unit/test_game_manager.gd`, after
`test_go_to_assign_equipment_rejects_an_unknown_item_id`:

```gdscript
func test_go_to_assign_equipment_with_a_party_id_scopes_and_records_the_origin() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	assert_eq(
		manager.go_to_assign_equipment(
			"dagger_iron", GameSession.FIRST_PARTY_ID, manager.AssignEquipmentOrigin.BATTLE_RESULT
		),
		OK
	)
	assert_eq(manager.route_context_id, "dagger_iron")
	assert_eq(manager.assign_equipment_party_id, GameSession.FIRST_PARTY_ID)
	assert_eq(manager.assign_equipment_origin, manager.AssignEquipmentOrigin.BATTLE_RESULT)


func test_go_to_assign_equipment_rejects_an_unknown_party_id() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)
	manager.assign_equipment_party_id = "stale"

	assert_eq(manager.go_to_assign_equipment("dagger_iron", "no_such_party"), ERR_INVALID_DATA)
	assert_eq(manager.assign_equipment_party_id, "")


func test_go_to_assign_equipment_defaults_to_the_stores_origin_and_no_party_scope() -> void:
	GameSession.reset()
	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
	add_child_autofree(manager)

	manager.go_to_assign_equipment("dagger_iron")

	assert_eq(manager.assign_equipment_party_id, "")
	assert_eq(manager.assign_equipment_origin, manager.AssignEquipmentOrigin.STORES)
```

The two pre-existing tests immediately above these
(`test_go_to_assign_equipment_sets_route_context_and_changes_scene_for_a_known_item`,
`test_go_to_assign_equipment_rejects_an_unknown_item_id`) call
`go_to_assign_equipment` with only one argument — they need no edits;
the new `party_id`/`origin` parameters default to the old unscoped/Stores
behavior.

### Step A2: Run the tests to verify they fail

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_manager.gd -gexit
```

Expected: the three new tests FAIL — `AssignEquipmentOrigin` and
`assign_equipment_party_id` don't exist yet, and `go_to_assign_equipment`
doesn't accept extra arguments.

### Step A3: Add the fields and extend `go_to_assign_equipment`

In `scripts/autoload/game_manager.gd`, add the new fields near
`add_member_return_party_id` (search for that name):

```gdscript
## Scopes Assign Equipment to one party's own members (the victory summary
## and World Map Party Details' [Equip] — see Steps 6/7 of
## docs/plans/2026-08-09-minor-fixes-and-encounter-loot/) instead of the
## full roster (Stores' [Equip]). Empty means unscoped.
var assign_equipment_party_id: String = ""

## Which screen opened Assign Equipment, so its Back action (and a
## successful equip) can return there instead of always landing on Stores.
enum AssignEquipmentOrigin { STORES, BATTLE_RESULT, PARTY_DETAILS }
var assign_equipment_origin: AssignEquipmentOrigin = AssignEquipmentOrigin.STORES
```

Find `_clear_detail_context()` (search for `func _clear_detail_context`)
and add the two new fields to it:

```gdscript
func _clear_detail_context() -> void:
	route_context_id = ""
	unit_details_origin = ""
	add_member_return_party_id = ""
	assign_equipment_party_id = ""
	assign_equipment_origin = AssignEquipmentOrigin.STORES
```

Find `go_to_assign_equipment()` and replace it:

```gdscript
## Mirrors go_to_unit_details()'s validate-then-route shape: an unknown item
## id, or an unknown party_id when one is given, clears the detail context
## and reports ERR_INVALID_DATA instead of routing to a screen with nothing
## to show. party_id/origin default to the old unscoped, Stores-originated
## behavior so every pre-existing call site keeps working unchanged.
func go_to_assign_equipment(
	item_id: String, party_id: String = "", origin: AssignEquipmentOrigin = AssignEquipmentOrigin.STORES
) -> Error:
	if GameSession.get_item_definition(item_id).is_empty():
		_clear_detail_context()
		return ERR_INVALID_DATA
	if party_id != "" and GameSession.get_party(party_id).is_empty():
		_clear_detail_context()
		return ERR_INVALID_DATA
	route_context_id = item_id
	unit_details_origin = ""
	add_member_return_party_id = ""
	assign_equipment_party_id = party_id
	assign_equipment_origin = origin
	return _change_scene(ASSIGN_EQUIPMENT_SCENE)
```

### Step A4: Run the tests to verify they pass

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_manager.gd -gexit
```

Expected: `N/N passed.`

## Part B — scope and route `assign_equipment.gd`

### Step B1: Write the failing tests

Add to `tests/unit/test_assign_equipment.gd`, after
`test_table_lists_the_default_warrior`:

```gdscript
func test_table_is_scoped_to_the_party_when_a_party_id_is_set() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	GameSession.recruit_adventurer()
	GameManager.route_context_id = "dagger_iron"
	GameManager.assign_equipment_party_id = GameSession.FIRST_PARTY_ID
	var screen: Control = AssignEquipmentScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/AdventurerTable/Tree")

	assert_eq(
		UiTestHelpers.tree_row_values(tree, 0), ["Warrior"],
		"Only the party's own member, not the freshly recruited, unassigned adventurer"
	)
```

Add near `test_back_button_returns_to_stores`:

```gdscript
func test_back_returns_to_battle_result_when_that_was_the_origin() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/assign_equipment.gd")
	assert_string_contains(source, "GameManager.go_to_battle_result(GameManager.battle_result_summary)")


func test_back_returns_to_party_details_when_that_was_the_origin() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/assign_equipment.gd")
	assert_string_contains(source, "GameManager.go_to_party_details(GameManager.assign_equipment_party_id)")
```

Update `after_each()` so leftover scoping state from one test never leaks
into the next:

```gdscript
func after_each() -> void:
	GameManager.close_game_menu()
	GameManager.route_context_id = ""
	GameManager.assign_equipment_party_id = ""
	GameManager.assign_equipment_origin = GameManager.AssignEquipmentOrigin.STORES
```

### Step B2: Run the tests to verify they fail

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_assign_equipment.gd -gexit
```

Expected: the three new tests FAIL (scoping and origin-aware routing don't
exist yet).

### Step B3: Rewrite `scripts/ui/assign_equipment.gd`

```gdscript
extends Control

## Lists roster adventurers for the item named by GameManager.route_context_id
## (see stores.gd/battle_result.gd/party_details.gd, each of which sets it
## before routing here) — every adventurer when
## GameManager.assign_equipment_party_id is empty (Stores' unscoped Equip),
## or only that party's own members when it's set (the victory summary and
## World Map Party Details' Equip — both scoped to the current party).
## Activating a row equips that adventurer immediately via
## GameSession.equip_item_from_bank() then returns to whichever screen sent
## us here (GameManager.assign_equipment_origin), mirroring add_member.gd's
## "activating a row is the action itself" pattern. A row that has gone
## stale (the item was sold elsewhere while this screen was open) fails
## safely and this screen just refreshes in place.

const TableColumnDescriptor := preload("res://scripts/ui/table_column.gd")

@onready var adventurer_table: TableView = $Body/Center/VBox/AdventurerTable
@onready var empty_label: Label = $Body/Center/VBox/EmptyLabel

var item_id: String = ""


func _ready() -> void:
	item_id = GameManager.route_context_id
	adventurer_table.row_activated.connect(_on_row_activated)
	adventurer_table.set_columns(_build_columns())
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	var rows := _build_rows()
	adventurer_table.set_rows(rows)
	empty_label.visible = rows.is_empty()


func _build_columns() -> Array[TableColumn]:
	var name_column := TableColumnDescriptor.new(&"name", tr("assign_equipment.column.name"))
	name_column.expand = true
	name_column.expand_ratio = 2
	var class_column := TableColumnDescriptor.new(&"class", tr("assign_equipment.column.class"))
	var level_column := TableColumnDescriptor.new(
		&"level", tr("assign_equipment.column.level"), TableColumnDescriptor.Type.INTEGER
	)
	return [name_column, class_column, level_column]


func _build_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for adventurer in _scoped_adventurers():
		rows.append({
			"id": adventurer.id,
			"name": adventurer.name,
			"class": adventurer["class"],
			"level": adventurer.level,
		})
	return rows


func _scoped_adventurers() -> Array:
	if GameManager.assign_equipment_party_id == "":
		return GameSession.adventurers
	var party := GameSession.get_party(GameManager.assign_equipment_party_id)
	var members: Array = []
	for adventurer_id in party.get("member_ids", []):
		var adventurer := GameSession.get_adventurer(adventurer_id)
		if not adventurer.is_empty():
			members.append(adventurer)
	return members


func _on_row_activated(row_id: Variant) -> void:
	if GameSession.equip_item_from_bank(str(row_id), item_id):
		_return_to_origin()
		return
	refresh()


func _on_back_pressed() -> void:
	_return_to_origin()


func _return_to_origin() -> void:
	match GameManager.assign_equipment_origin:
		GameManager.AssignEquipmentOrigin.BATTLE_RESULT:
			GameManager.go_to_battle_result(GameManager.battle_result_summary)
		GameManager.AssignEquipmentOrigin.PARTY_DETAILS:
			GameManager.go_to_party_details(GameManager.assign_equipment_party_id)
		_:
			GameManager.go_to_stores()
```

### Step B4: Run the tests to verify they pass

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_assign_equipment.gd -gexit
```

Expected: `N/N passed.`

## Part C — itemize this battle's loot in the summary

### Step C1: Write the failing test

`test_a_second_victory_in_one_deployment_reports_only_its_own_loot` in
`tests/unit/test_battlefield.gd` currently asserts the old aggregate-count
fields. Change its trailing assertions:

```gdscript
	assert_eq(
		GameManager.battle_result_summary.loot_gold, 1,
		"Only this battle's own gold, not the 50 already carried over"
	)
	assert_eq(
		GameManager.battle_result_summary.loot_mana_crystals, 1,
		"Only this battle's own mana crystals, not the 3 already carried over"
	)
	assert_eq(
		GameManager.battle_result_summary.loot_gear, 1,
		"Only this battle's own gear, not the 2 pieces already carried over"
	)
```

to:

```gdscript
	assert_eq(
		GameManager.battle_result_summary.loot_gold, 1,
		"Only this battle's own gold, not the 50 already carried over"
	)
	assert_eq(
		GameManager.battle_result_summary.loot_mana_crystal_counts, {1: 1},
		"Only this battle's own mana crystal, not the 3 already carried over"
	)
	assert_eq(
		GameManager.battle_result_summary.loot_gear_counts, {"shortsword_iron": 1},
		"Only this battle's own gear, not the 2 pieces already carried over"
	)
```

(`shortsword_iron` is the Goblin's documented Iron-tier weapon — see
`ENEMY_LOOT_TABLES["goblin"].gear_item_id` in `game_session.gd`.)

### Step C2: Run the test to verify it fails

```
godot --headless -s addons/gut/gut_cmdln.gd -gunit_test_name=test_a_second_victory_in_one_deployment_reports_only_its_own_loot -gexit
```

Expected: FAILS — today's summary still has `loot_mana_crystals`/`loot_gear`
as plain ints, not the new dict fields.

### Step C3: Rewrite `_finish_victory()` in `scripts/battle/battlefield.gd`

Find the existing `_finish_victory()` and its helper
`_total_pending_mana_crystals()` (search for `func _finish_victory`) and
replace both with:

```gdscript
## Rolls this battle's loot into GameSession's pending_* fields (see
## GameSession.complete_current_encounter() -> _roll_and_queue_loot()) and
## routes to the victory summary screen with everything this battle
## accumulated. Unlike GameManager.complete_battle() (still used by
## scripts/tools/screenshot_tour.gd to skip straight to the World Map),
## this is the real gameplay path -- it shows the summary before the
## player ever reaches the World Map.
func _finish_victory() -> void:
	var gold_before: int = GameSession.pending_reward
	var mana_crystal_counts_before: Dictionary = GameSession.pending_mana_crystals.duplicate()
	var gear_count_before: int = GameSession.pending_gear.size()

	GameSession.complete_current_encounter()

	var party := GameSession.get_party(GameSession.selected_party_id)
	var summary := {
		"kills_by_type": _kills_by_type,
		"total_xp": _total_xp_awarded,
		"party_member_count": maxi(party.get("member_ids", []).size(), 1),
		"leveled_up_ids": _leveled_up_ids,
		"party_id": GameSession.selected_party_id,
		# This battle's own loot only, not the party's full pending_* totals --
		# those accumulate across every encounter cleared before returning to
		# the settlement, but this summary screen is titled for just this
		# battle (see battle_result.gd).
		"loot_gold": GameSession.pending_reward - gold_before,
		"loot_mana_crystal_counts": _pending_mana_crystal_counts_delta(mana_crystal_counts_before),
		"loot_gear_counts": _pending_gear_counts_delta(gear_count_before),
	}
	GameManager.go_to_battle_result(summary)


func _pending_mana_crystal_counts_delta(counts_before: Dictionary) -> Dictionary:
	var delta: Dictionary = {}
	for tier in GameSession.pending_mana_crystals:
		var gained: int = GameSession.pending_mana_crystals[tier] - counts_before.get(tier, 0)
		if gained > 0:
			delta[tier] = gained
	return delta


## pending_gear only ever grows via append() before a deposit, so the tail
## slice starting at count_before is exactly this battle's own new drops.
func _pending_gear_counts_delta(count_before: int) -> Dictionary:
	var delta: Dictionary = {}
	for item_id in GameSession.pending_gear.slice(count_before, GameSession.pending_gear.size()):
		delta[item_id] = delta.get(item_id, 0) + 1
	return delta
```

### Step C4: Run the test to verify it passes

```
godot --headless -s addons/gut/gut_cmdln.gd -gunit_test_name=test_a_second_victory_in_one_deployment_reports_only_its_own_loot -gexit
```

Expected: PASS. Then run the whole file to confirm nothing else regressed:

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield.gd -gexit
```

Expected: `N/N passed.`

## Part D — the victory summary screen itself

### Step D1: Write the failing tests

Replace `test_shows_this_battles_loot_from_the_summary` in
`tests/unit/test_battle_result.gd` with:

```gdscript
func test_shows_the_battles_gold() -> void:
	var screen := _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": [],
		"loot_gold": 5,
	})

	assert_eq(screen.get_node("Center/VBox/GoldLabel").text, tr("battle_result.gold") % 5)


func test_shows_this_battles_loot_as_a_table() -> void:
	var screen := _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": [],
		"loot_gear_counts": {"shortsword_iron": 1}, "loot_mana_crystal_counts": {1: 2},
	})
	var tree: Tree = screen.get_node("Center/VBox/LootTable/Content/Table/Tree")

	assert_eq(UiTestHelpers.tree_row_values(tree, 0), ["Iron Shortsword", "Mana Crystal (Tier 1)"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 2), ["1", "2"])


## LootTable no longer puts Sell/Equip in per-row Tree buttons -- selecting
## a row and clicking [View] (or double-clicking it) opens LootDetailPanel,
## a real PanelContainer with real, text-labeled Sell/Equip buttons (see
## scripts/ui/loot_table.gd/loot_detail_panel.gd; this redesign landed
## during Step 4's manual verification, after this step was originally
## drafted). configure(false, true) means the detail panel's Equip button
## shows for a gear row and its Sell button never does.
func test_loot_table_has_an_equip_action_but_no_sell_action() -> void:
	var screen := _open_battle_result({
		"kills_by_type": {}, "total_xp": 0.0, "party_member_count": 1, "leveled_up_ids": [],
		"loot_gear_counts": {"shortsword_iron": 1},
	})
	var tree: Tree = screen.get_node("Center/VBox/LootTable/Content/Table/Tree")
	var item := tree.get_root().get_first_child()
	item.select(0)
	tree.emit_signal("item_selected")
	screen.get_node("Center/VBox/LootTable/Content/ViewButton").emit_signal("pressed")

	var detail_panel: Control = screen.get_node("Center/VBox/LootTable/LootDetailPanel")
	assert_true(detail_panel.visible)
	assert_true(detail_panel.get_node("Content/ButtonRow/EquipButton").visible)
	assert_false(detail_panel.get_node("Content/ButtonRow/SellButton").visible)


func test_equip_routes_via_game_manager_scoped_to_this_battles_party() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/battle_result.gd")
	assert_string_contains(source, "GameManager.go_to_assign_equipment(")
	assert_string_contains(source, "GameManager.AssignEquipmentOrigin.BATTLE_RESULT")
```

Add the `UiTestHelpers` const this file didn't previously need:

```gdscript
const UiTestHelpers := preload("res://tests/unit/ui_test_helpers.gd")
```

(add it next to the existing `BattleResultScene` const at the top of the
file.)

### Step D2: Run the tests to verify they fail

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_result.gd -gexit
```

Expected: the four new/changed tests FAIL —
`Center/VBox/GoldLabel`/`Center/VBox/LootTable` don't exist in the scene
yet, and `battle_result.gd` doesn't route Equip anywhere yet.

### Step D3: Add/remove translation keys

In `translations/en.tres`, remove the now-unused aggregate key:

```
"battle_result.loot": "Loot: %d gold, %d mana crystals, %d gear",
```

and add its replacement next to `battle_result.leveled_up`:

```
"battle_result.gold": "Gold: %d",
```

### Step D4: Rewrite `scripts/ui/battle_result.gd`

```gdscript
extends Control

## Reads GameManager.battle_result_summary (set by Battlefield._finish_
## victory() right before routing here — see that method) once, in
## _ready(), the same "transient payload set right before navigating"
## pattern route_context_id uses elsewhere in this codebase. Loot is part
## of that summary dict ("loot_gold" plus the itemized
## "loot_gear_counts"/"loot_mana_crystal_counts") -- reading
## GameSession.pending_reward/pending_mana_crystals/pending_gear directly
## would show every encounter a deployed party has cleared so far this
## deployment, not just this battle's own loot (see _finish_victory()'s
## before/after delta). The gear/mana-crystal table reuses LootTable,
## scoped to this battle's own party (summary.party_id) for its [Equip]
## action -- no [Sell] here, loot only sells once banked at the Encampment.

@onready var kills_label: Label = $Center/VBox/KillsLabel
@onready var xp_label: Label = $Center/VBox/XpLabel
@onready var level_up_label: Label = $Center/VBox/LevelUpLabel
@onready var gold_label: Label = $Center/VBox/GoldLabel
@onready var loot_table: LootTable = $Center/VBox/LootTable
@onready var ok_button: Button = $Center/VBox/OkButton


func _ready() -> void:
	loot_table.configure(false, true)
	loot_table.equip_requested.connect(_on_equip_requested)
	_refresh()


func _refresh() -> void:
	var summary: Dictionary = GameManager.battle_result_summary
	kills_label.text = _format_kills(summary.get("kills_by_type", {}))

	var total_xp: float = summary.get("total_xp", 0.0)
	var member_count: int = maxi(summary.get("party_member_count", 1), 1)
	var each_xp: float = total_xp / member_count
	xp_label.text = tr("battle_result.xp") % [int(round(total_xp)), int(round(each_xp))]

	var leveled_up_ids: Array = summary.get("leveled_up_ids", [])
	level_up_label.visible = not leveled_up_ids.is_empty()
	if level_up_label.visible:
		var names: Array = []
		for adventurer_id in leveled_up_ids:
			names.append(GameSession.get_adventurer(adventurer_id).get("name", ""))
		level_up_label.text = tr("battle_result.leveled_up") % ", ".join(names)

	gold_label.text = tr("battle_result.gold") % summary.get("loot_gold", 0)
	loot_table.set_rows(GameSession.build_loot_rows(
		summary.get("loot_gear_counts", {}), summary.get("loot_mana_crystal_counts", {})
	))


func _format_kills(kills_by_type: Dictionary) -> String:
	if kills_by_type.is_empty():
		return tr("battle_result.no_kills")
	var parts: Array = []
	for type_name in kills_by_type:
		parts.append("%s x%d" % [type_name, kills_by_type[type_name]])
	return tr("battle_result.kills") % ", ".join(parts)


func _on_equip_requested(item_id: String) -> void:
	GameManager.go_to_assign_equipment(
		item_id,
		GameManager.battle_result_summary.get("party_id", ""),
		GameManager.AssignEquipmentOrigin.BATTLE_RESULT
	)


func _on_ok_pressed() -> void:
	GameManager.battle_result_summary = {}
	GameManager.go_to_world_map()
```

### Step D5: Rewrite `scenes/ui/battle_result.tscn`

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/ui/battle_result.gd" id="1_battle_result"]
[ext_resource type="PackedScene" path="res://scenes/ui/loot_table.tscn" id="2_loot_table"]

[node name="BattleResult" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_battle_result")

[node name="Center" type="CenterContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="VBox" type="VBoxContainer" parent="Center"]
layout_mode = 2
theme_override_constants/separation = 16

[node name="Title" type="Label" parent="Center/VBox"]
layout_mode = 2
text = "battle_result.title"
horizontal_alignment = 1

[node name="KillsLabel" type="Label" parent="Center/VBox"]
layout_mode = 2
horizontal_alignment = 1

[node name="XpLabel" type="Label" parent="Center/VBox"]
layout_mode = 2
horizontal_alignment = 1

[node name="LevelUpLabel" type="Label" parent="Center/VBox"]
layout_mode = 2
visible = false
horizontal_alignment = 1

[node name="GoldLabel" type="Label" parent="Center/VBox"]
layout_mode = 2
horizontal_alignment = 1

[node name="LootTable" parent="Center/VBox" instance=ExtResource("2_loot_table")]
layout_mode = 2
custom_minimum_size = Vector2(560, 200)

[node name="OkButton" type="Button" parent="Center/VBox"]
layout_mode = 2
text = "battle_result.ok"

[connection signal="pressed" from="Center/VBox/OkButton" to="." method="_on_ok_pressed"]
```

### Step D6: Run the tests to verify they pass

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_result.gd -gexit
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

1. Press **FN+F9**, choose **Goblin Camp**, defeat the Goblin.
2. On the victory summary: confirm **Gold: N** shows on its own line, and
   below it a table lists any mana crystal/gear drops from this fight only,
   with an **[Equip]** button on the gear row (no Sell button anywhere).
3. Click **[Equip]** — Assign Equipment opens listing only this party's own
   members (a fresh single-Warrior party, so just the one row). Equip the
   item.
4. Confirm you land back on the victory summary screen (not Stores), still
   showing the same kills/XP/loot.
5. Click **OK** — routes to the World Map as before, and
   `GameManager.battle_result_summary` is cleared (re-opening the debug
   menu and jumping to another scenario should not show stale loot from
   this fight anywhere).

## Commit

```bash
git add scripts/autoload/game_manager.gd scripts/ui/assign_equipment.gd \
  scripts/battle/battlefield.gd scripts/ui/battle_result.gd scenes/ui/battle_result.tscn \
  translations/en.tres \
  tests/unit/test_game_manager.gd tests/unit/test_assign_equipment.gd \
  tests/unit/test_battlefield.gd tests/unit/test_battle_result.gd
git commit -m "feat: show the victory summary's loot as a party-scoped LootTable"
```

## Merge back to main

After user signoff on manual verification:

```bash
git checkout main
git merge victory-summary-loot-table
git branch -d victory-summary-loot-table
```
