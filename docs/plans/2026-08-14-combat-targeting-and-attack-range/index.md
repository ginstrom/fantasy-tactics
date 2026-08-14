# Combat Targeting and Attack Range Implementation Plan

This implementation plan details the addition of attack range visualization, target highlighting, and combat targeting failure feedback to resolve the issue where ranged/missile attacks appear unresponsive when clicking enemies outside attack range or without sufficient AP.

## Overview & Goals

When a player selects a ranged unit (like a Scout) and clicks on an enemy unit in combat:
1. **Visual Cues**: The player needs to see the selected unit's attack range (in addition to movement range) and clearly identify which enemies are valid targets.
2. **Clear Feedback**: If the player clicks an enemy that cannot currently be attacked, the game must provide immediate, clear feedback (e.g. "Target is out of range", "Not enough Action Points to attack (requires 3 AP)", "Line of sight to target is blocked", "Unit is paralyzed") instead of silently doing nothing.

---

## Steps & Milestones

| Step | Plan File | Focus Area | Key Milestone |
|---|---|---|---|
| 1 | [`step-1-targeting-feedback-and-diagnostics.md`](step-1-targeting-feedback-and-diagnostics.md) | Targeting Diagnostics & Feedback | Clicking an invalid target provides clear, localized feedback explaining why the attack failed |
| 2 | [`step-2-attack-range-and-target-highlighting.md`](step-2-attack-range-and-target-highlighting.md) | Attack Range & Target Highlighting | Attack range tiles and attackable enemy units are visually highlighted when a unit with sufficient AP is selected |

---

## Execution Principles

- **Branching Workflow**: Develop on feature branches off `main` in the working copy (`feat/combat-targeting-feedback`, `feat/attack-range-highlighting`).
- **TDD (Red/Green)**: Write failing unit tests first in `tests/unit/`, confirm test failure, implement, and verify with `make check`.
- **Manual Verification**: Verify in-game behavior using `make play` or debug scenarios.
- **Local Branch Merge**: After user sign-off, merge the feature branch back to `main` locally and delete the branch.
