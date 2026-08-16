# Debug Menu System Revamp & JSON-Driven Scenario Configuration

This implementation plan details the overhaul of the debug menu system (F9 key) from hardcoded GDScript match routines to a declarative, data-driven JSON configuration system (`config/debug_scenarios.json`).

## Motivation & Goals

The existing debug scenario mechanism in [`scripts/debug/debug_scenarios.gd`](file:///home/ryan/play/fantasy-tactics/scripts/debug/debug_scenarios.gd) and [`scenes/debug/debug_menu.tscn`](file:///home/ryan/play/fantasy-tactics/scenes/debug/debug_menu.tscn) relies on hardcoded procedural GDScript methods and a static 11-button UI. Testing complex edge cases (e.g. high-tier buildings, specific equipment loadouts, multi-class parties, custom enemy squads with bows or runic armor) currently requires writing custom GDScript code.

This revamp provides:
1. **Declarative JSON Configuration**: A centralized, extensible `config/debug_scenarios.json` file defining scenarios across every layer of game state:
   - Target scene navigation (Encampment, World Map, Battlefield, Stores, Guild Hall, Blacksmith, Alchemy Workshop, Runic Workshop, Recruitment, Roster, etc.).
   - Encampment buildings, upgrade tiers (Guild Hall 1-2, Blacksmith 1-3, Alchemy 1-2, Runic 1-2, Shop 1-2), and active crafting/sharpening jobs.
   - Economy & Stores (gold, mana crystals, banked gear, runed/sharpened item instances, pending battle rewards).
   - Parties & Roster (multi-unit parties, custom levels, classes, stats, attributes, perks, and equipped weapons/armor).
   - World Map (active encounter instances, custom positions, vacancies, completed encounters).
   - Battlefield & Tactical Combat (custom enemy squads, custom weapons, armor, ranges, damage stats, grid positions, and pinned rolls).
2. **Dynamic, Scrollable Debug UI**: A responsive, categorized UI that generates buttons dynamically from the JSON config, complete with in-game hot-reloading (edit JSON, click Reload without restarting the game).
3. **Full Backward Compatibility**: All 10 existing baseline scenarios (`new_campaign`, `encampment`, `party_ready`, `party_empty`, `world_map`, `goblin_camp`, `orc_outpost`, `ruined_fortress`, `stocked_stores`, `party_manager`) remain fully functional and pass all existing unit tests and test automation.

---

## Architecture & JSON Schema

### JSON Schema Specification (`config/debug_scenarios.json`)

```json
{
  "scenarios": [
    {
      "id": "scenario_identifier",
      "name": "display_name_or_translation_key",
      "category": "Campaign | Encampment | World Map | Combat | Economy",
      "description": "Brief summary of scenario setup",
      "scene": "encampment | world_map | battlefield | starting_settlement | party_manager | stores | shop | guild_hall | blacksmith | alchemy_workshop | runic_workshop | trading_post | units | roster | recruitment | parties | assign_equipment",
      "session": {
        "gold": 200,
        "world_turn": 1,
        "player_name": "Player",
        "tutorial_progress": {},
        "buildings": {
          "guild_hall_level": 1,
          "blacksmith_level": 0,
          "blacksmith_craft_job": {},
          "blacksmith_sharpening_job": {},
          "alchemy_workshop_level": 0,
          "alchemy_craft_job": {},
          "runic_workshop_level": 0,
          "runic_craft_job": {},
          "has_trading_post": false,
          "shop_level": 1,
          "shop_gold": 100
        },
        "stores": {
          "mana_crystals": { "1": 2, "2": 0 },
          "banked_gear": { "shortsword_iron": 1, "leather_armor": 1 },
          "owned_item_instances": {},
          "banked_item_instance_ids": [],
          "pending_reward": 0,
          "pending_mana_crystals": {},
          "pending_gear": {}
        },
        "units": [
          {
            "id": "warrior_001",
            "name": "Warrior",
            "class": "warrior",
            "level": 1,
            "health": 10,
            "stats": {
              "max_health": 10,
              "vitality": 10,
              "melee": 60,
              "missile": 60,
              "guard": 0,
              "might": 0,
              "move_range": 3
            },
            "equipment": {
              "weapon": "shortsword_iron",
              "weapon_inventory": ["shortsword_iron"],
              "armor": "leather_armor",
              "armor_inventory": ["leather_armor"]
            },
            "progression": { "xp": 0.0, "perks": [] },
            "availability_status": "assigned"
          }
        ],
        "parties": [
          {
            "id": "party_001",
            "name": "Party 1",
            "member_ids": ["warrior_001"],
            "state": "deployed",
            "position": [4, 4],
            "route": []
          }
        ],
        "selected_party_id": "party_001",
        "world_map": {
          "active_encounters": [],
          "completed_encounters": [],
          "encounter_vacancies": []
        }
      },
      "battle": {
        "encounter_id": "goblin_camp",
        "pinned_rolls": {
          "enemy_composition_roll": 0,
          "enemy_count_roll": 1
        },
        "enemies": [
          {
            "id": "enemy_goblin_1",
            "name_key": "battle.enemy.goblin",
            "display_name": "Goblin 1",
            "enemy_type_name": "Goblin",
            "position": [5, 5],
            "max_health": 13,
            "health": 13,
            "damage_min": 2,
            "damage_max": 2,
            "hit_chance": 0.3,
            "defense": 0,
            "resistance": 0,
            "move_range": 3,
            "attack_min_range": 1,
            "attack_max_range": 1,
            "kill_xp": 5,
            "loot_id": "goblin",
            "equipment": {}
          }
        ],
        "player_start_positions": [[0, 0], [1, 0]]
      }
    }
  ]
}
```

---

## Steps & Milestones

| Step | Plan File | Focus Area | Key Milestone |
|---|---|---|---|
| 1 | [`step-1-scenario-json-schema-and-loader.md`](step-1-scenario-json-schema-and-loader.md) | JSON Schema, Default Config & Parser | `config/debug_scenarios.json` created with all baseline scenarios; `DebugScenarios` parses, normalizes, and validates JSON with full test coverage |
| 2 | [`step-2-session-encampment-party-state-applicator.md`](step-2-session-encampment-party-state-applicator.md) | Encampment, Stores, Roster & Party State Engine | `DebugScenarios.apply()` sets up arbitrary building tiers, crafting jobs, stores/crystals, custom unit stats/equipment, parties, and world map state from JSON |
| 3 | [`step-3-battlefield-custom-enemies-and-equipment.md`](step-3-battlefield-custom-enemies-and-equipment.md) | Combat & Custom Battlefield Setup | `BattleController` and `GameSession` support declarative custom enemy squads, custom equipment, weapons, armor, ranges, and battle grid positions |
| 4 | [`step-4-gamemanager-dynamic-scene-dispatch.md`](step-4-gamemanager-dynamic-scene-dispatch.md) | Dynamic Scene Routing in GameManager | `GameManager.run_debug_scenario()` dynamically routes to any target scene based on scenario configuration |
| 5 | [`step-5-dynamic-debug-menu-ui-and-hot-reload.md`](step-5-dynamic-debug-menu-ui-and-hot-reload.md) | Dynamic Debug Menu UI & Hot-Reload | Debug Menu (F9) dynamically renders categorized scenario buttons inside a scrollable view with an in-game "Reload JSON" button and utility actions |
| 6 | [`step-6-documentation-and-manual-verification.md`](step-6-documentation-and-manual-verification.md) | Example Scenarios, Documentation & Verification | Rich example scenarios added, developer documentation in `docs/dev/running-the-game.md` updated, full test suite and manual verification complete |

---

## Execution Principles

- **Branching Workflow**: Develop on feature branches off `main` in the working copy (`feat/debug-scenario-json-loader`, `feat/debug-session-state-applicator`, etc.).
- **TDD (Red/Green)**: Write failing unit tests first in `tests/unit/`, confirm test failure, implement, and verify with `make check`.
- **Manual Verification**: Verify in-game behavior using `make play`, F9 overlay, scenario execution, and screenshot capture.
- **Local Branch Merge**: After user sign-off, merge the feature branch back to `main` locally and delete the branch.
