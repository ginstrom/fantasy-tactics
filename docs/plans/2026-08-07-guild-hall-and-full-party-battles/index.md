# Guild Hall and Full-Party Battles Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Add the game's first building (Guild Hall, which raises the party-
size cap) and rework the battlefield to field every party member at once,
with a portrait panel, mouse/keyboard selection, and a shared movement-points
budget.

**Architecture:** `GameSession` gains the Guild Hall's durable level/cap
state and rules, following the same pattern as its other domain rules
(progression, vacancy timers). `battle_controller.gd` (the headless-testable
combat logic) gains multi-unit fielding, a shared per-unit movement budget,
and WASD/number-key input handling; `battlefield.gd` (the scene-owning UI
layer) gains a new portrait-panel component and an adjusted HUD. Two new
list/detail screens (Buildings, Guild Hall) follow the existing
`roster.tscn`/`party_details.tscn` list-then-detail pattern.

**Tech Stack:** Godot 4, GDScript, GUT, semantic translation keys in
`translations/en.tres`.

---

## Scope and sequencing

Read [design.md](../2026-08-07-guild-hall-and-full-party-battles-design.md)
first — it is the approved spec this plan implements; do not deviate from
its documented constants (positions, colors, costs, caps) without checking
back with the user. Deliver the tasks in order:

1. [01-guild-hall-domain-and-cap.md](01-guild-hall-domain-and-cap.md) —
   `GameSession` state/rules for Guild Hall level and the party-size cap.
2. [02-guild-hall-ui-and-party-screens.md](02-guild-hall-ui-and-party-screens.md)
   — Buildings and Guild Hall screens, and the two existing screens that must
   react to a full party.
3. [03-shared-movement-points.md](03-shared-movement-points.md) — replace
   `Unit.has_moved` with a spendable `moves_remaining` budget.
4. [04-full-party-fielding.md](04-full-party-fielding.md) — spawn one Unit
   per party member and per encounter enemy count, at fixed start clusters.
5. [05-wasd-and-number-key-selection.md](05-wasd-and-number-key-selection.md)
   — keyboard movement and party-member selection.
6. [06-portrait-panel-and-hud.md](06-portrait-panel-and-hud.md) — the
   Baldur's-Gate-style left portrait panel and the adjusted health HUD.
7. [07-integration-and-regression-sweep.md](07-integration-and-regression-sweep.md)
   — full-suite regression pass, manual verification, merge back to `main`.
   (The full-campaign integration test rewrite this task originally owned
   landed early, as an in-scope straggler fix during Task 4.)

Tasks 1-2 (Guild Hall) are small and low-risk and establish
`GameSession.get_max_party_size()`, which task 4's fielding logic does not
itself call but which the same design doc groups with this slice. Tasks 3-6
are the larger, riskier battlefield rework and touch a large share of the
existing battle test suite — expect real, nontrivial test-rewrite cost in
each of those tasks, not just new tests.

## Shared delivery protocol

1. Work on a regular branch off current `main` (e.g.
   `git checkout -b feat/guild-hall-and-full-party-battles`); do not create a
   worktree. `git checkout main && git pull` first if `main` may have moved.
2. For every behavior change, add the named GUT test, run it red, implement
   the smallest code path, and rerun it green. Commit each completed task
   separately, staging only that task's files.
3. Run `make check` (`godot --headless -s addons/gut/gut_cmdln.gd -gexit`)
   before moving to the next task. A focused run against one file looks like:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session -gexit
   ```
4. Run `make play` for manual verification in Task 7. Do not merge until the
   user signs off on that manual pass. Then merge locally into `main`,
   delete the branch, and do not push unless asked.

## Definition of done

- A fresh campaign caps party assignment at 4 members; spending 50 gold at
  the Guild Hall raises the cap to 5 (level 2, the max for this slice).
  `party_details.gd` and `unit_details.gd` both stay honest about a full
  party rather than silently failing an assignment.
- Every deployed party member (not just the first) appears on the
  battlefield, at a fixed start position; every encounter's documented enemy
  count is fielded, not just one enemy.
- A unit's movement is a spendable per-turn points budget, not an
  all-or-nothing flag: WASD steps and multi-tile clicks share the same
  budget and can be freely interleaved with the unit's one attack.
- A left portrait panel shows one square per fielded party member (color,
  health, selection ring, dimmed-when-defeated), selectable by click or by
  number key 1-5.
- The full first-campaign integration test and the whole existing test suite
  pass under `make check`.
