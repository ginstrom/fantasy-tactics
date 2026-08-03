# Scene Taxonomy Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor the current generic tactical scene into the approved battle-specific scene taxonomy without changing gameplay behavior.

**Architecture:** The scene manager will route to `scenes/battle/battlefield.tscn`; the scene's attached script will move with it. Existing boot, UI, and world scenes stay in their domain folders. An empty local-map folder documents the reserved domain without adding unimplemented gameplay.

**Tech Stack:** Godot 4.7, GDScript, GUT, Make.

---

### Task 1: Prove the future battle-scene route is not present

**Files:**
- Modify: `tests/unit/test_game_manager.gd`

**Step 1: Write the failing test**

Add a test that reads `scripts/autoload/game_manager.gd` and asserts it contains
`res://scenes/battle/battlefield.tscn`.

**Step 2: Run test to verify it fails**

Run: `make test`

Expected: FAIL because the manager still points to `scenes/game/game.tscn`.

### Task 2: Move the tactical scene into the battle domain

**Files:**
- Move: `scenes/game/game.tscn` to `scenes/battle/battlefield.tscn`
- Move: `scripts/game/game.gd` to `scripts/battle/battlefield.gd`
- Modify: `scenes/battle/battlefield.tscn`
- Modify: `scripts/autoload/game_manager.gd`
- Create: `scenes/local/.gitkeep`

**Step 1: Implement the minimal move and route update**

Update the scene's script resource path and `GameManager` battle scene constant
to the new paths. Preserve all runtime behavior.

**Step 2: Run test to verify it passes**

Run: `make test`

Expected: PASS, including the new route test.

### Task 3: Update path-based tests and validate the project

**Files:**
- Modify: `tests/unit/test_game.gd`
- Modify: `tests/unit/test_localization.gd`

**Step 1: Update only stale `game` scene/script paths**

Point tests at `battlefield.tscn` and `battlefield.gd`.

**Step 2: Run the full validation suite**

Run: `make check`

Expected: all GUT tests pass with no parse errors or stale scene paths.

### Task 4: Commit the refactor

**Files:**
- Modify: all files above

**Step 1: Review the diff**

Run: `git diff --check` and `git status --short`

**Step 2: Commit**

```bash
git add docs/plans scenes scripts tests
git commit -m "refactor: organize battle scene taxonomy"
```
