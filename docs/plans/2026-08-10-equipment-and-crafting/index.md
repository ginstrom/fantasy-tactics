# Equipment and Crafting Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Establish generic Action Points and owned equipment instances, then deliver Blacksmith, Alchemy Workshop, and Runic Workshop crafting in bounded, testable slices.

**Architecture:** `GameSession` owns item catalogues, unique owned instances, material counts, recipes, and durable inventories. `BattleController` validates and resolves AP actions/effects but never mutates campaign inventory directly. Item and effect definitions are data; UI renders state and emits intents.

**Tech Stack:** Godot 4.7.1, GDScript, GUT 9.7.1, snapshots, headless battle simulation, and `make` targets.

---

## Invariants

- A Round starts with 6 AP; move costs 1, basic attack 3, potion use 2.
- A unit may take any legal actions it can afford; no separate one-attack cap remains.
- Normal base items are immutable and stackable; an improvement creates an owned unique instance.
- Modifier categories stack, but an advanced tier replaces its lower tier within that category.
- Recipe validation and inventory mutation are atomic; failed actions consume nothing.
- Potions, spells, perks, and runes share one AP/effect contract, never bespoke UI shortcuts.

## Delivery order

1. [01-generic-action-points.md](01-generic-action-points.md)
2. [02-item-instance-contract.md](02-item-instance-contract.md)
3. [03-blacksmith.md](03-blacksmith.md)
4. [04-alchemy-workshop.md](04-alchemy-workshop.md)
5. [05-runic-workshop.md](05-runic-workshop.md)
6. [06-verification-and-local-merge.md](06-verification-and-local-merge.md)
