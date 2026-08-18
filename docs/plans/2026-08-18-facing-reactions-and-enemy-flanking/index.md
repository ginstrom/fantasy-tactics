# Facing Reactions and Enemy Flanking Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Complete the facing design by letting players freely turn selected units, making each defender react to its first landed hit in a round, and having enemies choose reachable side/rear attacks against their nearest target.

**Architecture:** `Unit` owns its per-round automatic-facing guard; `BattleController` remains the sole owner of input, round resets, combat resolution, and enemy policy. The enemy planner evaluates only legal movement destinations and calls the existing public move/attack actions, preserving AP, blockers, line of sight, and deterministic behavior.

**Tech Stack:** Godot 4.7.1, GDScript, GUT 9.7.1, `make check`, scenario runner.

---

## Scope contract

- The existing `facing` model, board indicator, diagonal melee, critical hits, and flank modifiers are already shipped. Do not duplicate or redesign them.
- A player-only right-click is a **free** facing action. It requires an alive selected player unit during the player turn, never spends AP, never changes action mode, and has no keyboard binding. A click on the unit's own tile is a no-op.
- On a landed hit, a surviving defender turns toward the attacker at most once per round. The flag resets for every living unit when `end_turn()` hands control back to the player (the project’s round boundary).
- Enemy target selection remains nearest living player, with existing reading-order tie-breaks. Against that one target, choose an affordable attack position by flank quality `rear > side > front`, then lower movement AP, then reading order. If none is affordable, retain the current approach-toward-target fallback.
- Do not stage, rewrite, or discard the user-owned modification in `docs/designs/combat-system.md`; it is the source design input. Do not push or open a PR.

| Order | Step | Branch | Depends on |
|---|---|---|---|
| 1 | [01-player-facing-and-hit-reactions.md](01-player-facing-and-hit-reactions.md) | `feat/player-facing-reactions` | — |
| 2 | [02-enemy-flanking-pathing.md](02-enemy-flanking-pathing.md) | `feat/enemy-flanking-pathing` | Step 1 merged locally |

## Shared setup and evidence

Before every step, inspect ownership and retain unrelated edits:

```bash
git status --short --branch
git diff -- docs/designs/combat-system.md
git checkout main && git pull
make check
```

Expected: the baseline suite passes. If `docs/designs/combat-system.md` is still modified, leave it untouched and out of every `git add` command.

Focused GUT command used by both steps:

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd -gexit
```

## Overall acceptance criteria

1. Right-click changes only the valid selected player unit’s facing and costs zero AP.
2. A defender turns toward its first landed attacker in a round; later landed hits in that round cannot turn it again; a new player round restores the reaction.
3. A six-AP enemy moves to a reachable rear attack tile before choosing a nearer front attack; side wins only when rear is unavailable; equal choices are deterministic.
4. No legal flank route means existing closest-approach behavior is unchanged.
5. `make check` passes and the user verifies the behavior in `make play` before each local merge.

## Risks and deliberate boundaries

- The input conversion must use the existing `_to_grid_position(make_input_local(event).position)` path so viewport offsets do not change what “direction clicked” means.
- Do not call `try_attack_selected_unit()` merely to evaluate candidates: it mutates AP, positions, facing, RNG, and health. Candidate ranking must be pure.
- Living units are the only movement and line-of-sight blockers today. Do not add terrain pathing in this slice.
- The scenario runner’s `CurrentEnemyPolicy` already delegates to `BattleController.run_enemy_turn()`, so no parallel policy implementation belongs in the plan.
