# Task 11: Enable the Trade button in `CampNav`

## Objective

Turn on the Trade destination in the encampment's shared navigation
sidebar, which has shown a permanently-disabled Trade button since the
encampment UI shell shipped.

## Files

- Modify: `scripts/ui/camp_nav.gd`, `scenes/ui/camp_nav.tscn`
- Test: `tests/unit/test_camp_nav.gd`

## Depends on

Task 10 (`GameManager.go_to_trade()`).

## Produces

`CampNav._on_trade_button_pressed()`. `camp_nav.gd` already declares
`@onready var trade_button: Button = $VBox/TradeButton` — this task only
adds the handler and enables the button, it does not add the `@onready`
line.

## Steps

1. **Write the failing tests.** Replace the existing
   `test_trade_is_present_but_disabled` test in
   `tests/unit/test_camp_nav.gd` with:

   ```gdscript
   func test_trade_button_is_enabled() -> void:
   	var nav := _make_nav()

   	assert_false(nav.get_node("VBox/TradeButton").disabled)


   func test_trade_button_routes_via_game_manager() -> void:
   	var source := FileAccess.get_file_as_string("res://scripts/ui/camp_nav.gd")
   	assert_string_contains(source, "GameManager.go_to_trade()")
   ```

2. **Run the tests to verify they fail.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_camp_nav.gd -gunit_test_name=trade_button -gexit
   ```

   Expected: FAIL — `trade_button.disabled` is still `true`, and
   `camp_nav.gd`'s source does not yet contain `GameManager.go_to_trade()`.

3. **Implement.** In `scenes/ui/camp_nav.tscn`, remove the
   `disabled = true` line from the `TradeButton` node, and add a `pressed`
   connection alongside the others at the bottom of the file:

   ```
   [connection signal="pressed" from="VBox/TradeButton" to="." method="_on_trade_button_pressed"]
   ```

   In `scripts/ui/camp_nav.gd`, add next to
   `_on_buildings_button_pressed()`:

   ```gdscript
   func _on_trade_button_pressed() -> void:
   	GameManager.go_to_trade()
   ```

4. **Run the tests to verify they pass.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_camp_nav.gd -gexit
   ```

   Expected: PASS. (Clicking all the way through would still try to load
   `trade.tscn`, which doesn't exist until Task 12 — these two tests only
   check the button's `disabled` flag and the handler's source text, so
   they pass on their own.)

5. **Commit** only this task's files:

   ```bash
   git add scripts/ui/camp_nav.gd scenes/ui/camp_nav.tscn tests/unit/test_camp_nav.gd
   git commit -m "feat: enable the Trade button in CampNav"
   ```

## Milestone

The Trade button in every camp screen's navigation sidebar is clickable and
wired to `GameManager.go_to_trade()`, even though the destination screen
itself doesn't exist yet — that lands in Task 12.
