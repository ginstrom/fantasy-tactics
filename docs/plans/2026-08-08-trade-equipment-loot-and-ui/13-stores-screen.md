# Task 13: Stores screen

## Objective

Build the table view of everything the company has stored: banked gear and
mana crystals, with row-selection-driven Sell (Trading-Post-gated) and
Assign (gear only) actions.

## Files

- Create: `scenes/ui/stores.tscn`, `scripts/ui/stores.gd`
- Test: `tests/unit/test_stores.gd`

## Depends on

Task 09 (`GameSession.banked_gear`, `mana_crystals`, `get_item_definition()`,
`get_item_sale_price()`, `sell_item()`, `has_trading_post`), Task 10
(`GameManager.go_to_assign_equipment()`, `go_to_trade()`).

## Steps

1. **Add translation keys.** In `translations/en.tres`, add:

   ```
   "stores.title": "Stores",
   "stores.column.name": "Name",
   "stores.column.type": "Type",
   "stores.column.count": "Count",
   "stores.column.price": "Price",
   "stores.type.weapon": "Weapon",
   "stores.type.armor": "Armor",
   "stores.type.mana_crystal": "Mana Crystal",
   "stores.mana_crystal": "Mana Crystal (Tier %d)",
   "stores.empty": "Nothing in storage yet.",
   "stores.selected": "%s — %d in stock, sells for %d gold",
   "stores.sell": "Sell",
   "stores.assign": "Assign to Unit",
   ```

2. **Write the failing tests.** Create `tests/unit/test_stores.gd`:

   ```gdscript
   extends GutTest

   const StoresScene := preload("res://scenes/ui/stores.tscn")
   const UiTestHelpers := preload("res://tests/unit/ui_test_helpers.gd")


   func before_each() -> void:
   	GameSession.reset()


   func after_each() -> void:
   	GameManager.close_game_menu()


   func test_stores_shows_the_title_and_the_back_action() -> void:
   	var screen: Control = StoresScene.instantiate()
   	add_child_autofree(screen)

   	assert_eq(screen.get_node("Body/Center/VBox/Title").text, "stores.title")
   	assert_eq(screen.get_node("Body/Center/VBox/BackButton").text, "ui.back")


   func test_stores_contains_the_camp_nav() -> void:
   	var screen: Control = StoresScene.instantiate()
   	add_child_autofree(screen)

   	assert_not_null(screen.get_node_or_null("Body/CampNav"))


   func test_back_button_returns_to_trade() -> void:
   	var source := FileAccess.get_file_as_string("res://scripts/ui/stores.gd")
   	assert_string_contains(source, "GameManager.go_to_trade()")


   func test_empty_label_shows_when_nothing_is_banked() -> void:
   	var screen: Control = StoresScene.instantiate()
   	add_child_autofree(screen)

   	assert_true(screen.get_node("Body/Center/VBox/EmptyLabel").visible)


   func test_table_shows_a_gear_row_and_a_mana_crystal_row() -> void:
   	GameSession.banked_gear = {"shortsword_iron": 3}
   	GameSession.mana_crystals = {1: 2}
   	var screen: Control = StoresScene.instantiate()
   	add_child_autofree(screen)
   	var tree: Tree = screen.get_node("Body/Center/VBox/StoresTable/Tree")

   	assert_eq(UiTestHelpers.tree_row_values(tree, 0), ["Shortsword", "Mana Crystal (Tier 1)"])
   	assert_eq(UiTestHelpers.tree_row_values(tree, 1), ["Weapon", "Mana Crystal"])
   	assert_eq(UiTestHelpers.tree_row_values(tree, 2), ["3", "2"])
   	assert_eq(UiTestHelpers.tree_row_values(tree, 3), ["10", "5"])
   	assert_false(screen.get_node("Body/Center/VBox/EmptyLabel").visible)


   func test_selecting_a_gear_row_shows_its_detail_and_both_actions() -> void:
   	GameSession.banked_gear = {"shortsword_iron": 3}
   	var screen: Control = StoresScene.instantiate()
   	add_child_autofree(screen)
   	var tree: Tree = screen.get_node("Body/Center/VBox/StoresTable/Tree")
   	tree.get_root().get_first_child().select(0)

   	tree.emit_signal("item_selected")

   	assert_eq(
   		screen.get_node("Body/Center/VBox/SelectedItemLabel").text,
   		tr("stores.selected") % ["Shortsword", 3, 10]
   	)
   	assert_true(screen.get_node("Body/Center/VBox/SellButton").visible)
   	assert_true(screen.get_node("Body/Center/VBox/AssignButton").visible)


   func test_selecting_a_mana_crystal_row_hides_the_assign_action() -> void:
   	GameSession.mana_crystals = {1: 2}
   	var screen: Control = StoresScene.instantiate()
   	add_child_autofree(screen)
   	var tree: Tree = screen.get_node("Body/Center/VBox/StoresTable/Tree")
   	tree.get_root().get_first_child().select(0)

   	tree.emit_signal("item_selected")

   	assert_false(screen.get_node("Body/Center/VBox/AssignButton").visible)


   func test_sell_button_is_disabled_without_a_trading_post_and_enabled_with_one() -> void:
   	GameSession.banked_gear = {"shortsword_iron": 1}
   	var screen: Control = StoresScene.instantiate()
   	add_child_autofree(screen)
   	var tree: Tree = screen.get_node("Body/Center/VBox/StoresTable/Tree")
   	tree.get_root().get_first_child().select(0)
   	tree.emit_signal("item_selected")

   	assert_true(screen.get_node("Body/Center/VBox/SellButton").disabled)

   	GameSession.has_trading_post = true
   	screen.refresh()

   	assert_false(screen.get_node("Body/Center/VBox/SellButton").disabled)


   func test_pressing_sell_sells_one_unit_and_refreshes() -> void:
   	GameSession.has_trading_post = true
   	GameSession.banked_gear = {"shortsword_iron": 2}
   	var screen: Control = StoresScene.instantiate()
   	add_child_autofree(screen)
   	var tree: Tree = screen.get_node("Body/Center/VBox/StoresTable/Tree")
   	tree.get_root().get_first_child().select(0)
   	tree.emit_signal("item_selected")
   	var sell_button: Button = screen.get_node("Body/Center/VBox/SellButton")

   	sell_button.emit_signal("pressed")

   	assert_eq(GameSession.banked_gear.shortsword_iron, 1)
   	assert_eq(GameSession.gold, 10)


   func test_pressing_assign_routes_via_game_manager() -> void:
   	var source := FileAccess.get_file_as_string("res://scripts/ui/stores.gd")
   	assert_string_contains(source, "GameManager.go_to_assign_equipment(selected_item_id)")


   func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
   	var screen: Control = StoresScene.instantiate()
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
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_stores.gd -gexit
   ```

   Expected: FAIL — `res://scenes/ui/stores.tscn` does not exist yet.

4. **Create `scripts/ui/stores.gd`.**

   ```gdscript
   extends Control

   ## Lists everything banked in storage (GameSession.banked_gear +
   ## GameSession.mana_crystals) as a TableView row per item, keyed by a stable
   ## item id (a weapon/armor catalog id, or "mana_crystal_<tier>" for a mana
   ## crystal stack). Selecting a row shows its detail plus two gated actions —
   ## Sell (requires a Trading Post) and Assign (gear rows only) — following the
   ## same row-selection-drives-a-detail-action pattern recruitment.gd/
   ## unit_details.gd already use.

   const TableColumnDescriptor := preload("res://scripts/ui/table_column.gd")

   const MANA_CRYSTAL_ID_PREFIX := "mana_crystal_"

   @onready var stores_table: TableView = $Body/Center/VBox/StoresTable
   @onready var empty_label: Label = $Body/Center/VBox/EmptyLabel
   @onready var selected_item_label: Label = $Body/Center/VBox/SelectedItemLabel
   @onready var sell_button: Button = $Body/Center/VBox/SellButton
   @onready var assign_button: Button = $Body/Center/VBox/AssignButton

   var selected_item_id: String = ""


   func _ready() -> void:
   	stores_table.row_selected.connect(_on_row_selected)
   	stores_table.set_columns(_build_columns())
   	refresh()


   func _unhandled_input(event: InputEvent) -> void:
   	if event.is_action_pressed("ui_cancel"):
   		get_viewport().set_input_as_handled()
   		GameManager.open_game_menu()


   func refresh() -> void:
   	var rows := _build_rows()
   	stores_table.set_rows(rows)
   	empty_label.visible = rows.is_empty()
   	_refresh_selection(rows)


   func _build_columns() -> Array[TableColumn]:
   	var name_column := TableColumnDescriptor.new(&"name", tr("stores.column.name"))
   	name_column.expand = true
   	name_column.expand_ratio = 2
   	var type_column := TableColumnDescriptor.new(&"type", tr("stores.column.type"))
   	var count_column := TableColumnDescriptor.new(&"count", tr("stores.column.count"), TableColumnDescriptor.Type.INTEGER)
   	var price_column := TableColumnDescriptor.new(&"price", tr("stores.column.price"), TableColumnDescriptor.Type.INTEGER)
   	return [name_column, type_column, count_column, price_column]


   func _build_rows() -> Array[Dictionary]:
   	var rows: Array[Dictionary] = []
   	for item_id in GameSession.banked_gear:
   		var count: int = GameSession.banked_gear[item_id]
   		if count <= 0:
   			continue
   		var item := GameSession.get_item_definition(item_id)
   		rows.append({
   			"id": item_id,
   			"name": tr(item.name_key),
   			"type": tr("stores.type.%s" % item.slot),
   			"count": count,
   			"price": GameSession.get_item_sale_price(item_id),
   		})
   	for tier in GameSession.mana_crystals:
   		var count: int = GameSession.mana_crystals[tier]
   		if count <= 0:
   			continue
   		var item_id: String = "%s%d" % [MANA_CRYSTAL_ID_PREFIX, tier]
   		rows.append({
   			"id": item_id,
   			"name": tr("stores.mana_crystal") % tier,
   			"type": tr("stores.type.mana_crystal"),
   			"count": count,
   			"price": GameSession.get_item_sale_price(item_id),
   		})
   	return rows


   ## A selection that no longer names a current row (sold to zero, or a fresh
   ## refresh after this screen was reopened) clears back to the safe,
   ## unselected empty state, mirroring add_member.gd/recruitment.gd's
   ## _refresh_selection convention.
   func _refresh_selection(rows: Array[Dictionary]) -> void:
   	var row := _find_row(rows, selected_item_id)
   	if row.is_empty():
   		selected_item_id = ""
   		selected_item_label.visible = false
   		sell_button.visible = false
   		assign_button.visible = false
   		return

   	selected_item_label.visible = true
   	selected_item_label.text = tr("stores.selected") % [row.name, row.count, row.price]
   	sell_button.visible = true
   	sell_button.disabled = not GameSession.has_trading_post
   	assign_button.visible = not selected_item_id.begins_with(MANA_CRYSTAL_ID_PREFIX)


   func _find_row(rows: Array[Dictionary], item_id: String) -> Dictionary:
   	if item_id == "":
   		return {}
   	for row in rows:
   		if row.id == item_id:
   			return row
   	return {}


   func _on_row_selected(row_id: Variant) -> void:
   	selected_item_id = str(row_id)
   	_refresh_selection(_build_rows())


   func _on_sell_button_pressed() -> void:
   	GameSession.sell_item(selected_item_id, 1)
   	refresh()


   func _on_assign_button_pressed() -> void:
   	GameManager.go_to_assign_equipment(selected_item_id)


   func _on_back_pressed() -> void:
   	GameManager.go_to_trade()
   ```

5. **Create `scenes/ui/stores.tscn`.**

   ```
   [gd_scene load_steps=4 format=3]

   [ext_resource type="Script" path="res://scripts/ui/stores.gd" id="1_stores"]
   [ext_resource type="Script" path="res://scripts/ui/table_view.gd" id="2_table_view"]
   [ext_resource type="PackedScene" path="res://scenes/ui/camp_nav.tscn" id="3_camp_nav"]

   [node name="Stores" type="Control"]
   layout_mode = 3
   anchors_preset = 15
   anchor_right = 1.0
   anchor_bottom = 1.0
   grow_horizontal = 2
   grow_vertical = 2
   script = ExtResource("1_stores")

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
   text = "stores.title"
   horizontal_alignment = 1

   [node name="StoresTable" type="VBoxContainer" parent="Body/Center/VBox"]
   layout_mode = 2
   custom_minimum_size = Vector2(560, 280)
   script = ExtResource("2_table_view")

   [node name="EmptyLabel" type="Label" parent="Body/Center/VBox"]
   layout_mode = 2
   visible = false
   text = "stores.empty"
   horizontal_alignment = 1

   [node name="SelectedItemLabel" type="Label" parent="Body/Center/VBox"]
   layout_mode = 2
   visible = false
   horizontal_alignment = 1

   [node name="SellButton" type="Button" parent="Body/Center/VBox"]
   layout_mode = 2
   visible = false
   text = "stores.sell"

   [node name="AssignButton" type="Button" parent="Body/Center/VBox"]
   layout_mode = 2
   visible = false
   text = "stores.assign"

   [node name="BackButton" type="Button" parent="Body/Center/VBox"]
   layout_mode = 2
   text = "ui.back"

   [connection signal="pressed" from="Body/Center/VBox/SellButton" to="." method="_on_sell_button_pressed"]
   [connection signal="pressed" from="Body/Center/VBox/AssignButton" to="." method="_on_assign_button_pressed"]
   [connection signal="pressed" from="Body/Center/VBox/BackButton" to="." method="_on_back_pressed"]
   ```

6. **Run the tests to verify they pass.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_stores.gd -gexit
   ```

   Expected: PASS.

7. **Commit** only this task's files:

   ```bash
   git add scenes/ui/stores.tscn scripts/ui/stores.gd tests/unit/test_stores.gd translations/en.tres
   git commit -m "feat: add the Stores screen"
   ```

## Milestone

Every banked gear item and mana crystal stack is visible in one table with
correct sale prices; selecting a row shows its detail and correctly gates
Sell on Trading Post ownership and Assign on the row being gear, not a mana
crystal.
