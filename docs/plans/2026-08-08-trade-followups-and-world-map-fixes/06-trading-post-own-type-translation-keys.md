# Task 06: Trading Post gets its own Type translation keys

## Objective

`scripts/ui/trading_post.gd`'s `_row_for()` renders its Type column via
`tr("stores.type.%s" % item.slot)` — reaching into the Stores screen's
translation namespace even though Trading Post already declares its own
`trading_post.column.*` keys for its other columns. Harmless today, but it
means renaming or removing a `stores.type.*` key would silently break
Trading Post too. Give it its own keys.

## Files

- Modify: `scripts/ui/trading_post.gd`, `translations/en.tres`
- Test: `tests/unit/test_trading_post.gd`

## Depends on

None.

## Produces

Two new translation keys, `trading_post.type.weapon` and
`trading_post.type.armor` (Trading Post only ever lists weapons and
armors, never mana crystals, so no `trading_post.type.mana_crystal` is
needed), and `_row_for()` reads from them instead of `stores.type.*`.

## Steps

1. **Write the failing test.** Add to `tests/unit/test_trading_post.gd`,
   near `test_buy_table_lists_every_weapon_and_armor`:

   ```gdscript
   func test_type_column_uses_trading_posts_own_translation_keys() -> void:
   	var screen: Control = TradingPostScene.instantiate()
   	add_child_autofree(screen)
   	var tree: Tree = screen.get_node("Body/Center/VBox/BuyTable/Tree")

   	var row_values := UiTestHelpers.tree_row_values(tree, 1)
   	assert_true(row_values.has(tr("trading_post.type.weapon")))
   	assert_true(row_values.has(tr("trading_post.type.armor")))
   ```

2. **Run the test to verify it fails.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_trading_post.gd -gunit_test_name=type_column_uses -gexit
   ```

   Expected: FAIL — `tr("trading_post.type.weapon")` and
   `tr("trading_post.type.armor")` don't exist yet, so they resolve to the
   literal key strings, which won't match the rendered `"Weapon"`/`"Armor"`
   text still coming from `stores.type.*`.

3. **Add the translation keys.** In `translations/en.tres`, add next to
   `"trading_post.column.price": "Price",`:

   ```
   "trading_post.type.weapon": "Weapon",
   "trading_post.type.armor": "Armor",
   ```

4. **Update `_row_for()`.** In `scripts/ui/trading_post.gd`, replace:

   ```gdscript
   func _row_for(item_id: String, item: Dictionary) -> Dictionary:
   	return {"id": item_id, "name": tr(item.name_key), "type": tr("stores.type.%s" % item.slot), "price": item.price}
   ```

   with:

   ```gdscript
   func _row_for(item_id: String, item: Dictionary) -> Dictionary:
   	return {"id": item_id, "name": tr(item.name_key), "type": tr("trading_post.type.%s" % item.slot), "price": item.price}
   ```

5. **Run the test to verify it passes.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_trading_post.gd -gexit
   ```

   Expected: PASS (the values are identical strings today, "Weapon"/"Armor",
   so this is a namespace change, not a visible text change).

6. **Run the full suite.**

   ```bash
   make test
   ```

   Expected: `---- All tests passed! ----`, exit code 0.

7. **Commit** only this task's files:

   ```bash
   git add scripts/ui/trading_post.gd translations/en.tres tests/unit/test_trading_post.gd
   git commit -m "fix: give Trading Post its own Type column translation keys"
   ```

## Milestone

Trading Post's Type column no longer depends on Stores' translation keys
existing — renaming or removing a `stores.type.*` key can no longer
silently break an unrelated screen.
