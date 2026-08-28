# Code Audit Findings & Architectural Review

**Date**: 2026-08-29
**Scope**: Source-verified audit of Fantasy Tactics (Battle, Campaign & Session State, Persistence & Audio, UI & World Map)
**Objective**: Separate confirmed player-facing defects from latent extensibility risks and longer-term maintainability opportunities. Severity reflects demonstrated impact, not code size alone.

---

## 1. Executive Summary & Health Scorecard

| Area | Grade | Strengths | Key Concerns |
|---|:---:|---|---|
| **Combat & Battle** | **B-** | Deterministic AI policy, rich status/perk resolution, clean tile geometry. | One confirmed reaction-step crash; one confirmed playback-state presentation defect; the controller remains oversized. |
| **Campaign & State** | **C+** | Service extractions and broad automated coverage. | Guild Hall upgrades do not populate newly unlocked offer slots; `GameSession` remains a large facade over mutable state. |
| **Persistence & Save** | **B+** | Deep-copy snapshots, atomic campaign-save writes, strict validation. | MP validation conflicts with configurable caps; global numeric-key normalization is a latent schema constraint. |
| **Audio & Tooling** | **A-** | Excellent headless simulation tools and soft-failing audio loader. | Crossfade and settings-write concerns require measurement or product direction before prioritization. |
| **UI & World Map** | **B** | Standardized `CardNavigator` and consistent Encampment navigation. | Confirmed modal click-through; duplicate detail presentation and refresh architecture are maintenance concerns. |

---

## 2. Confirmed player-facing defects

### 2.1 [HIGH] Runtime crash on an enemy opportunity-attack playback step
* **File:** [`scripts/battle/battlefield.gd:732`](file:///home/ryan/play/fantasy-tactics/scripts/battle/battlefield.gd#L732)
* **Description:** When an enemy unit moves during `run_enemy_turn()` and triggers a player unit's Attack of Opportunity, `_take_enemy_unit_actions()` appends `last_reaction_results` directly to `steps`. A reaction step dictionary has the structure `{"type": "reaction", "reactor": ..., "mover": ..., "damage": ...}` — it lacks a `"unit"` key.
* **Failure Mode:** In `_describe_step()`, unhandled types fall through to:
  ```gdscript
  var mover_name: String = tr(SIDE_NAME_KEYS[step.unit.side])
  ```
  Evaluating `step.unit.side` crashes with `Invalid get index 'side' on base 'Nil'`.
* **Why HIGH, not critical:** it terminates a battle interaction but does not establish save corruption, data loss, or a startup-wide failure.
* **Recommendation:** Add a dedicated handler for `step.type == "reaction"` in [`_describe_step()`](file:///home/ryan/play/fantasy-tactics/scripts/battle/battlefield.gd#L710), with a focused scene-level regression that drives an enemy move which provokes a reaction.

---

### 2.2 [HIGH] World Map Modals Allow Click-Through to Tiles Behind Them
* **File:** [`scripts/world/world_map.gd:116-160`](file:///home/ryan/play/fantasy-tactics/scripts/world/world_map.gd#L116-L160), [`scenes/world/world_map.tscn`](file:///home/ryan/play/fantasy-tactics/scenes/world/world_map.tscn)
* **Description:** `%ArrivalPanel` ("Enter / Withdraw / Cancel") and `%SendPartyModal` are floating `PanelContainer`s without a full-screen input blocker (`MOUSE_FILTER_STOP`).
* **Failure Mode:** In `_unhandled_input()`, clicks outside the panel boundaries pass through to `_handle_tile_click()`, repathing or moving the party while the modal remains open with stale encounter data. Furthermore, pressing Escape (`ui_cancel`) opens the pause menu instead of dismissing the active modal.
* **Recommendation:** In `_unhandled_input()`, consume clicks and handle `ui_cancel` when modals are visible, and back dialogs with full-screen `MOUSE_FILTER_STOP` blockers (or integrate [`ModalDialog`](file:///home/ryan/play/fantasy-tactics/scripts/ui/modal_dialog.gd)).

---

### 2.3 [MEDIUM] Global JSON key normalization is a latent schema hazard
* **File:** [`scripts/save/save_repository.gd:184-188`](file:///home/ryan/play/fantasy-tactics/scripts/save/save_repository.gd#L184-L188), [`scripts/save/campaign_snapshot.gd:826,857,898`](file:///home/ryan/play/fantasy-tactics/scripts/save/campaign_snapshot.gd#L826)
* **Description:** `SaveRepository._normalize_json_key()` runs globally across every Dictionary in the parsed JSON tree:
  ```gdscript
  static func _normalize_json_key(key: Variant) -> Variant:
      if key is String and key.is_valid_int():
          return int(key)
      return key
  ```
* **Failure Mode:** A numeric-only key in `quests`, `tutorial_progress`, `encounter_intel`, or `owned_item_instances` would become an `int`; the strict snapshot normalizers reject such keys. Current generated IDs include non-digit characters, so no current save is known to trigger this.
* **Recommendation:** Before adding a numeric-only ID namespace, either make the conversion schema-aware (only crystal tiers become integers) or explicitly forbid numeric-only keys at every affected write boundary. Add a real JSON round-trip regression for the selected policy.

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

### 2.6 [MEDIUM] Enemy-turn playback redraws already-mutated state
* **File:** [`scripts/battle/battlefield.gd:329-337`](file:///home/ryan/play/fantasy-tactics/scripts/battle/battlefield.gd#L329-L337), [`scripts/battle/battle_controller.gd:2245`](file:///home/ryan/play/fantasy-tactics/scripts/battle/battle_controller.gd#L2245)
* **Description:** `grid.run_enemy_turn()` executes the entire enemy turn synchronously in memory before `_play_enemy_turn()` begins playing back step animations.
* **Failure Mode:** During delayed playback, `_play_enemy_turn()` calls `_draw_units()` on each step, reading the mutated final state:
  1. A player unit killed on Step 4 disappears from the grid immediately on Step 1.
  2. Enemy units visually appear at their final destination tiles before their movement step plays.
* **Recommendation:** Record per-step visual state or execute one simulation step per playback beat. This is a presentation-correctness issue, not a rules-state desynchronization.

---

### 2.7 [MEDIUM] Public selected-party access returns a mutable reference
* **File:** [`scripts/campaign/party_service.gd:80-90`](file:///home/ryan/play/fantasy-tactics/scripts/campaign/party_service.gd#L80-L90)
* **Description:** `get_selected_party()` returns the stored Dictionary, whereas `get_party(id)` deep-copies it. `_get_party_for_adventurer()` is private and its direct reference is an internal implementation detail, not a public API leak.
* **Impact:** An external caller can bypass party validation by mutating a selected-party result. The audit did not identify a production caller doing so; [`assign_equipment.gd`](file:///home/ryan/play/fantasy-tactics/scripts/ui/assign_equipment.gd#L73) instead reads the public `adventurers` array and is not evidence for this getter.
* **Recommendation:** Decide whether `get_selected_party()` is a query or an internal mutation helper. If it is a query, return `duplicate(true)` and add a defensive-copy regression; otherwise rename/document it as an internal mutable accessor.

---

## 3. Architectural follow-ups — not immediate bug fixes

### 3.1 Monolithic God Objects

```
┌─────────────────────────────────────────────────────────────┐
│                    GameSession.gd (4,863 lines)             │
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

1. **[`GameSession.gd`](file:///home/ryan/play/fantasy-tactics/scripts/autoload/game_session.gd) (4,863 lines):**
   - **Static catalogs:** Encounters, equipment, classes, and loot still live beside durable state.
   - **~600 lines of forwarders:** Thin 1-line delegations to `PartyService`, `EncounterService`, and `ProgressionService`.
   - **Remaining domains:** Workshop/Crafting, Inventory/Equipment, Trade/Shop, Intel/Quests, Recruitment/Roster, Journal/Guidance, and snapshot orchestration remain concentrated here.
   - **Assessment:** this is a real maintainability and expansion risk, but not proof that a large rewrite is currently safe. The extracted services deliberately share one durable-state owner; preserve that invariant while extending the existing Stage 6 catalog/domain work in small verified slices.

2. **[`BattleController.gd`](file:///home/ryan/play/fantasy-tactics/scripts/battle/battle_controller.gd) (2,961 lines):**
   - Merges combat rules & formulas, spell/perk execution, spatial grid representations, entity instantiation, 2D scene graph rendering (`_draw_tiles`, `_draw_units`, `_update_highlights`), floating combat text pooling, SFX dispatch, and enemy AI into a single script.

---

### 3.2 Sparse domain signals create a maintenance cost
* **File:** [`scripts/autoload/game_session.gd:44-57`](file:///home/ryan/play/fantasy-tactics/scripts/autoload/game_session.gd#L44-L57), [`scripts/ui/camp_nav.gd`](file:///home/ryan/play/fantasy-tactics/scripts/ui/camp_nav.gd), [`scripts/ui/information_panel.gd`](file:///home/ryan/play/fantasy-tactics/scripts/ui/information_panel.gd)
* **Finding:** `GameSession` only defines 3 signals (`campaign_progress_changed`, `campaign_victory`, `journal_updated`). It has no signals for `gold_changed`, `party_updated`, `roster_changed`, `inventory_changed`, or `building_upgraded`.
* **Impact:** screens use explicit refresh chains. This is a maintainability concern, not a demonstrated stale-UI bug: `journal_updated` already provides a working reactive precedent.
* **Recommendation:** introduce a domain signal only where a concrete stale-state or repeated refresh-chain regression is demonstrated; do not add a broad signal inventory preemptively.

---

### 3.3 Substantial detail-view duplication
* **File:** [`scripts/ui/unit_details.gd`](file:///home/ryan/play/fantasy-tactics/scripts/ui/unit_details.gd) (452 lines) & [`scripts/ui/unit_detail_card.gd`](file:///home/ryan/play/fantasy-tactics/scripts/ui/unit_detail_card.gd) (318 lines)
* **Finding:** When [`CardNavigator`](file:///home/ryan/play/fantasy-tactics/scripts/ui/card_navigator.gd) was introduced, `unit_detail_card.gd` was created. `unit_details.gd` remains as a full-screen scene with ~450 lines of duplicate logic (stat strings, promotions, gear, healing, party assignment).
* **Assessment:** this is a credible cleanup target, but the full-screen view and embedded card have different route/focus responsibilities. Confirm those responsibilities can be composed before replacing the former with the latter.

---

## 4. Performance and idiom candidates — require targeted evidence

### 4.1 World Map route previews allocate nodes for every mouse-motion event
* **File:** [`scripts/world/world_map.gd:116-125`](file:///home/ryan/play/fantasy-tactics/scripts/world/world_map.gd#L116-L125), [`scripts/world/world_map.gd:318-323`](file:///home/ryan/play/fantasy-tactics/scripts/world/world_map.gd#L318-L323)
* **Issue:** `_update_hover_route()` always calls `_draw_routes()`, which frees and rebuilds route nodes. This happens even when the pointer remains on the same tile.
* **Qualification:** the same claim is not established for the Battlefield: it rebuilds highlights only when the hovered **unit** changes.
* **Recommendation:** cache the last hover tile or route before redrawing the World Map preview; profile before replacing it with a pooled/canvas implementation.

### 4.2 ContentCatalog reloading is intentional, not a confirmed performance defect
* **File:** [`scripts/content/content_catalog.gd:113-163`](file:///home/ryan/play/fantasy-tactics/scripts/content/content_catalog.gd#L113-L163)
* **Finding:** `get_encounter_definition()` reloads content, but the loader explicitly chooses this to make hand-edited JSON take effect without restart. The audit found no evidence of 50+ reads in a World Map tick; current call sites are battle setup, campaign simulation, and expedition lookup boundaries.
* **Recommendation:** retain the current behavior unless profiling shows a real hitch or the content set grows enough to invalidate the documented turn-based trade-off. A cache would need an explicit reload/invalidation contract.

### 4.3 Missing `class_name` declarations and loose types
* **Files:** [`scripts/battle/unit.gd`](file:///home/ryan/play/fantasy-tactics/scripts/battle/unit.gd), [`scripts/battle/grid.gd`](file:///home/ryan/play/fantasy-tactics/scripts/battle/grid.gd), [`scripts/battle/battle_controller.gd`](file:///home/ryan/play/fantasy-tactics/scripts/battle/battle_controller.gd)
* **Issue:** Core combat classes lack `class_name` declarations, forcing other scripts to use `preload(...)` constants and declare parameters as generic `Node2D` or untyped `RefCounted`.
* **Assessment:** reasonable incremental cleanup, but not a correctness or performance finding. Adopt only with a focused parser/editor validation because global class names alter project-wide type resolution.

### 4.4 Audio crossfade shape and settings persistence
* **File:** [`scripts/autoload/audio_manager.gd:302-308`](file:///home/ryan/play/fantasy-tactics/scripts/autoload/audio_manager.gd#L302-L308)
* **Finding:** the implementation does tween dB values directly, and settings are written directly rather than through the campaign save's atomic-write path. Neither concern has a reproduction, perceptual playtest, or measured failure attached.
* **Recommendation:** record a short listening check for the crossfade and decide whether settings-file interruption recovery matters before changing either path. If adopted, test an equal-power or linear-amplitude fade and atomic settings replacement separately.

---

## 5. Revised execution order

### Phase 1: Confirmed defects — plan and implement serially

1. **Reaction-step crash:** add reaction-specific presentation handling and a
   scene-level regression that exercises an enemy move provoking an
   opportunity attack.
2. **World Map modal input:** block background clicks, make Escape dismiss the
   active dialog, and test both Arrival and Send Party flows through actual
   input routing.
3. **Recruitment-cap upgrade:** decide whether new slots appear immediately or
   through normal vacancy timing, then test the selected behavior at both Guild
   Hall upgrades.
4. **Configurable MP snapshots:** make snapshot validation/migration use the
   same MP-cap source as runtime, with a temporary non-default `GameConfig`
   regression.
5. **Enemy playback state:** choose snapshot-based playback or incremental
   simulation, then verify that early beats render their own state.

Each is a separate behavior change requiring red/green focused tests, the
full suite, and a manual `make play` check where visual/input behavior is
involved.

### Phase 2: Bounded hardening after Phase 1

1. Set and test a policy for numeric-only persisted dictionary keys; do not
   change JSON normalization until that policy is chosen.
2. Make `get_selected_party()` defensive if it remains a public query, and add
   a mutation-isolation regression.
3. Avoid redundant World Map route-preview redraws, with profiling before any
   larger rendering rewrite.

### Phase 3: Extend existing architecture work deliberately

Continue the existing content/domain extraction direction in small slices:
catalog ownership first, then a bounded domain service or battle presentation
seam only when a concrete change is blocked by the current shape. Do not start
a parallel wholesale `GameSession`/`BattleController` rewrite, add broad
signals without a demonstrated stale-state failure, or cache `ContentCatalog`
without an explicit live-reload replacement.

## 6. Verification boundary

This document records source inspection and a full automated-suite baseline,
not reproductions of every defect. The suite passed on 2026-08-28 with 2,333
tests and 10,025 assertions; it does not currently cover the reaction playback
crash, modal click-through/Escape routing, expanded recruitment vacancies,
non-default MP-cap snapshots, or per-step enemy rendering. Each Phase 1 item
must add a reproducing test before implementation.
