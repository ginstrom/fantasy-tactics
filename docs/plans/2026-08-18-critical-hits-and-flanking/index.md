# Critical Hits and Flanking — Implementation Plan

**Date:** 2026-08-18
**Status:** proposed
**Implements:** [`docs/designs/combat-system.md`](../../designs/combat-system.md) §Defending (Critical Hits) & §Cover, Flanking, and Opportunity Attacks (Facing, Flanking)

## Scope & Objective

The combat design specification adds tactical depth through **Unit Facing**, **Critical Hits**, and **Flanking**:

1. **Unit Facing and attack geometry:** Units have a cardinal facing (`LEFT`, `RIGHT`, `UP`, `DOWN`). Moving or attacking updates facing orientation. Facing is visually indicated on the battlefield grid. Melee may strike any of the eight neighboring tiles, while movement remains cardinal-only.
2. **Critical Hits:** Successful physical weapon hits have a natural 5% base chance to land a critical hit. A critical hit amplifies raw damage by +50% and reduces defender damage resistance by 20 percentage points.
3. **Flanking:** Attack angle relative to defender facing determines whether an attack strikes the **Front**, **Side / Oblique Flank**, or **Rear Flank**:
   - **Front:** Standard guard, base 5% critical hit chance.
   - **Side / Oblique Flank:** -20% defender Guard, +20% critical hit chance (25% total).
   - **Rear Flank:** -50% defender Guard, +50% critical hit chance (55% total).

This plan decomposes the implementation into three self-contained steps executed in sequence:

| # | Step file | Summary | Branch | Depends on |
|---|---|---|---|---|
| 1 | [01-unit-facing-and-visualization.md](01-unit-facing-and-visualization.md) | Unit facing model, deterministic move paths, diagonal-melee legality, production/headless initialization, and board indicators | `feat/combat-unit-facing` | — |
| 2 | [02-critical-hit-mechanics.md](02-critical-hit-mechanics.md) | Seeded base critical roll, damage amplification (+50%), resistance reduction (-20%), and combat log presentation | `feat/combat-critical-hits` | Step 1 merged |
| 3 | [03-flanking-tactics-and-combat-resolution.md](03-flanking-tactics-and-combat-resolution.md) | Flanking geometry, tactical Guard/critical modifiers, and deterministic scripted tactical verification | `feat/combat-flanking-tactics` | Step 2 merged |

Each step is self-contained: setup, red/green TDD task list, automated verification, manual `make play` sign-off, commit, and local merge to `main`.

---

## Grounding — Current State of `main`

Verified against codebase state at commit `6024931`:

- **Unit Model ([`scripts/battle/unit.gd`](../../../scripts/battle/unit.gd)):**
  Tracks grid position, health, AP, weapon damage range, hit chance, defense, resistance, display name, and statuses. Currently has no concept of `facing`.
- **Combat Resolution ([`scripts/battle/battle_controller.gd`](../../../scripts/battle/battle_controller.gd)):**
  `try_attack_selected_unit()` rolls hit chance via `hit_roll.call() < effective_hit_chance`, where `effective_hit_chance = maxf(attacker.hit_chance - target.defense / 100.0, MIN_HIT_CHANCE)`.
  Damage is computed as `maxi(1, round(raw_damage * (1.0 - target.resistance / 100.0)))`.
  There is currently no critical hit check, no flank calculation, and no facing orientation on attack.
- **Board Visualization ([`scripts/battle/battle_controller.gd`](../../../scripts/battle/battle_controller.gd)):**
  `_draw_units()` renders a single solid `ColorRect` per unit on the grid. There is currently no indicator showing which direction a unit is facing.
- **Unit Details & Info Panels ([`scripts/battle/unit_info_panel.gd`](../../../scripts/battle/unit_info_panel.gd)):**
  Displays HP, AP, weapon, wound tier, and statuses for hovered/selected units.
- **Combat Configuration ([`config/game_config.json`](../../../config/game_config.json) & [`scripts/autoload/game_config.gd`](../../../scripts/autoload/game_config.gd)):**
  Houses combat balance values (`base_move_range`, `effective_hit_chance_cap`, `attack_to_hit_chance_divisor`). `DEFAULTS` in `game_config.gd` mirrors the JSON file key-for-key and is locked by [`tests/unit/test_game_config.gd`](../../../tests/unit/test_game_config.gd).
- **Localization ([`translations/en.tres`](../../../translations/en.tres) & [`tests/unit/test_localization.gd`](../../../tests/unit/test_localization.gd)):**
  Centralizes player-facing combat status and log strings (`battle.status.*`, `battle.log.*`).
- **Headless Balance Tools ([`scripts/tools/battle_scenarios/battle_state_factory.gd`](../../../scripts/tools/battle_scenarios/battle_state_factory.gd) & [`Makefile`](../../../Makefile)):**
  `BattleStateFactory` constructs a bare controller rather than calling `_ready()`, and currently seeds `hit_roll` and `damage_roll`. `make check` runs the GUT suite; `make simulate` is a scene-driven smoke client; and `make scenario` runs seed-pinned scenario cases. New combat randomness and initial unit state must be wired through this factory or records cease to be reproducible and diverge from play.

---

## Technical Specifications & Formulas

### 1. Facing Directions

Four cardinal directions represented as `Vector2i`:
- `Vector2i.RIGHT` (`(1, 0)`): East / Facing Right (initial player unit facing).
- `Vector2i.LEFT` (`(-1, 0)`): West / Facing Left (initial enemy unit facing).
- `Vector2i.UP` (`(0, -1)`): North / Facing Up.
- `Vector2i.DOWN` (`(0, 1)`): South / Facing Down.

Facing updates:
- **On Movement:** When a unit moves between tiles, its facing updates to the step direction vector of its last step.
- **On Attack:** When a unit initiates an attack against a target tile, the attacker turns to face the target before striking. For diagonal or multi-tile attacks, the primary cardinal direction (`abs(dx) >= abs(dy) ? sign(dx) : sign(dy)`) is used.

### 2. Flanking Geometry

For an attacker at `attacker_pos` attacking a defender at `defender_pos` who is facing `defender_facing`:

Let `offset = attacker_pos - defender_pos`.
Let `u = offset.x * defender_facing.x + offset.y * defender_facing.y` (signed forward projection along facing vector).
Let `v = abs(offset.x * defender_facing.y - offset.y * defender_facing.x)` (lateral offset perpendicular to facing).

Flank classification:
- **Front (`"front"`):** `u > 0` (attacker is located in the forward half-plane / front arc).
- **Rear (`"rear"`):** `u < 0 and v == 0` (attacker is located directly behind the defender along the opposite facing line).
- **Side / Oblique (`"side"`):** All other angles (`u <= 0 and v > 0`).

This formula exactly matches the 3x3 flanking diagrams in `docs/designs/combat-system.md` for all 4 cardinal facings:

```text
Facing Left (<):       Facing Up (^):         Facing Right (>):      Facing Down (v):
  F S S                  F F F                  S S F                  S R S
  F < R                  S ^ S                  R > F                  S v S
  F S S                  S R S                  S S F                  F F F
```

### 3. Combat Modifiers and Damage Calculation

1. **Defender Effective Guard:**
   - Front: `effective_guard = defender.defense`
   - Side Flank: `effective_guard = max(0, defender.defense - 20)`
   - Rear Flank: `effective_guard = max(0, defender.defense - 50)`

2. **Hit Chance:**
   `effective_hit_chance = clamp(attacker.hit_chance - effective_guard / 100.0, 0.05, GameSession.EFFECTIVE_HIT_CHANCE_CAP)`
   `is_hit = hit_roll.call() < effective_hit_chance`

3. **Critical Hit Chance:**
   - Base Crit Chance: `0.05` (5%)
   - Side Flank Bonus: `+0.20` (+20% -> 25% total)
   - Rear Flank Bonus: `+0.50` (+50% -> 55% total)
   - `effective_crit_chance = clamp(base_crit_chance + flank_crit_bonus, 0.0, 0.95)`
   - `is_critical = is_hit and (crit_roll.call() < effective_crit_chance)`

4. **Damage Resolution:**
   - Raw damage: `raw_damage = damage_roll.call(damage_min, damage_max) + raw_damage_bonus + might`
   - If Critical:
     - `raw_damage = round(raw_damage * 1.5)`
     - `effective_resistance = max(0, defender.resistance - 20)`
   - Else:
     - `effective_resistance = defender.resistance`
   - Final inflicted damage:
     `final_damage = max(1, round(raw_damage * (1.0 - effective_resistance / 100.0)))`

---

## Constraints Carried into Every Step

1. **Strict Branching Workflow ([`AGENTS.md`](../../../AGENTS.md)):**
   Develop on a regular branch off `main` in the existing working copy (no worktrees).
   `git checkout main && git pull` -> `git checkout -b <branch>` -> TDD -> `make check` -> manual verification -> commit -> merge locally to `main` -> delete branch. Never push to `origin` unless requested.
2. **Red/Green TDD:**
   Write failing unit tests first, verify test failure, implement changes, and confirm `make check` is fully green.
3. **Deterministic Injectable Callables:**
   Maintain testability using injectable callables on `BattleController` (`hit_roll`, `damage_roll`, `crit_roll`). `BattleStateFactory` must assign every gameplay-random callable from its per-iteration seeded RNG; two runs with the same scenario/seed/iterations must write byte-identical records.
4. **Config & Defaults Invariant:**
   Any added configuration in `config/game_config.json` must be reflected identically in `scripts/autoload/game_config.gd`'s `DEFAULTS` and verified by `tests/unit/test_game_config.gd`.
5. **Localization Invariant:**
   All player-facing strings in UI, combat status, and combat logs must use `tr()` with entries in `translations/en.tres` and lockstep tests in `tests/unit/test_localization.gd`.
6. **Out of Scope (Deferred to Future Plans):**
   - Line of sight Cover bonuses (+25% / +50% Guard against missile attacks).
   - Attacks of Opportunity (movement out of adjacent melee tiles).
   - Dodge and Parry mechanics / Off-balance conditions.
   - Spells & Magic Resistance.
   - Diagonal movement. Diagonal attacks are expressly in scope; only movement stays four-directional.

---

## Shared Definition of Done for Every Step

- `make check` passes with 0 failures and 0 warnings.
- All new methods and properties have complete unit test coverage in `tests/unit/`.
- Combat determinism and scenario contracts are preserved.
- New `ScenarioContract` fields have normalization, validation, factory-hydration, and byte-identical-record coverage.
- Manual verification performed via `make play` and verified against the step's criteria.
- Local feature branch merged to `main` and branch deleted.

Every commit stages an explicit, reviewed file list. Do not use `git add -A`: the shared checkout can contain unrelated user edits.
