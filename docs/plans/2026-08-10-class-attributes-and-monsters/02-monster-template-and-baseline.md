# Step 2 — Monster Template and Baseline

## Milestone

Kobold, Goblin, Orc, and Hobgoblin are immutable shared-attribute templates; the documented level-1/level-2 Warrior matchups have seeded simulation evidence and retain their current encounter composition/reward behaviour.

## Setup and red/green tasks

```bash
git checkout main && git pull --ff-only
git checkout -b feat/monster-template-baseline
make check
```

Read the monster manual, `GameSession.EXPEDITIONS`, `STAR_ENEMY_COMPOSITIONS`, `ENEMY_LOOT_TABLES`, and existing battle simulator tests. Add failing tests proving template lookup returns deep copies, initial monster attributes match the manual, and an encounter composition cannot mutate its source template. Replace split enemy stat constants with one template-shaped source while preserving ids, localization keys, XP, loot ids, counts, and current values exactly. Add seeded battle-simulation scenarios for level-1, level-2-unspent, and level-2-Accuracy Warrior matchups; report win rate, rounds, and damage. Run focused tests, `make check`, a representative simulator run, the editor scan, and `git diff --check`. With `make play`, verify Goblin Camp, Orc Outpost, and a Ruined Fortress composition. After user signoff, commit, merge locally into `main`, delete the branch, and do not push.
