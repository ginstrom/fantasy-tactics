# Step 3: Flanking Geometry, Tactical Modifiers, and Balance Verification

**Date:** 2026-08-18
**Status:** proposed
**Branch:** `feat/combat-flanking-tactics`
**Part of:** [`docs/plans/2026-08-18-critical-hits-and-flanking/index.md`](index.md)

## Summary

Implement **Flanking Geometry** and **Tactical Flanking Modifiers** per [`docs/designs/combat-system.md`](../../designs/combat-system.md) §Cover, Flanking, and Opportunity Attacks:
- Attacking an enemy from different angles provides tactical advantages based on defender facing:
  - **Side / Oblique Flank:** -20% defender Guard, +20% critical hit chance (25% total).
  - **Rear Flank:** -50% defender Guard, +50% critical hit chance (55% total).
  - **Front:** Standard defender Guard, base 5% critical hit chance.
- Geometry rigorously matches the 3x3 directional diagrams in the design document for all four facings, and generalizes to ranged line-of-sight attacks.
- Combat log, status messaging, and unit inspection display flanking information.
- A new deterministic scenario suite (`scenarios/battle/flanking-tactics.json`) verifies balance and tactical positioning benefits.

---

## Technical Design

### 1. Game Configuration (`config/game_config.json` & `scripts/autoload/game_config.gd`)
Add flanking balance constants:
```json
{
  "combat": {
    "side_flank_guard_penalty": 20,
    "side_flank_crit_bonus": 0.20,
    "rear_flank_guard_penalty": 50,
    "rear_flank_crit_bonus": 0.50
  }
}
```
Mirror these keys identically in `GameConfig.DEFAULTS["combat"]`.

### 2. Flanking Geometry Classification (`scripts/battle/battle_controller.gd`)
Add helper method:
```gdscript
func get_flank_type(attacker_pos: Vector2i, defender_pos: Vector2i, defender_facing: Vector2i) -> String
```
**Algorithm:**
1. Compute relative offset: `offset = attacker_pos - defender_pos`.
2. Compute forward dot product: `u = offset.x * defender_facing.x + offset.y * defender_facing.y`.
3. Compute lateral perpendicular offset: `v = abs(offset.x * defender_facing.y - offset.y * defender_facing.x)`.
4. Classification:
   - If `u > 0`: return `"front"` (Front arc: attacker is positioned in front of defender).
   - If `u < 0 and v == 0`: return `"rear"` (Directly behind defender).
   - Else: return `"side"` (Flanked from side or oblique rear diagonal).

**Truth Table Verification (relative to defender at (0, 0)):**

| Defender Facing | Front Tiles (`"front"`) | Side Tiles (`"side"`) | Rear Tile (`"rear"`) |
|---|---|---|---|
| **Facing Left** `(-1, 0)` | `(-1, -1), (-1, 0), (-1, 1)` | `(0, -1), (0, 1), (1, -1), (1, 1)` | `(1, 0)` |
| **Facing Up** `(0, -1)` | `(-1, -1), (0, -1), (1, -1)` | `(-1, 0), (1, 0), (-1, 1), (1, 1)` | `(0, 1)` |
| **Facing Right** `(1, 0)` | `(1, -1), (1, 0), (1, 1)` | `(0, -1), (0, 1), (-1, -1), (-1, 1)` | `(-1, 0)` |
| **Facing Down** `(0, 1)` | `(-1, 1), (0, 1), (1, 1)` | `(-1, 0), (1, 0), (-1, -1), (1, -1)` | `(0, -1)` |

### 3. Combat Resolution Integration (`scripts/battle/battle_controller.gd`)
In `try_attack_selected_unit(target_pos)`:
1. Determine attack angle:
   `var flank_type: String = get_flank_type(selected_unit.grid_position, target.grid_position, target.facing)`
2. Compute effective guard:
   ```gdscript
   var guard_penalty: int = 0
   var crit_bonus: float = 0.0
   if flank_type == "side":
       guard_penalty = GameConfig.get_int("combat", "side_flank_guard_penalty", 20)
       crit_bonus = GameConfig.get_float("combat", "side_flank_crit_bonus", 0.20)
   elif flank_type == "rear":
       guard_penalty = GameConfig.get_int("combat", "rear_flank_guard_penalty", 50)
       crit_bonus = GameConfig.get_float("combat", "rear_flank_crit_bonus", 0.50)

   var effective_defense: int = maxi(0, target.defense - guard_penalty)
   var effective_hit_chance: float = clampf(selected_unit.hit_chance - effective_defense / 100.0, MIN_HIT_CHANCE, 0.95)
   ```
3. Compute effective critical chance:
   ```gdscript
   var base_crit: float = GameConfig.get_float("combat", "base_critical_chance", 0.05)
   var effective_crit_chance: float = clampf(base_crit + crit_bonus, 0.0, 0.95)
   ```
4. Record flank type in `last_attack_result`:
   `last_attack_result["flank"] = flank_type`

### 4. Battlefield Presentation & Combat Logs (`scripts/battle/battlefield.gd`)
- If attack is a side or rear flank, enhance the combat log entry and status message:
  - `"battle.log.flank.side": "%s attacks %s from the side — hits for %d damage!"`
  - `"battle.log.flank.rear": "%s attacks %s from behind — hits for %d damage!"`
  - `"battle.log.flank.rear_crit": "%s attacks %s from behind — Critical Hit! Hits for %d damage!"`
  - `"battle.log.flank.side_crit": "%s attacks %s from the side — Critical Hit! Hits for %d damage!"`
- Add translation entries in `translations/en.tres` and lockstep tests in [`tests/unit/test_localization.gd`](../../../tests/unit/test_localization.gd).

---

## Setup

```bash
git checkout main && git pull
git checkout -b feat/combat-flanking-tactics
make check   # confirm clean baseline before changes
```

---

## TDD Task List (Red → Green)

1. **Config & Defaults Invariant ([`tests/unit/test_game_config.gd`](../../../tests/unit/test_game_config.gd)):**
   - Add `side_flank_guard_penalty`, `side_flank_crit_bonus`, `rear_flank_guard_penalty`, and `rear_flank_crit_bonus` to `config/game_config.json` and `game_config.gd` `DEFAULTS`.
   - Update `test_game_config.gd` to assert all new keys match.

2. **Flanking Classification Geometry ([`tests/unit/test_battle_controller.gd`](../../../tests/unit/test_battle_controller.gd)):**
   - Test all 8 adjacent tiles for **Facing Left** (`(-1, 0)`):
     - Assert `(-1, -1)`, `(-1, 0)`, `(-1, 1)` are `"front"`.
     - Assert `(0, -1)`, `(0, 1)`, `(1, -1)`, `(1, 1)` are `"side"`.
     - Assert `(1, 0)` is `"rear"`.
   - Test all 8 adjacent tiles for **Facing Up** (`(0, -1)`).
   - Test all 8 adjacent tiles for **Facing Right** (`(1, 0)`).
   - Test all 8 adjacent tiles for **Facing Down** (`(0, 1)`).
   - Test ranged attack positions (e.g., attacker at `(0, 4)` vs defender at `(0, 2)` facing Up is `"rear"`).

3. **Guard Reduction & Hit Chance Modifiers ([`tests/unit/test_battle_controller.gd`](../../../tests/unit/test_battle_controller.gd)):**
   - Given defender with `40%` defense and attacker with `70%` hit chance:
     - Front attack: effective defense `40%` -> effective hit chance `30%` (`0.30`).
     - Side attack: effective defense `20%` (`40 - 20`) -> effective hit chance `50%` (`0.50`).
     - Rear attack: effective defense `0%` (`max(0, 40 - 50)`) -> effective hit chance `70%` (`0.70`).

4. **Flanking Critical Hit Chance Bonuses ([`tests/unit/test_battle_controller.gd`](../../../tests/unit/test_battle_controller.gd)):**
   - Given base critical chance `5%`:
     - Front attack: critical threshold is `0.05`.
     - Side attack: critical threshold is `0.25` (`0.05 + 0.20`).
     - Rear attack: critical threshold is `0.55` (`0.05 + 0.50`).
   - Test with injected `crit_roll = 0.40`:
     - Front attack: no critical hit.
     - Side attack: no critical hit.
     - Rear attack: lands a critical hit (`0.40 < 0.55`).

5. **Combat Result & Logging ([`tests/unit/test_battlefield.gd`](../../../tests/unit/test_battlefield.gd) & [`tests/unit/test_localization.gd`](../../../tests/unit/test_localization.gd)):**
   - Test `last_attack_result.flank` contains `"front"`, `"side"`, or `"rear"`.
   - Test log output formats correctly for side and rear flanks with and without critical hits.
   - Update `translations/en.tres` and `test_localization.gd`.

6. **Scenario Suite & Balance Tooling ([`scenarios/battle/flanking-tactics.json`](../../../scenarios/battle/)):**
   - Create `scenarios/battle/flanking-tactics.json` matrixing attack angles (front vs flank).
   - Run `make scenario SCENARIO=scenarios/battle/flanking-tactics.json SEED=20260818 ITERATIONS=20`.

---

## Verification

Run the full validation suite:

```bash
make check
```

Run simulation & scenario balance gates:

```bash
make scenario SCENARIO=scenarios/battle/flanking-tactics.json SEED=20260818 ITERATIONS=20
make scenario SCENARIO=scenarios/battle/baseline-party-viability.json SEED=20260810 ITERATIONS=20
make simulate RUNS=20
```

---

## Manual Verification (User Sign-off)

1. Run `make play`.
2. Press **FN+F9** -> **Goblin Camp Battle**.
3. **Frontal Attack:**
   - Move directly in front of a goblin (facing east toward the goblin who faces west).
   - Attack and observe standard combat logs (no flank notation).
4. **Side Flank:**
   - Maneuver a unit to the north or south tile adjacent to the goblin (side tile).
   - Attack and observe combat log reads: `<Attacker> attacks <Defender> from the side — hits for <N> damage!`.
5. **Rear Flank:**
   - Maneuver a unit directly behind the goblin (east of the goblin who faces west).
   - Attack and observe combat log reads: `<Attacker> attacks <Defender> from behind — hits for <N> damage!`.
   - Confirm increased critical hit occurrence and higher damage output from rear positioning.
6. **Enemy AI Symmetry:**
   - Position a player unit facing away from approaching goblins.
   - End turn and verify enemy attacks from behind/side correctly apply flanking bonuses against the player.

---

## Commit and Merge

```bash
git add -A && git status
git commit -m "feat(combat): implement flanking geometry, tactical guard penalties, and critical hit bonuses"

# After user sign-off:
git checkout main
git merge feat/combat-flanking-tactics
git branch -d feat/combat-flanking-tactics
```

---

## Milestone (Concretely Verifiable)

- `get_flank_type()` classifies Front, Side, and Rear positions matching design doc diagrams 100%.
- Side and Rear flanks apply exact Guard reductions (-20%, -50%) and Critical Hit bonuses (+20%, +50%).
- `scenarios/battle/flanking-tactics.json` passes deterministically with higher win/damage rates for flanked attacks.
- `make check` is 100% green with zero errors or warnings.
