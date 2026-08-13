# Step 6: Debug Menu Orc Scenario Update

## Overview

This step updates the Orc battle debug shortcut (`orc_outpost` scenario in `DebugScenarios`) to configure a party of 4 warriors facing 2 orcs in tactical combat.

---

## Setup Instructions

1. Check out `main` and pull the latest changes:
   ```bash
   git checkout main && git pull
   ```
2. Create and check out a new branch:
   ```bash
   git checkout -b feat/debug-menu-orc-scenario
   ```

---

## Test-Driven Development (TDD) Plan

### 1. Write Failing Tests (Red Phase)

Add unit tests in [`tests/unit/test_debug_scenarios.gd`](file:///home/ryan/play/fantasy-tactics/tests/unit/test_debug_scenarios.gd):

- **Test `orc_outpost` debug scenario configuration**:
  - Apply `DebugScenarios.apply("orc_outpost")`.
  - Assert selected party has 4 members (4 warriors).
  - Enter encounter and assert 2 orcs are spawned in combat.

Run tests to confirm failure:
```bash
godot --headless -s --path . addons/gut/gut_cmdln.gd -gselect=test_debug_scenarios.gd
```

### 2. Implementation (Green Phase)

1. **Modify [`scripts/debug/debug_scenarios.gd`](file:///home/ryan/play/fantasy-tactics/scripts/debug/debug_scenarios.gd)**:
   - Add helper `static func _create_four_warrior_party() -> bool:`:
     - Creates party, assigns initial warrior, recruits 3 extra warriors via `GameSession.recruit_adventurer()`, and assigns all 4 to the selected party.
   - Refactor `"orc_outpost"` match arm in `apply()`:
     ```gdscript
     "orc_outpost":
         return _deploy_at_orc_outpost()
     ```
   - Implement `_deploy_at_orc_outpost() -> bool`:
     - Creates 4-warrior party via `_create_four_warrior_party()`.
     - Pins `GameSession.enemy_composition_roll = func(_opts: int) -> int: return 1` (Orcs option in Tier 2 composition table).
     - Pins `GameSession.enemy_count_roll = func(_min: int, _max: int) -> int: return 2` (2 Orcs).
     - Departs selected party and sets deployed position to `orc_outpost` position.

---

## Concrete Verifiable Milestone

Run the test suite:
```bash
make check
```
All GUT unit tests pass cleanly.

---

## Manual Verification

1. Launch `make play`.
2. Open debug menu (`~` key or debug shortcut).
3. Select `Orc Outpost` scenario.
4. Verify battlefield opens with 4 player warriors and 2 enemy orcs.
