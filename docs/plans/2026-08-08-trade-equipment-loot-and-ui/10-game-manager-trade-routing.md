# Task 10: `GameManager` routing for Trade, Stores, Trading Post, and Assign Equipment

## Objective

Add the four scene routes the Trade destination needs, following the
existing `go_to_*` convention exactly, including the validate-then-route
shape `go_to_unit_details()` already uses for a route that carries context.

## Files

- Modify: `scripts/autoload/game_manager.gd`
- Test: `tests/unit/test_game_manager.gd`

## Depends on

Task 01 (`GameSession.get_item_definition()`, used to validate
`go_to_assign_equipment`'s argument).

## Produces

`GameManager.go_to_trade() -> Error`, `GameManager.go_to_stores() -> Error`,
`GameManager.go_to_trading_post() -> Error`,
`GameManager.go_to_assign_equipment(item_id: String) -> Error`.

## Steps

1. **Write the failing tests.** Add to `tests/unit/test_game_manager.gd`:

   ```gdscript
   func test_go_to_trade_changes_scene_and_clears_detail_context() -> void:
   	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
   	add_child_autofree(manager)
   	manager.route_context_id = "stale"

   	assert_eq(manager.go_to_trade(), OK)
   	assert_eq(manager.route_context_id, "")


   func test_go_to_stores_changes_scene() -> void:
   	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
   	add_child_autofree(manager)

   	assert_eq(manager.go_to_stores(), OK)


   func test_go_to_trading_post_changes_scene() -> void:
   	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
   	add_child_autofree(manager)

   	assert_eq(manager.go_to_trading_post(), OK)


   func test_go_to_assign_equipment_sets_route_context_and_changes_scene_for_a_known_item() -> void:
   	GameSession.reset()
   	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
   	add_child_autofree(manager)

   	assert_eq(manager.go_to_assign_equipment("dagger_iron"), OK)
   	assert_eq(manager.route_context_id, "dagger_iron")


   func test_go_to_assign_equipment_rejects_an_unknown_item_id() -> void:
   	GameSession.reset()
   	var manager: Node = preload("res://scripts/autoload/game_manager.gd").new()
   	add_child_autofree(manager)
   	manager.route_context_id = "stale"

   	assert_eq(manager.go_to_assign_equipment("no_such_item"), ERR_INVALID_DATA)
   	assert_eq(manager.route_context_id, "")
   ```

   Match the exact bare-`GameManager`-instance style already used by the
   other `go_to_*` tests in this file — check the file for the established
   `preload(...).new()` + `add_child_autofree` idiom before adding these,
   and follow it rather than inventing a new one.

2. **Run the tests to verify they fail.**

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_manager.gd -gunit_test_name=go_to_trade -gexit
   ```

   (and `go_to_stores`, `go_to_trading_post`, `go_to_assign_equipment`).
   Expected: FAIL — `Nonexistent function 'go_to_trade'` (etc.).

3. **Implement.** In `scripts/autoload/game_manager.gd`, add next to
   `const GUILD_HALL_SCENE := "res://scenes/ui/guild_hall.tscn"`:

   ```gdscript
   const TRADE_SCENE := "res://scenes/ui/trade.tscn"
   const STORES_SCENE := "res://scenes/ui/stores.tscn"
   const TRADING_POST_SCENE := "res://scenes/ui/trading_post.tscn"
   const ASSIGN_EQUIPMENT_SCENE := "res://scenes/ui/assign_equipment.tscn"
   ```

   Add next to `go_to_guild_hall()`:

   ```gdscript
   func go_to_trade() -> Error:
   	_clear_detail_context()
   	return _change_scene(TRADE_SCENE)


   func go_to_stores() -> Error:
   	_clear_detail_context()
   	return _change_scene(STORES_SCENE)


   func go_to_trading_post() -> Error:
   	_clear_detail_context()
   	return _change_scene(TRADING_POST_SCENE)


   ## Mirrors go_to_unit_details()'s validate-then-route shape: an unknown item
   ## id clears the detail context and reports ERR_INVALID_DATA instead of
   ## routing to a screen with nothing to show.
   func go_to_assign_equipment(item_id: String) -> Error:
   	if GameSession.get_item_definition(item_id).is_empty():
   		_clear_detail_context()
   		return ERR_INVALID_DATA
   	route_context_id = item_id
   	unit_details_origin = ""
   	add_member_return_party_id = ""
   	return _change_scene(ASSIGN_EQUIPMENT_SCENE)
   ```

   Note: `_change_scene()` will fail (return non-`OK`, and `push_error`)
   until Tasks 12-15 create the four `.tscn` files this points at — that is
   expected at this point in the plan; these tests will only fully pass once
   every screen exists. Re-run them again after Task 15.

4. **Commit** only this task's files:

   ```bash
   git add scripts/autoload/game_manager.gd tests/unit/test_game_manager.gd
   git commit -m "feat: add GameManager routing for Trade, Stores, Trading Post, Assign Equipment"
   ```

## Milestone

`GameManager` exposes all four Trade-family routes with the id-validation
`go_to_assign_equipment` needs; the routing tests are expected to stay red
for scene-existence reasons only until Task 15, which is a known and
temporary intermediate state, not a bug in this task.
