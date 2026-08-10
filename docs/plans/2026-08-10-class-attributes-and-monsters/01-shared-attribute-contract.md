# Step 1 — Shared Attribute Contract

## Milestone

A saved campaign and battle use `max_health`, `might`, `accuracy`, `guard`, `resistance`, and `mobility`, while a starter Warrior and current monsters produce the same deterministic combat outcomes as before migration.

## Setup

```bash
git checkout main && git pull --ff-only
git checkout -b feat/shared-tactical-attributes
make check
```

Read `docs/designs/class-system.md`, `docs/designs/monster-manual.md`, `docs/dev/code-map.md`, `scripts/autoload/game_session.gd`, `scripts/battle/unit.gd`, and `scripts/battle/battle_controller.gd` first.

## Red/green tasks

1. Add focused GUT tests for effective base/equipment attributes, the Accuracy-minus-Guard hit floor/cap, Might-before-Resistance damage, and snapshot import of each new field. Run the focused tests and confirm the contract fails before production changes.
2. Add versioned, JSON-safe adventurer attribute data and compatibility import for existing `attack`, `defense`, and `move_range` snapshots. Make `GameSession` the only source of effective-stat resolution.
3. Rename or add `Unit` runtime values only after getters supply resolved values; update battle construction and combat resolution without changing public scene ownership.
4. Run focused tests, then `make check`, the headless editor scan, and `git diff --check`.
5. Run `make play`; verify a level-1 Warrior still moves three tiles, has the documented 5–95% hit bounds, and takes the same damage from a Goblin.
6. After user signoff, commit, merge locally into `main`, and delete the feature branch. Do not push.
