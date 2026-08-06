# Step 1: Two-site session state

## Objective

Seed the two available encounter choices and make their display difficulty
durable, without changing combat or refill rules.

## Files

- Modify: `scripts/autoload/game_session.gd`
- Modify: `tests/unit/test_game_session.gd`

## Red/green TDD

1. Add a failing reset-state test asserting active instances are, in order,
   `goblin_camp` at `(4, 4)` with `difficulty == 1`, then `orc_outpost` at
   `(4, 0)` with `difficulty == 2`.
2. Add a failing test that clearing Goblin Camp leaves Orc Outpost active and
   starts exactly one 15-turn vacancy timer.
3. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session -gexit
   ```

   Expected: the new assertions fail because reset seeds only Goblin Camp and
   template records have no `difficulty` field.
4. Add `difficulty: 1` to the Goblin template and `difficulty: 2` to the Orc
   template. In `reset()`, construct both documented instances in a stable
   Goblin-then-Orc order and initialise `_used_encounter_template_ids` with
   both template IDs.
5. Do not alter `ENCOUNTER_INSTANCE_CAP`, `_start_encounter_vacancy()`, spawn
   position logic, battle data, or recruitment.
6. Rerun the focused test green and commit:

   ```bash
   git add scripts/autoload/game_session.gd tests/unit/test_game_session.gd
   git commit -m "feat: seed two starting encounters"
   ```

## Milestone

A fresh session exposes two distinct active expeditions whose difficulty is
available to presentation code; clearing either one preserves the other.
