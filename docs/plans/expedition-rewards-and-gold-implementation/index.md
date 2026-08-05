# Expedition Rewards and Gold Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Add a tougher second expedition, banked gold paid only on return to the Encampment, and a reusable right-side information panel that shows gold.

**Architecture:** `GameSession` owns expedition definitions, completion, pending reward, and banked gold. `GameManager` deposits the pending reward on the Encampment transition. The World Map, Battlefield, and strategic UI render or request that state; none owns resources.

**Tech Stack:** Godot 4.7.1, GDScript, GUT 9.7.1, Godot `.tscn` scenes, English translations.

---

## Scope and fixed choices

| Expedition | World position | Enemy | Reward | Difference |
| --- | --- | --- | ---: | --- |
| Goblin Camp | `(4, 4)` | Goblin: 3 HP, 1 damage, 30% hit | 10 gold | Introductory battle |
| Orc Outpost | `(4, 0)` | Orc: 5 HP, 2 damage, 50% hit | 25 gold | Needs a third warrior hit and attacks more dangerously |

The Warrior and combat vocabulary stay unchanged. No spending, save/load, art, audio, resource inventory, multiple parties, or new tactical rule is added.

## Delivery order

| Step | Plan file | Verifiable milestone | Depends on |
| --- | --- | --- | --- |
| 1 | [01: catalog and battle](01-expedition-catalog-and-battle.md) | Two selectable map expeditions and selected battle configuration | current `main` |
| 2 | [02: delayed gold](02-delayed-gold-reward.md) | Victory queues gold; Encampment banks it once | Step 1 |
| 3 | [03: information panel](03-information-panel.md) | Shared right-side gold panel on both strategy screens | Step 2 |
| 4 | [04: tools and release check](04-debug-tour-and-release-check.md) | Developer access, screenshot coverage, and complete-loop evidence | Step 3 |

## Cross-step rules

- Use a normal branch from updated `main` in this checkout; do not create a worktree.
- Preserve unrelated changes. In particular, do not stage `docs/plans/2026-08-05-expedition-rewards-and-gold-design.md` unless the user separately asks to commit its current local edits.
- Follow the stated red/green test order, then run `make check`.
- After a new GDScript file, run `godot --headless --path . --editor --quit` and commit generated `.uid` sidecars if any.
- Stop for user manual `make play` signoff before each commit and local fast-forward merge. Do not push or open a PR.

## Definition of Done

- New games start with zero banked and pending gold.
- The map communicates two fixed-reward expeditions while preserving selection-before-activation.
- Victory records, but does not bank, the correct reward; Encampment deposits it once and clears it.
- Defeat grants nothing and leaves the expedition retryable.
- The reusable right-side panel shows the same banked total on Encampment and World Map.
- Tests, editor scan, whitespace check, screenshot tour when available, and ordinary manual routes for both expeditions have passed.
