# Step 5 — Runic Workshop

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Deliver the level-1 Runic Workshop and its first armor-only Thorn
Rune, backed by shared hit-event and Paralyze-status behavior.

**Architecture:** `GameSession` owns building state, jobs, recipes, rune
ownership, and snapshots. `BattleController` owns hit events, chance
resolution, statuses, and action legality; `Battlefield` renders the resulting
state. A rune definition describes its event/tag/status behavior rather than
adding a callback inside normal attack resolution.

**Tech Stack:** Godot 4.7.1, GDScript, GUT 9.7.1, campaign snapshots, and
seeded scenario reports.

---

## Approved rules

- Build: 50 gold. Level 1 -> 2 upgrade: 50 gold.
- Thorn Rune is available at level 1. A job costs 20 gold plus one tier-1-or-
  higher mana crystal, takes seven World Map Turns, and only one job can run.
- Thorn sockets only into owned armor instances. Each armor instance has one
  socket; a replacement consumes the displaced rune.
- On a successful melee hit against Thorn armor, a 25% chance applies Paralyze
  to the attacker for one Round. Existing Paralyze blocks reapplication and
  never refreshes or stacks.
- Paralyze blocks movement, attacks, potion use, and item transfer. It expires
  at the next Round boundary, and the AI ends a paralyzed unit's turn safely.

### Task 1: Add durable Runic Workshop rules and jobs

**Files:**
- Modify: `scripts/autoload/game_session.gd`
- Modify: `scripts/save/campaign_snapshot.gd`
- Test: `tests/unit/test_game_session.gd`

1. Write failing tests for a 50-gold build, a 50-gold upgrade, an empty-job
   rejection, and a level-1 Thorn job consuming exactly 20 gold and one
   eligible crystal.
2. Run `make test TEST=tests/unit/test_game_session.gd`; expect the new APIs
   or assertions to fail.
3. Add Runic Workshop constants/state, reset/snapshot fields, recipe data, and
   atomic build/upgrade/start/query/World Map Turn advancement methods.
4. Add tests for failed preconditions leaving all durable state unchanged and
   for snapshot round trips preserving an active job.
5. Rerun the focused test file; expect all tests to pass.
6. Commit: `feat: add runic workshop jobs`.

### Task 2: Socket Thorn into armor atomically

**Files:**
- Modify: `scripts/autoload/game_session.gd`
- Test: `tests/unit/test_game_session.gd`

1. Write failing tests for armor-only compatibility, completed-job socketing,
   one-socket replacement consuming the old rune, and completed-rune snapshot
   persistence.
2. Run the focused test file; expect these cases to fail.
3. Validate the target owned instance and armor slot before completion mutates
   it. Store `rune_id: "thorn"` and rune tier metadata via the existing owned
   item instance contract.
4. Rerun the focused test file; expect all tests to pass.
5. Commit: `feat: socket thorn runes into armor`.

### Task 3: Add shared hit events and Paralyze

**Files:**
- Modify: `scripts/battle/battle_controller.gd`
- Modify: `scripts/battle/unit.gd` only if the existing unit-state boundary
  requires it
- Test: `tests/unit/test_battle_controller.gd`
- Test: `tests/unit/test_battlefield.gd`

1. Write failing controller tests for a melee-only completed-hit event, a
   chance-injection seam at 0% and 100%, trigger ordering after damage, a
   one-Round Paralyze, immunity while present, no refresh, and expiry at the
   Round boundary.
2. Add failing action tests proving Paralyze atomically blocks move, attack,
   potion use, and item transfer; add an AI turn test proving a paralyzed unit
   safely ends its turn.
3. Run `make test TEST=tests/unit/test_battle_controller.gd` and the relevant
   Battlefield test; expect the new behavior to fail.
4. Implement declarative effect dispatch from the completed-hit event and the
   reusable status query/lifecycle. Keep randomness injectable and do not
   mutate `GameSession` during a battle.
5. Rerun both focused tests; expect all tests to pass.
6. Commit: `feat: add thorn rune paralysis`.

### Task 4: Present the Runic Workshop and combat feedback

**Files:**
- Create: `scenes/ui/runic_workshop.tscn`
- Create: `scripts/ui/runic_workshop.gd`
- Modify: `scripts/autoload/game_manager.gd`
- Modify: `scripts/ui/buildings.gd`
- Modify: `scenes/battle/battlefield.tscn`
- Modify: `scripts/battle/battlefield.gd`
- Modify: `translations/en.tres`
- Test: `tests/unit/test_runic_workshop.gd`
- Test: `tests/unit/test_buildings.gd`
- Test: `tests/unit/test_game_manager.gd`
- Test: `tests/unit/test_battlefield.gd`

1. Write failing UI tests for Buildings routing, build/upgrade labels, eligible
   armor selection, the seven-turn countdown, and return navigation.
2. Write failing Battlefield feedback tests for a Thorn trigger and a visible
   Paralyzed state.
3. Run each focused test; expect failures for absent route/scene/UI feedback.
4. Implement the screen using the established workshop pattern, a selection of
   owned compatible armor instances, and translated feedback. Keep unavailable
   actions disabled and let `GameSession` remain the authority.
5. Rerun focused tests; expect all tests to pass.
6. Commit: `feat: add runic workshop UI`.

### Task 5: Verify and hand off

1. Run `godot --headless --path . --editor --quit`, `make check`, and
   `git diff --check`; expect exit code 0.
2. Run a seeded Thorn scenario (including both trigger and non-trigger cases)
   and preserve generated reports outside Git.
3. Run `make play`: build the workshop, socket Thorn into armor, enter a
   battle, observe a melee trigger and the Paralyzed attacker, then verify a
   replacement consumes the old rune.
4. Ask the user for signoff. After it, commit any final changes, merge
   `feat/runic-workshop` locally to `main`, delete the branch, and do not push.
