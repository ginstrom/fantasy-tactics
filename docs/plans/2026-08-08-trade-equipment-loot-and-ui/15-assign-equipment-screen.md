# Task 15: Assign Equipment screen

## Objective

Build the destination Stores' Assign action routes to: pick an adventurer
from the roster and equip them with the item the player came here to
assign.

## Files

- Create: `scenes/ui/assign_equipment.tscn`, `scripts/ui/assign_equipment.gd`
- Test: `tests/unit/test_assign_equipment.gd`

## Depends on

Task 02 (`GameSession.adventurers`), Task 09
(`GameSession.equip_item_from_bank()`), Task 10
(`GameManager.route_context_id`, `go_to_stores()`).

## Steps

1. **Add translation keys.** In `translations/en.tres`, add:

   ```
   "assign_equipment.title": "Assign Equipment",
   "assign_equipment.column.name": "Name",
   "assign_equipment.column.class": "Class",
   "assign_equipment.column.level": "Level",
   "assign_equipment.empty": "No adventurers have been recruited yet.",
   "assign_equipment.hint": "Double-click a row, or select it and press Enter, to equip that adventurer.",
   ```

2. **Write the failing tests.** Create `tests/unit/test_assign_equipment.gd`:

   ```gdscript
   extends GutTest

   const AssignEquipmentScene := preload("res://scenes/ui/assign_equipment.tscn")
   const UiTestHelpers := preload("res://tests/unit/ui_test_helpers.gd")


   func before_each() -> void:
   	GameSession.reset()


   func after_each() -> void:
   	GameManager.close_game_menu()
   	GameManager.route_context_id = ""


   func test_assign_equipment_shows_the_title_and_the_back_action() -> void:
   	GameManager.route_context_id = "dagger_iron"
   	var screen: Control = AssignEquipmentScene.instantiate()
   	add_child_autofree(screen)

   	assert_eq(screen.get_node("Body/Center/VBox/Title").text, "assign_equipment.title")
   	assert_eq(screen.get_node("Body/Center/VBox/BackButton").text, "ui.back")


   func test_assign_equipment_contains_the_camp_nav() -> void:
   	GameManager.route_context_id = "dagger_iron"
   	var screen: Control = AssignEquipmentScene.instantiate()
   	add_child_autofree(screen)

   	assert_not_null(screen.get_node_or_null("Body/CampNav"))


   func test_back_button_returns_to_stores() -> void:
   	var source := FileAccess.get_file_as_string("res://scripts/ui/assign_equipment.gd")
   	assert_string_contains(source, "GameManager.go_to_stores()")


   func test_table_lists_the_default_warrior() -> void:
   	GameManager.route_context_id = "dagger_iron"
   	var screen: Control = AssignEquipmentScene.instantiate()
   	add_child_autofree(screen)
   	var tree: Tree = screen.get_node("Body/Center/VBox/AdventurerTable/Tree")

   	assert_eq(UiTestHelpers.tree_row_values(tree, 0), ["Warrior"])
   	assert_false(screen.get_node("Body/Center/VBox/EmptyLabel").visible)


   func test_activating_a_row_equips_the_item_and_returns_to_stores() -> void:
   	GameSession.banked_gear = {"dagger_iron": 1}
   	GameManager.route_context_id = "dagger_iron"
   	var screen: Control = AssignEquipmentScene.instantiate()
   	add_child_autofree(screen)

   	screen._on_row_activated(GameSession.WARRIOR_ID)

   	assert_eq(GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment.weapon, "dagger_iron")


   func test_activating_a_row_for_an_item_no_longer_in_stock_refreshes_in_place() -> void:
   	GameManager.route_context_id = "dagger_iron"
   	var screen: Control = AssignEquipmentScene.instantiate()
   	add_child_autofree(screen)

   	screen._on_row_activated(GameSession.WARRIOR_ID)

   	assert_eq(
   		GameSession.get_adventurer(GameSession.WARRIOR_ID).equipment.weapon,
   		GameSession.DEFAULT_WEAPON_ID,
   		"An item that was sold elsewhere while this screen was open must not equip"
   	)


   func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
   	GameManager.route_context_id = "dagger_iron"
   	var screen: Control = AssignEquipmentScene.instantiate()
   	add_child_autofree(screen)
   	var escape_event := InputEventAction.new()
   	escape_event.action = "ui_cancel"
   	escape_event.pressed = true

   	screen._unhandled_input(escape_event)

   	assert_true(screen.get_viewport().is_input_handled())
   	assert_true(GameManager.is_game_menu_open())
   	assert_true(get_tree().paused)
   ```

3. **Run the tests to verify they fail.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_assign_equipment.gd -gexit
   ```

   Expected: FAIL — `res://scenes/ui/assign_equipment.tscn` does not exist
   yet.

4. **Create `scripts/ui/assign_equipment.gd`.**

   ```gdscript
   extends Control

   ## Lists every roster adventurer (GameSession.adventurers) as a TableView
   ## row, keyed by adventurer id, for the item named by
   ## GameManager.route_context_id (see stores.gd, which sets it before routing
   ## here). Activating a row equips that adventurer immediately via
   ## GameSession.equip_item_from_bank() then returns to Stores — mirroring
   ## add_member.gd's "activating a row is the action itself" pattern. A row
   ## that has gone stale (the item was sold elsewhere while this screen was
   ## open) fails safely and this screen just refreshes in place.

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
   	for adventurer in GameSession.adventurers:
   		rows.append({
   			"id": adventurer.id,
   			"name": adventurer.name,
   			"class": adventurer["class"],
   			"level": adventurer.level,
   		})
   	return rows


   func _on_row_activated(row_id: Variant) -> void:
   	if GameSession.equip_item_from_bank(str(row_id), item_id):
   		GameManager.go_to_stores()
   		return
   	refresh()


   func _on_back_pressed() -> void:
   	GameManager.go_to_stores()
   ```

5. **Create `scenes/ui/assign_equipment.tscn`.**

   ```
   [gd_scene load_steps=4 format=3]

   [ext_resource type="Script" path="res://scripts/ui/assign_equipment.gd" id="1_assign_equipment"]
   [ext_resource type="Script" path="res://scripts/ui/table_view.gd" id="2_table_view"]
   [ext_resource type="PackedScene" path="res://scenes/ui/camp_nav.tscn" id="3_camp_nav"]

   [node name="AssignEquipment" type="Control"]
   layout_mode = 3
   anchors_preset = 15
   anchor_right = 1.0
   anchor_bottom = 1.0
   grow_horizontal = 2
   grow_vertical = 2
   script = ExtResource("1_assign_equipment")

   [node name="Body" type="HBoxContainer" parent="."]
   layout_mode = 1
   anchors_preset = 15
   anchor_right = 1.0
   anchor_bottom = 1.0
   grow_horizontal = 2
   grow_vertical = 2
   theme_override_constants/separation = 16

   [node name="CampNav" parent="Body" instance=ExtResource("3_camp_nav")]
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
   text = "assign_equipment.title"
   horizontal_alignment = 1

   [node name="AdventurerTable" type="VBoxContainer" parent="Body/Center/VBox"]
   layout_mode = 2
   custom_minimum_size = Vector2(520, 280)
   script = ExtResource("2_table_view")

   [node name="HintLabel" type="Label" parent="Body/Center/VBox"]
   layout_mode = 2
   text = "assign_equipment.hint"
   horizontal_alignment = 1

   [node name="EmptyLabel" type="Label" parent="Body/Center/VBox"]
   layout_mode = 2
   visible = false
   text = "assign_equipment.empty"
   horizontal_alignment = 1

   [node name="BackButton" type="Button" parent="Body/Center/VBox"]
   layout_mode = 2
   text = "ui.back"

   [connection signal="pressed" from="Body/Center/VBox/BackButton" to="." method="_on_back_pressed"]
   ```

6. **Run the tests to verify they pass.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_assign_equipment.gd -gexit
   ```

   Expected: PASS.

7. **Run the full suite** (this also re-validates Task 10's `GameManager`
   routing tests, which needed these scenes to exist):

   ```bash
   make test
   ```

   Expected: `---- All tests passed! ----`, exit code 0.

8. **Commit** only this task's files:

   ```bash
   git add scenes/ui/assign_equipment.tscn scripts/ui/assign_equipment.gd tests/unit/test_assign_equipment.gd translations/en.tres
   git commit -m "feat: add the Assign Equipment screen"
   ```

## Milestone

Every Trade screen now exists and routes correctly end to end: buy at the
Trading Post, sell or assign from Stores, and equip lands on the chosen
adventurer's record — and the full suite (including every earlier task's
scene-dependent routing test) is green.
