# Step 2: Defeat, Permadeath, Tactical Retreat, and Economy Floor

**Date:** 2026-08-18
**Status:** proposed
**Branch:** `feat/permadeath-retreat-and-economy`
**Part of:** [`docs/plans/2026-08-18-core-loop-and-engagement/index.md`](index.md)

---

## Summary

Implement the high-stakes permadeath and defeat mechanics while establishing the anti-soft-lock economy safety floor. Units reaching 0 HP in battle are permanently removed at battle resolution, with their equipped and carried gear transferred atomically to the party loot pool. Implement a tactical **Retreat** button on the battle action bar that resolves distance-based survival consequences and leaves the party on the encounter map tile. Implement party wipe resolution (returning to Encampment and forfeiting carried loot without resetting campaign objectives). Guarantee recovery via passive Shop income (2/5/10 gold/turn), zero-party turn advancement, and affordable recruitment replenishment.

---

## Technical Design

### 1. Unit Permadeath Resolution (`scripts/autoload/game_session.gd` & `scripts/battle/battlefield.gd`)
- Add one `GameSession.resolve_battle_deaths(health_by_id)` transaction, invoked by `Battlefield._persist_battle_aftermath()` after it has collected all player health. Do not add durable aftermath rules to `GameManager`:
  - Identify all player units whose current HP <= 0.
  - For each dead adventurer:
    - Validate every affected adventurer and item owner before mutating anything. Transfer ordinary carried counts and every equipped/unique instance into the party's `pending_*` loot stores; preserve the owned-instance record and move its id to the pending item-id location. On a successful retreat or victory, the existing party-to-Encampment settlement transition banks it. A wipe discards the carried loot under the roadmap's loss rule.
    - Erase the dead unit from `GameSession.adventurers`.
    - Remove the unit's ID from `party.member_ids`.
    - Remove only the dead adventurer's ownership references; never delete a recovered owned-item record.
- Validate that dead unit IDs are nowhere in live session state, parties, or save snapshots.

### 2. Tactical Retreat Action (`scripts/battle/battle_controller.gd` & `scenes/battle/battlefield.tscn`)
- Add a **Retreat** button to the bottom panel ActionBar in `battlefield.tscn`, positioned to the left of the Move and Attack buttons.
- In `BattleController.try_retreat()`:
  - Only callable during the player's active turn.
  - Calculate the minimum Chebyshev/grid distance from each living player unit to the nearest living enemy.
  - Roll retreat consequence per unit against the locked roadmap distribution:

    | Nearest Enemy Distance | No HP Loss | 10% HP Loss | 50% HP Loss | Death (0 HP) |
    |---|---:|---:|---:|---:|
    | **1–3 tiles** | 10% | 30% | 30% | 30% |
    | **4–6 tiles** | 20% | 50% | 10% | 10% |
    | **7+ tiles** | 50% | 30% | 10% | 10% |

  - Injectable roll Callable: `var retreat_roll: Callable = Callable()` defaulting to `randf()`.
  - Discard all unbanked `battle_reward`, `battle_mana_crystals`, and `battle_gear`.
  - Trigger battle exit signal `retreat_resolved(results: Array[Dictionary])`.

### 3. Retreat & Wipe Aftermath on World Map (`scripts/autoload/game_manager.gd` & `scripts/world/world_map.gd`)
- **On Retreat:**
  - Route the player back to `scenes/world/world_map.tscn`.
  - Party position remains at the encounter tile.
  - Encounter remains active and unconquered.
  - Surviving units retain applied HP loss; units slain during retreat drop their gear into pending loot.
- **On Party Wipe (all units slain in battle or via retreat):**
  - Route the party back to the Encampment (`STARTING_SETTLEMENT_WORLD_POSITION`).
  - Clear `pending_reward`, `pending_mana_crystals`, `pending_gear`, and set `gold = 0` (if unbanked).
  - Preserved: completed campaign objectives, building levels, banked gear, and banked crystals.

### 4. Economy Floor & Passive Recovery (`scripts/autoload/game_session.gd`)
- **Shop Passive Income:** Move 2/5/10 income and tier limits into `config/game_config.json` and mirrored `GameConfig.DEFAULTS`, then read those values in `GameSession`.
  - During `GameSession.end_world_turn()`:
    - Shop Level 1: grant +2 gold / turn.
    - Shop Level 2: grant +5 gold / turn.
    - Shop Level 3: grant +10 gold / turn.
- **Turn Advancement Without Deployed Party:**
  - Allow `end_world_turn()` to execute when `parties` is empty or has 0 living members.
  - Advances natural healing for encamped roster members (+4 HP/turn), active workshop craft/sharpening jobs, recruitment vacancy countdowns, and Shop passive gold.
- **Guaranteed Affordable Recruitment:**
  - Ensure at least one Level 1 recruit offer is generated with cost <= 50 gold to prevent recruitment soft locks even at zero gold after passive turn accumulation.

---

## Setup

```bash
git checkout main && git pull
git checkout -b feat/permadeath-retreat-and-economy
make check   # confirm clean baseline before changes
```

---

## TDD Task List (Red → Green)

Write failing unit tests first, verify failure, implement changes, and confirm `make check` passes.

1. **Permadeath & Gear Transfer ([`tests/unit/test_game_session.gd`](../../../tests/unit/test_game_session.gd) & [`tests/unit/test_battlefield.gd`](../../../tests/unit/test_battlefield.gd)):**
   - Test that a unit reduced to 0 HP is removed from `GameSession.adventurers` and `party.member_ids` when battle resolves.
   - Test that the slain unit's weapons, armor, and item instances are transferred once to pending party loot, retain their modifiers, and are only banked by the established settlement transition.
   - Test that dead IDs do not remain in `GameSession` lookups or cause crashes during roster inspection.

2. **Retreat Distance Calculation & Roll Distribution ([`tests/unit/test_battle_controller.gd`](../../../tests/unit/test_battle_controller.gd)):**
   - Test distance calculation to nearest enemy for distance buckets: 1–3, 4–6, and 7+.
   - Test seeded retreat rolls verify exact outcome distribution:
     - Distance 2, roll < 0.10 -> No HP loss.
     - Distance 2, roll in [0.10, 0.40) -> 10% max HP loss.
     - Distance 2, roll in [0.40, 0.70) -> 50% max HP loss.
     - Distance 2, roll >= 0.70 -> Death (0 HP).
     - Verify buckets for 4–6 and 7+ as well.
   - Test that retreating discards battle loot and emits `retreat_resolved`.

3. **Party Wipe & World Map Handling ([`tests/unit/test_game_manager.gd`](../../../tests/unit/test_game_manager.gd) & [`tests/unit/test_world_map.gd`](../../../tests/unit/test_world_map.gd)):**
   - Test retreating keeps the party on the encounter tile on the World Map.
   - Test party wipe returns party position to Encampment settlement `(3, 3)`.
   - Test party wipe clears pending loot and unbanked gold but keeps completed campaign objectives and building upgrades intact.

4. **Passive Economy Floor & Turn Advancement ([`tests/unit/test_game_session.gd`](../../../tests/unit/test_game_session.gd)):**
   - Test `end_world_turn()` with Shop level 1 awards 2 gold per turn; level 2 awards 5 gold; level 3 awards 10 gold.
   - Test `end_world_turn()` advances turns, recovery, jobs, encounter/recruitment vacancies, and Shop income when no party is deployable.
   - Test recruitment vacancy refills with a guaranteed affordable recruit offer.

5. **UI Retreat Button & Localization ([`tests/unit/test_battlefield.gd`](../../../tests/unit/test_battlefield.gd) & [`tests/unit/test_localization.gd`](../../../tests/unit/test_localization.gd)):**
   - Test Retreat button exists in `battlefield.tscn` ActionBar and connects to `try_retreat()`.
   - Test localization string `battle.action.retreat` resolves in `translations/en.tres`.

---

## Verification

```bash
make check
```

Expected output: All unit tests pass with zero errors, zero orphans, and zero warnings.

---

## Manual Verification (User Sign-off)

1. Launch `make play`.
2. Form a party and enter an encounter (e.g. Goblin Camp).
3. **Test Retreat:**
   - On round 1, select a unit and verify the **Retreat** button is present on the action bar.
   - Move one unit far away (7+ tiles) and leave another adjacent (1 tile). Click **Retreat**.
   - Confirm combat log details the retreat outcomes (e.g. distance-based HP penalty or escape).
   - Verify the party returns to the World Map directly on the encounter tile, retaining surviving members and HP states.
4. **Test Unit Permadeath:**
   - Re-enter the encounter. Allow one unit to be reduced to 0 HP and defeated.
   - Win or retreat from the battle.
   - Inspect the Encampment **Roster** and **Bank**: confirm the fallen unit is removed from the roster, and their equipped weapon/armor has been recovered to the Encampment inventory.
5. **Test Passive Income & Wipe Recovery:**
   - Pass several world map turns by clicking **End Turn** in Encampment.
   - Confirm gold increases by +2 each turn from the Tier 1 Shop.
   - Recruit a new adventurer from the refreshed recruitment pool.

---

## Commit and Merge

```bash
git status --short
git add config/game_config.json scripts/autoload/game_config.gd scripts/autoload/game_session.gd scripts/autoload/game_manager.gd scripts/battle/battle_controller.gd scripts/battle/battlefield.gd scenes/battle/battlefield.tscn translations/en.tres tests/unit/test_game_config.gd tests/unit/test_game_session.gd tests/unit/test_battle_controller.gd tests/unit/test_battlefield.gd tests/unit/test_game_manager.gd tests/unit/test_world_map.gd tests/unit/test_localization.gd
git diff --cached --check
git commit -m "feat(combat): implement unit permadeath, tactical retreat, wipe aftermath, and economy safety floor"

# After user sign-off:
git checkout main
git merge feat/permadeath-retreat-and-economy
git branch -d feat/permadeath-retreat-and-economy
```

---

## Milestone (Concretely Verifiable)

- Units reaching 0 HP are permanently deleted at battle aftermath, with all gear safely recovered.
- Tactical Retreat button functions with distance-based risk calculations and combat logging.
- Passive shop income and world-turn recovery prevent economy soft-locks.
- `make check` passes 100% green.
