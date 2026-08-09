# Step 4: Selling Loot — the Shared LootTable Component

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Branch:** `selling-loot-table`

**Goal:** This is the foundational step Steps 6 and 7 build on. It:

1. Adds a `button_visible: Callable` predicate to `TableColumn`/`TableView`,
   so a `BUTTON` column can hide itself on a per-row basis (Equip only
   makes sense on gear rows, never mana-crystal rows).
2. Adds `GameSession.build_loot_rows()`, the row-building logic Stores'
   `_build_rows()` already has, generalized to take any gear-counts /
   mana-crystal-counts pair — so Stores, the victory summary (Step 6), and
   the World Map's Party Details screen (Step 7) all build rows the same
   way from whichever `GameSession` fields they read.
3. Adds `LootTable` (`scenes/ui/loot_table.tscn` /
   `scripts/ui/loot_table.gd`) — a reusable `TableView` wrapper with
   Name/Type/Count/Price columns, an optional per-row `[Sell]` button
   column (Rimworld-style quantity dialog when a row has more than one in
   stock, otherwise an immediate one-unit sale), and an optional per-row
   `[Equip]` button column (hidden on mana-crystal rows).
4. Migrates Stores onto it, replacing the old single
   selected-row-plus-external-button pattern.

**Design decision this step locks in** (not spelled out verbatim in
`docs/plans/minor-fixes.md`): "if there is more than one item" (the
quantity-dialog trigger) means *that row's own stock count* — pressing
`[Sell]` on a row with exactly 1 in stock sells that 1 unit immediately,
with no dialog; pressing it on a row with 2 or more opens the quantity
dialog.

**Files:**
- Modify: `scripts/ui/table_column.gd`
- Modify: `scripts/ui/table_view.gd`
- Modify: `scripts/autoload/game_session.gd`
- Create: `scripts/ui/loot_table.gd`
- Create: `scenes/ui/loot_table.tscn`
- Create: `scripts/ui/sell_quantity_dialog.gd`
- Create: `scenes/ui/sell_quantity_dialog.tscn`
- Modify: `scripts/ui/stores.gd`
- Modify: `scenes/ui/stores.tscn`
- Modify: `translations/en.tres`
- Test: `tests/unit/test_table_view.gd`
- Test: `tests/unit/test_game_session.gd`
- Test: `tests/unit/test_loot_table.gd` (new)
- Test: `tests/unit/test_sell_quantity_dialog.gd` (new)
- Test: `tests/unit/test_stores.gd` (rewritten)

## Part A — `TableColumn.button_visible`

### Step A1: Write the failing test

Add to `tests/unit/test_table_view.gd`, after
`test_button_column_creates_a_native_tree_button_with_its_source_column_id`:

```gdscript
func test_button_visible_callable_hides_the_button_on_rows_it_rejects() -> void:
	var table: Variant = await _make_table()
	var action_column := TableColumnDescriptor.new(&"action", "Action", TableColumnDescriptor.Type.BUTTON)
	action_column.button_visible = func(row: Dictionary) -> bool: return row.id != "borin"

	table.set_columns([action_column])
	table.set_rows([{"id": "alin", "action": ""}, {"id": "borin", "action": ""}])

	var tree: Tree = table.get_node("Tree")
	var first_item := tree.get_root().get_first_child()
	var second_item := first_item.get_next()
	assert_eq(first_item.get_button_count(0), 1)
	assert_eq(second_item.get_button_count(0), 0)
```

### Step A2: Run the test to verify it fails

```
godot --headless -s addons/gut/gut_cmdln.gd -gunit_test_name=test_button_visible_callable_hides_the_button_on_rows_it_rejects -gexit
```

Expected: FAIL — `button_visible` doesn't exist on `TableColumn` yet
(`get_button_count(0)` returns `1` for both rows since every `BUTTON`
column currently always renders its button).

### Step A3: Add the field and honor it

In `scripts/ui/table_column.gd`, add the new field next to `button_text`:

```gdscript
var button_visible: Callable = Callable()
```

In `scripts/ui/table_view.gd`'s `_render()`, find:

```gdscript
			if column.type == TableColumn.Type.BUTTON:
				item.add_button(tree_column_index, _button_icon, column_index, false, column.title)
```

and change it to:

```gdscript
			if column.type == TableColumn.Type.BUTTON:
				if not column.button_visible.is_valid() or column.button_visible.call(row):
					item.add_button(tree_column_index, _button_icon, column_index, false, column.title)
```

### Step A4: Run the test to verify it passes

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_table_view.gd -gexit
```

Expected: `N/N passed.`

## Part B — `GameSession.build_loot_rows()`

### Step B1: Write the failing tests

Add to `tests/unit/test_game_session.gd` (near the existing item-pricing
tests — search for `func test_.*sale_price` or `get_item_definition`):

```gdscript
func test_build_loot_rows_builds_a_gear_row_and_a_mana_crystal_row() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var rows := session.build_loot_rows({"shortsword_iron": 3}, {1: 2})

	assert_eq(rows.size(), 2)
	assert_eq(rows[0], {"id": "shortsword_iron", "name": "Iron Shortsword", "type": "Weapon", "count": 3, "price": 10})
	assert_eq(
		rows[1],
		{"id": "mana_crystal_1", "name": "Mana Crystal (Tier 1)", "type": "Mana Crystal", "count": 2, "price": 5}
	)


func test_build_loot_rows_skips_zero_and_negative_counts() -> void:
	var session: Node = GameSessionScript.new()
	autofree(session)

	var rows := session.build_loot_rows({"shortsword_iron": 0}, {1: -1})

	assert_eq(rows, [] as Array[Dictionary])
```

### Step B2: Run the tests to verify they fail

```
godot --headless -s addons/gut/gut_cmdln.gd -gunit_test_name=test_build_loot_rows -gexit
```

Expected: both FAIL — `build_loot_rows` doesn't exist yet.

### Step B3: Implement it

In `scripts/autoload/game_session.gd`, add this function right after
`get_item_sale_price()` (search for `func get_item_sale_price`):

```gdscript
## The shared loot-row shape (id/name/type/count/price) every loot-listing
## screen renders through LootTable — Stores (banked_gear/mana_crystals),
## the victory summary, and the World Map's Party Details screen
## (pending_gear/pending_mana_crystals), each backed by a different pair of
## GameSession fields but sharing this exact row shape and this exact
## pricing/naming logic.
func build_loot_rows(gear_counts: Dictionary, mana_crystal_counts: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for item_id in gear_counts:
		var count: int = gear_counts[item_id]
		if count <= 0:
			continue
		var item := get_item_definition(item_id)
		rows.append({
			"id": item_id,
			"name": tr(item.name_key),
			"type": tr("stores.type.%s" % item.slot),
			"count": count,
			"price": get_item_sale_price(item_id),
		})
	for tier in mana_crystal_counts:
		var count: int = mana_crystal_counts[tier]
		if count <= 0:
			continue
		var item_id: String = "%s%d" % [MANA_CRYSTAL_ID_PREFIX, tier]
		rows.append({
			"id": item_id,
			"name": tr("stores.mana_crystal") % tier,
			"type": tr("stores.type.mana_crystal"),
			"count": count,
			"price": get_item_sale_price(item_id),
		})
	return rows
```

### Step B4: Run the tests to verify they pass

```
godot --headless -s addons/gut/gut_cmdln.gd -gunit_test_name=test_build_loot_rows -gexit
```

Expected: `N/N passed.`

## Part C — the `SellQuantityDialog`

### Step C1: Write the failing tests

Create `tests/unit/test_sell_quantity_dialog.gd`:

```gdscript
extends GutTest

const SellQuantityDialogScene := preload("res://scenes/ui/sell_quantity_dialog.tscn")


func _open(max_quantity: int, unit_price: int) -> Control:
	var dialog: Control = SellQuantityDialogScene.instantiate()
	add_child_autofree(dialog)
	dialog.show_for_item("shortsword_iron", "Iron Shortsword", max_quantity, unit_price)
	return dialog


func test_show_for_item_starts_at_quantity_one_and_is_visible() -> void:
	var dialog := _open(5, 10)

	assert_true(dialog.visible)
	assert_eq(dialog.get_node("Content/QuantityRow/QuantityInput").text, "1")
	assert_eq(dialog.get_node("Content/TotalLabel").text, tr("sell_quantity_dialog.total") % 10)


func test_plus_and_minus_buttons_adjust_quantity_and_clamp_to_the_stock_range() -> void:
	var dialog := _open(5, 10)

	dialog.get_node("Content/QuantityRow/PlusTenButton").emit_signal("pressed")
	assert_eq(dialog.get_node("Content/QuantityRow/QuantityInput").text, "5", "Clamped to max stock")

	dialog.get_node("Content/QuantityRow/MinusTenButton").emit_signal("pressed")
	assert_eq(dialog.get_node("Content/QuantityRow/QuantityInput").text, "1", "Clamped to a minimum of 1")

	dialog.get_node("Content/QuantityRow/PlusOneButton").emit_signal("pressed")
	assert_eq(dialog.get_node("Content/QuantityRow/QuantityInput").text, "2")

	dialog.get_node("Content/QuantityRow/MinusOneButton").emit_signal("pressed")
	assert_eq(dialog.get_node("Content/QuantityRow/QuantityInput").text, "1")


func test_all_button_sets_quantity_to_the_full_stock() -> void:
	var dialog := _open(5, 10)

	dialog.get_node("Content/AllButton").emit_signal("pressed")

	assert_eq(dialog.get_node("Content/QuantityRow/QuantityInput").text, "5")
	assert_eq(dialog.get_node("Content/TotalLabel").text, tr("sell_quantity_dialog.total") % 50)


func test_ok_emits_confirmed_with_the_item_id_and_chosen_quantity_then_hides() -> void:
	var dialog := _open(5, 10)
	dialog.get_node("Content/AllButton").emit_signal("pressed")
	watch_signals(dialog)

	dialog.get_node("Content/ButtonRow/OkButton").emit_signal("pressed")

	assert_signal_emitted_with_parameters(dialog, "confirmed", ["shortsword_iron", 5])
	assert_false(dialog.visible)


func test_cancel_hides_without_emitting_confirmed() -> void:
	var dialog := _open(5, 10)
	watch_signals(dialog)

	dialog.get_node("Content/ButtonRow/CancelButton").emit_signal("pressed")

	assert_signal_not_emitted(dialog, "confirmed")
	assert_false(dialog.visible)
```

### Step C2: Run the tests to verify they fail

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_sell_quantity_dialog.gd -gexit
```

Expected: every test FAILS — `res://scenes/ui/sell_quantity_dialog.tscn`
doesn't exist yet.

### Step C3: Add the translation keys

In `translations/en.tres`, add (anywhere near the other new keys this step
adds — group them together):

```
"sell_quantity_dialog.total": "Total: %d gold",
"sell_quantity_dialog.all": "ALL",
"sell_quantity_dialog.cancel": "Cancel",
"sell_quantity_dialog.ok": "OK",
```

### Step C4: Create `scripts/ui/sell_quantity_dialog.gd`

```gdscript
class_name SellQuantityDialog
extends PanelContainer

## A Rimworld-style sell quantity picker: a directly-editable quantity
## field, -10/-1/+1/+10 step buttons, an ALL button, and Cancel/OK. Owns no
## GameSession state itself — show_for_item() is given everything it needs
## to render (max stock, unit price), and confirmed(item_id, quantity) is
## the caller's cue to actually call GameSession.sell_item().

signal confirmed(item_id: String, quantity: int)

@onready var item_label: Label = $Content/ItemLabel
@onready var quantity_input: LineEdit = $Content/QuantityRow/QuantityInput
@onready var total_label: Label = $Content/TotalLabel

var _item_id: String = ""
var _max_quantity: int = 1
var _unit_price: int = 0
var _quantity: int = 1


func _ready() -> void:
	visible = false


func show_for_item(item_id: String, item_name: String, max_quantity: int, unit_price: int) -> void:
	_item_id = item_id
	_max_quantity = max_quantity
	_unit_price = unit_price
	item_label.text = item_name
	_set_quantity(1)
	visible = true


func _set_quantity(value: int) -> void:
	_quantity = clampi(value, 1, maxi(_max_quantity, 1))
	quantity_input.text = str(_quantity)
	total_label.text = tr("sell_quantity_dialog.total") % (_quantity * _unit_price)


func _on_quantity_input_text_submitted(new_text: String) -> void:
	_set_quantity(int(new_text) if new_text.is_valid_int() else _quantity)


func _on_minus_ten_button_pressed() -> void:
	_set_quantity(_quantity - 10)


func _on_minus_one_button_pressed() -> void:
	_set_quantity(_quantity - 1)


func _on_plus_one_button_pressed() -> void:
	_set_quantity(_quantity + 1)


func _on_plus_ten_button_pressed() -> void:
	_set_quantity(_quantity + 10)


func _on_all_button_pressed() -> void:
	_set_quantity(_max_quantity)


func _on_cancel_button_pressed() -> void:
	visible = false


func _on_ok_button_pressed() -> void:
	visible = false
	confirmed.emit(_item_id, _quantity)
```

### Step C5: Create `scenes/ui/sell_quantity_dialog.tscn`

The root uses the same centered-anchor setup `level_up.tscn`'s `LevelUp`
root already does (`anchors_preset = 8`, explicit pixel offsets around the
center) — this is what lets it float over `LootTable`'s content instead of
docking into a corner, once instanced there in Part D5:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/sell_quantity_dialog.gd" id="1_dialog"]

[node name="SellQuantityDialog" type="PanelContainer"]
visible = false
layout_mode = 3
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -160.0
offset_top = -110.0
offset_right = 160.0
offset_bottom = 110.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_dialog")

[node name="Content" type="VBoxContainer" parent="."]
layout_mode = 2
theme_override_constants/separation = 8

[node name="ItemLabel" type="Label" parent="Content"]
layout_mode = 2
horizontal_alignment = 1

[node name="QuantityRow" type="HBoxContainer" parent="Content"]
layout_mode = 2
theme_override_constants/separation = 4

[node name="MinusTenButton" type="Button" parent="Content/QuantityRow"]
layout_mode = 2
text = "-10"

[node name="MinusOneButton" type="Button" parent="Content/QuantityRow"]
layout_mode = 2
text = "-"

[node name="QuantityInput" type="LineEdit" parent="Content/QuantityRow"]
layout_mode = 2
custom_minimum_size = Vector2(60, 0)
horizontal_alignment = 1

[node name="PlusOneButton" type="Button" parent="Content/QuantityRow"]
layout_mode = 2
text = "+"

[node name="PlusTenButton" type="Button" parent="Content/QuantityRow"]
layout_mode = 2
text = "+10"

[node name="AllButton" type="Button" parent="Content"]
layout_mode = 2
text = "sell_quantity_dialog.all"

[node name="TotalLabel" type="Label" parent="Content"]
layout_mode = 2
horizontal_alignment = 1

[node name="ButtonRow" type="HBoxContainer" parent="Content"]
layout_mode = 2
theme_override_constants/separation = 8

[node name="CancelButton" type="Button" parent="Content/ButtonRow"]
layout_mode = 2
text = "sell_quantity_dialog.cancel"

[node name="OkButton" type="Button" parent="Content/ButtonRow"]
layout_mode = 2
text = "sell_quantity_dialog.ok"

[connection signal="text_submitted" from="Content/QuantityRow/QuantityInput" to="." method="_on_quantity_input_text_submitted"]
[connection signal="pressed" from="Content/QuantityRow/MinusTenButton" to="." method="_on_minus_ten_button_pressed"]
[connection signal="pressed" from="Content/QuantityRow/MinusOneButton" to="." method="_on_minus_one_button_pressed"]
[connection signal="pressed" from="Content/QuantityRow/PlusOneButton" to="." method="_on_plus_one_button_pressed"]
[connection signal="pressed" from="Content/QuantityRow/PlusTenButton" to="." method="_on_plus_ten_button_pressed"]
[connection signal="pressed" from="Content/AllButton" to="." method="_on_all_button_pressed"]
[connection signal="pressed" from="Content/ButtonRow/CancelButton" to="." method="_on_cancel_button_pressed"]
[connection signal="pressed" from="Content/ButtonRow/OkButton" to="." method="_on_ok_button_pressed"]
```

### Step C6: Run the tests to verify they pass

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_sell_quantity_dialog.gd -gexit
```

Expected: `N/N passed.`

## Part D — the `LootTable` component

### Step D1: Write the failing tests

Create `tests/unit/test_loot_table.gd`:

```gdscript
extends GutTest

const LootTableScene := preload("res://scenes/ui/loot_table.tscn")


func before_each() -> void:
	GameSession.reset()


func _open(show_sell: bool, show_equip: bool) -> Control:
	var loot_table: Control = LootTableScene.instantiate()
	add_child_autofree(loot_table)
	loot_table.configure(show_sell, show_equip)
	return loot_table


func test_empty_rows_shows_the_empty_label_and_hides_the_table() -> void:
	var loot_table := _open(true, true)

	loot_table.set_rows([])

	assert_true(loot_table.get_node("EmptyLabel").visible)
	assert_false(loot_table.get_node("Table").visible)


func test_rows_hide_the_empty_label_and_show_the_table() -> void:
	var loot_table := _open(false, false)

	loot_table.set_rows(GameSession.build_loot_rows({"shortsword_iron": 1}, {}))

	assert_false(loot_table.get_node("EmptyLabel").visible)
	assert_true(loot_table.get_node("Table").visible)


func test_equip_button_is_hidden_on_mana_crystal_rows_and_shown_on_gear_rows() -> void:
	var loot_table := _open(false, true)
	loot_table.set_rows(GameSession.build_loot_rows({"shortsword_iron": 1}, {1: 2}))

	var tree: Tree = loot_table.get_node("Table/Tree")
	var gear_item := tree.get_root().get_first_child()
	var crystal_item := gear_item.get_next()
	# Columns with show_sell=false, show_equip=true: name=0, type=1, count=2, price=3, equip=4.
	assert_eq(gear_item.get_button_count(4), 1)
	assert_eq(crystal_item.get_button_count(4), 0)


func test_equip_button_emits_equip_requested_with_the_item_id() -> void:
	var loot_table := _open(false, true)
	loot_table.set_rows(GameSession.build_loot_rows({"shortsword_iron": 1}, {}))
	watch_signals(loot_table)
	var tree: Tree = loot_table.get_node("Table/Tree")
	var item := tree.get_root().get_first_child()

	tree.emit_signal("button_clicked", item, 4, item.get_button_id(4, 0), MOUSE_BUTTON_LEFT)

	assert_signal_emitted_with_parameters(loot_table, "equip_requested", ["shortsword_iron"])


func test_sell_column_is_absent_without_a_trading_post_and_present_with_one() -> void:
	var loot_table := _open(true, false)
	loot_table.set_rows(GameSession.build_loot_rows({"shortsword_iron": 1}, {}))
	var tree: Tree = loot_table.get_node("Table/Tree")
	# Columns with show_sell=true, show_equip=false: name=0, type=1, count=2, price=3, sell=4.
	assert_eq(tree.get_root().get_first_child().get_button_count(4), 0, "No Trading Post yet")

	GameSession.has_trading_post = true
	loot_table.set_rows(GameSession.build_loot_rows({"shortsword_iron": 1}, {}))

	assert_eq(tree.get_root().get_first_child().get_button_count(4), 1)


func test_pressing_sell_on_a_single_unit_row_sells_it_immediately_without_a_dialog() -> void:
	GameSession.has_trading_post = true
	GameSession.banked_gear = {"shortsword_iron": 1}
	var loot_table := _open(true, false)
	loot_table.set_rows(GameSession.build_loot_rows(GameSession.banked_gear, {}))
	var tree: Tree = loot_table.get_node("Table/Tree")
	var item := tree.get_root().get_first_child()

	tree.emit_signal("button_clicked", item, 4, item.get_button_id(4, 0), MOUSE_BUTTON_LEFT)

	assert_eq(GameSession.banked_gear.shortsword_iron, 0)
	assert_eq(GameSession.gold, 10)
	assert_false(loot_table.get_node("SellQuantityDialog").visible)


func test_pressing_sell_on_a_multi_unit_row_opens_the_quantity_dialog_without_selling() -> void:
	GameSession.has_trading_post = true
	GameSession.banked_gear = {"shortsword_iron": 3}
	var loot_table := _open(true, false)
	loot_table.set_rows(GameSession.build_loot_rows(GameSession.banked_gear, {}))
	var tree: Tree = loot_table.get_node("Table/Tree")
	var item := tree.get_root().get_first_child()

	tree.emit_signal("button_clicked", item, 4, item.get_button_id(4, 0), MOUSE_BUTTON_LEFT)

	assert_eq(GameSession.banked_gear.shortsword_iron, 3, "Nothing sold until the dialog is confirmed")
	assert_true(loot_table.get_node("SellQuantityDialog").visible)


func test_confirming_the_quantity_dialog_sells_that_many_and_emits_sold() -> void:
	GameSession.has_trading_post = true
	GameSession.banked_gear = {"shortsword_iron": 3}
	var loot_table := _open(true, false)
	loot_table.set_rows(GameSession.build_loot_rows(GameSession.banked_gear, {}))
	var tree: Tree = loot_table.get_node("Table/Tree")
	var item := tree.get_root().get_first_child()
	tree.emit_signal("button_clicked", item, 4, item.get_button_id(4, 0), MOUSE_BUTTON_LEFT)
	watch_signals(loot_table)

	loot_table.get_node("SellQuantityDialog").confirmed.emit("shortsword_iron", 2)

	assert_eq(GameSession.banked_gear.shortsword_iron, 1)
	assert_eq(GameSession.gold, 20)
	assert_signal_emitted(loot_table, "sold")
```

### Step D2: Run the tests to verify they fail

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_loot_table.gd -gexit
```

Expected: every test FAILS — `res://scenes/ui/loot_table.tscn` doesn't
exist yet.

### Step D3: Add the translation keys

In `translations/en.tres`:

```
"loot_table.column.name": "Name",
"loot_table.column.type": "Type",
"loot_table.column.count": "Count",
"loot_table.column.price": "Price",
"loot_table.sell": "Sell",
"loot_table.equip": "Equip",
"loot_table.empty": "Nothing here yet.",
```

### Step D4: Create `scripts/ui/loot_table.gd`

```gdscript
class_name LootTable
extends Control

## Reusable gear/mana-crystal loot listing, shared by Stores (Step 4), the
## victory summary (Step 6), and the World Map's Party Details screen
## (Step 7). Callers supply rows via set_rows() — see
## GameSession.build_loot_rows() for the expected id/name/type/count/price
## shape — and pick which per-row actions to show via configure().
## Selling is fully self-contained (it always means
## GameSession.sell_item()): a single-unit row sells immediately, a
## multi-unit row opens SellQuantityDialog first. Equipping is not
## self-contained, since where it should navigate varies by caller — a
## click only emits equip_requested(item_id) for the parent to route.
##
## extends Control, not VBoxContainer: SellQuantityDialog must float
## centered over Table/EmptyLabel, not get squashed into their vertical
## flow. A Container forces every direct child's position/size, so Table,
## EmptyLabel, and SellQuantityDialog are instead full-rect/centered via
## their own anchors (see loot_table.tscn) — the same reason
## battlefield.tscn's LevelUp overlay is a child of the plain-Control HUD
## rather than of any of HUD's own VBoxContainers. Table and EmptyLabel can
## safely share the same full-rect space since set_rows() always keeps
## exactly one of them visible.

signal equip_requested(item_id: String)
signal sold

const TableColumnDescriptor := preload("res://scripts/ui/table_column.gd")

@onready var table: TableView = $Table
@onready var empty_label: Label = $EmptyLabel
@onready var sell_dialog: SellQuantityDialog = $SellQuantityDialog

var show_sell: bool = false
var show_equip: bool = false
var _rows_by_id: Dictionary = {}


func _ready() -> void:
	table.action_pressed.connect(_on_action_pressed)
	sell_dialog.confirmed.connect(_on_sell_dialog_confirmed)
	table.set_columns(_build_columns())


func configure(new_show_sell: bool, new_show_equip: bool) -> void:
	show_sell = new_show_sell
	show_equip = new_show_equip
	table.set_columns(_build_columns())


func set_rows(rows: Array[Dictionary]) -> void:
	_rows_by_id.clear()
	for row in rows:
		_rows_by_id[row.id] = row
	table.set_rows(rows)
	empty_label.visible = rows.is_empty()
	table.visible = not rows.is_empty()


func _build_columns() -> Array[TableColumn]:
	var name_column := TableColumnDescriptor.new(&"name", tr("loot_table.column.name"))
	name_column.expand = true
	name_column.expand_ratio = 2
	var type_column := TableColumnDescriptor.new(&"type", tr("loot_table.column.type"))
	var count_column := TableColumnDescriptor.new(&"count", tr("loot_table.column.count"), TableColumnDescriptor.Type.INTEGER)
	var price_column := TableColumnDescriptor.new(&"price", tr("loot_table.column.price"), TableColumnDescriptor.Type.INTEGER)
	var columns: Array[TableColumn] = [name_column, type_column, count_column, price_column]
	if show_sell:
		var sell_column := TableColumnDescriptor.new(&"sell", tr("loot_table.sell"), TableColumnDescriptor.Type.BUTTON)
		sell_column.button_visible = func(_row: Dictionary) -> bool: return GameSession.has_trading_post
		columns.append(sell_column)
	if show_equip:
		var equip_column := TableColumnDescriptor.new(&"equip", tr("loot_table.equip"), TableColumnDescriptor.Type.BUTTON)
		equip_column.button_visible = func(row: Dictionary) -> bool: return not str(row.id).begins_with(GameSession.MANA_CRYSTAL_ID_PREFIX)
		columns.append(equip_column)
	return columns


func _on_action_pressed(row_id: Variant, column_key: StringName) -> void:
	match column_key:
		&"sell":
			_handle_sell(str(row_id))
		&"equip":
			equip_requested.emit(str(row_id))


func _handle_sell(item_id: String) -> void:
	if not GameSession.has_trading_post:
		return
	var row: Dictionary = _rows_by_id.get(item_id, {})
	if row.is_empty():
		return
	if int(row.count) <= 1:
		GameSession.sell_item(item_id, 1)
		sold.emit()
		return
	sell_dialog.show_for_item(item_id, str(row.name), int(row.count), int(row.price))


func _on_sell_dialog_confirmed(item_id: String, quantity: int) -> void:
	GameSession.sell_item(item_id, quantity)
	sold.emit()
```

### Step D5: Create `scenes/ui/loot_table.tscn`

`Table` and `EmptyLabel` are each anchored full-rect (`anchors_preset = 15`,
the same "Full Rect" preset `stores.tscn`'s own root `Control` already
uses) instead of being managed by a container, precisely so
`SellQuantityDialog` — anchored centered inside its own scene file — can
float above them instead of being squashed into a vertical flow:

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/ui/loot_table.gd" id="1_loot_table"]
[ext_resource type="Script" path="res://scripts/ui/table_view.gd" id="2_table_view"]
[ext_resource type="PackedScene" path="res://scenes/ui/sell_quantity_dialog.tscn" id="3_sell_quantity_dialog"]

[node name="LootTable" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_loot_table")

[node name="Table" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("2_table_view")

[node name="EmptyLabel" type="Label" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
visible = false
text = "loot_table.empty"
horizontal_alignment = 1

[node name="SellQuantityDialog" parent="." instance=ExtResource("3_sell_quantity_dialog")]
layout_mode = 1
```

(`SellQuantityDialog`'s own centered anchors come from
`sell_quantity_dialog.tscn` itself, created in Part C — the instance here
only needs `layout_mode = 1` so `LootTable`, a plain `Control`, leaves
those anchors alone instead of trying to container-manage it. This is the
same pattern `battlefield.tscn` already uses to place `LevelUp` — see its
`[node name="LevelUp" parent="HUD" instance=...]` block, `layout_mode = 1`
with no anchor overrides of its own.)

### Step D6: Run the tests to verify they pass

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_loot_table.gd -gexit
```

Expected: `N/N passed.`

## Part E — migrate Stores onto `LootTable`

### Step E1: Rewrite `tests/unit/test_stores.gd`

Replace the file's contents entirely:

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

	assert_true(screen.get_node("Body/Center/VBox/LootTable/EmptyLabel").visible)


func test_table_shows_a_gear_row_and_a_mana_crystal_row() -> void:
	GameSession.banked_gear = {"shortsword_iron": 3}
	GameSession.mana_crystals = {1: 2}
	var screen: Control = StoresScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/LootTable/Table/Tree")

	assert_eq(UiTestHelpers.tree_row_values(tree, 0), ["Iron Shortsword", "Mana Crystal (Tier 1)"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 1), ["Weapon", "Mana Crystal"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 2), ["3", "2"])
	assert_eq(UiTestHelpers.tree_row_values(tree, 3), ["10", "5"])
	assert_false(screen.get_node("Body/Center/VBox/LootTable/EmptyLabel").visible)


## Columns with Stores' show_sell=true, show_equip=true: name=0, type=1,
## count=2, price=3, sell=4, equip=5.
func test_equip_button_is_hidden_on_mana_crystal_rows() -> void:
	GameSession.mana_crystals = {1: 2}
	var screen: Control = StoresScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/LootTable/Table/Tree")

	assert_eq(tree.get_root().get_first_child().get_button_count(5), 0)


func test_sell_button_is_absent_without_a_trading_post_and_present_with_one() -> void:
	GameSession.banked_gear = {"shortsword_iron": 1}
	var screen: Control = StoresScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/LootTable/Table/Tree")

	assert_eq(tree.get_root().get_first_child().get_button_count(4), 0)

	GameSession.has_trading_post = true
	screen.refresh()

	assert_eq(tree.get_root().get_first_child().get_button_count(4), 1)


func test_pressing_sell_on_a_single_unit_row_sells_it_immediately() -> void:
	GameSession.has_trading_post = true
	GameSession.banked_gear = {"shortsword_iron": 1}
	var screen: Control = StoresScene.instantiate()
	add_child_autofree(screen)
	var tree: Tree = screen.get_node("Body/Center/VBox/LootTable/Table/Tree")
	var item := tree.get_root().get_first_child()

	tree.emit_signal("button_clicked", item, 4, item.get_button_id(4, 0), MOUSE_BUTTON_LEFT)

	assert_eq(GameSession.banked_gear.shortsword_iron, 0)
	assert_eq(GameSession.gold, 10)


func test_pressing_equip_routes_via_game_manager() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/stores.gd")
	assert_string_contains(source, "GameManager.go_to_assign_equipment(item_id)")


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

### Step E2: Run the tests to verify they fail

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_stores.gd -gexit
```

Expected: every test that touches `Body/Center/VBox/LootTable/...` FAILS
(the node doesn't exist in the scene yet); title/camp-nav/back/escape tests
still pass since those parts of `stores.tscn`/`stores.gd` aren't changing.

### Step E3: Rewrite `scripts/ui/stores.gd`

```gdscript
extends Control

## Lists everything banked in storage (GameSession.banked_gear +
## GameSession.mana_crystals) via the shared LootTable component (see
## loot_table.gd) — full [Sell]/[Equip] actions, unscoped (any roster
## adventurer can be assigned here, unlike the party-scoped Equip on the
## victory summary and World Map Party Details — see Steps 6/7).

@onready var loot_table: LootTable = $Body/Center/VBox/LootTable


func _ready() -> void:
	loot_table.configure(true, true)
	loot_table.equip_requested.connect(_on_equip_requested)
	loot_table.sold.connect(refresh)
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		GameManager.open_game_menu()


func refresh() -> void:
	loot_table.set_rows(GameSession.build_loot_rows(GameSession.banked_gear, GameSession.mana_crystals))


func _on_equip_requested(item_id: String) -> void:
	GameManager.go_to_assign_equipment(item_id)


func _on_back_pressed() -> void:
	GameManager.go_to_trade()
```

### Step E4: Rewrite `scenes/ui/stores.tscn`

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/ui/stores.gd" id="1_stores"]
[ext_resource type="PackedScene" path="res://scenes/ui/loot_table.tscn" id="2_loot_table"]
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

[node name="LootTable" parent="Body/Center/VBox" instance=ExtResource("2_loot_table")]
layout_mode = 2
custom_minimum_size = Vector2(640, 280)

[node name="BackButton" type="Button" parent="Body/Center/VBox"]
layout_mode = 2
text = "ui.back"

[connection signal="pressed" from="Body/Center/VBox/BackButton" to="." method="_on_back_pressed"]
```

### Step E5: Remove the now-dead translation keys

In `translations/en.tres`, remove these three keys (nothing references them
anymore after this step):

```
"stores.selected": "%s — %d in stock, sells for %d gold",
"stores.sell": "Sell",
"stores.assign": "Assign to Unit",
```

### Step E6: Run the tests to verify they pass

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_stores.gd -gexit
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

1. Press **FN+F9**, choose the **Stocked Trading Post + Stores** scenario
   (staffed party, Trading Post owned, Stores pre-stocked with 2 tier-1
   mana crystals and a banked Iron Shortsword).
2. Open Trade → Stores. Confirm the table shows both rows with
   Name/Type/Count/Price, each with a **[Sell]** button, and only the
   Shortsword row also has an **[Equip]** button.
3. Click **[Sell]** on the mana crystal row (count 2) — the Rimworld-style
   quantity dialog opens. Try **[-10]**/**[-]**/**[+]**/**[+10]**/**[ALL]**
   and confirm the total updates and clamps between 1 and the stock count.
   Click **OK** — the row's count drops by the chosen amount and gold
   increases to match.
4. Click **[Sell]** on the Shortsword row (count 1) — it sells immediately
   with no dialog, and the row disappears once its count reaches 0.
5. Recruit a second adventurer (Roster → Recruit, or FN+F9 doesn't have a
   direct shortcut for this — use the in-game Recruitment screen), bank
   another weapon (defeat the Goblin Camp once more, or re-run the debug
   scenario), then click **[Equip]** on a gear row — the existing Assign
   Equipment screen opens listing the full roster, same as before this
   step.

## Commit

```bash
git add scripts/ui/table_column.gd scripts/ui/table_view.gd \
  scripts/autoload/game_session.gd \
  scripts/ui/loot_table.gd scenes/ui/loot_table.tscn \
  scripts/ui/sell_quantity_dialog.gd scenes/ui/sell_quantity_dialog.tscn \
  scripts/ui/stores.gd scenes/ui/stores.tscn \
  translations/en.tres \
  tests/unit/test_table_view.gd tests/unit/test_game_session.gd \
  tests/unit/test_loot_table.gd tests/unit/test_sell_quantity_dialog.gd \
  tests/unit/test_stores.gd
git commit -m "feat: add the shared LootTable component and a Rimworld-style sell dialog"
```

## Merge back to main

After user signoff on manual verification:

```bash
git checkout main
git merge selling-loot-table
git branch -d selling-loot-table
```
