# Step 5: Dynamic Debug Menu UI & Hot-Reload

## Overview

Currently, [`scenes/debug/debug_menu.tscn`](file:///home/ryan/play/fantasy-tactics/scenes/debug/debug_menu.tscn) has a fixed vertical container with 11 hardcoded buttons, which will overflow the screen as new debug scenarios are added. Furthermore, testing changes to scenarios currently requires restarting the game.

This step updates the debug menu UI:
1. **Dynamic Button Instantiation**: Populates scenario buttons dynamically at runtime from `DebugScenarios.get_all_scenarios()`.
2. **Scrollable Layout**: Wraps scenario buttons inside a `ScrollContainer` with a maximum height, guaranteeing the menu never overflows regardless of scenario count.
3. **Category Grouping**: Visually groups scenarios by their declared `category` (e.g. "Campaign & Flow", "Encampment & Buildings", "World Map", "Combat & Battles", "Economy & Trade") with clean header labels.
4. **Runtime Hot-Reload**: Adds a "Reload Config" button that re-parses `config/debug_scenarios.json` and rebuilds the menu UI immediately while the game is running.
5. **Utility Actions**: Preserves in-battle action buttons ("Super Power", "Recruit Adventurer") in a dedicated utilities footer.

---

## Setup Instructions

1. Check out `main` and pull the latest changes:
   ```bash
   git checkout main && git pull
   ```
2. Create and check out the feature branch:
   ```bash
   git checkout -b feat/debug-menu-dynamic-ui
   ```

---

## Test-Driven Development (TDD) Plan

### 1. Write Failing Tests (Red Phase)

Add unit tests in [`tests/unit/test_debug_menu.gd`](file:///home/ryan/play/fantasy-tactics/tests/unit/test_debug_menu.gd):

- **Test Dynamic Button Generation**:
  - Instantiate `DebugMenuScene`.
  - Assert scenario buttons exist for all scenario IDs in `DebugScenarios.scenario_ids()`.
  - Verify button text matches localized translation key or scenario name.
- **Test Category Grouping**:
  - Assert category headers are created for each unique category present in the config.
- **Test Scenario Button Click Action**:
  - Trigger `pressed` on a dynamic scenario button (e.g. `goblin_camp`).
  - Verify `GameManager.run_debug_scenario("goblin_camp")` is invoked and the menu hides itself on success.
- **Test Hot-Reload Button**:
  - Trigger `_on_reload_config_pressed()`.
  - Verify `DebugScenarios.load_scenarios()` is called and buttons are re-instantiated.
- **Test Persistent Utilities**:
  - Assert "Super Power" and "Recruit Adventurer" buttons exist in the utilities footer and perform their respective actions.

Run tests to confirm failure:
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_debug_menu.gd -gexit
```

---

### 2. Implementation (Green Phase)

1. **Update [`scenes/debug/debug_menu.tscn`](file:///home/ryan/play/fantasy-tactics/scenes/debug/debug_menu.tscn)**:
   - Restructure node hierarchy:
     ```
     DebugMenu (CanvasLayer, layer 101)
     └── Panel (PanelContainer)
         └── Layout (VBoxContainer)
             ├── Title (Label: "debug.title")
             ├── CloseHint (Label: "debug.close_hint")
             ├── Scroll (ScrollContainer, custom_minimum_size = (280, 420))
             │   └── ScenariosContainer (VBoxContainer)
             ├── Separator (HSeparator)
             ├── UtilitiesContainer (VBoxContainer)
             │   ├── ReloadButton (Button: "debug.reload_config")
             │   ├── SuperPowerButton (Button: "debug.super_power")
             │   └── RecruitButton (Button: "debug.recruit")
     ```
2. **Update [`scripts/debug/debug_menu.gd`](file:///home/ryan/play/fantasy-tactics/scripts/debug/debug_menu.gd)**:
   - On `_ready()` and when opened (`_unhandled_key_input` on F9):
     - Call `_rebuild_scenario_buttons()`.
   - Implement `func _rebuild_scenario_buttons() -> void`:
     - Clear existing children in `ScenariosContainer`.
     - Fetch categorized scenarios via `DebugScenarios.get_scenarios_by_category()`.
     - For each category:
       - If category name is non-empty, add a stylized category `Label`.
       - For each scenario in the category:
         - Create a `Button`.
         - Set `text = tr(scenario.name)` (or `scenario.id`).
         - Connect `button.pressed` to `_run.bind(scenario.id)`.
         - Add button to `ScenariosContainer`.
   - Implement `func _on_reload_config_pressed() -> void`:
     - Calls `DebugScenarios.load_scenarios()`.
     - Calls `_rebuild_scenario_buttons()`.
   - Implement `_on_super_power_pressed()` and `_on_recruit_pressed()` as before.
3. **Update [`translations/en.tres`](file:///home/ryan/play/fantasy-tactics/translations/en.tres)**:
   - Add `"debug.reload_config": "Reload Scenarios (JSON)"`.

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
2. Press **FN + F9** to toggle the debug menu.
3. Verify:
   - Menu opens with clean categorized scenario buttons inside a scrollable view.
   - Click a scenario (e.g. `Orc Outpost Battle`), confirm the scene transitions and menu closes.
   - Press F9 again, click "Reload Scenarios (JSON)", confirm buttons refresh.
   - Click "Recruit Adventurer", confirm a new adventurer is added to the roster.

---

## Local Branch Merge

After user sign-off:
```bash
git checkout main
git merge feat/debug-menu-dynamic-ui
git branch -d feat/debug-menu-dynamic-ui
```
