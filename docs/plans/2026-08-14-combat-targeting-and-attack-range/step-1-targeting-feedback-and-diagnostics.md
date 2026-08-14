# Step 1: Combat Targeting Feedback and Failure Diagnostics

## Overview

Currently, when a player has a unit selected and clicks on an enemy that cannot be attacked (because it is out of range, blocked by line-of-sight, the unit lacks the 3 AP required for a basic attack, or the unit is paralyzed), `BattleController._handle_tile_click` silently sets `inspected_unit = clicked_unit` without providing any explanation of why no attack occurred.

This step introduces targeting failure diagnosis in `BattleController`, stores/emits the failure reason, and updates `Battlefield`'s status label to display a localized, player-facing feedback message.

---

## Setup Instructions

1. Check out `main` and pull the latest changes:
   ```bash
   git checkout main && git pull
   ```
2. Create and check out the feature branch:
   ```bash
   git checkout -b feat/combat-targeting-feedback
   ```

---

## Test-Driven Development (TDD) Plan

### 1. Write Failing Tests (Red Phase)

Add unit tests in [`tests/unit/test_battle_controller.gd`](file:///home/ryan/play/fantasy-tactics/tests/unit/test_battle_controller.gd) and [`tests/unit/test_battlefield.gd`](file:///home/ryan/play/fantasy-tactics/tests/unit/test_battlefield.gd):

- **Test `get_targeting_failure_reason(attacker, target)`**:
  - Returns `""` if target is legal.
  - Returns `"paralyzed"` when attacker has the paralyzed status.
  - Returns `"insufficient_ap"` when attacker has less than `BASIC_ATTACK_ACTION_POINT_COST` (3 AP).
  - Returns `"out_of_range"` when target is beyond `attack_max_range` or closer than `attack_min_range`.
  - Returns `"line_of_sight_blocked"` when an intermediate unit blocks line of sight.
- **Test `BattleController._handle_tile_click` stores `last_targeting_failure`**:
  - When clicking an invalid enemy target, `last_targeting_failure` is populated with `{"reason": String, "attacker": Unit, "target": Unit}` and `board_changed` is emitted.
- **Test `Battlefield` status updates on targeting failure**:
  - When `last_targeting_failure` is present, `status.text` is updated to the corresponding localized string (`battle.feedback.out_of_range`, `battle.feedback.not_enough_ap`, `battle.feedback.line_of_sight_blocked`, etc.).
- **Test localization keys in [`translations/en.tres`](file:///home/ryan/play/fantasy-tactics/translations/en.tres)**:
  - Verify all new feedback translation keys resolve properly.

Run tests to confirm failure:
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd,test_battlefield.gd -gexit
```

### 2. Implementation (Green Phase)

1. **Update [`translations/en.tres`](file:///home/ryan/play/fantasy-tactics/translations/en.tres)**:
   - Add translation strings:
     - `"battle.feedback.out_of_range": "Target is out of range."`
     - `"battle.feedback.not_enough_ap": "Not enough Action Points to attack (requires %d AP)."`
     - `"battle.feedback.line_of_sight_blocked": "Line of sight to target is blocked."`
     - `"battle.feedback.paralyzed": "%s is paralyzed and cannot act."`
2. **Update [`scripts/battle/battle_controller.gd`](file:///home/ryan/play/fantasy-tactics/scripts/battle/battle_controller.gd)**:
   - Add `var last_targeting_failure: Dictionary = {}`.
   - Add `func get_targeting_failure_reason(attacker, target) -> String`:
     - Checks paralyzed, AP < 3, distance < min or > max, line of sight.
   - In `_handle_tile_click(tile_pos)`:
     - Clear `last_targeting_failure` at start of click processing.
     - When `clicked_unit != null and clicked_unit.side != active_side`:
       - If `try_attack_selected_unit(tile_pos)` succeeds: clear failure and proceed.
       - Else if `selected_unit != null`:
         - Determine failure reason using `get_targeting_failure_reason(selected_unit, clicked_unit)`.
         - Set `last_targeting_failure = {"reason": reason, "attacker": selected_unit, "target": clicked_unit}`.
         - Set inspected unit, update highlights, and emit `board_changed`.
3. **Update [`scripts/battle/battlefield.gd`](file:///home/ryan/play/fantasy-tactics/scripts/battle/battlefield.gd)**:
   - In `_on_board_changed()`:
     - If `grid.last_targeting_failure` is not empty, set `status.text = _describe_targeting_failure(grid.last_targeting_failure)`.
     - Implement `_describe_targeting_failure(failure: Dictionary) -> String` using localized strings.

---

## Concrete Verifiable Milestone

Run the full test suite:
```bash
make check
```
All GUT unit tests pass cleanly with 0 errors.

---

## Manual Verification

1. Run the game:
   ```bash
   make play
   ```
2. Open debug menu (F9) -> select `goblin_camp`.
3. Select your unit (Warrior or recruit a Scout) and click on an out-of-range Goblin at (5, 5).
4. Verify that the bottom status line displays: `"Target is out of range."`
5. Move 4 tiles so AP drops to 2, click an enemy, and verify status displays: `"Not enough Action Points to attack (requires 3 AP)."`

---

## Local Branch Merge

After user sign-off:
```bash
git checkout main
git merge feat/combat-targeting-feedback
git branch -d feat/combat-targeting-feedback
```
