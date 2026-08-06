# Task 5: WASD movement and number-key selection

## Objective

Add keyboard input: WASD steps the selected unit one tile (attacking instead
of moving onto an enemy tile), and number keys 1-5 select a living party
member by its party-order slot (design.md §3 "Selection", "Movement —
shared points budget"'s WASD bullet). Builds on Task 3's
`moves_remaining` and Task 4's `_player_adventurer_ids`.

## Files

- Modify: `scripts/battle/battle_controller.gd`,
  `tests/unit/test_battle_controller.gd`

## Steps

1. Add failing tests to `test_battle_controller.gd` for the new pure-logic
   methods (built directly on a `_make_controller` instance, same style as
   the existing move/attack tests):
   - `test_wasd_step_moves_one_tile_and_spends_one_movement_point`: a
     `move_range = 3` unit steps `Vector2i.RIGHT`; position moves by one
     tile, `moves_remaining` drops by exactly `1`.
   - `test_wasd_step_is_rejected_once_movement_points_are_exhausted`: a
     `move_range = 1` unit steps once (succeeds), a second step in the same
     direction fails and position is unchanged.
   - `test_wasd_step_onto_an_enemy_tile_attacks_instead_of_moving`: an
     attacker adjacent to a defender steps toward it; the step succeeds as
     an attack (`defender.health` drops, `attacker.has_acted == true`,
     `attacker.grid_position` unchanged).
   - `test_wasd_step_is_rejected_while_input_is_locked`: `input_locked =
     true`, a step fails and position is unchanged.
   - `test_wasd_step_is_rejected_for_a_unit_on_the_inactive_side`: a
     `Side.ENEMY` unit steps while `active_side = Side.PLAYER`; fails,
     position unchanged (mirrors the existing
     `test_move_is_rejected_for_a_unit_on_the_inactive_side`).
   - `test_wasd_step_is_rejected_for_a_target_outside_the_grid`: a unit at
     `(0, 0)` on a controller `_make_controller(6, 6)` steps `Vector2i.UP`;
     fails, position unchanged.
   - `test_wasd_step_and_a_click_move_share_the_same_movement_budget_in_one_turn`:
     a `move_range = 3` unit at `(1, 1)` steps `Vector2i.RIGHT` via
     `try_step_selected_unit` (now at `(2, 1)`, `moves_remaining == 2`), then
     `try_move_selected_unit(Vector2i(4, 1))` (2 more tiles, the full
     remaining budget) — both succeed, final position `(4, 1)`,
     `moves_remaining == 0`; a further step in either form then fails. This
     is the design doc's documented "WASD step and a multi-tile click within
     the same unit turn" budget-sharing case.
   - `test_select_unit_by_adventurer_id_selects_a_living_player_unit`: a
     `Side.PLAYER` unit constructed with `adventurer_id = "warrior_001"` is
     selected by that id; `controller.selected_unit` becomes that unit.
   - `test_select_unit_by_adventurer_id_is_a_no_op_for_a_defeated_or_unknown_member`:
     a unit with `health = 0` cannot be selected by its id; neither can an
     id with no matching unit at all.
   - `test_select_unit_by_adventurer_id_is_a_no_op_during_the_enemy_turn_or_while_locked`:
     `active_side = Side.ENEMY` blocks selection; back on `Side.PLAYER`,
     `input_locked = true` also blocks it.
   - `test_select_unit_by_number_key_maps_one_based_keys_to_party_order`: set
     `controller._player_adventurer_ids = ["warrior_001", "warrior_002"]`
     directly (mirrors how existing tests set `controller.units` directly
     rather than going through `_ready()`), with matching `units` for each
     id; key `1` selects the first, key `2` the second.
   - `test_select_unit_by_number_key_is_a_no_op_for_a_slot_beyond_the_fielded_party`:
     with only one id in `_player_adventurer_ids`, key `5` is a no-op.
2. Add two failing input-wiring tests proving `_unhandled_input` actually
   calls the new methods (same pattern as the existing
   `test_locked_input_is_ignored_by_handle_tile_click`, but driving a real
   `InputEventKey`): instantiate `BattlefieldScene`, select the spawned
   Warrior, build `var key_event := InputEventKey.new(); key_event.pressed =
   true; key_event.keycode = KEY_D`, call
   `battlefield.grid._unhandled_input(key_event)`, and assert the Warrior
   moved one tile right of `PLAYER_START_POSITIONS[0]`. Do the same for
   `KEY_2` selecting a second fielded party member (create/assign a second
   member first, as in Task 4's fielding test).
3. Run `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller
   -gexit`. Expected: fails, none of the new methods exist.
4. Implement in `battle_controller.gd`:

   ```gdscript
   func try_step_selected_unit(direction: Vector2i) -> bool:
       if input_locked:
           return false
       if selected_unit == null or not selected_unit.is_alive():
           return false
       if selected_unit.side != active_side:
           return false
       var target: Vector2i = selected_unit.grid_position + direction
       if not grid.is_in_bounds(target):
           return false
       var occupant = get_unit_at(target)
       if occupant != null:
           if occupant.side == selected_unit.side:
               return false
           return try_attack_selected_unit(target)
       if selected_unit.moves_remaining <= 0:
           return false
       selected_unit.grid_position = target
       selected_unit.moves_remaining -= 1
       last_attack_result = {}
       return true


   func select_unit_by_adventurer_id(adventurer_id: String) -> bool:
       if input_locked or active_side != Side.PLAYER:
           return false
       var unit = _get_unit_by_adventurer_id(adventurer_id)
       if unit == null or not unit.is_alive():
           return false
       _select_unit(unit)
       return true


   func select_unit_by_number_key(key_number: int) -> bool:
       var slot_index := key_number - 1
       if slot_index < 0 or slot_index >= _player_adventurer_ids.size():
           return false
       return select_unit_by_adventurer_id(_player_adventurer_ids[slot_index])


   func _get_unit_by_adventurer_id(adventurer_id: String):
       for unit in units:
           if unit.adventurer_id == adventurer_id:
               return unit
       return null
   ```

   Split the existing `_unhandled_input(event)` into a mouse branch (the
   current body, unchanged) and a new key branch:

   ```gdscript
   const MOVE_KEY_DIRECTIONS := {
       KEY_W: Vector2i.UP, KEY_A: Vector2i.LEFT, KEY_S: Vector2i.DOWN, KEY_D: Vector2i.RIGHT,
   }
   const NUMBER_KEYS := {KEY_1: 1, KEY_2: 2, KEY_3: 3, KEY_4: 4, KEY_5: 5}


   func _unhandled_input(event: InputEvent) -> void:
       if event is InputEventMouseButton:
           _handle_mouse_input(event)
       elif event is InputEventKey:
           _handle_key_input(event)


   func _handle_mouse_input(event: InputEventMouseButton) -> void:
       if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
           return
       var tile_pos := _to_grid_position(get_local_mouse_position())
       if not grid.is_in_bounds(tile_pos):
           return
       get_viewport().set_input_as_handled()
       _handle_tile_click(tile_pos)


   func _handle_key_input(event: InputEventKey) -> void:
       if not event.pressed or event.echo:
           return
       if MOVE_KEY_DIRECTIONS.has(event.keycode):
           get_viewport().set_input_as_handled()
           if try_step_selected_unit(MOVE_KEY_DIRECTIONS[event.keycode]):
               _draw_units()
               _select_unit_after_action()
           return
       if NUMBER_KEYS.has(event.keycode):
           get_viewport().set_input_as_handled()
           select_unit_by_number_key(NUMBER_KEYS[event.keycode])
   ```

   (`select_unit_by_number_key`/`select_unit_by_adventurer_id` already redraw
   highlights and emit `board_changed` via `_select_unit()`, so the number-key
   branch needs no extra redraw call.)
5. Rerun `test_battle_controller` green, then `make check` for the full
   suite.
6. Commit:

   ```bash
   git add scripts/battle/battle_controller.gd tests/unit/test_battle_controller.gd
   git commit -m "feat: add WASD movement and number-key party selection"
   ```

## Milestone

During the player's turn, WASD steps the selected unit (attacking instead of
moving onto an enemy), and keys 1-5 select any living, fielded party member
— all gated identically to the existing mouse rules (player turn only, never
while `input_locked`) and provable without any portrait UI yet.
