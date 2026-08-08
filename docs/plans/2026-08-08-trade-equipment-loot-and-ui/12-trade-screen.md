# Task 12: Trade screen (Stores + Trading Post purchase gate)

## Objective

Build the Trade landing screen: a two-row table (Stores always, Trading
Post once purchased) and a gold-gated purchase button for the Trading Post
itself.

## Files

- Create: `scenes/ui/trade.tscn`, `scripts/ui/trade.gd`
- Test: `tests/unit/test_trade.gd`

## Depends on

Task 09 (`GameSession.has_trading_post`, `can_purchase_trading_post()`,
`purchase_trading_post()`, `TRADING_POST_PURCHASE_COST`), Task 10
(`GameManager.go_to_stores()`, `go_to_trading_post()`, `go_to_encampment()`).

## Steps

1. **Add translation keys.** In `translations/en.tres`, add:

   ```
   "trade.title": "Trade",
   "trade.column.name": "Name",
   "trade.stores": "Stores",
   "trade.trading_post": "Trading Post",
   "trade.purchase_trading_post": "Purchase Trading Post (%d gold)",
   ```

2. **Write the failing tests.** Create `tests/unit/test_trade.gd`:

   ```gdscript
   extends GutTest

   const TradeScene := preload("res://scenes/ui/trade.tscn")
   const UiTestHelpers := preload("res://tests/unit/ui_test_helpers.gd")


   func before_each() -> void:
   	GameSession.reset()


   func after_each() -> void:
   	GameManager.close_game_menu()


   func test_trade_shows_the_title_and_the_back_action() -> void:
   	var screen: Control = TradeScene.instantiate()
   	add_child_autofree(screen)

   	assert_eq(screen.get_node("Body/Center/VBox/Title").text, "trade.title")
   	assert_eq(screen.get_node("Body/Center/VBox/BackButton").text, "ui.back")


   func test_trade_contains_the_camp_nav() -> void:
   	var screen: Control = TradeScene.instantiate()
   	add_child_autofree(screen)

   	assert_not_null(screen.get_node_or_null("Body/CampNav"))


   func test_back_button_returns_to_the_encampment() -> void:
   	var source := FileAccess.get_file_as_string("res://scripts/ui/trade.gd")
   	assert_string_contains(source, "GameManager.go_to_encampment()")


   func test_trade_table_shows_only_stores_before_a_trading_post_is_purchased() -> void:
   	var screen: Control = TradeScene.instantiate()
   	add_child_autofree(screen)
   	var tree: Tree = screen.get_node("Body/Center/VBox/TradeTable/Tree")

   	assert_eq(UiTestHelpers.tree_row_values(tree, 0), ["Stores"])


   func test_trade_table_also_shows_trading_post_once_purchased() -> void:
   	GameSession.gold = GameSession.TRADING_POST_PURCHASE_COST
   	GameSession.purchase_trading_post()
   	var screen: Control = TradeScene.instantiate()
   	add_child_autofree(screen)
   	var tree: Tree = screen.get_node("Body/Center/VBox/TradeTable/Tree")

   	assert_eq(UiTestHelpers.tree_row_values(tree, 0), ["Stores", "Trading Post"])


   func test_activating_the_stores_row_routes_via_game_manager() -> void:
   	var screen: Control = TradeScene.instantiate()
   	add_child_autofree(screen)
   	var tree: Tree = screen.get_node("Body/Center/VBox/TradeTable/Tree")
   	tree.get_root().get_first_child().select(0)

   	tree.emit_signal("item_activated")

   	var source := FileAccess.get_file_as_string("res://scripts/ui/trade.gd")
   	assert_string_contains(source, "GameManager.go_to_stores()")


   func test_purchase_button_is_disabled_below_the_cost_and_enabled_at_it() -> void:
   	var screen: Control = TradeScene.instantiate()
   	add_child_autofree(screen)
   	var purchase_button: Button = screen.get_node("Body/Center/VBox/PurchaseTradingPostButton")

   	assert_true(purchase_button.visible)
   	assert_true(purchase_button.disabled, "No gold cannot afford the Trading Post")
   	assert_eq(purchase_button.text, tr("trade.purchase_trading_post") % GameSession.TRADING_POST_PURCHASE_COST)

   	GameSession.gold = GameSession.TRADING_POST_PURCHASE_COST
   	screen.refresh()

   	assert_false(purchase_button.disabled)


   func test_pressing_purchase_buys_the_trading_post_and_hides_the_button() -> void:
   	GameSession.gold = GameSession.TRADING_POST_PURCHASE_COST
   	var screen: Control = TradeScene.instantiate()
   	add_child_autofree(screen)
   	var purchase_button: Button = screen.get_node("Body/Center/VBox/PurchaseTradingPostButton")

   	purchase_button.emit_signal("pressed")

   	assert_true(GameSession.has_trading_post)
   	assert_false(screen.get_node("Body/Center/VBox/PurchaseTradingPostButton").visible)


   func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
   	var screen: Control = TradeScene.instantiate()
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
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_trade.gd -gexit
   ```

   Expected: FAIL — `res://scenes/ui/trade.tscn` does not exist yet.

4. **Create `scripts/ui/trade.gd`.**

   ```gdscript
   extends Control

   ## Lists Stores (always present) and, once purchased, Trading Post as
   ## TableView rows — the same one-row-per-destination pattern buildings.gd
   ## uses for Guild Hall. Purchasing the Trading Post is a gated action button
   ## below the table (guild_hall.gd's affordability-gated upgrade-button
   ## pattern), not a table row, since it is a one-time purchase rather than a
   ## destination to navigate to until it succeeds.

   const TableColumnDescriptor := preload("res://scripts/ui/table_column.gd")

   const STORES_ROW_ID := "stores"
   const TRADING_POST_ROW_ID := "trading_post"

   @onready var trade_table: TableView = $Body/Center/VBox/TradeTable
   @onready var purchase_trading_post_button: Button = $Body/Center/VBox/PurchaseTradingPostButton


   func _ready() -> void:
   	trade_table.row_activated.connect(_on_row_activated)
   	trade_table.set_columns(_build_columns())
   	refresh()


   func _unhandled_input(event: InputEvent) -> void:
   	if event.is_action_pressed("ui_cancel"):
   		get_viewport().set_input_as_handled()
   		GameManager.open_game_menu()


   func refresh() -> void:
   	trade_table.set_rows(_build_rows())
   	purchase_trading_post_button.visible = not GameSession.has_trading_post
   	purchase_trading_post_button.disabled = not GameSession.can_purchase_trading_post()
   	purchase_trading_post_button.text = tr("trade.purchase_trading_post") % GameSession.TRADING_POST_PURCHASE_COST


   func _build_columns() -> Array[TableColumn]:
   	var name_column := TableColumnDescriptor.new(&"name", tr("trade.column.name"))
   	name_column.expand = true
   	return [name_column]


   func _build_rows() -> Array[Dictionary]:
   	var rows: Array[Dictionary] = [{"id": STORES_ROW_ID, "name": tr("trade.stores")}]
   	if GameSession.has_trading_post:
   		rows.append({"id": TRADING_POST_ROW_ID, "name": tr("trade.trading_post")})
   	return rows


   func _on_row_activated(row_id: Variant) -> void:
   	if str(row_id) == STORES_ROW_ID:
   		GameManager.go_to_stores()
   	elif str(row_id) == TRADING_POST_ROW_ID:
   		GameManager.go_to_trading_post()


   func _on_purchase_trading_post_button_pressed() -> void:
   	GameSession.purchase_trading_post()
   	refresh()


   func _on_back_pressed() -> void:
   	GameManager.go_to_encampment()
   ```

5. **Create `scenes/ui/trade.tscn`.**

   ```
   [gd_scene load_steps=4 format=3]

   [ext_resource type="Script" path="res://scripts/ui/trade.gd" id="1_trade"]
   [ext_resource type="Script" path="res://scripts/ui/table_view.gd" id="2_table_view"]
   [ext_resource type="PackedScene" path="res://scenes/ui/camp_nav.tscn" id="3_camp_nav"]

   [node name="Trade" type="Control"]
   layout_mode = 3
   anchors_preset = 15
   anchor_right = 1.0
   anchor_bottom = 1.0
   grow_horizontal = 2
   grow_vertical = 2
   script = ExtResource("1_trade")

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
   text = "trade.title"
   horizontal_alignment = 1

   [node name="TradeTable" type="VBoxContainer" parent="Body/Center/VBox"]
   layout_mode = 2
   custom_minimum_size = Vector2(520, 120)
   script = ExtResource("2_table_view")

   [node name="PurchaseTradingPostButton" type="Button" parent="Body/Center/VBox"]
   layout_mode = 2

   [node name="BackButton" type="Button" parent="Body/Center/VBox"]
   layout_mode = 2
   text = "ui.back"

   [connection signal="pressed" from="Body/Center/VBox/PurchaseTradingPostButton" to="." method="_on_purchase_trading_post_button_pressed"]
   [connection signal="pressed" from="Body/Center/VBox/BackButton" to="." method="_on_back_pressed"]
   ```

6. **Run the tests to verify they pass.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_trade.gd -gexit
   ```

   Expected: PASS.

7. **Commit** only this task's files:

   ```bash
   git add scenes/ui/trade.tscn scripts/ui/trade.gd tests/unit/test_trade.gd translations/en.tres
   git commit -m "feat: add the Trade screen"
   ```

## Milestone

The Trade button now leads somewhere real: a Trade screen listing Stores
and, once the Trading Post is purchased, Trading Post — with a working
gold-gated purchase button for the Trading Post itself.
