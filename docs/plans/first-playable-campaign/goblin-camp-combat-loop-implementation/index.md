# Goblin Camp Combat Loop Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Turn `goblin_camp` into the first complete campaign loop: reach it from the world map, fight a short deterministic tactical battle with real health/attack/hit-chance rules and a visible goblin turn, then win and clear the site or lose and return home safely.

**Architecture:** `world_map.gd` moves site entry to a selection-first model shared by the goblin camp and the settlement. `battle_controller.gd` (the `Grid` node) gains unit stats, hit resolution behind an injectable roll source, and a synchronous, fully-resolved `run_enemy_turn()` that returns an observable action log. `battlefield.gd` stays the sole presentation/sequencing/routing layer: it paces the returned log for the player, gates input during it, and calls new `GameSession`/`GameManager` outcome routes.

**Tech Stack:** Godot 4.7, GDScript, GUT, Make.

---

## Scope and timing

Implement this on top of the merged settlement/first-party prototype and the existing `goblin_camp` encounter stub, as described in [the combat loop design](../goblin-camp-combat-loop-design.md). It replaces the current first-click encounter activation and the developer-facing **Complete Battle** button; it does not add classes, weapons, inventory, multiple units per side, terrain, ranged attacks, save/load, or final art/animation. Those stay deferred per the design doc.

## Plan order

| Step | Outcome | Prerequisite | Manual check |
| --- | --- | --- | --- |
| [01](01-world-map-selection-and-site-entry.md) | Clicking the deployed party always selects it first; a second click on the goblin camp or settlement enters it; completed encounters reject entry. | None | No |
| [02](02-battle-unit-stats-and-combat-rules.md) | The battlefield spawns a Warrior (3 HP, move 3, sword 2 dmg/60%) and a Goblin (3 HP, move 3, short sword 1 dmg/30%); a unit can move once and attack once per turn with deterministic, injectable hit resolution; defeated units are removed; `is_battle_won()`/`is_battle_lost()` detect each outcome. | None | No |
| [03](03-goblin-ai-and-battle-outcome-detection.md) | `run_enemy_turn()` deterministically moves the goblin toward the nearest living player unit (stable tie-break) and attacks when adjacent, returning an ordered, fully-resolved action log. | 02 | No |
| [04](04-battlefield-presentation-and-campaign-outcomes.md) | The battlefield HUD shows health and hit/miss/damage feedback, paces the enemy-turn log with input locked and **End Turn** disabled, and routes victory to the cleared world map or defeat back to the starting settlement. The **Complete Battle** button is gone. | 01, 02, 03 | Yes |

Steps 02 → 03 → 04 are strictly sequential: each depends on the previous step's `battle_controller.gd` interface. Step 01 touches only `world_map.gd` and can be done before, after, or interleaved with the others.

## Shared workflow

Each numbered document is one mergeable feature branch. Follow [AGENTS.md](../../../../AGENTS.md): branch from updated `main`, use red/green TDD, run `make check`, obtain any specified `make play` verification, commit, and merge locally only after user signoff. Do not push unless asked.

## Overall Definition of Done

- A party standing on the goblin camp can be selected and moved away without entering battle; a selected party can move to and enter the settlement tile; a completed goblin camp rejects further entry.
- The Warrior and Goblin have exactly the stats in [the design's setup table](../goblin-camp-combat-loop-design.md#first-battle-setup); a unit gets one move and one attack per turn in either order; a defeated unit is removed and cannot act or be targeted.
- Hit resolution is deterministic under test (an injectable roll source) and matches the documented 60%/30% hit chances and 2/1 damage values in production.
- Pressing **End Turn** visibly plays the goblin's move-then-attack decision one beat at a time, using centrally tuned timing constants; player board input and **End Turn** are unavailable for that whole sequence.
- Killing the goblin marks `goblin_camp` complete and returns to the world map; defeating the Warrior returns the party to `starting_settlement` without completing the encounter.
- `make check` passes at the end of every step, and the complete win and loss paths are manually verified with `make play` at the end of step 04.
