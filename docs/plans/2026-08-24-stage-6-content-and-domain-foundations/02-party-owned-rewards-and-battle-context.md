# Step 2 — Party-Owned Rewards and Battle Context

**Branch:** `refactor/party-owned-rewards`

**Depends on:** Step 1 locally merged; G4 closed.

**Milestone:** Two deployed parties independently carry, equip, and bank their own rewards without cross-party interference, while an explicit `BattleContext` governs active combat lifecycle and attribution.

## Files

- Modify: `scripts/autoload/game_session.gd`, `scripts/autoload/game_manager.gd`, `scripts/save/campaign_snapshot.gd`.
- Modify: `scripts/battle/battle_controller.gd`, `scripts/battle/battlefield.gd`, `scripts/ui/battle_result.gd`, `scripts/ui/party_details.gd`, `scripts/ui/information_panel.gd`, `scripts/ui/stores.gd`, `scripts/ui/victory_screen.gd`, and any scene/script that reads `pending_*` or `battle_*`.
- Modify: `scripts/tools/campaign_sim.gd` and scenario fixtures needed to pass explicit party/battle IDs.
- Test: `tests/unit/test_game_session.gd`, `tests/unit/test_campaign_snapshot.gd`, `tests/unit/test_party_details.gd`, `tests/unit/test_battle_result.gd`, `tests/unit/test_campaign_recovery.gd`, `tests/unit/test_game_manager.gd`, and a new focused multi-party journey test (`tests/unit/test_multi_party_carry.gd`).

## Red/green tasks

1. **Write failing unit tests for Party Carry isolation:**
   - Create two deployed parties (`party_001`, `party_002`).
   - Assign distinct carried gold, stacked gear, mana crystals, and unique item instances to `party_001.carry` and `party_002.carry`.
   - Assert that:
     - Depositing `party_001`'s carry into Encampment bank leaves `party_002`'s carry untouched.
     - `party_001` wiping in battle forfeits only `party_001`'s carry, leaving `party_002` intact.
     - `party_001` retreating from combat applies loot loss only to `party_001`.
     - In-field equipping (`equip_item_from_party_carry`) draws strictly from the target party's carry dictionary.
     - Dead party member salvage in battle transfers dropped equipment directly into that party's carry.
2. **Run focused GUT tests red:**
   - Run `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gselect=test_multi_party_carry.gd -gexit` and record failures stemming from global `pending_*`/`battle_*` storage.
3. **Refactor Party Data Structure & Eliminate Globals:**
   - Add `carry` dictionary to every party entry in `GameSession.parties`:
     ```gdscript
     "carry": {
         "gold": 0,
         "gear": {} as Dictionary, # item_id -> count
         "mana_crystals": {} as Dictionary, # crystal_id -> count
         "item_instance_ids": [] as Array[String],
     }
     ```
   - Retire campaign-wide global variables from `GameSession`:
     - Delete `var pending_reward: int`
     - Delete `var pending_mana_crystals: Dictionary`
     - Delete `var pending_gear: Dictionary`
     - Delete `var battle_reward: int`
     - Delete `var battle_mana_crystals: Dictionary`
     - Delete `var battle_gear: Dictionary`
     - Delete `var active_battle_party_id: String`
4. **Implement Explicit Party Carry & BattleContext APIs in `GameSession`:**
   - `get_party_carry(party_id: String) -> Dictionary`
   - `deposit_party_carry(party_id: String) -> Dictionary` (moves party carry to Encampment `gold`, `banked_gear`, `mana_crystals`, and `banked_item_instance_ids`)
   - `forfeit_party_carry(party_id: String) -> void` (clears carry on wipe)
   - `transfer_dead_unit_gear_to_party_carry(party_id: String, unit_id: String) -> void`
   - `equip_item_from_party_carry(party_id: String, adventurer_id: String, item_id: String) -> bool`
   - `create_battle_context(party_id: String, encounter_id: String, seed: int = 0) -> Dictionary`
   - `get_active_battle_context() -> Dictionary`
   - `resolve_battle_victory(battle_id: String) -> bool` (transfers battle reward into owning party's `carry`)
   - `resolve_battle_retreat(battle_id: String) -> bool` (discards battle reward, applies retreat penalty)
   - `resolve_battle_defeat(battle_id: String) -> bool` (discards battle reward, forfeits party carry)
5. **Update UI Callers:**
   - `party_details.gd`: Render carried loot strictly from `GameSession.get_party_carry(current_party_id)`.
   - `victory_screen.gd` & `battle_result.gd`: Query the active `BattleContext` for earned gold/gear/crystals.
   - `information_panel.gd`: Bind party carry display to the currently selected party.
   - `world_map.gd`: Pass explicit `party_id` when checking settlement arrival and triggering encampment deposit.
6. **Update Save Snapshot (`CampaignSnapshot`):**
   - Include `carry` inside each party dictionary in `parties`.
   - Remove root-level `pending_*` and `battle_*` fields.
   - Validate that `carry` conforms to `{ gold: int >= 0, gear: dict, mana_crystals: dict, item_instance_ids: array }` before applying.
   - Reject corrupt or malformed carry records transactionally.
7. **Thread Explicit Ownership Through CampaignSim & Scenario Runner:**
   - Update `CampaignSim` to manage multi-party deployments and per-party carry tracking.
   - Add deterministic two-party simulation test: Party A completes an encounter and banks loot while Party B remains deployed in transit with its own carry undisturbed.
8. **Run All Tests Green & Complete Common Final Checks:**
   - `make campaign-sim`
   - `make check`
   - `godot --headless --path . --editor --quit`
   - `git diff --check`

## Manual check

In `make play`:
1. Form two parties in the Encampment and deploy both to separate encounters on the World Map.
2. Resolve the battle for Party 1, inspect its victory rewards and carried loot on Party Details.
3. Switch selection to Party 2 and confirm Party 2's carried loot is completely empty and independent.
4. Route Party 1 back to the Encampment and verify its loot is banked into Encampment stores, while Party 2 remains deployed in the field.
5. Enter battle with Party 2, retreat, and verify that Party 2 suffers retreat consequences without impacting banked Encampment gold or Party 1.

## Commit and local merge

After review and user signoff, commit only the party ownership refactor and tests as `refactor(campaign): make carried rewards and battle context party-owned`, merge locally to `main`, and delete the branch.
