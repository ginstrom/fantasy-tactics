# Step 6: Example Scenarios, Developer Documentation & Verification

## Overview

This final step adds a rich set of production-ready example debug scenarios to [`config/debug_scenarios.json`](file:///home/ryan/play/fantasy-tactics/config/debug_scenarios.json), updates developer documentation in [`docs/dev/running-the-game.md`](file:///home/ryan/play/fantasy-tactics/docs/dev/running-the-game.md) and [`README.md`](file:///home/ryan/play/fantasy-tactics/README.md), and conducts end-to-end regression validation.

---

## Setup Instructions

1. Check out `main` and pull the latest changes:
   ```bash
   git checkout main && git pull
   ```
2. Create and check out the feature branch:
   ```bash
   git checkout -b feat/debug-menu-docs-and-examples
   ```

---

## Test-Driven Development (TDD) Plan

### 1. Write Failing Tests (Red Phase)

Add unit tests in [`tests/unit/test_debug_scenarios.gd`](file:///home/ryan/play/fantasy-tactics/tests/unit/test_debug_scenarios.gd) and [`tests/unit/test_localization.gd`](file:///home/ryan/play/fantasy-tactics/tests/unit/test_localization.gd):

- **Test New Example Scenarios**:
  - `advanced_encampment`: Tests that all buildings are upgraded to their maximum tiers with active workshop jobs and full stores.
  - `archer_skirmish`: Tests a combat scenario fielding a player Scout and Warrior against enemy Goblin Archers with bows at `[5, 3]` and `[5, 5]`.
  - `veteran_party`: Tests Level 3 player units with assigned perks and steel weapons.
- **Test Localization Keys**:
  - Verify all new scenario display name keys resolve cleanly in `translations/en.tres`.

Run tests to confirm failure:
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_debug_scenarios.gd,test_localization.gd -gexit
```

---

### 2. Implementation (Green Phase)

1. **Add Example Scenarios to [`config/debug_scenarios.json`](file:///home/ryan/play/fantasy-tactics/config/debug_scenarios.json)**:
   - **`advanced_encampment`** (Category: `"Encampment"`):
     - `guild_hall_level`: 2, `blacksmith_level`: 3, `alchemy_workshop_level`: 2, `runic_workshop_level`: 2, `has_trading_post`: true, `shop_level`: 2.
     - Active crafting jobs for steel weapons and healing potions.
     - 1,000 gold and banked gear.
   - **`archer_skirmish`** (Category: `"Combat"`):
     - Target: `battlefield`.
     - 1 Warrior and 1 Scout vs 2 Goblin Archers (equipped with `shortbow_iron`, range 1–3) and 1 Goblin frontline.
   - **`veteran_party`** (Category: `"Campaign"`):
     - Target: `roster`.
     - 4 Level 3 adventurers with allocated skill points, perks, sharpened weapons, and chainmail armor.
2. **Update [`translations/en.tres`](file:///home/ryan/play/fantasy-tactics/translations/en.tres)**:
   - Add localized names and category headers.
3. **Update [`docs/dev/running-the-game.md`](file:///home/ryan/play/fantasy-tactics/docs/dev/running-the-game.md)**:
   - Document how to open the F9 menu, trigger scenarios, and hot-reload.
   - Add an "Authoring Debug Scenarios" reference guide explaining the JSON schema properties (`scene`, `buildings`, `stores`, `units`, `parties`, `battle`).
4. **Update [`README.md`](file:///home/ryan/play/fantasy-tactics/README.md)**:
   - Update mentions of debug scenarios to reference `config/debug_scenarios.json`.

---

## Concrete Verifiable Milestone

Run the full validation suite:
```bash
make check
```
All GUT unit tests pass cleanly with 0 errors and 0 leaked singletons.

---

## Manual Verification

1. Run the game:
   ```bash
   make play
   ```
2. Press **FN + F9**:
   - Scroll through the categorized scenarios.
   - Select `Archer Skirmish` -> confirm tactical combat starts with Goblin Archers firing bows.
   - Press F9 -> select `Advanced Encampment` -> open Buildings and verify Guild Hall Level 2, Blacksmith Level 3, and active jobs.
3. Edit `config/debug_scenarios.json` to change a scenario parameter, press F9, click "Reload Scenarios (JSON)", and confirm the updated scenario runs immediately without restarting Godot.

---

## Local Branch Merge

After user sign-off:
```bash
git checkout main
git merge feat/debug-menu-docs-and-examples
git branch -d feat/debug-menu-docs-and-examples
```
