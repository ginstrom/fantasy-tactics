# Step 4: Dynamic Scene Routing & Navigation in GameManager

## Overview

Currently, [`GameManager.run_debug_scenario()`](file:///home/ryan/play/fantasy-tactics/scripts/autoload/game_manager.gd) uses a static enum `DebugTarget` and match statement in `debug_scenario_target()` that only recognizes a narrow set of 7 hardcoded scenario strings.

This step updates `GameManager` to inspect the scenario's declarative `scene` / `target_scene` property from JSON and route to any screen in the game dynamically:
- Primary campaign screens: `starting_settlement`, `encampment`, `world_map`, `battlefield` / `battle`.
- Management & UI sub-screens: `party_manager`, `parties`, `units`, `roster`, `recruitment`, `assign_equipment`.
- Encampment building screens: `guild_hall`, `blacksmith`, `alchemy_workshop`, `runic_workshop`, `trade`, `stores`, `shop`, `trading_post`.
- Robust error handling: returns `ERR_INVALID_DATA` if a scenario or target scene is unrecognized, and `ERR_UNAVAILABLE` in non-debug builds.

---

## Setup Instructions

1. Check out `main` and pull the latest changes:
   ```bash
   git checkout main && git pull
   ```
2. Create and check out the feature branch:
   ```bash
   git checkout -b feat/debug-gamemanager-dynamic-dispatch
   ```

---

## Test-Driven Development (TDD) Plan

### 1. Write Failing Tests (Red Phase)

Add unit tests in [`tests/unit/test_game_manager.gd`](file:///home/ryan/play/fantasy-tactics/tests/unit/test_game_manager.gd):

- **Test Navigation to Encampment Buildings via Scenarios**:
  - Define debug scenarios with `scene: "guild_hall"`, `scene: "blacksmith"`, `scene: "alchemy_workshop"`, `scene: "runic_workshop"`, `scene: "shop"`.
  - Call `GameManager.run_debug_scenario(id)` and verify the active scene matches the requested screen.
- **Test Navigation to Roster & Recruitment Screens**:
  - Define scenarios with `scene: "roster"`, `scene: "recruitment"`, `scene: "units"`, `scene: "parties"`.
  - Verify `GameManager.run_debug_scenario(id)` navigates cleanly to those scenes.
- **Test Battle Routing with and without Encounter ID**:
  - For `scene: "battlefield"` with `encounter_id: "orc_outpost"`, asserts `enter_battle("orc_outpost")` is called.
  - For custom battles without an encounter ID, asserts battlefield scene is loaded with custom battle override active.
- **Test Error Handling**:
  - Attempting to run a non-existent scenario ID returns `ERR_INVALID_DATA`.
  - Running a scenario with an invalid `scene` name returns `ERR_INVALID_DATA`.
  - Running in a non-debug build returns `ERR_UNAVAILABLE`.

Run tests to confirm failure:
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_manager.gd -gexit
```

---

### 2. Implementation (Green Phase)

1. **Update [`scripts/autoload/game_manager.gd`](file:///home/ryan/play/fantasy-tactics/scripts/autoload/game_manager.gd)**:
   - Refactor `run_debug_scenario(scenario_id: String) -> Error`:
     ```gdscript
     func run_debug_scenario(scenario_id: String) -> Error:
         if not OS.is_debug_build():
             return ERR_UNAVAILABLE
         var scenario := DebugScenarios.get_scenario(scenario_id)
         if scenario.is_empty():
             return ERR_INVALID_DATA
         if not DebugScenarios.apply(scenario_id):
             return ERR_INVALID_DATA

         var target_scene: String = scenario.get("scene", scenario.get("target_scene", "encampment"))
         return _dispatch_debug_scene(target_scene, scenario)
     ```
   - Implement `func _dispatch_debug_scene(target_scene: String, scenario: Dictionary) -> Error`:
     - Matches `target_scene`:
       - `"starting_settlement"`, `"settlement"`: `return go_to_starting_settlement()`
       - `"encampment"`: `return go_to_encampment()`
       - `"party_manager"`: `return open_party_manager()`
       - `"parties"`: `return go_to_parties()`
       - `"units"`: `return go_to_units()`
       - `"roster"`: `return go_to_roster()`
       - `"recruitment"`: `return go_to_recruitment()`
       - `"guild_hall"`: `return go_to_guild_hall()`
       - `"blacksmith"`: `return go_to_blacksmith()`
       - `"alchemy_workshop"`: `return go_to_alchemy_workshop()`
       - `"runic_workshop"`: `return go_to_runic_workshop()`
       - `"trade"`: `return go_to_trade()`
       - `"stores"`: `return go_to_stores()`
       - `"shop"`: `return go_to_shop()`
       - `"trading_post"`: `return go_to_trading_post()`
       - `"world_map"`: `return go_to_world_map()`
       - `"battlefield"`, `"battle"`:
         - var encounter_id: String = scenario.get("battle", {}).get("encounter_id", scenario_id)
         - `return enter_battle(encounter_id)`
       - `"assign_equipment"`: `return go_to_assign_equipment(AssignEquipmentOrigin.STORES)`
       - `_`: `push_error("Unknown debug target scene: " + target_scene); return ERR_INVALID_DATA`

---

## Concrete Verifiable Milestone

Run the test suite:
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
2. Open debug menu (F9) -> select `party_manager`.
3. Verify the Party Manager screen opens.
4. Open debug menu (F9) -> select `stocked_stores`.
5. Verify the Stores screen opens with stocked items.

---

## Local Branch Merge

After user sign-off:
```bash
git checkout main
git merge feat/debug-gamemanager-dynamic-dispatch
git branch -d feat/debug-gamemanager-dynamic-dispatch
```
