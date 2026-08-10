# Class Attributes and Monster Manual Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Migrate the current Warrior and four initial monsters to a shared, data-driven tactical attribute contract, then unlock balanced classes in capability-first slices.

**Architecture:** `GameSession` owns persistent adventurer base attributes, effective-stat getters, immutable monster templates, and combat balance configuration. `BattleController` receives fully resolved `Unit` values and owns synchronous combat application only. Class definitions describe role, equipment permissions, advancement, and abilities; scenes render state and emit intents.

**Tech Stack:** Godot 4.7.1, GDScript, GUT 9.7.1, existing headless battle simulation and `make` targets.

---

## Scope and invariants

- Preserve existing Warrior/monster outcomes while the shared data schema is introduced: the migration is not a balance pass.
- Base adventurer values stay durable in `GameSession`; `Unit` keeps only the effective values needed in the current battle.
- Monster templates are immutable; encounter instances choose compositions but do not mutate shared templates.
- Damage remains attack range plus Might, then Resistance; hit chance remains Accuracy minus Guard, clamped to 5–95%.
- A new class ships only with a useful role, encounter/counterplay, automated balance scenarios, and manual player verification.
- Do not add MP, spells, ranged attacks, status effects, cooldowns, or specializations before their enabling slice.

## Delivery order

1. [equipment and crafting plan](../2026-08-10-equipment-and-crafting/index.md) — generic Action Points and item instances, prerequisites for active class abilities.
2. [01-shared-attribute-contract.md](01-shared-attribute-contract.md) — schema, compatibility migration, and snapshot contract.
3. [02-monster-template-and-baseline.md](02-monster-template-and-baseline.md) — initial roster data and reproducible balance baselines.
4. [03-scout-ranger.md](03-scout-ranger.md) — ranged combat and scouting.
5. [04-cleric-healer.md](04-cleric-healer.md) — sustain and protection.
6. [05-mage-spellcaster.md](05-mage-spellcaster.md) — MP, spells, and control.
7. [06-specializations-and-monster-slices.md](06-specializations-and-monster-slices.md) — specialization gates and additional monster families.
8. [07-verification-and-local-merge.md](07-verification-and-local-merge.md) — full verification, user signoff, local merge, and branch cleanup.

Each numbered file is self-contained. Complete and merge one approved slice before starting the next; the class document and monster manual remain the cross-slice contract.
