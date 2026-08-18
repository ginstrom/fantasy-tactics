# Step 1: Campaign Progression State, Objectives Graph, and Onboarding Flow

**Date:** 2026-08-18
**Status:** proposed
**Branch:** `feat/campaign-state-and-onboarding`
**Part of:** [`docs/plans/2026-08-18-core-loop-and-engagement/index.md`](index.md)

---

## Summary

Establish the durable campaign progression contract and onboarding flow. Scope the active campaign to exactly one party (`party_001`), initialize and track versioned campaign milestone progression in `GameSession` (current objective, completed objective IDs, unlocked authored encounters, victory state, and free-play state) separate from repeatable sandbox vacancies. Persist this state through `CampaignSnapshot` with backwards-compatible save migration. Streamline onboarding so starting a new game routes directly into party formation and introduces the initial objective. Surface the active objective and final victory goal in the Encampment and World Map UI.

---

## Technical Design

### 1. Single Party Scope & ID Invariant (`scripts/autoload/game_session.gd`)
- Assert `get_max_party_count()` strictly returns `1`.
- Ensure the single party is identified as `FIRST_PARTY_ID = "party_001"`.
- Reject any attempt to spawn additional parties beyond `party_001` in the campaign loop.

### 2. Campaign Progression Model (`scripts/autoload/game_session.gd`)
- Add durable progression variables to `GameSession` and the complete immutable authored-node catalog. This step is the sole owner of objective ids and encounter ids; later steps fill in the catalog's composition and balance values rather than introduce a second naming scheme:
  - `campaign_objective_id: String = "obj_tier1_1_goblin_outpost"`
  - `completed_objectives: Array[String] = []`
  - `unlocked_authored_encounters: Array[String] = ["obj_tier1_1_goblin_outpost"]`
  - `is_campaign_completed: bool = false`
  - `is_free_play_active: bool = false`
- Define the authored objective definitions table in `GameSession`:
  ```gdscript
  const CAMPAIGN_OBJECTIVES: Dictionary = {
      "obj_tier1_1_goblin_outpost": {
          "title_key": "campaign.obj.tier1_1.title",
          "desc_key": "campaign.obj.tier1_1.desc",
          "tier": 1,
          "encounter_id": "obj_tier1_1_goblin_outpost",
          "next_objective_id": "obj_tier1_2_kobold_warren",
          "reward_summary_key": "campaign.obj.tier1_1.reward",
      },
      # All twelve nodes are declared here with stable ids, prerequisite id,
      # position, reward contract, counterplay text, and loss consequence.
  }
  ```
- Methods:
  - `get_current_campaign_objective() -> Dictionary`
  - `is_objective_completed(id: String) -> bool`
  - `complete_campaign_objective(id: String) -> void`: Atomically moves `id` to `completed_objectives`, unlocks the next authored encounter in `unlocked_authored_encounters`, and advances `campaign_objective_id`.
  - `set_campaign_victory() -> void`: Sets `is_campaign_completed = true` and `is_free_play_active = true`.

### 3. Campaign Snapshot Serialization & Migration (`scripts/save/campaign_snapshot.gd`)
- Bump `FORMAT_VERSION := 2`.
- Add snapshot fields:
  - `var campaign_objective_id: String = "obj_tier1_1_goblin_outpost"`
  - `var completed_objectives: Array[String] = []`
  - `var unlocked_authored_encounters: Array[String] = ["obj_tier1_1_goblin_outpost"]`
  - `var is_campaign_completed: bool = false`
  - `var is_free_play_active: bool = false`
- Update `to_dictionary()` and `from_dictionary()`:
  - Handle `version: 1` saves gracefully: normalize missing fields to default starting campaign values (or infer completed objectives based on `completed_encounters`).
  - Strict validation of all campaign objective fields for `version: 2` payloads.

### 4. Streamlined Onboarding Routing (`scripts/autoload/game_manager.gd` & `scripts/ui/start_menu.gd`)
- Retain `GameManager.go_to_game()` as the New Game entry point. After it resets `GameSession`, route directly to the existing Parties flow (`GameManager.go_to_parties(true)`) rather than inventing a parallel `start_new_campaign()` router or relying on a generic settlement scene.
- Guide messages introduce the first objective: clearing the Goblin Outpost to secure the Encampment perimeter.

### 5. Campaign Objective Banner UI (`scenes/ui/encampment.tscn`, `scenes/world/world_map.tscn`)
- Add `CampaignObjectiveBanner` UI component (displaying current objective title, brief description, and progress indicator).
- Embed in `Encampment` HUD and `WorldMap` HUD.
- Update banner on `board_changed` / world-turn progression.

### 6. Localization Strings (`translations/en.tres`)
- Add keys:
  - `campaign.objective.label`: `"Active Objective:"`
  - `campaign.victory.goal_label`: `"Campaign Goal: Defeat the Borderlands Ogre"`
  - `campaign.obj.tier1_1.title`: `"Scout the Perimeter"`
  - `campaign.obj.tier1_1.desc`: `"Form a party and clear the Goblin Outpost."`
  - `campaign.obj.tier1_1.reward`: `"50 Gold, Iron Weapon"`
  - `campaign.free_play.active_label`: `"Free Play Mode Active"`

---

## Setup

```bash
git checkout main && git pull
git checkout -b feat/campaign-state-and-onboarding
make check   # confirm clean baseline before changes
```

---

## TDD Task List (Red → Green)

Write failing unit tests first, verify failure, implement changes, and confirm `make check` passes.

1. **Party Count Invariant ([`tests/unit/test_game_session.gd`](../../../tests/unit/test_game_session.gd)):**
   - Test `GameSession.get_max_party_count()` returns `1`.
   - Test attempting to create a second party fails or returns an error.

2. **Campaign Objective Progression in `GameSession` ([`tests/unit/test_game_session.gd`](../../../tests/unit/test_game_session.gd)):**
   - Test all twelve ids are unique, each non-first node has an existing prerequisite, and the starting objective is `obj_tier1_1_goblin_outpost`.
   - Test `complete_campaign_objective("obj_tier1_1_goblin_outpost")` marks it completed, unlocks the next objective and encounter, and emits `board_changed` / campaign state signals.
   - Test completing an objective is idempotent (cannot complete twice or corrupt state).
   - Test `set_campaign_victory()` atomically flags victory and free play.

3. **CampaignSnapshot Serialization & Migration ([`tests/unit/test_campaign_snapshot.gd`](../../../tests/unit/test_campaign_snapshot.gd)):**
   - Test `to_dictionary()` exports `version: 2` with all campaign progression fields.
   - Test `from_dictionary()` validates and deserializes format version 2 snapshots.
   - Test backward-compatibility migration: importing a `version: 1` dictionary safely assigns the valid authored-node state derived from completed encounters, without crashing or dropping roster/building state.
   - Test round-trip serialization preservation.

4. **New Game Onboarding Flow ([`tests/unit/test_start_menu.gd`](../../../tests/unit/test_start_menu.gd) & [`tests/unit/test_game_manager.gd`](../../../tests/unit/test_game_manager.gd)):**
   - Test clicking "New Game" routes to party formation rather than a generic settlement view.
   - Test party formation screen prompts the player to assign initial members to `party_001`.

5. **Campaign Objective Banner Component ([`tests/unit/test_encampment.gd`](../../../tests/unit/test_encampment.gd) & [`tests/unit/test_world_map.gd`](../../../tests/unit/test_world_map.gd)):**
   - Test `Encampment` displays the active campaign objective string.
   - Test `WorldMap` displays the active campaign objective string.
   - Test objective banner updates immediately when campaign objective advances.

6. **Localization Keys ([`tests/unit/test_localization.gd`](../../../tests/unit/test_localization.gd)):**
   - Test all new `campaign.obj.*`, `campaign.objective.*`, and `campaign.victory.*` localization keys resolve properly.

---

## Verification

```bash
make check
```

Expected output: All unit tests pass with zero errors, zero orphans, and zero warnings.

---

## Manual Verification (User Sign-off)

1. Launch the game via `make play`.
2. Click **New Game** on the title menu.
3. Verify the game routes directly to the **Party Formation / Deploy** screen with guidance to recruit and assign adventurers.
4. Form a party of 3 members and navigate to the **Encampment**.
5. Verify the **Active Objective** banner appears at the top of the Encampment screen showing "Scout the Perimeter: Clear the Goblin Outpost".
6. Navigate to the **World Map**.
7. Verify the objective banner is visible on the World Map and points towards the first encounter.
8. Save and exit the game via Game Menu, then restart `make play` and click **Continue**.
9. Verify the campaign objective state, party, and progress persist accurately.

---

## Commit and Merge

```bash
git status --short
git add scripts/autoload/game_session.gd scripts/autoload/game_manager.gd scripts/save/campaign_snapshot.gd scripts/ui/start_menu.gd scripts/ui/encampment.gd scripts/world/world_map.gd scenes/ui/encampment.tscn scenes/world/world_map.tscn translations/en.tres tests/unit/test_game_session.gd tests/unit/test_campaign_snapshot.gd tests/unit/test_game_manager.gd tests/unit/test_start_menu.gd tests/unit/test_encampment.gd tests/unit/test_world_map.gd tests/unit/test_localization.gd
git diff --cached --check
git commit -m "feat(campaign): implement campaign progression state, snapshot migration, and onboarding flow"

# After user sign-off:
git checkout main
git merge feat/campaign-state-and-onboarding
git branch -d feat/campaign-state-and-onboarding
```

---

## Milestone (Concretely Verifiable)

- Durable campaign objective state exists in `GameSession`, tested across progression and versioned `CampaignSnapshot` save/load.
- New game start routes immediately to party formation with clear starting objective.
- Objective UI is visible in Encampment and World Map scenes.
- `make check` passes 100% green.
