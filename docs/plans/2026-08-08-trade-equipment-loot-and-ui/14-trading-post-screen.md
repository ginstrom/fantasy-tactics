# Task 14: Trading Post screen

## Objective

Build the Trading Post's buy screen: passive-income readout plus a table
of the full weapon/armor catalog with a gold-gated buy action.

## Files

- Create: `scenes/ui/trading_post.tscn`, `scripts/ui/trading_post.gd`
- Test: `tests/unit/test_trading_post.gd`

## Depends on

Task 01 (`GameSession.WEAPONS`, `ARMORS`, `get_item_definition()`), Task 09
(`GameSession.buy_item()`, `TRADING_POST_INCOME_PER_TURN`), Task 10
(`GameManager.go_to_trade()`).

## Steps

1. **Add translation keys.** In `translations/en.tres`, add:

   ```
   "trading_post.title": "Trading Post",
   "trading_post.income": "Passive income: %d gold per turn",
   "trading_post.column.name": "Name",
   "trading_post.column.type": "Type",
   "trading_post.column.price": "Price",
   "trading_post.selected": "%s — %d gold",
   "trading_post.buy": "Buy",
   ```

2. **Write the failing tests.** Create `tests/unit/test_trading_post.gd`:

   ```gdscript
   extends GutTest

   const TradingPostScene := preload("res://scenes/ui/trading_post.tscn")
   const UiTestHelpers := preload("res://tests/unit/ui_test_helpers.gd")


   func before_each() -> void:
   	GameSession.reset()


   func after_each() -> void:
   	GameManager.close_game_menu()


   func test_trading_post_shows_the_title_income_and_back_action() -> void:
   	var screen: Control = TradingPostScene.instantiate()
   	add_child_autofree(screen)

   	assert_eq(screen.get_node("Body/Center/VBox/Title").text, "trading_post.title")
   	assert_eq(
   		screen.get_node("Body/Center/VBox/IncomeLabel").text,
   		tr("trading_post.income") % GameSession.TRADING_POST_INCOME_PER_TURN
   	)
   	assert_eq(screen.get_node("Body/Center/VBox/BackButton").text, "ui.back")


   func test_trading_post_contains_the_camp_nav() -> void:
   	var screen: Control = TradingPostScene.instantiate()
   	add_child_autofree(screen)

   	assert_not_null(screen.get_node_or_null("Body/CampNav"))


   func test_back_button_returns_to_trade() -> void:
   	var source := FileAccess.get_file_as_string("res://scripts/ui/trading_post.gd")
   	assert_string_contains(source, "GameManager.go_to_trade()")


   func test_buy_table_lists_every_weapon_and_armor() -> void:
   	var screen: Control = TradingPostScene.instantiate()
   	add_child_autofree(screen)
   	var tree: Tree = screen.get_node("Body/Center/VBox/BuyTable/Tree")

   	assert_eq(
   		UiTestHelpers.tree_row_values(tree, 0).size(),
   		GameSession.WEAPONS.size() + GameSession.ARMORS.size()
   	)


   func test_selecting_a_row_shows_its_detail_and_the_buy_button() -> void:
   	var screen: Control = TradingPostScene.instantiate()
   	add_child_autofree(screen)
   	var tree: Tree = screen.get_node("Body/Center/VBox/BuyTable/Tree")
   	tree.get_root().get_first_child().select(0)

   	tree.emit_signal("item_selected")

   	assert_true(screen.get_node("Body/Center/VBox/BuyButton").visible)
   	assert_true(screen.get_node("Body/Center/VBox/SelectedItemLabel").visible)


   func test_buy_button_is_disabled_when_unaffordable_and_enabled_once_affordable() -> void:
   	var screen: Control = TradingPostScene.instantiate()
   	add_child_autofree(screen)
   	var tree: Tree = screen.get_node("Body/Center/VBox/BuyTable/Tree")
   	tree.get_root().get_first_child().select(0)
   	tree.emit_signal("item_selected")

   	assert_true(screen.get_node("Body/Center/VBox/BuyButton").disabled)

   	GameSession.gold = 1000
   	screen.refresh()
   	screen._on_row_selected(screen.selected_item_id)

   	assert_false(screen.get_node("Body/Center/VBox/BuyButton").disabled)


   func test_pressing_buy_purchases_the_selected_item_and_refreshes() -> void:
   	GameSession.gold = 1000
   	var screen: Control = TradingPostScene.instantiate()
   	add_child_autofree(screen)
   	screen.selected_item_id = "dagger_iron"
   	var buy_button: Button = screen.get_node("Body/Center/VBox/BuyButton")

   	buy_button.emit_signal("pressed")

   	assert_eq(GameSession.banked_gear.get("dagger_iron", 0), 1)


   func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
   	var screen: Control = TradingPostScene.instantiate()
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
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_trading_post.gd -gexit
   ```

   Expected: FAIL — `res://scenes/ui/trading_post.tscn` does not exist yet.

4. **Create `scripts/ui/trading_post.gd`.**

   ```gdscript
   extends Control

   ## Shows the Trading Post's passive per-turn income and a Buy table listing
   ## every catalog item (GameSession.WEAPONS + GameSession.ARMORS). Selecting a
   ## row shows its detail and a Buy action gated on affordability, mirroring
   ## recruitment.gd's row-selection-drives-a-gated-purchase-button pattern.
   ## Note: no upgrade tiers here — see this plan's Phase C architecture note.

   const TableColumnDescriptor := preload("res://scripts/ui/table_column.gd")

   @onready var income_label: Label = $Body/Center/VBox/IncomeLabel
   @onready var buy_table: TableView = $Body/Center/VBox/BuyTable
   @onready var selected_item_label: Label = $Body/Center/VBox/SelectedItemLabel
   @onready var buy_button: Button = $Body/Center/VBox/BuyButton

   var selected_item_id: String = ""


   func _ready() -> void:
   	buy_table.row_selected.connect(_on_row_selected)
   	buy_table.set_columns(_build_columns())
   	refresh()


   func _unhandled_input(event: InputEvent) -> void:
   	if event.is_action_pressed("ui_cancel"):
   		get_viewport().set_input_as_handled()
   		GameManager.open_game_menu()


   func refresh() -> void:
   	income_label.text = tr("trading_post.income") % GameSession.TRADING_POST_INCOME_PER_TURN
   	buy_table.set_rows(_build_rows())
   	_refresh_selection()


   func _build_columns() -> Array[TableColumn]:
   	var name_column := TableColumnDescriptor.new(&"name", tr("trading_post.column.name"))
   	name_column.expand = true
   	name_column.expand_ratio = 2
   	var type_column := TableColumnDescriptor.new(&"type", tr("trading_post.column.type"))
   	var price_column := TableColumnDescriptor.new(&"price", tr("trading_post.column.price"), TableColumnDescriptor.Type.INTEGER)
   	return [name_column, type_column, price_column]


   func _build_rows() -> Array[Dictionary]:
   	var rows: Array[Dictionary] = []
   	for item_id in GameSession.WEAPONS:
   		rows.append(_row_for(item_id, GameSession.WEAPONS[item_id]))
   	for item_id in GameSession.ARMORS:
   		rows.append(_row_for(item_id, GameSession.ARMORS[item_id]))
   	return rows


   func _row_for(item_id: String, item: Dictionary) -> Dictionary:
   	return {"id": item_id, "name": tr(item.name_key), "type": tr("stores.type.%s" % item.slot), "price": item.price}


   func _refresh_selection() -> void:
   	var item := GameSession.get_item_definition(selected_item_id)
   	if item.is_empty():
   		selected_item_id = ""
   		selected_item_label.visible = false
   		buy_button.visible = false
   		return

   	selected_item_label.visible = true
   	selected_item_label.text = tr("trading_post.selected") % [tr(item.name_key), item.price]
   	buy_button.visible = true
   	buy_button.disabled = GameSession.gold < int(item.price)


   func _on_row_selected(row_id: Variant) -> void:
   	selected_item_id = str(row_id)
   	_refresh_selection()


   func _on_buy_button_pressed() -> void:
   	GameSession.buy_item(selected_item_id)
   	refresh()


   func _on_back_pressed() -> void:
   	GameManager.go_to_trade()
   ```

5. **Create `scenes/ui/trading_post.tscn`.**

   ```
   [gd_scene load_steps=4 format=3]

   [ext_resource type="Script" path="res://scripts/ui/trading_post.gd" id="1_trading_post"]
   [ext_resource type="Script" path="res://scripts/ui/table_view.gd" id="2_table_view"]
   [ext_resource type="PackedScene" path="res://scenes/ui/camp_nav.tscn" id="3_camp_nav"]

   [node name="TradingPost" type="Control"]
   layout_mode = 3
   anchors_preset = 15
   anchor_right = 1.0
   anchor_bottom = 1.0
   grow_horizontal = 2
   grow_vertical = 2
   script = ExtResource("1_trading_post")

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
   text = "trading_post.title"
   horizontal_alignment = 1

   [node name="IncomeLabel" type="Label" parent="Body/Center/VBox"]
   layout_mode = 2
   horizontal_alignment = 1

   [node name="BuyTable" type="VBoxContainer" parent="Body/Center/VBox"]
   layout_mode = 2
   custom_minimum_size = Vector2(560, 280)
   script = ExtResource("2_table_view")

   [node name="SelectedItemLabel" type="Label" parent="Body/Center/VBox"]
   layout_mode = 2
   visible = false
   horizontal_alignment = 1

   [node name="BuyButton" type="Button" parent="Body/Center/VBox"]
   layout_mode = 2
   visible = false
   text = "trading_post.buy"

   [node name="BackButton" type="Button" parent="Body/Center/VBox"]
   layout_mode = 2
   text = "ui.back"

   [connection signal="pressed" from="Body/Center/VBox/BuyButton" to="." method="_on_buy_button_pressed"]
   [connection signal="pressed" from="Body/Center/VBox/BackButton" to="." method="_on_back_pressed"]
   ```

6. **Run the tests to verify they pass.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_trading_post.gd -gexit
   ```

   Expected: PASS.

7. **Commit** only this task's files:

   ```bash
   git add scenes/ui/trading_post.tscn scripts/ui/trading_post.gd tests/unit/test_trading_post.gd translations/en.tres
   git commit -m "feat: add the Trading Post screen"
   ```

## Milestone

The full weapon/armor catalog is purchasable with gold once the Trading
Post is owned, with a correctly gold-gated Buy button and purchases landing
in `banked_gear`, ready for Task 15 to equip.
