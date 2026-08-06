# Task 7: Integration rewrite, regression sweep, manual verification, merge

## Objective

Rewrite the one integration test that drives a real click-through battle
victory (now harder, since the Goblin Camp fields two goblins against a
still-single-member starting party), confirm the whole suite and editor
import are clean, get manual sign-off, and merge back to `main`.

## Files

- Modify: `tests/unit/test_first_campaign_ui_flow.gd`

## Steps

### Integration test rewrite

1. `test_fresh_campaign_completes_the_full_game_loop_and_banks_the_reward`
   currently clicks the Warrior onto one adjacent tile and attacks once,
   assuming a single goblin. With the Goblin Camp now fielding two goblins
   (Task 4) and a single deployed party member acting once per round, one
   click sequence can no longer clear the site. Add
   `const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")`
   to the file, then replace the click sequence (from
   `var warrior_start: Vector2i = battlefield.grid.WARRIOR_START` through the
   three `_handle_tile_click` calls) with a small round loop that keeps
   attacking the nearest living goblin and ending turns until the site is
   clear:

   ```gdscript
   battlefield.grid._handle_tile_click(BattleControllerScript.PLAYER_START_POSITIONS[0])

   var rounds_remaining := 6
   while not battlefield.grid.is_battle_won() and rounds_remaining > 0:
       rounds_remaining -= 1
       var warrior = battlefield.grid.selected_unit
       if warrior == null:
           warrior = battlefield.grid.get_unit_at(BattleControllerScript.PLAYER_START_POSITIONS[0])
       var target = null
       for unit in battlefield.grid.units:
           if unit.side == BattleControllerScript.Side.ENEMY and unit.is_alive():
               target = unit
               break
       if target != null:
           var adjacent_tile: Vector2i = target.grid_position
           for candidate in battlefield.grid.grid.get_adjacent(target.grid_position):
               if battlefield.grid.get_unit_at(candidate) == null:
                   adjacent_tile = candidate
                   break
           battlefield.grid._handle_tile_click(warrior.grid_position)
           battlefield.grid._handle_tile_click(adjacent_tile)
           battlefield.grid._handle_tile_click(target.grid_position)
       if not battlefield.grid.is_battle_won():
           battlefield._on_end_turn_pressed()
           var settle_frames := 0
           while battlefield._enemy_turn_in_progress and settle_frames < 30:
               await get_tree().process_frame
               settle_frames += 1
   ```

   Keep `battlefield.grid.hit_roll = func() -> float: return 0.0` and
   `battlefield.grid.apply_super_power()` exactly as they are today (they
   run before this loop) — the super power's one-hit-kill damage still means
   at most one goblin dies per acted turn, which is why the loop exists.
   Everything after the loop (the `settle_frames` wait for
   `selected_encounter` to clear, and every assertion after it) is
   unchanged.
2. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_first_campaign_ui_flow -gexit
   ```

   Expected: green. If the loop's adjacency-tile search ever fails to find
   an open adjacent tile (only possible if goblins end up mutually
   surrounding each other, which the AI's reading-order tie-break makes
   unlikely on a 6x6 board with 2 enemies), increase `rounds_remaining`
   rather than reworking the search.
3. Commit:

   ```bash
   git add tests/unit/test_first_campaign_ui_flow.gd
   git commit -m "test: rewrite the campaign integration test for a two-goblin camp"
   ```

### Full regression sweep

4. Run the full suite and confirm every file is green, not just the ones
   this plan touched directly:

   ```bash
   make check
   ```
5. Grep for any straggling reference this plan's tasks may have missed:

   ```bash
   grep -rn "WARRIOR_START\|GOBLIN_START\|WARRIOR_COLOR\|GOBLIN_COLOR\|has_moved" scripts tests
   ```

   Expected: no matches. If any turn up, fix them and rerun `make check`.
6. Confirm the project still opens cleanly in the editor (catches scene/
   script wiring mistakes GUT alone won't, e.g. a broken `NodePath` in
   `battlefield.tscn`):

   ```bash
   godot --headless --path . --editor --quit
   ```
7. Run `git diff --check` against `main` to catch stray whitespace/conflict
   markers before manual verification.

### Manual verification

8. Run `make play`. Walk the full loop by hand:
   - Encampment → Buildings → Guild Hall: confirm "Guild Hall — Level 1" /
     "Party size: 4", upgrade is disabled with 0 gold.
   - Create a party, add a second member via Roster/Add Member, confirm a
     5th assignment attempt is refused once the party holds 4 (cap not yet
     raised).
   - Deploy the 2-member party, enter the Goblin Camp: confirm both party
     members appear on the battlefield in the left portrait panel, both
     goblins are visible on the board, WASD moves the selected unit, number
     keys 1/2 switch selection between the two portraits (and clicking a
     portrait does too), and moving onto a goblin's tile attacks instead of
     stepping onto it.
   - Win or retreat the battle; confirm the HUD's enemy health list tracks
     each living goblin and drops entries as they die.
9. Report the manual pass (or any deviation) to the user and wait for
   explicit sign-off before merging.

### Merge

10. Once approved:

    ```bash
    git checkout main
    git pull
    git merge feat/guild-hall-and-full-party-battles
    git branch -d feat/guild-hall-and-full-party-battles
    ```

    Do not push to `origin` or open a PR unless the user asks.

## Milestone

The full test suite is green end to end, the editor opens the project
without errors, the user has manually confirmed the Guild Hall and
full-party battlefield both work as designed, and the branch is merged into
`main`.
