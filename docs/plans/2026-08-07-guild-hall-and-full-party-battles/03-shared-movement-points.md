# Task 3: Shared movement-points budget

## Objective

Replace `Unit.has_moved: bool` with a spendable `Unit.moves_remaining: int`
so a unit can split its move across multiple clicks/steps in one turn
instead of moving exactly once (design.md §3 "Movement — shared points
budget"). This task lands the budget mechanics only, on the existing
single-player-unit battlefield — full-party fielding is Task 4, and WASD
input is Task 5. Land this first because Tasks 4-6 all build on
`moves_remaining`.

## Files

- Modify: `scripts/battle/grid.gd`, `tests/unit/test_grid.gd`
- Modify: `scripts/battle/unit.gd`
- Modify: `scripts/battle/battle_controller.gd`,
  `tests/unit/test_battle_controller.gd`
- Modify: `scripts/battle/battlefield.gd`

## Steps

### Grid: real path-distance, not just reachability

1. Add failing tests to `test_grid.gd` for a new `get_tile_distances(start,
   move_range, is_blocked) -> Dictionary` (mirrors `get_tiles_in_range`'s
   BFS, but returns `{Vector2i: int}` step-distances instead of just an
   `Array`): one tile away costs `1`, two tiles away costs `2`, the start
   tile itself is absent from the result, and a tile beyond `move_range` is
   absent. Add one more test proving a detour around a blocked tile costs
   more than the straight-line distance: from `(2, 2)` with `(3, 2)` blocked
   and `move_range = 4`, `(4, 2)` costs `4` (not the Manhattan `2`), because
   every path there must go around the block.
2. Run `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_grid
   -gexit`. Expected: fails, `get_tile_distances` does not exist.
3. Implement `get_tile_distances()` in `grid.gd` as a level-by-level BFS
   identical in structure to `get_tiles_in_range()`, but keyed by distance:

   ```gdscript
   func get_tile_distances(start: Vector2i, move_range: int, is_blocked: Callable) -> Dictionary:
       var distances := {start: 0}
       var frontier: Array[Vector2i] = [start]

       for step in move_range:
           var next_frontier: Array[Vector2i] = []
           for pos in frontier:
               for neighbor in get_adjacent(pos):
                   if distances.has(neighbor):
                       continue
                   if is_blocked.call(neighbor):
                       continue
                   distances[neighbor] = step + 1
                   next_frontier.append(neighbor)
           frontier = next_frontier

       distances.erase(start)
       return distances
   ```

   Rerun `test_grid` green.

### Unit: the budget field

4. In `unit.gd`, replace `var has_moved: bool = false` with
   `var moves_remaining: int`, and set it to `p_move_range` in `_init()`
   (alongside the existing `move_range = p_move_range` line). There is no
   dedicated `test_unit.gd`; Unit behavior is exercised indirectly through
   `test_battle_controller.gd` below.

### Battle controller: spend the budget instead of a flag

5. Add a failing test to `test_battle_controller.gd` replacing
   `test_unit_cannot_move_a_second_time_in_the_same_turn` (delete it — the
   all-or-nothing behavior it tested is intentionally being replaced) with
   two new tests:
   - `test_unit_can_click_move_multiple_times_within_the_same_turn_while_points_remain`:
     a `move_range = 3` unit at `(1, 1)` moves to `(2, 1)` (spends 1), then
     moves again to `(4, 1)` (spends the remaining 2); both moves succeed,
     final position `(4, 1)`, `moves_remaining == 0`.
   - `test_unit_cannot_move_once_its_points_budget_is_exhausted`: the same
     unit, after spending its full budget in one move to `(4, 1)`, fails a
     further move to `(5, 1)`.
6. Update the two existing `has_moved` assertions in
   `test_end_turn_switches_the_active_side_and_resets_movement` to
   `assert_eq(enemy_unit.moves_remaining, enemy_unit.move_range, ...)` and
   `assert_eq(player_unit.moves_remaining, player_unit.move_range, ...)`
   respectively (same intent — movement is fresh on the newly active side —
   expressed against the new field).
7. Run `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller
   -gexit`. Expected: the new/changed tests fail; everything else (unrelated
   to `has_moved`) still passes.
8. Implement in `battle_controller.gd`:
   - `get_legal_moves(unit)`: replace `if unit.has_moved: return []` with
     `if unit.moves_remaining <= 0: return []`, and pass
     `unit.moves_remaining` (not `unit.move_range`) as the range argument to
     `grid.get_tiles_in_range(...)`.
   - `try_move_selected_unit(target)`: after the existing legality check,
     look up the real cost via `grid.get_tile_distances(selected_unit.grid_position,
     selected_unit.moves_remaining, is_blocked)` (same `is_blocked` closure
     `get_legal_moves` uses) and do
     `selected_unit.moves_remaining -= distances[target]` instead of setting
     `has_moved = true`.
   - `end_turn()`: replace `unit.has_moved = false` with
     `unit.moves_remaining = unit.move_range`.
   - `_select_unit_after_action()`: replace
     `if selected_unit.has_moved and selected_unit.has_acted:` with
     `if selected_unit.moves_remaining <= 0 and selected_unit.has_acted:`.
   - `apply_super_power()`: alongside `unit.move_range =
     SUPER_POWER_MOVE_RANGE`, also set
     `unit.moves_remaining = SUPER_POWER_MOVE_RANGE`, so a mid-battle debug
     super power isn't capped by whatever budget was already spent that
     turn.
9. In `battlefield.gd`'s `_on_board_changed()`, replace
   `selected_unit.has_moved and selected_unit.has_acted` with
   `selected_unit.moves_remaining <= 0 and selected_unit.has_acted`, and
   `elif selected_unit.has_moved:` with
   `elif selected_unit.moves_remaining <= 0:`. (Same hint copy, same
   `battle.hint.already_moved`/`battle.hint.turn_complete` keys — only the
   underlying condition changes.)
10. Rerun `test_battle_controller` and the full suite (`make check`).
    Expected: green — this task should not change any other test's outcome.
11. Commit:

    ```bash
    git add scripts/battle/grid.gd tests/unit/test_grid.gd \
      scripts/battle/unit.gd scripts/battle/battle_controller.gd \
      tests/unit/test_battle_controller.gd scripts/battle/battlefield.gd
    git commit -m "feat: replace has_moved with a spendable movement-points budget"
    ```

## Milestone

A unit can split its move across multiple same-turn clicks as long as
points remain, and the exact points spent equal the real (block-aware) path
distance walked — provable purely through `battle_controller.gd`, with no
UI changes yet.
