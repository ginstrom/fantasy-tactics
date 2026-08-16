# Step 2: Encampment, Stores, Roster & Party State Application Engine

## Overview

Currently, [`DebugScenarios.apply()`](file:///home/ryan/play/fantasy-tactics/scripts/debug/debug_scenarios.gd) has hardcoded GDScript functions (such as `_create_staffed_party()`, `_create_three_warrior_party()`, `_stock_shop_and_stores()`, etc.) that manually manipulate `GameSession`.

This step introduces a general-purpose state application engine in `DebugScenarios` that reads any scenario's declarative `session` block from JSON and applies all game systems cleanly:
- Encampment buildings and tiers (`guild_hall_level`, `blacksmith_level`, `alchemy_workshop_level`, `runic_workshop_level`, `shop_level`, `has_trading_post`) and active jobs.
- Stores & economy (`gold`, `mana_crystals`, `banked_gear`, `owned_item_instances`, `banked_item_instance_ids`, `pending_reward`, `shop_gold`).
- Roster & units (custom classes `warrior`/`scout`, levels, base stats, attribute distributions, perks, and equipped gear including sharpened weapons and runed armor).
- Parties (multi-party setups, member assignments, encamped vs. deployed state, World Map position coordinates, routes).
- World Map encounters (active encounter instances, custom positions, vacancies, completed encounters).

---

## Setup Instructions

1. Check out `main` and pull the latest changes:
   ```bash
   git checkout main && git pull
   ```
2. Create and check out the feature branch:
   ```bash
   git checkout -b feat/debug-session-state-applicator
   ```

---

## Test-Driven Development (TDD) Plan

### 1. Write Failing Tests (Red Phase)

Add unit tests in [`tests/unit/test_debug_scenarios.gd`](file:///home/ryan/play/fantasy-tactics/tests/unit/test_debug_scenarios.gd):

- **Test Building & Tier Setup**:
  - Define scenario with `guild_hall_level: 2`, `blacksmith_level: 3`, `alchemy_workshop_level: 2`, `runic_workshop_level: 2`, `has_trading_post: true`.
  - Apply scenario and assert `GameSession` building levels match exactly.
- **Test Workshop Active Jobs Setup**:
  - Define scenario with active `blacksmith_craft_job` (`{"item_id": "longsword_steel", "ready_turn": 6}`), `blacksmith_sharpening_job`, `alchemy_craft_job`, and `runic_craft_job`.
  - Apply scenario and assert `GameSession` job dictionaries match.
- **Test Stores & Mana Crystals Setup**:
  - Define scenario with `gold: 750`, `mana_crystals: {"1": 4, "2": 2}`, `banked_gear: {"longbow_steel": 2}`, `pending_reward: 120`.
  - Apply scenario and assert `GameSession` inventory and stores match.
- **Test Custom Roster & Equipment Setup**:
  - Define scenario with custom Scout unit (level 2, 50 XP, equipped with `shortbow_steel` and `chainmail_armor`) and Warrior unit (equipped with sharpened `two_handed_sword_iron`).
  - Apply scenario and verify `GameSession.adventurers` contains custom units with correct stats, weapons, armors, and item instances.
- **Test Party Configuration & Deployment**:
  - Define scenario with 2 parties: Party 1 deployed at `Vector2i(2, 3)` with 3 members, Party 2 encamped with 1 member.
  - Apply scenario and verify `GameSession.parties`, `GameSession.selected_party_id`, and deployed positions match.
- **Test Backward Compatibility of Baseline Scenarios**:
  - Verify all 10 baseline scenarios (`new_campaign`, `encampment`, `party_manager`, `party_ready`, `party_empty`, `world_map`, `goblin_camp`, `orc_outpost`, `ruined_fortress`, `stocked_stores`) produce identical `GameSession` states as before.

Run tests to confirm failure:
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_debug_scenarios.gd -gexit
```

---

### 2. Implementation (Green Phase)

1. **Update [`scripts/debug/debug_scenarios.gd`](file:///home/ryan/play/fantasy-tactics/scripts/debug/debug_scenarios.gd)**:
   - Implement `static func apply(scenario_id: String) -> bool`:
     - Calls `GameSession.start_new_game()`.
     - Calls `GameSession.reset_injectable_rolls()`.
     - Retrieves scenario Dictionary via `get_scenario(scenario_id)`.
     - If scenario not found, returns `false`.
     - Calls `_apply_session_state(scenario.get("session", {}))`.
     - Calls `_apply_battle_state(scenario.get("battle", {}))` (Step 3).
     - Returns `true`.
   - Implement `static func _apply_session_state(session_config: Dictionary) -> void`:
     - **General**: Sets `GameSession.gold`, `GameSession.world_turn`, `GameSession.player_name`, `GameSession.tutorial_progress`.
     - **Buildings**: Sets `GameSession.guild_hall_level`, `blacksmith_level`, `blacksmith_craft_job`, `blacksmith_sharpening_job`, `alchemy_workshop_level`, `alchemy_craft_job`, `runic_workshop_level`, `runic_craft_job`, `has_trading_post`, `shop_level`, `shop_gold`.
     - **Stores**: Populates `mana_crystals`, `banked_gear`, `owned_item_instances`, `banked_item_instance_ids`, `pending_reward`, `pending_mana_crystals`, `pending_gear`.
     - **Units & Roster**:
       - If `units` array specified in JSON, clears default roster and builds units via helper `_build_adventurer_from_json(unit_dict)`.
       - Supports shorthand unit specifications (e.g. `{"class": "warrior", "level": 2, "count": 2}`).
       - Handles equipment assignment, weapon/armor inventory arrays, and custom item instances (e.g. sharpened weapons, runed armor).
     - **Parties**:
       - If `parties` array specified, clears default parties and populates parties from JSON (`id`, `name`, `member_ids`, `state`, `position`, `route`).
       - Updates `GameSession.selected_party_id`.
       - If deployed, sets deployed party position on World Map.
     - **World Map**:
       - Populates `active_encounters`, `completed_encounters`, and `encounter_vacancies`.

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
2. Open debug menu (F9) -> select `Stocked Stores`.
3. Verify Stores shows 500 gold, 2 mana crystals, 1 Iron Shortsword, and Shop Buy tab is accessible.
4. Select `Ruined Fortress`.
5. Verify 3 Warriors are in the party deployed at `(0, 4)`.

---

## Local Branch Merge

After user sign-off:
```bash
git checkout main
git merge feat/debug-session-state-applicator
git branch -d feat/debug-session-state-applicator
```
