# Trade Follow-ups and World-Map Regression Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development`
> (recommended) or `superpowers:executing-plans` to implement this plan
> task-by-task.

**Goal:** Close out the deferred findings from the trade/equipment/loot
plan's final review (iron/steel weapons sharing a display name, no
equipment readback anywhere, a few small cleanup items) and investigate the
three world-map pathing symptoms found during that plan's manual
verification — while adding the regression-test coverage that would have
caught both classes of gap earlier.

**Architecture:** Three independent phases in one plan (the user chose one
combined plan over two separate ones): **Phase A** investigates and (as far
as evidence allows) fixes the pre-existing world-map symptoms; **Phase B**
addresses the deferred trade/equipment UX and cleanup items; **Phase C**
hardens regression-test coverage for both the equipment/loot/trade system
and the gap Phase A's investigation exposed (no test previously exercised a
*real* `SceneTree.change_scene_to_file()` transition). Phases don't depend
on each other except where noted per-task; Phase C's final task depends on
Phase B's naming/display tasks landing first so its assertions read final
values.

**Tech Stack:** Godot 4 / GDScript, GUT 9.7.1 test framework.

## Global Constraints

- Follow `docs/plans/trading-system.md` for any game number this plan
  touches (none of these tasks introduce new balance numbers — Phase B is
  display/cleanup only).
- GDScript indentation in this codebase is tabs, one per nesting level —
  match it exactly in every code block below.
- Per `AGENTS.md`'s branching workflow: one regular branch off `main` for
  the whole plan, no worktree. Commit each task separately, staging only
  that task's files, using the commit message given at the end of that
  task file. Merge back to `main` locally only after user sign-off; do not
  push to `origin` or open a PR unless asked.
- Use red/green TDD for every task that has a test — the one exception is
  Task 02, which is diagnostic-only by design (see that task's own note).
- Run `make test` before moving to the next task; the whole suite must stay
  green (`---- All tests passed! ----`, exit 0) after every task.

---

## Scope and sequencing

Read this plan's originating context first if you weren't part of the
conversation that produced it: `docs/plans/2026-08-08-trade-equipment-loot-and-ui/index.md`
is the plan whose final review and manual-verification pass produced every
item below. `docs/plans/trading-system.md` remains the authoritative design
spec for game numbers.

**Phase A — World-Map Pathing Investigation**

During the trade plan's manual verification, the user reported three
symptoms on the World Map, confirmed present on `main` before that plan's
branch even existed (not a regression from it):
1. After winning a battle entered via the debug menu, the party is not
   selectable on the World Map.
2. Selecting a multi-tile route and pressing End Turn once appears to make
   the whole route "disappear."
3. Walking a deployed party to the Goblin Camp and clicking does not enter
   the battle.

Extensive investigation during that plan's Task 17 (documented in this
plan's Task 01/02) could **not** reproduce any of the three symptoms
through either isolated logic tests or a newly-built, maximally faithful
integration test that drives a real battle to victory and inspects the
actual live scene produced by `GameManager`'s real
`get_tree().change_scene_to_file()` call — every code path involved
behaves correctly under test. This means the root cause is very likely
either (a) something specific to real mouse-to-tile coordinate mapping in
a running window, which no headless test can exercise, or (b) a UX clarity
gap (entering an encounter requires a select-then-activate double click on
the same tile; nothing currently signals that to the player). Phase A
cannot conclude with a confident code fix without more evidence — Task 01
banks the regression-test value this investigation already produced, and
Task 02 adds narrowly-scoped diagnostic logging and hands reproduction
back to the user with instructions on exactly what to capture. **Do not
guess at a fix beyond Task 02 without that evidence** — if it arrives
before this plan is executed, replace Task 02's open item with a concrete
fix task before starting Phase A.

**Addendum (found during Task 10's manual verification):** hypothesis (a)
was correct. Root cause: `_unhandled_input()` derived the clicked tile
from `board.get_local_mouse_position()` — the Viewport's tracked cursor
position, refreshed only by `MouseMotion` events — instead of the actual
`InputEventMouseButton`'s own `.position`. Godot never emits a fresh
`MouseMotion` event for a stationary mouse, so right after a scene
transition (Battlefield → World Map on victory) the tracked position is
stale from the *old* scene until the mouse physically moves, and the
first click can resolve to the wrong tile entirely — exactly reproducing
symptom 1. A real `InputEventMouseButton` dispatched through
`_unhandled_input()` on a live post-victory World Map (not a direct
`_handle_tile_click()` call, which bypasses this code path entirely)
reproduced it deterministically. Fixed by using
`CanvasItem.make_input_local(event)` to derive the tile from the event's
own position; a permanent regression test
(`test_a_real_click_event_selects_the_party_even_when_the_tracked_cursor_position_is_stale`)
was added to `test_world_map.gd` and confirmed red-then-green against the
fix. Symptoms 2 and 3 were not independently re-investigated after this
fix — 3 may well have shared this same root cause (any click, not just
the first one after a scene change, reads the same code path), but that
needs a fresh manual verification pass to confirm.

**Phase B — Trade/Equipment Follow-ups** (independent of Phase A)

1. [03-split-iron-and-steel-weapon-display-names.md](03-split-iron-and-steel-weapon-display-names.md)
2. [04-adventurer-equipment-readback-in-unit-details.md](04-adventurer-equipment-readback-in-unit-details.md)
   — depends on Task 03 (uses the split weapon names in its manual
   verification, though its own assertions don't hardcode them).
3. [05-remove-dead-bank-bypassing-equip-methods.md](05-remove-dead-bank-bypassing-equip-methods.md)
4. [06-trading-post-own-type-translation-keys.md](06-trading-post-own-type-translation-keys.md)
5. [07-screenshot-tour-stores-step-shows-sell-enabled.md](07-screenshot-tour-stores-step-shows-sell-enabled.md)

**Phase C — Regression Test Hardening**

1. [08-harden-gamesession-injectable-callable-test-isolation.md](08-harden-gamesession-injectable-callable-test-isolation.md)
2. [09-full-trade-loop-integration-regression-test.md](09-full-trade-loop-integration-regression-test.md)
   — depends on Task 03 (weapon display names) and Task 04 (equipment
   readback), since it exercises both.

**Close-out**

- [10-regression-sweep-and-merge.md](10-regression-sweep-and-merge.md)

**Explicitly out of scope for this plan:** the final review of the trade
plan also surfaced two balance observations — gold income dropped sharply
under the new roll-based loot system (1-6/kill vs. the old flat 10/25)
while the Trading Post that unlocks converting loot to gold costs 50 gold
upfront; and armor's `resistance` stat currently mitigates zero damage
against both currently-fightable enemies (goblin/orc) due to rounding, so
only the `defense`/hit-chance half of armor does anything today. Both
follow correctly from `docs/plans/trading-system.md`'s approved formulas —
fixing either means changing approved game-balance numbers, which is a
design decision for the user to make, not an engineering task to plan
around. No task here touches either; raise them with the user directly if
and when a rebalance is wanted.

## Shared delivery protocol

1. `git checkout main && git pull`, then
   `git checkout -b fix/trade-followups-and-world-map`.
2. Work the tasks in the order above (Phase A first is not required by any
   dependency — Phases A/B/C are independent of each other except where
   individual tasks note otherwise — but keep Phase C's Task 09 last since
   it depends on Task 03 and Task 04).
3. For every task with a test: write it, run it red, implement, run it
   green. Commit each completed task separately using the commit message
   given at the end of that task file.
4. Run `make test` before moving to the next task.
5. Do not skip ahead to Task 10's manual verification and merge until
   Tasks 03-09 are committed and `make test` is green, and until Phase A
   has either landed a fix (if evidence arrived) or is explicitly deferred
   with the user's agreement (see Task 02).

## Definition of done

- Every weapon in `GameSession.WEAPONS` has a display name that
  distinguishes its Iron and Steel tiers in Trading Post and Stores.
- Unit Details shows an adventurer's equipped weapon (name + damage range)
  and armor (name + defense/resistance).
- `set_adventurer_weapon`/`set_adventurer_armor` (dead code, zero
  production callers) are removed.
- Trading Post's Type column reads its own translation keys, not Stores'.
- The screenshot tour's `stores` step renders with Sell enabled.
- `GameSession`'s injectable Callables (`enemy_composition_roll`,
  `loot_gold_roll`, `loot_gear_roll`) no longer leak a stub from one test
  file into a later one within the same `make test` run.
- A real, `change_scene_to_file()`-driven integration test asserts the
  live World Map is selectable/interactive immediately after a real battle
  victory (Task 01) — this closes the specific testing gap Phase A's
  investigation found, independent of whether Phase A's root cause is
  ever found.
- A full trade-loop integration test (buy at the Trading Post, assign to a
  unit, fight with the new equipment) exists as permanent regression
  coverage, automating what the trade plan's Task 17 asked the user to
  verify by hand.
- `make test` prints `---- All tests passed! ----` and exits 0.
- The branch is merged into `main` after the user has manually verified
  Phase B's changes via `make play` (Task 10) and after Phase A's status —
  fixed, or explicitly deferred pending more evidence — is confirmed with
  the user.
