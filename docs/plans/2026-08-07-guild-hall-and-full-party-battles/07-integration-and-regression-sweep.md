# Task 7: Regression sweep, manual verification, merge

## Objective

Confirm the whole suite and editor import are clean, get manual sign-off,
and merge back to `main`.

**Update:** the integration-test rewrite this task originally owned
(`test_fresh_campaign_completes_the_full_game_loop_and_banks_the_reward`,
which used to win the Goblin Camp battle by killing a single goblin) was
already done as an in-scope straggler fix during Task 4 — that task's own
regression sweep found the test broken by the two-goblin Goblin Camp and
fixed it for real (a dynamic round loop that hunts down and kills whichever
goblin survives, driven through the real `_handle_tile_click` path, not a
hardcoded two-click sequence). It was reviewed and approved as part of
Task 4. Step 1 below is now a verification step, not a rewrite — do not
redo it; only re-run it to confirm it's still green after every later
task's changes.

## Files

- Modify: `docs/dev/testing.md` (a stale example this plan's rename left
  behind — see step 2)

## Steps

### Integration test verification

1. Confirm `test_fresh_campaign_completes_the_full_game_loop_and_banks_the_reward`
   (in `tests/unit/test_first_campaign_ui_flow.gd`) is still green after
   every task in this plan has landed:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_first_campaign_ui_flow -gexit
   ```

   Expected: green. If it now fails (e.g. a later task changed
   `battle_controller.gd`'s click/select flow in a way this test's dynamic
   goblin-hunting loop didn't anticipate), fix the test to match current
   behavior rather than reverting production code — the test's job is to
   prove the real end-to-end loop still works, not to pin down one specific
   implementation.

### Full regression sweep

2. Task 4's reviewer flagged that `docs/dev/testing.md` still shows an
   example using `battlefield.grid.WARRIOR_START` / `battlefield.grid.GOBLIN_START`,
   both removed by this plan's fielding rework (Task 4). Read that file's
   example (around the `WARRIOR_START`/`GOBLIN_START` reference), update it
   to use `BattleControllerScript.PLAYER_START_POSITIONS[0]` /
   `BattleControllerScript.ENEMY_START_POSITIONS[0]` instead (matching how
   the rewritten tests reference them), and commit it on its own:

   ```bash
   git add docs/dev/testing.md
   git commit -m "docs: fix stale WARRIOR_START/GOBLIN_START example in testing.md"
   ```
3. Run the full suite and confirm every file is green, not just the ones
   this plan touched directly:

   ```bash
   make check
   ```
4. Grep for any straggling reference this plan's tasks may have missed:

   ```bash
   grep -rn "WARRIOR_START\|GOBLIN_START\|WARRIOR_COLOR\|GOBLIN_COLOR\|has_moved" scripts tests docs
   ```

   Expected: no matches. If any turn up, fix them and rerun `make check`.
5. Confirm the project still opens cleanly in the editor (catches scene/
   script wiring mistakes GUT alone won't, e.g. a broken `NodePath` in
   `battlefield.tscn`):

   ```bash
   godot --headless --path . --editor --quit
   ```
6. Run `git diff --check` against `main` to catch stray whitespace/conflict
   markers before manual verification.

### Manual verification

7. Run `make play`. Walk the full loop by hand:
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
8. Report the manual pass (or any deviation) to the user and wait for
   explicit sign-off before merging.

### Merge

9. Once approved:

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
