# Step 1: Scenario JSON Schema, Default Config & Parser

## Overview

Currently, [`scripts/debug/debug_scenarios.gd`](file:///home/ryan/play/fantasy-tactics/scripts/debug/debug_scenarios.gd) defines debug scenarios via a hardcoded array `SCENARIO_IDS` and static GDScript procedures.

This step establishes the JSON configuration contract, creates [`config/debug_scenarios.json`](file:///home/ryan/play/fantasy-tactics/config/debug_scenarios.json) containing all existing scenarios (plus baseline schema descriptors), and updates `DebugScenarios` to load, parse, validate, and normalize scenarios from JSON while maintaining complete backward compatibility with existing method signatures (`scenario_ids()`, `apply()`, etc.).

---

## Setup Instructions

1. Check out `main` and pull the latest changes:
   ```bash
   git checkout main && git pull
   ```
2. Create and check out the feature branch:
   ```bash
   git checkout -b feat/debug-scenario-json-loader
   ```

---

## Test-Driven Development (TDD) Plan

### 1. Write Failing Tests (Red Phase)

Add unit tests in [`tests/unit/test_debug_scenarios.gd`](file:///home/ryan/play/fantasy-tactics/tests/unit/test_debug_scenarios.gd):

- **Test `DebugScenarios.load_scenarios(path)`**:
  - Successfully loads and parses valid JSON from `config/debug_scenarios.json`.
  - Returns fallback defaults if the file does not exist or has invalid JSON syntax.
- **Test `DebugScenarios.scenario_ids()`**:
  - Returns array of scenario IDs parsed from `config/debug_scenarios.json`.
  - Confirms standard scenario IDs (`new_campaign`, `encampment`, `party_manager`, `party_ready`, `party_empty`, `world_map`, `goblin_camp`, `orc_outpost`, `ruined_fortress`, `stocked_stores`) are present.
- **Test `DebugScenarios.get_scenario(scenario_id)`**:
  - Returns the normalized scenario Dictionary for a known scenario ID.
  - Returns `{}` for an unknown scenario ID.
- **Test `DebugScenarios.get_scenarios_by_category()`**:
  - Returns a Dictionary grouping scenarios by their `category` attribute (e.g. `{"Campaign": [...], "Encampment": [...], "Combat": [...]}`).
- **Test normalization of sparse scenario configurations**:
  - Omitted fields (e.g. empty `session`, missing `buildings`, default `units`) are cleanly populated with standard defaults.

Run tests to confirm failure:
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_debug_scenarios.gd -gexit
```

---

### 2. Implementation (Green Phase)

1. **Create [`config/debug_scenarios.json`](file:///home/ryan/play/fantasy-tactics/config/debug_scenarios.json)**:
   - Define the standard scenario list:
     - `new_campaign`: target `starting_settlement`, fresh session.
     - `encampment`: target `encampment`, fresh session.
     - `party_manager`: target `party_manager`, fresh session.
     - `party_ready`: target `encampment`, single party with Warrior 1.
     - `party_empty`: target `encampment`, single party with no members.
     - `world_map`: target `world_map`, party deployed at `[1, 0]`.
     - `goblin_camp`: target `battlefield`, encounter `goblin_camp`, party deployed at camp position `[4, 4]`.
     - `orc_outpost`: target `battlefield`, encounter `orc_outpost`, 4 warriors vs 2 orcs.
     - `ruined_fortress`: target `battlefield`, encounter `ruined_fortress`, 3 warriors vs 8 kobolds.
     - `stocked_stores`: target `stores`, 500 gold, 2 tier-1 mana crystals, 1 banked iron shortsword, trading post active, shop level 1.
2. **Update [`scripts/debug/debug_scenarios.gd`](file:///home/ryan/play/fantasy-tactics/scripts/debug/debug_scenarios.gd)**:
   - Add constant `const DEFAULT_CONFIG_PATH := "res://config/debug_scenarios.json"`.
   - Add cached dictionary `static var _scenarios_cache: Dictionary = {}`.
   - Implement `static func load_scenarios(path: String = DEFAULT_CONFIG_PATH) -> bool`:
     - Reads JSON file using `FileAccess.get_file_as_string(path)`.
     - Parses JSON via `JSON.parse_string()`.
     - Normalizes each scenario and populates `_scenarios_cache`.
   - Implement `static func get_scenario(scenario_id: String) -> Dictionary`.
   - Implement `static func get_all_scenarios() -> Array[Dictionary]`.
   - Implement `static func get_scenarios_by_category() -> Dictionary`.
   - Implement `static func scenario_ids() -> Array[String]` returning keys from loaded scenarios.
   - Implement `static func normalize_scenario(raw_scenario: Dictionary) -> Dictionary` ensuring expected fields (`id`, `name`, `category`, `scene`, `session`, `battle`) are well-formed.

---

## Concrete Verifiable Milestone

Run the test suite:
```bash
make check
```
All GUT unit tests pass cleanly with 0 errors.

---

## Manual Verification

1. Verify JSON file syntax:
   ```bash
   python3 -m json.tool config/debug_scenarios.json > /dev/null
   ```
2. Verify scenarios load and print from GDScript:
   ```bash
   godot --headless --script scripts/debug/debug_scenarios.gd
   ```

---

## Local Branch Merge

After user sign-off:
```bash
git checkout main
git merge feat/debug-scenario-json-loader
git branch -d feat/debug-scenario-json-loader
```
