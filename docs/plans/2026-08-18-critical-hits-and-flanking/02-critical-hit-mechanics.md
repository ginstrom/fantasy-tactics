# Step 2: Critical Hit Mechanics and Damage Amplification

**Date:** 2026-08-18
**Status:** proposed
**Branch:** `feat/combat-critical-hits`
**Part of:** [`docs/plans/2026-08-18-critical-hits-and-flanking/index.md`](index.md)

## Summary

Implement the core **Critical Hit** mechanic for physical attacks per [`docs/designs/combat-system.md`](../../designs/combat-system.md) §Defending (Critical Hits):
- Any successful weapon hit has a natural 5% base chance to land a critical hit.
- A critical hit increases raw inflicted damage by 50% (`round(raw_damage * 1.5)`).
- A critical hit reduces defender damage resistance by 20 percentage points (`max(0, defender.resistance - 20)`).
- Combat balance constants are loaded via `GameConfig` and backed by hard-coded fallback defaults.
- Injectable roll callable `crit_roll` ensures 100% deterministic testability.
- Combat log and battle status lines highlight critical hits.

---

## Technical Design

### 1. Game Configuration (`config/game_config.json` & `scripts/autoload/game_config.gd`)
Add combat configuration keys under `"combat"`:
```json
{
  "combat": {
    "base_move_range": 3,
    "effective_hit_chance_cap": 0.95,
    "attack_to_hit_chance_divisor": 100.0,
    "base_critical_chance": 0.05,
    "critical_damage_multiplier": 1.5,
    "critical_resistance_reduction": 20
  }
}
```
Mirror these keys identically in `GameConfig.DEFAULTS["combat"]`.

### 2. BattleController Combat Resolution (`scripts/battle/battle_controller.gd`)
- Add injectable callable:
  ```gdscript
  var crit_roll: Callable = func() -> float: return randf()
  ```
- In `BattleStateFactory.build()`, assign `controller.crit_roll` from the same per-iteration `RandomNumberGenerator` already used for `hit_roll` and `damage_roll`. Do not use global `randf()` in scenario execution.
- In `try_attack_selected_unit(target_pos)`:
  1. Roll hit chance as normal: `hit = hit_roll.call() < effective_hit_chance`.
  2. If `hit`:
     - Determine base critical hit chance: `base_crit = GameConfig.get_float("combat", "base_critical_chance", 0.05)`.
     - Check critical success: `is_critical = crit_roll.call() < base_crit`.
     - Calculate raw damage: `raw_damage = damage_roll.call(selected_unit.damage_min, selected_unit.damage_max) + selected_unit.raw_damage_bonus + selected_unit.might`.
     - If `is_critical`:
       - `mult = GameConfig.get_float("combat", "critical_damage_multiplier", 1.5)`
       - `raw_damage = int(round(raw_damage * mult))`
       - `res_reduction = GameConfig.get_int("combat", "critical_resistance_reduction", 20)`
       - `effective_resistance = maxi(0, target.resistance - res_reduction)`
     - Else:
       - `effective_resistance = target.resistance`
     - Final damage:
       `damage = int(maxi(1, round(raw_damage * (1.0 - effective_resistance / 100.0))))`
     - Apply damage to defender: `target.take_damage(damage)`.
  3. Include `"critical": is_critical` in `last_attack_result`.

### 3. Battlefield Presentation & Logs (`scripts/battle/battlefield.gd`)
- In `_describe_step(step)`:
  - If `step.hit` and `step.get("critical", false)`:
    Return `tr("battle.status.critical_hit") % [attacker_name, step.damage]`
    (e.g., `"Critical Hit! Warrior hits for 6 damage."`).
- In `_describe_log_entry(step)`:
  - If `step.hit` and `step.get("critical", false)`:
    Include critical hit notation: `tr("battle.log.critical_hit") % [attacker_name, defender_name, step.damage]`
    (e.g., `"Warrior attacks Goblin 1 — Critical Hit! Hits for 6 damage!"`).
- In `translations/en.tres`:
  - `"battle.status.critical_hit": "Critical Hit! %s hits for %d damage."`
  - `"battle.log.critical_hit": "%s attacks %s — Critical Hit! Hits for %d damage!"`

---

## Setup

```bash
git checkout main && git pull
git checkout -b feat/combat-critical-hits
make check   # confirm clean baseline before changes
```

---

## TDD Task List (Red → Green)

Write failing tests first, run to confirm failure, then implement:

1. **Config & Defaults Invariant ([`tests/unit/test_game_config.gd`](../../../tests/unit/test_game_config.gd)):**
   - Update `config/game_config.json` with `base_critical_chance`, `critical_damage_multiplier`, and `critical_resistance_reduction`.
   - Update `scripts/autoload/game_config.gd` `DEFAULTS`.
   - Add assertions in `test_game_config.gd` to verify the new keys load correctly from disk and match defaults.

2. **Critical Hit Roll Determinism ([`tests/unit/test_battle_controller.gd`](../../../tests/unit/test_battle_controller.gd)):**
   - Test that when `crit_roll` returns `< 0.05` (e.g. `0.01`), `last_attack_result.critical` is `true`.
   - Test that when `crit_roll` returns `>= 0.05` (e.g. `0.50`), `last_attack_result.critical` is `false`.
   - Test that missed attacks (`hit == false`) never trigger critical hits and have `last_attack_result.critical == false`.

3. **Seeded Scenario-Roll Determinism ([`tests/unit/test_battle_state_factory.gd`](../../../tests/unit/test_battle_state_factory.gd) & [`tests/unit/test_scenario_runner.gd`](../../../tests/unit/test_scenario_runner.gd)):**
   - Build the same normalized scenario twice with one seed and assert its hit, damage, and critical callables yield the same sequence.
   - Run the same critical-capable scenario case twice with identical iteration seeds and assert the resulting records are byte-identical, including `damage` and survivors.

4. **Damage Amplification Formula ([`tests/unit/test_battle_controller.gd`](../../../tests/unit/test_battle_controller.gd)):**
   - Given an attacker with base damage `4` and `0` might, against a defender with `0` resistance:
     - Normal hit: `4` damage.
     - Critical hit (`crit_roll = 0.0`): `round(4 * 1.5) = 6` damage.
   - Assert `target.health` reflects the amplified damage.

5. **Resistance Reduction on Critical Hit ([`tests/unit/test_battle_controller.gd`](../../../tests/unit/test_battle_controller.gd)):**
   - Given an attacker with raw damage `10`, against a defender with `50%` resistance:
     - Normal hit: `round(10 * (1 - 0.50)) = 5` damage.
     - Critical hit: Raw damage becomes `round(10 * 1.5) = 15`. Effective resistance is reduced by 20% points to `30%`. Final damage is `round(15 * (1 - 0.30)) = round(10.5) = 11` damage.
   - Assert `last_attack_result.damage == 11`.
   - Given a defender with `10%` resistance:
     - Critical hit reduces resistance to `max(0, 10 - 20) = 0%`. Final damage is `round(10 * 1.5) = 15`.

6. **Combat Feedback and Log Presentation ([`tests/unit/test_battlefield.gd`](../../../tests/unit/test_battlefield.gd) & [`tests/unit/test_localization.gd`](../../../tests/unit/test_localization.gd)):**
   - Test `_describe_step()` with critical hit result formats expected critical status string.
   - Test `_describe_log_entry()` with critical hit result formats expected critical log entry.
   - Verify `translations/en.tres` entries and lockstep assertions in `test_localization.gd`.

---

## Verification

Run the full validation suite:

```bash
make check
```

Run headless battle simulations to ensure combat stability:

```bash
make simulate RUNS=20
make scenario SCENARIO=scenarios/battle/baseline-party-viability.json SEED=20260810 ITERATIONS=20
```

---

## Manual Verification (User Sign-off)

1. Run `make play`.
2. Press **FN+F9** -> **Orc Outpost Battle**.
3. Engage in combat with the Orcs and Goblins.
4. When a critical hit occurs (or temporarily forcing `crit_roll = 0.0` in debug):
   - Confirm status text reads: `Critical Hit! <Attacker> hits for <N> damage.`
   - Confirm combat log at bottom contains: `<Attacker> attacks <Defender> — Critical Hit! Hits for <N> damage!`
   - Verify damage dealt matches the +50% amplified value.

---

## Commit and Merge

```bash
git status --short
git add config/game_config.json scripts/autoload/game_config.gd scripts/battle/battle_controller.gd scripts/tools/battle_scenarios/battle_state_factory.gd scripts/battle/battlefield.gd translations/en.tres tests/unit/test_game_config.gd tests/unit/test_battle_controller.gd tests/unit/test_battle_state_factory.gd tests/unit/test_scenario_runner.gd tests/unit/test_battlefield.gd tests/unit/test_localization.gd
git diff --cached --check
git commit -m "feat(combat): implement base critical hits with damage amplification and resistance reduction"

# After user sign-off:
git checkout main
git merge feat/combat-critical-hits
git branch -d feat/combat-critical-hits
```

---

## Milestone (Concretely Verifiable)

- Config keys `base_critical_chance`, `critical_damage_multiplier`, and `critical_resistance_reduction` are wired and tested.
- `BattleController` rolls critical hits with injectable `crit_roll`.
- Critical damage formula (+50% raw damage, -20% defender resistance) verified by exact math tests.
- `make check` is 100% green.
