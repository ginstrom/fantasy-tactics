# Step 3: Action Modes and Action Bar UI

## Objective

Add a dedicated action button bar at the bottom of the battle screen with Move and Attack buttons, button-only action-mode state management, and active-mode visual indicators. Do not add Move/Attack keyboard shortcuts; preserve existing WASD direct-step movement and `1`–`5` unit selection.

## Setup

```bash
git checkout main && git pull
git checkout -b feat/battle-action-modes-and-action-bar
```

Read:
- `docs/battle-screen.md`
- `scenes/battle/battlefield.tscn`
- `scripts/battle/battlefield.gd`
- `scripts/battle/battle_controller.gd`
- `tests/unit/test_battlefield.gd`
- `tests/unit/test_battle_controller.gd`

## Red / Green Work

1. In `tests/unit/test_battle_controller.gd` and `tests/unit/test_battlefield.gd`, add failing tests:
   - `BattleController` has `action_mode` (`ActionMode.CONTEXTUAL`, `ActionMode.MOVE`, `ActionMode.ATTACK`).
   - Calling `set_action_mode(ActionMode.MOVE)` or clicking `MoveButton` sets mode to `MOVE`; no `KEY_M` input changes mode.
   - Calling `set_action_mode(ActionMode.ATTACK)` or clicking `AttackButton` sets mode to `ATTACK`; no `KEY_A` input changes mode.
   - Existing `KEY_A` remains the WASD-left direct-step control, and `KEY_W`, `KEY_S`, `KEY_D`, and `1`–`5` retain their existing behavior.
   - In `MOVE` mode: clicking a valid move tile moves the unit; clicking an enemy does not attack, leaves state unchanged, and emits move-mode feedback.
   - In `ATTACK` mode: clicking an enemy attacks (with auto move-and-attack); clicking an empty tile does not move, leaves state unchanged, and emits attack-mode feedback.
   - Selecting a player unit, returning from the enemy turn, and resolving a move/attack each reset to `CONTEXTUAL`; contextual preserves the current click behavior.
   - `Battlefield` UI includes an `ActionBar` container containing `MoveButton` (`Move`) and `AttackButton` (`Attack`).
   - Clicking `MoveButton` activates `MOVE` mode and visually highlights the move button.
   - Clicking `AttackButton` activates `ATTACK` mode and visually highlights the attack button.
   - Selecting a unit or starting a turn sets action mode to `CONTEXTUAL`.
   - Buttons are disabled when the selected unit lacks sufficient AP or input is locked.
2. Run focused tests:
   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield.gd -gexit
   ```
   Confirm new tests fail.
3. In `scripts/battle/battle_controller.gd`:
   - Declare enum `ActionMode { CONTEXTUAL, MOVE, ATTACK }`.
   - Add property `action_mode: int = ActionMode.ATTACK` (or signal `action_mode_changed(mode)`).
   - Add method `set_action_mode(mode: int) -> void`.
   - In `_handle_tile_click()`, respect current `action_mode`.
4. In `scenes/battle/battlefield.tscn` and `scripts/battle/battlefield.gd`:
   - Add `ActionBar` container with `MoveButton` (`Move`) and `AttackButton` (`Attack`).
   - Connect buttons to `grid.set_action_mode(...)`.
   - Connect `action_mode_changed` signal to update button toggle/highlight states.
   - Integrate with existing Item actions (`PotionOption`, `TransferItemOption`) and `EndTurnButton`.
5. Add translation strings to `translations/en.tres` (e.g. `"battle.action.move": "Move"`, `"battle.action.attack": "Attack"`, and mode-feedback copy).
6. Rerun both focused files and `make check`:
   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield.gd -gexit
   make check
   ```

## Milestone and Manual Check

- `make check` passes completely.
- Manual check using `make play`: Select a party member. Click Move; verify its button is highlighted and clicking empty tiles moves the unit. Click Attack; verify its button is highlighted and clicking enemies triggers attack (with auto move-and-attack). Verify `A` still steps the selected unit left when legal, and neither `M` nor `A` switches an action mode.

## Handoff

After user sign-off:
1. Run `godot --headless --path . --editor --quit` and `git diff --check`.
2. Commit `feat: implement battle action modes and bottom action bar`.
3. Merge `feat/battle-action-modes-and-action-bar` locally into `main` and delete the branch. Do not push.
