# Step 06 — Enemy playback state repair

**Objective:** Implement the user-approved Step 05 model so every displayed
enemy-turn beat renders the state belonging to that beat.

**Dependency:** Step 05 approved and merged. **Branch:** `fix/enemy-playback-state`.

## Files

- Modify: exact `scripts/battle/battle_controller.gd` and/or
  `scripts/battle/battlefield.gd` seams chosen in Step 05
- Modify: `tests/unit/test_battlefield.gd` and possibly
  `tests/unit/test_battle_controller.gd`
- Modify: `docs/designs/enemy-playback-state.md` only if review changes the
  already approved design

## Red/green TDD

1. Add an end-to-end scene test using the deterministic scenario from Step 05.
   Advance the playback one beat at a time (inject zero/controlled beat delay
   and await frames as existing async tests do). Assert the first movement beat
   presents its origin/destination state and that a later kill does not remove
   its victim before the killing beat. The test must observe rendering-facing
   state, not merely the final model state.
2. Run red with the exact selected test name:
   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gunit_test_name=<approved_playback_test_name> -gexit
   ```
3. Implement only the approved model. Preserve the one authoritative combat
   rules path, deterministic `run_enemy_turn()` behavior for simulation tools,
   and input locking during playback. Do not mask the defect by removing
   intermediate redraws.
4. Run the focused test and relevant battle files green, then `make check`,
   editor parse, and `git diff --check`.

## Review, manual confirmation, merge

Reviewer compares the diff to the approved Step 05 design, checks no combat
state is duplicated, and verifies a later kill/move case. Manual check via
`make play`: use the recorded scenario, watch each movement and damage beat,
and confirm units neither teleport early nor disappear before their beat.
After user signoff, commit `fix(battle): render enemy turns from per-step state`,
merge locally, delete the branch, and attach the visual evidence to the handoff.
