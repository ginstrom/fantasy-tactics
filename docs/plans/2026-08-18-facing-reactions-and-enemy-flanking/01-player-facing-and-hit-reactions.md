# Step 1: Player Facing Input and Hit Reactions

**Branch:** `feat/player-facing-reactions`  
**Depends on:** local `main` at the start of this step  
**Milestone:** A selected player unit can right-click to turn at zero AP, and a defender turns toward only its first landed attacker until the next player round.

## Files

- Modify: `scripts/battle/unit.gd`
- Modify: `scripts/battle/battle_controller.gd`
- Modify: `tests/unit/test_battle_controller.gd`
- Manual evidence: a `make play` battle and, if useful, `make screenshots`

## Setup

```bash
git status --short --branch
git checkout main && git pull
git checkout -b feat/player-facing-reactions
make check
```

Expected: clean passing baseline apart from the pre-existing, user-owned `docs/designs/combat-system.md` edit. Do not stage that file.

## TDD tasks

### Task 1: Define the free-facing action contract

**Files:** Modify `tests/unit/test_battle_controller.gd`, then `scripts/battle/battle_controller.gd`.

1. Write failing tests for a `try_face_selected_unit(direction: Vector2i) -> bool` controller action:
   - player at `(2, 2)`, 0 AP, facing right; `try_face_selected_unit(Vector2i.UP)` returns true, faces up, and leaves AP at 0;
   - a diagonal vector uses `Unit.set_facing()`’s existing primary-axis normalization;
   - zero direction, no selection, enemy turn, selected enemy, dead selection, or locked input returns false and preserves facing/AP;
   - a successful turn leaves `last_attack_result`, `last_targeting_failure`, and `action_mode` unchanged.
2. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gunit_test_name=face_selected_unit -gexit
   ```

   Expected: FAIL because the action does not exist.
3. Implement the smallest controller method. It must check the same player-input authority as a non-attacking player action, reject `Vector2i.ZERO`, call `selected_unit.set_facing(direction)`, and perform no AP or action-mode mutation.
4. Re-run the focused command. Expected: PASS.

### Task 2: Route right-click into the free action

**Files:** Modify `tests/unit/test_battle_controller.gd`, then `scripts/battle/battle_controller.gd: _handle_mouse_input()`.

1. Add failing synthetic `InputEventMouseButton` tests using the existing in-tree battlefield/controller setup:
   - right-click an in-bounds tile north of the selected player: facing becomes up, AP and action mode are unchanged, and input is handled;
   - right-click a diagonal target proves primary-axis normalization;
   - right-click the selected unit’s own tile, during enemy turn, or while locked leaves all state unchanged;
   - left-click selection/move/attack tests continue to exercise their original behavior.
2. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gunit_test_name=right_click -gexit
   ```

   Expected: FAIL because `_handle_mouse_input()` ignores every non-left button.
3. Add a right-button branch before the left-click branch. Convert the click with the existing local-coordinate/grid conversion; derive `tile_pos - selected_unit.grid_position`; call `try_face_selected_unit`; only when it succeeds, mark input handled, redraw units, and emit `board_changed` so the facing pointer and info panel refresh. Do not introduce an `InputMap` action or alter `MOVE_KEY_DIRECTIONS`.
4. Re-run the focused command and the whole controller file:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd -gexit
   ```

   Expected: PASS.

### Task 3: Model and enforce the once-per-round hit reaction

**Files:** Modify `tests/unit/test_battle_controller.gd`, then `scripts/battle/unit.gd` and `scripts/battle/battle_controller.gd`.

1. Add failing deterministic attack tests (inject `hit_roll = func() -> float: return 0.0` and a non-critical roll):
   - defender facing up is hit from the right; it ends facing right and records that it has consumed its automatic reaction;
   - a second landed attack from below in the same round damages normally but leaves the defender facing right;
   - call `end_turn()` twice to start the next player round, attack from below, and assert the defender now faces down;
   - a miss neither turns the defender nor consumes the reaction;
   - an attack that defeats/removes the defender does not break resolution or the next round’s reset.
2. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gunit_test_name=facing_reaction -gexit
   ```

   Expected: FAIL because `Unit` has no per-round reaction state and hit resolution never turns defenders.
3. Add `var has_auto_faced_this_round: bool = false` to `Unit`. In `try_attack_selected_unit()`, after a hit lands and before result emission, if the defender is alive and has not reacted, call `target.set_facing(selected_unit.grid_position - target.grid_position)` and set the flag. Add a small controller reset helper that clears this flag for living units, invoked only when `end_turn()` changes `active_side` back to `Side.PLAYER`; retain the existing status-expiry timing.
4. Re-run the focused test, then all controller tests. Expected: PASS.

### Task 4: Full regression and manual sign-off

1. Run:

   ```bash
   make check
   git diff --check
   ```

   Expected: all tests pass; no whitespace errors.
2. Manual verification:
   - Run `make play`, open **FN+F9 → Goblin Camp Battle**, and select a player unit.
   - Right-click above, beside, and diagonally from it. Confirm the pointer changes direction, AP does not change, and WASD still moves (`A` remains move-left).
   - Let two enemies strike the same player from different directions in one enemy turn. Confirm the first landed hit turns the player toward its attacker and the second does not turn it again.
   - End/advance through the next round, take a landed hit from a different direction, and confirm the reaction is available again.
   - Optional visual capture: `make screenshots`; inspect the Battlefield image for the changed pointer.
3. Ask the user for manual sign-off before merging.

## Commit and local merge (only after sign-off)

```bash
git status --short
git add scripts/battle/unit.gd scripts/battle/battle_controller.gd tests/unit/test_battle_controller.gd
git diff --cached --check
git commit -m "feat(combat): add player facing and hit reactions"
git checkout main
git merge feat/player-facing-reactions
git branch -d feat/player-facing-reactions
```

Do not push or open a PR.
