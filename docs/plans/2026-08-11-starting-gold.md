# Starting Gold Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** New campaigns start with 200 gold while a raw session reset remains zero-gold.

**Architecture:** Keep new-campaign policy in `GameSession.start_new_game()` and retain `reset()` as a neutral durable-state baseline. A named constant makes the temporary policy easy to replace with difficulty-specific resources later.

**Tech Stack:** Godot 4.7, GDScript, GUT.

---

### Task 1: Isolate starting-gold policy

**Files:**

- Modify: `scripts/autoload/game_session.gd`
- Modify: `tests/unit/test_game_session.gd`

**Step 1: Write the failing test**

Change `test_start_new_game_sets_the_player_name_and_resets_other_state()` to expect 200 gold after `start_new_game("Aria")`.

**Step 2: Run test to verify it fails**

Run: `make test TEST=tests/unit/test_game_session.gd`

Expected: the test reports the current zero-gold value instead of 200.

**Step 3: Write minimal implementation**

Add `const STARTING_GOLD := 200` near other GameSession constants, then set `gold = STARTING_GOLD` in `start_new_game()` immediately after `reset()`.

**Step 4: Run test to verify it passes**

Run: `make test TEST=tests/unit/test_game_session.gd`

Expected: all tests pass.

**Step 5: Commit**

```bash
git add scripts/autoload/game_session.gd tests/unit/test_game_session.gd \
  docs/plans/2026-08-11-starting-gold-design.md docs/plans/2026-08-11-starting-gold.md
git commit -m "feat: start new campaigns with gold"
```
