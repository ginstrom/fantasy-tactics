# Code Audit Findings & Architectural Review

**Date**: 2026-08-28  
**Scope**: Full codebase audit of Fantasy Tactics (Battle, Campaign & Session State, Persistence & Audio, UI & World Map)  
**Objective**: Identify structural/architectural issues, potential bugs, and opportunities for idiomatic, readable, and maintainable Godot 4 code.

---

## 1. Executive Summary & Health Scorecard

| Area | Grade | Strengths | Key Concerns |
|---|:---:|---|---|
| **Combat & Battle** | **B-** | Deterministic AI policy, rich status/perk resolution, clean separation of tile geometry in [`GridScript`](file:///home/ryan/play/fantasy-tactics/scripts/battle/grid.gd). | [`BattleController`](file:///home/ryan/play/fantasy-tactics/scripts/battle/battle_controller.gd) is a ~3,000-line God Object mixing rules, presentation, and AI; opportunity attack crash in log formatting; synchronous simulation vs. async playback desync. |
| **Campaign & State** | **C+** | Strong initial service extractions ([`EncounterService`](file:///home/ryan/play/fantasy-tactics/scripts/campaign/encounter_service.gd), [`PartyService`](file:///home/ryan/play/fantasy-tactics/scripts/campaign/party_service.gd), [`ProgressionService`](file:///home/ryan/play/fantasy-tactics/scripts/progression/progression_service.gd)); robust test coverage. | [`GameSession`](file:///home/ryan/play/fantasy-tactics/scripts/autoload/game_session.gd) is ~4,864 lines; ~1,700 lines of static catalog tables embedded in code; shallow service delegation with direct mutable variable access; vacancy stagnation bugs. |
| **Persistence & Save** | **B+** | Deep-copy cloning, atomic temp-file writes in [`SaveRepository`](file:///home/ryan/play/fantasy-tactics/scripts/save/save_repository.gd), strict snapshot validation. | Global integer key conversion in [`SaveRepository`](file:///home/ryan/play/fantasy-tactics/scripts/save/save_repository.gd) corrupts string-keyed dictionaries; hardcoded compile-time MP limits break `GameConfig` overrides. |
| **Audio & Tooling** | **A-** | Excellent headless simulation tools ([`BattleBot`](file:///home/ryan/play/fantasy-tactics/scripts/tools/battle_bot.gd), [`CampaignSim`](file:///home/ryan/play/fantasy-tactics/scripts/tools/campaign_sim.gd)); soft-failing audio loader. | Linear decibel crossfading causes perceived silence dips; non-atomic audio settings write. |
| **UI & World Map** | **B** | Standardized [`CardNavigator`](file:///home/ryan/play/fantasy-tactics/scripts/ui/card_navigator.gd) modal browser; consistent [`CampNav`](file:///home/ryan/play/fantasy-tactics/scripts/ui/camp_nav.gd) left nav. | Unshielded dialogs permit click-through to map tiles; ~450 duplicated lines between `unit_details.gd` and `unit_detail_card.gd`; mouse motion node churn; lack of domain signals forces manual UI polling/refresh cascades. |

---

## 2. Critical & High-Severity Bugs

### 2.1 [CRITICAL] Runtime Crash on Enemy Opportunity Attack Step in Battle Log
* **File:** [`scripts/battle/battlefield.gd:732`](file:///home/ryan/play/fantasy-tactics/scripts/battle/battlefield.gd#L732)
* **Description:** When an enemy unit moves during `run_enemy_turn()` and triggers a player unit's Attack of Opportunity, `_take_enemy_unit_actions()` appends `last_reaction_results` directly to `steps`. A reaction step dictionary has the structure `{"type": "reaction", "reactor": ..., "mover": ..., "damage": ...}` — it lacks a `"unit"` key.
* **Failure Mode:** In `_describe_step()`, unhandled types fall through to:
  ```gdscript
  var mover_name: String = tr(SIDE_NAME_KEYS[step.unit.side])
  ```
  Evaluating `step.unit.side` crashes with `Invalid get index 'side' on base 'Nil'`.
* **Recommendation:** Add a dedicated handler for `step.type == "reaction"` in [`_describe_step()`](file:///home/ryan/play/fantasy-tactics/scripts/battle/battlefield.gd#L710) and guard `step.get("unit")` before accessing properties.

---

### 2.2 [HIGH] World Map Modals Allow Click-Through to Tiles Behind Them
* **File:** [`scripts/world/world_map.gd:116-160`](file:///home/ryan/play/fantasy-tactics/scripts/world/world_map.gd#L116-L160), [`scenes/world/world_map.tscn`](file:///home/ryan/play/fantasy-tactics/scenes/world/world_map.tscn)
* **Description:** `%ArrivalPanel` ("Enter / Withdraw / Cancel") and `%SendPartyModal` are floating `PanelContainer`s without a full-screen input blocker (`MOUSE_FILTER_STOP`).
* **Failure Mode:** In `_unhandled_input()`, clicks outside the panel boundaries pass through to `_handle_tile_click()`, repathing or moving the party while the modal remains open with stale encounter data. Furthermore, pressing Escape (`ui_cancel`) opens the pause menu instead of dismissing the active modal.
* **Recommendation:** In `_unhandled_input()`, consume clicks and handle `ui_cancel` when modals are visible, and back dialogs with full-screen `MOUSE_FILTER_STOP` blockers (or integrate [`ModalDialog`](file:///home/ryan/play/fantasy-tactics/scripts/ui/modal_dialog.gd)).

---

### 2.3 [HIGH] Global JSON Key Normalization Corrupts String-Keyed Dictionaries
* **File:** [`scripts/save/save_repository.gd:184-188`](file:///home/ryan/play/fantasy-tactics/scripts/save/save_repository.gd#L184-L188), [`scripts/save/campaign_snapshot.gd:826,857,898`](file:///home/ryan/play/fantasy-tactics/scripts/save/campaign_snapshot.gd#L826)
* **Description:** `SaveRepository._normalize_json_key()` runs globally across every Dictionary in the parsed JSON tree:
  ```gdscript
  static func _normalize_json_key(key: Variant) -> Variant:
      if key is String and key.is_valid_int():
          return int(key)
      return key
  ```
* **Failure Mode:** If any entry ID in `quests` (e.g. `"102"`), `tutorial_progress`, `encounter_intel`, or `owned_item_instances` is numeric, it is converted to an `int`. [`CampaignSnapshot.from_dictionary()`](file:///home/ryan/play/fantasy-tactics/scripts/save/campaign_snapshot.gd#L205) strictly rejects non-string keys, causing valid save files to be rejected as corrupted (`INVALID_SNAPSHOT`).
* **Recommendation:** Remove global key conversion from `SaveRepository` and restrict `int` key coercion specifically to `mana_crystals` inside `CampaignSnapshot`.

---

### 2.4 [HIGH] Static Compile-Time MP Validation Breaks `GameConfig` Overrides
* **File:** [`scripts/save/campaign_snapshot.gd:735-748`](file:///home/ryan/play/fantasy-tactics/scripts/save/campaign_snapshot.gd#L735-L748), [`scripts/autoload/game_session.gd:1811`](file:///home/ryan/play/fantasy-tactics/scripts/autoload/game_session.gd#L1811)
* **Description:** `GameSession` derives class MP caps dynamically from `GameConfig` (`CLERIC_MP_MAX` / `MAGE_MP_MAX`). However, `CampaignSnapshot._validate_mp_field()` validates `mp_current` against static compile-time constants in `CLASS_DEFINITIONS` (`mp_max = 3`).
* **Failure Mode:** If balance configuration sets `cleric.mp_max` to 4 or 5, any character saved with their valid current MP (> 3) will be rejected on load with `"out-of-range mp_current"`.
* **Recommendation:** Have `CampaignSnapshot` read class MP limits from `GameConfig` (or validate dynamically).

---

### 2.5 [HIGH] Recruitment Offer Pool Stagnation on Guild Hall Upgrades
* **File:** [`scripts/autoload/game_session.gd:2430-2436`](file:///home/ryan/play/fantasy-tactics/scripts/autoload/game_session.gd#L2430-L2436), [`scripts/autoload/game_session.gd:3730`](file:///home/ryan/play/fantasy-tactics/scripts/autoload/game_session.gd#L3730)
* **Description:** Upgrading the Guild Hall increases `get_recruitment_offer_cap()` from 4 to 8 (or 10). However, `upgrade_guild_hall()` does not trigger vacancies to populate the new capacity slots, and vacancies only spawn when a candidate is hired (1-for-1 refill).
* **Failure Mode:** The candidate pool **never expands beyond the initial 4 offers**, depriving the player of the 8–10 simultaneous offers unlocked by Guild Hall upgrades.
* **Recommendation:** In `upgrade_guild_hall()`, spawn recruitment vacancies for all newly unlocked capacity slots.

---

### 2.6 [HIGH] Synchronous Turn Execution vs. Asynchronous Playback Desync in Battlefield
* **File:** [`scripts/battle/battlefield.gd:329-337`](file:///home/ryan/play/fantasy-tactics/scripts/battle/battlefield.gd#L329-L337), [`scripts/battle/battle_controller.gd:2245`](file:///home/ryan/play/fantasy-tactics/scripts/battle/battle_controller.gd#L2245)
* **Description:** `grid.run_enemy_turn()` executes the entire enemy turn synchronously in memory before `_play_enemy_turn()` begins playing back step animations.
* **Failure Mode:** During delayed playback, `_play_enemy_turn()` calls `_draw_units()` on each step, reading the mutated final state:
  1. A player unit killed on Step 4 disappears from the grid immediately on Step 1.
  2. Enemy units visually appear at their final destination tiles before their movement step plays.
* **Recommendation:** Execute enemy actions incrementally with awaits between steps, or record visual snapshot diffs in the step records instead of redrawing live unit arrays during historical steps.

---

### 2.7 [HIGH] State Reference Leaks via `get_selected_party()` and `adventurers`
* **File:** [`scripts/campaign/party_service.gd:80-84`](file:///home/ryan/play/fantasy-tactics/scripts/campaign/party_service.gd#L80-L84), [`scripts/ui/assign_equipment.gd:73`](file:///home/ryan/play/fantasy-tactics/scripts/ui/assign_equipment.gd#L73)
* **Description:** While `get_party(id)` returns `duplicate(true)`, `get_selected_party()` and `_get_party_for_adventurer()` return direct internal dictionary references.
* **Failure Mode:** UI scripts or callers modifying the returned dictionary directly mutate internal session state without triggering validations or signal emissions.
* **Recommendation:** Ensure all public session getters return `duplicate(true)` consistently.

---

## 3. Core Architectural & Structural Issues

### 3.1 Monolithic God Objects

```
┌─────────────────────────────────────────────────────────────┐
│                    GameSession.gd (4,864 lines)             │
├──────────────────────────────┬──────────────────────────────┤
│ Static Catalogs (~1,700 ln)  │ Unextracted Domains (~2,500) │
│ - WEAPONS, ARMORS, POTIONS   │ - Workshop & Crafting        │
│ - CLASS_DEFINITIONS          │ - Inventory & Equipment      │
│ - ENEMY_LOOT_TABLES          │ - Trade & Economy            │
│ - EXPEDITIONS                │ - Intel, Scouting & Quests   │
│ - CAMPAIGN_OBJECTIVES        │ - Recruitment & Roster       │
├──────────────────────────────┤ - Journal & Guidance         │
│ Facade Forwarders (~600 ln)  │ - Snapshot Validation        │
└──────────────────────────────┴──────────────────────────────┘
```

1. **[`GameSession.gd`](file:///home/ryan/play/fantasy-tactics/scripts/autoload/game_session.gd) (4,864 lines):**
   - **~1,735 lines of static catalogs:** Hardcoded tables that belong in standalone static catalog scripts or JSON content files.
   - **~600 lines of forwarders:** Thin 1-line delegations to `PartyService`, `EncounterService`, and `ProgressionService`.
   - **~2,500 lines of unextracted domains:** Workshop/Crafting, Inventory/Equipment, Trade/Shop, Intel/Quests, Recruitment/Roster, Journal/Guidance, and Snapshot Validation.
   - **Shallow delegation:** Extracted services own no internal state, directly mutating untyped fields on `_gs: Node`.

2. **[`BattleController.gd`](file:///home/ryan/play/fantasy-tactics/scripts/battle/battle_controller.gd) (2,962 lines):**
   - Merges combat rules & formulas, spell/perk execution, spatial grid representations, entity instantiation, 2D scene graph rendering (`_draw_tiles`, `_draw_units`, `_update_highlights`), floating combat text pooling, SFX dispatch, and enemy AI into a single script.

---

### 3.2 Lack of Domain Signals Forcing Fragile UI Polling / Refresh Cascades
* **File:** [`scripts/autoload/game_session.gd:44-57`](file:///home/ryan/play/fantasy-tactics/scripts/autoload/game_session.gd#L44-L57), [`scripts/ui/camp_nav.gd`](file:///home/ryan/play/fantasy-tactics/scripts/ui/camp_nav.gd), [`scripts/ui/information_panel.gd`](file:///home/ryan/play/fantasy-tactics/scripts/ui/information_panel.gd)
* **Finding:** `GameSession` only defines 3 signals (`campaign_progress_changed`, `campaign_victory`, `journal_updated`). It has no signals for `gold_changed`, `party_updated`, `roster_changed`, `inventory_changed`, or `building_upgraded`.
* **Impact:** Persistent UI components like [`CampNav`](file:///home/ryan/play/fantasy-tactics/scripts/ui/camp_nav.gd) and [`InformationPanel`](file:///home/ryan/play/fantasy-tactics/scripts/ui/information_panel.gd) cannot reactively update; every screen must manually remember to invoke `refresh()` on children in every mutation callback.

---

### 3.3 Severe Code Duplication: `unit_details.gd` vs `unit_detail_card.gd`
* **File:** [`scripts/ui/unit_details.gd`](file:///home/ryan/play/fantasy-tactics/scripts/ui/unit_details.gd) (452 lines) & [`scripts/ui/unit_detail_card.gd`](file:///home/ryan/play/fantasy-tactics/scripts/ui/unit_detail_card.gd) (318 lines)
* **Finding:** When [`CardNavigator`](file:///home/ryan/play/fantasy-tactics/scripts/ui/card_navigator.gd) was introduced, `unit_detail_card.gd` was created. `unit_details.gd` remains as a full-screen scene with ~450 lines of duplicate logic (stat strings, promotions, gear, healing, party assignment).
* **Recommendation:** Refactor `unit_details.gd` to host `UnitDetailCard` inside its container or eliminate the legacy scene.

---

## 4. Godot 4 Idioms, Performance & Memory Management

### 4.1 Node Allocation and Garbage Churn on Mouse Motion
* **Files:** [`scripts/world/world_map.gd:122-126`](file:///home/ryan/play/fantasy-tactics/scripts/world/world_map.gd#L122-L126), [`scripts/battle/battle_controller.gd:2884-2962`](file:///home/ryan/play/fantasy-tactics/scripts/battle/battle_controller.gd#L2884-L2962)
* **Issue:** In both World Map route previews and Battle grid highlights, every `InputEventMouseMotion` clears the container via `queue_free()` and instantiates 10–30 new `ColorRect` and `Label` nodes per event. High-polling gaming mice generate thousands of node allocations/deallocations per second.
* **Recommendation:** Cache the hovered tile position (`if tile_pos == _last_hovered_tile: return`) and use custom `_draw()` canvas items or static pooled highlight grids instead of dynamic Node instantiation.

### 4.2 Synchronous Disk I/O in `ContentCatalog` Getter Queries
* **File:** [`scripts/content/content_catalog.gd:113-163`](file:///home/ryan/play/fantasy-tactics/scripts/content/content_catalog.gd#L113-L163)
* **Issue:** `ContentCatalog.get_encounter_definition()` re-reads `catalog.json` and all encounter JSONs from disk on every invocation via `load_catalog()`. During world turns and scouting updates, 50+ file read/parse cycles occur in a single tick.
* **Recommendation:** Cache parsed encounter definitions in memory on startup.

### 4.3 Missing `class_name` Declarations & Untyped Parameters
* **Files:** [`scripts/battle/unit.gd`](file:///home/ryan/play/fantasy-tactics/scripts/battle/unit.gd), [`scripts/battle/grid.gd`](file:///home/ryan/play/fantasy-tactics/scripts/battle/grid.gd), [`scripts/battle/battle_controller.gd`](file:///home/ryan/play/fantasy-tactics/scripts/battle/battle_controller.gd)
* **Issue:** Core combat classes lack `class_name` declarations, forcing other scripts to use `preload(...)` constants and declare parameters as generic `Node2D` or untyped `RefCounted`.
* **Recommendation:** Add `class_name Unit`, `class_name BattleGrid`, `class_name BattleController`, and `class_name FloatingText`.

### 4.4 Perceptually Non-Linear Decibel Crossfading in Audio Manager
* **File:** [`scripts/autoload/audio_manager.gd:302-308`](file:///home/ryan/play/fantasy-tactics/scripts/autoload/audio_manager.gd#L302-L308)
* **Issue:** `_music_tween` tweens `volume_db` linearly from `-80.0 dB` to `0.0 dB`. Because decibels are logarithmic, the outgoing track drops by 90% volume in the first 25% of the fade duration, while the incoming track remains inaudible until the final 25%, creating a noticeable dip in volume mid-crossfade.
* **Recommendation:** Tween linear volume `0.0 -> 1.0` and convert to dB via `linear_to_db()` using `tween_method()`.

---

## 5. Prioritized Action Plan & Refactoring Roadmap

### Phase 1: High-Priority Bug Fixes (Immediate)
1. **Fix Opportunity Attack Log Crash**: Add `reaction` step handling in [`battlefield.gd:_describe_step()`](file:///home/ryan/play/fantasy-tactics/scripts/battle/battlefield.gd#L710).
2. **Fix World Map Modal Click-Through**: Consume input and block background clicks in [`world_map.gd`](file:///home/ryan/play/fantasy-tactics/scripts/world/world_map.gd).
3. **Fix Save Repository Key Normalization**: Scope integer conversion specifically to `mana_crystals` in [`campaign_snapshot.gd`](file:///home/ryan/play/fantasy-tactics/scripts/save/campaign_snapshot.gd).
4. **Fix Snapshot MP Validation**: Dynamically read class MP limits from [`GameConfig`](file:///home/ryan/play/fantasy-tactics/scripts/autoload/game_config.gd).
5. **Fix Guild Hall Recruitment Vacancies**: Trigger vacancy refills up to new cap in [`game_session.gd:upgrade_guild_hall()`](file:///home/ryan/play/fantasy-tactics/scripts/autoload/game_session.gd#L2430).
6. **Fix Mutability Leaks**: Ensure `get_selected_party()` returns `duplicate(true)`.

### Phase 2: Performance & Catalog Optimization
1. **Cache `ContentCatalog`**: Cache loaded encounter JSONs in memory to eliminate per-turn disk I/O.
2. **Mouse Motion Throttling**: Cache hovered tile positions in [`world_map.gd`](file:///home/ryan/play/fantasy-tactics/scripts/world/world_map.gd) and [`battle_controller.gd`](file:///home/ryan/play/fantasy-tactics/scripts/battle/battle_controller.gd).
3. **Externalize Static Catalogs**: Move static dictionary tables (`WEAPONS`, `ARMORS`, `CLASS_DEFINITIONS`, `EXPEDITIONS`, `CAMPAIGN_OBJECTIVES`) from `GameSession.gd` into dedicated static catalog scripts (mirroring [`PerkCatalog`](file:///home/ryan/play/fantasy-tactics/scripts/progression/perk_catalog.gd)).

### Phase 3: Domain Service Extractions & Reactive Architecture
1. **Extract Domain Services from `GameSession`**:
   - `WorkshopService` (Blacksmith, Alchemy, Runic crafting jobs)
   - `InventoryService` (Item instances, modifiers, equipment management)
   - `IntelligenceService` (Scouting, Intel tiers, Quests)
   - `RecruitmentService` (Candidate generation, vacancy timing)
   - `TradeService` (Shop economy, buy/sell transactions)
2. **Introduce Domain Signals**: Add `gold_changed`, `party_updated`, `roster_changed`, and `inventory_changed` to `GameSession`.
3. **Decompose `BattleController`**: Separate pure `BattleSimulation` (domain rules/state) from `BattleView` (sprites/highlights) and `EnemyAI`.
