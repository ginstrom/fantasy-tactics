# Step 4: Combat Rewards Rebalance

## Overview

Playtesting revealed combat gold rewards were too sparse to support party expansion and workshop progression. This step rebalances combat completion rewards so encounters yield significantly higher gold rewards:
- **Tier 1 encounters**: Average 25 gold total (not including dropped loot/crystals).
- **Tier 2 encounters**: Average 50 gold total (not including dropped loot/crystals).

---

## Setup Instructions

1. Check out `main` and pull the latest changes:
   ```bash
   git checkout main && git pull
   ```
2. Create and check out a new branch:
   ```bash
   git checkout -b feat/combat-rewards-rebalance
   ```

---

## Test-Driven Development (TDD) Plan

### 1. Write Failing Tests (Red Phase)

Add unit tests in [`tests/unit/test_game_session.gd`](file:///home/ryan/play/fantasy-tactics/tests/unit/test_game_session.gd):

- **Tier 1 encounter reward test**:
  Complete a Tier 1 encounter (`goblin_camp`, difficulty 1) with deterministic `loot_gold_roll` returning midpoint values, and verify total `battle_reward` is ~25 gold.
- **Tier 2 encounter reward test**:
  Complete a Tier 2 encounter (`orc_outpost`, difficulty 2) with deterministic `loot_gold_roll` returning midpoint values, and verify total `battle_reward` is ~50 gold.

Run tests to confirm failure:
```bash
godot --headless -s --path . addons/gut/gut_cmdln.gd -gselect=test_game_session.gd
```

### 2. Implementation (Green Phase)

1. **Modify [`scripts/autoload/game_session.gd`](file:///home/ryan/play/fantasy-tactics/scripts/autoload/game_session.gd)**:
   - Update `complete_current_encounter()` completion bonus calculation:
     - Set base completion gold bonus roll to `loot_gold_roll.call(18, 22) * difficulty` (or `20 * difficulty`), which when combined with per-kill enemy gold loot (~5g for Tier 1, ~10g for Tier 2) brings total encounter rewards to:
       - Tier 1: 20 (base) + 5 (kill) = **25 gold average**
       - Tier 2: 40 (base) + 10 (kill) = **50 gold average**
   - Verify `ENEMY_LOOT_TABLES` gold ranges remain consistent.

2. **Update any dependent tests**:
   - Update expectation numbers in `test_game_session.gd` or `test_battle_result.gd` that assert exact historical reward amounts.

---

## Concrete Verifiable Milestone

Run the full test suite:
```bash
make check
```
All tests pass cleanly.

---

## Manual Verification

1. Run headless battle simulator or complete a battle manually via `make play`.
2. Win a Tier 1 battle (`goblin_camp`) and verify victory summary shows ~25 gold reward.
3. Win a Tier 2 battle (`orc_outpost`) and verify victory summary shows ~50 gold reward.
