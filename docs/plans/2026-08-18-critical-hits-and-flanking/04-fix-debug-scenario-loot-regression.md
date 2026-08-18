# Step 4: Fix Missing Loot on Debug-Scenario Battles

**Date:** 2026-08-18
**Status:** proposed
**Branch:** `fix/debug-scenario-loot-regression`
**Part of:** [`docs/plans/2026-08-18-critical-hits-and-flanking/index.md`](index.md)

## Summary

During Step 1's manual sign-off (`make play` → FN+F9 → **Goblin Camp Battle**), no mana crystal (or gold, or gear) was queued after defeating the goblin. This is unrelated to facing/critical-hits/flanking — it is a pre-existing regression in the **debug scenario fixtures**, confirmed by root-cause analysis below. The user asked for it to be fixed as its own step before the plan's final whole-branch review.

## Root Cause

`GameSession._roll_and_queue_loot(enemy)` ([`scripts/autoload/game_session.gd:1136`](../../../scripts/autoload/game_session.gd)) looks up `enemy.get("loot_id", "")` in `ENEMY_LOOT_TABLES` and returns immediately (queuing nothing) when that id isn't found:

```gdscript
var loot_id: String = enemy.get("loot_id", "")
if not ENEMY_LOOT_TABLES.has(loot_id):
    return
```

In real campaign play, `enter_encounter()` calls `_resolve_enemy_composition()`, which replaces `active_encounters[i].enemy` with an entry drawn from `STAR_ENEMY_COMPOSITIONS` (`GOBLIN_ENEMY_STATS` / `ORC_ENEMY_STATS` / `KOBOLD_ENEMY_STATS` / `HOBGOBLIN_ENEMY_STATS`, `game_session.gd:85-137`) — every one of those constants carries a `loot_id`. This path is covered by existing tests (e.g. `test_completing_the_goblin_camp_queues_gold_a_mana_crystal_and_no_gear_when_the_gear_roll_misses`, `tests/unit/test_game_session.gd:760`) and works correctly.

The debug-scenario fixtures in `config/debug_scenarios.json` were captured directly from `GameSession.export_campaign_snapshot()` output, but every `active_encounters[].enemy` entry in every one of the 10 scenarios mirrors the **static `EXPEDITIONS` template stub** (`game_session.gd:35-83`), not a resolved composition — and that stub has never carried a `loot_id`. Confirmed by inspection: `grep -c loot_id config/debug_scenarios.json` is `0` across all 21 `active_encounters` entries (goblin_camp ×10, orc_outpost ×10, ruined_fortress ×1). Launching straight into a debug scenario (FN+F9) restores this snapshot verbatim — including `selected_encounter`, so `complete_current_encounter()` does run on victory — but `_roll_and_queue_loot()` silently no-ops for every kill because `loot_id` is missing.

This affects **only** the debug-scenario JSON fixtures. No production code changes are needed.

## Technical Design

### `config/debug_scenarios.json`

Add a `"loot_id"` key to every `active_encounters[].enemy` dictionary, matching the `loot_id` the corresponding production composition would resolve to:
- `goblin_camp` encounter → `"loot_id": "goblin"` (matches `GOBLIN_ENEMY_STATS`, the tier-1 `STAR_ENEMY_COMPOSITIONS` option).
- `orc_outpost` encounter → `"loot_id": "orc"` (matches `ORC_ENEMY_STATS`).
- `ruined_fortress` encounter (scenario `ruined_fortress` only) → `"loot_id": "kobold"` (matches `KOBOLD_ENEMY_STATS`, the tier-3 first/"Kobold-first" `STAR_ENEMY_COMPOSITIONS` option per `game_session.gd:145-147`'s ordering note).

No other field changes. `_normalize_active_encounters()` (`scripts/save/campaign_snapshot.gd:563`) passes the `enemy` sub-dictionary through opaquely, so this survives import/export round-trips unchanged — the existing `_assert_fixture_round_trips()` tests stay valid without modification.

### `tests/unit/test_debug_scenarios.gd`

1. A fixture-coverage test iterating every scenario's `campaign_snapshot.active_encounters`, asserting each `enemy.get("loot_id", "")` is a key present in `GameSession.ENEMY_LOOT_TABLES`. This locks the invariant so a future fixture edit or new scenario can't silently reintroduce the drop.
2. An end-to-end regression test that reproduces the exact bug the user hit: apply the `goblin_camp` debug scenario (`DebugScenarios.apply("goblin_camp")`, which — per the existing `test_goblin_camp_fixture_round_trips_through_apply_and_export` test's own comment — already sets `GameSession.selected_encounter` without needing a live battle), call `GameSession.complete_current_encounter()` directly (the same call `battlefield.gd:_finish_victory()` makes on victory), and assert `GameSession.battle_mana_crystals` is non-empty (`{1: 1}`, matching goblin's `mana_crystal_tier`) and `GameSession.battle_reward > 0`.

---

## Setup

```bash
git checkout main && git pull
git checkout -b fix/debug-scenario-loot-regression
make check   # confirm clean baseline before changes
```

---

## TDD Task List (Red → Green)

1. **Fixture Loot-ID Coverage & End-to-End Regression ([`tests/unit/test_debug_scenarios.gd`](../../../tests/unit/test_debug_scenarios.gd)):**
   - Add the fixture-coverage test (Technical Design §2.1). Run it — confirm it fails for all 21 `active_encounters` entries (missing `loot_id`).
   - Add the end-to-end regression test (Technical Design §2.2). Run it — confirm it fails (`battle_mana_crystals` stays empty, `battle_reward` stays `0`).
2. **Fix the Fixtures ([`config/debug_scenarios.json`](../../../config/debug_scenarios.json)):**
   - Add `"loot_id"` to all 21 `active_encounters[].enemy` entries per Technical Design §1.
   - Re-run both new tests — confirm green.
   - Re-run the existing `_assert_fixture_round_trips` tests (`test_goblin_camp_fixture_round_trips_through_apply_and_export`, `test_orc_outpost_fixture_round_trips_through_apply_and_export`, `test_ruined_fortress_fixture_round_trips_through_apply_and_export`, and the rest) — confirm they still pass unchanged, proving the added field round-trips cleanly.

---

## Verification

Run the full validation suite:

```bash
make check
```

Expected output: All unit tests pass with zero errors, zero orphans, and zero warnings.

---

## Manual Verification (User Sign-off)

1. Run `make play`.
2. Press **FN+F9** to open the Debug Scenario Menu, select **Goblin Camp Battle**.
3. Defeat the goblin and reach the victory summary screen.
4. Confirm the loot rows now show gold **and** a mana crystal (gear appears only if its chance roll hits — that part was already correct).
5. Repeat with **Orc Outpost Battle** and confirm the same.

---

## Commit and Merge

```bash
git status --short
git add config/debug_scenarios.json tests/unit/test_debug_scenarios.gd
git diff --cached --check
git commit -m "fix(debug): add missing loot_id to debug scenario enemy fixtures"

# After user sign-off:
git checkout main
git merge fix/debug-scenario-loot-regression
git branch -d fix/debug-scenario-loot-regression
```

---

## Milestone (Concretely Verifiable)

- Every debug-scenario fixture's `active_encounters[].enemy` declares a `loot_id` present in `GameSession.ENEMY_LOOT_TABLES`, locked by a regression test.
- Completing an encounter loaded from a debug scenario queues gold and a mana crystal identically to real campaign play, proven by a direct `complete_current_encounter()` assertion (no manual play required to catch a regression here again).
- `make check` passes 100% green.
- Manual `make play` verification confirms loot now appears after a debug-scenario victory.
