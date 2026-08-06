# Task 1: Durable progression domain

## Objective

Give every adventurer deterministic, testable progression state without
changing battle or screen behavior yet.

## Files

- Modify: `scripts/autoload/game_session.gd`
- Modify: `tests/unit/test_game_session.gd`

## Steps

1. Add failing tests for a new campaign's default Warrior: `xp == 0.0`, level
   1, 60 Attack, zero unspent points, no perks, and three max health.
2. Add failing tests for `award_party_xp(party_id, amount: float)`: it divides
   a 5.0 award exactly between two members as 2.5 each; ignores an unknown or
   empty party; and returns the IDs that crossed a level threshold.
3. Add failing tests for cumulative thresholds: 20 reaches level 2, 50 reaches
   level 3, an oversized award can resolve multiple levels, each level adds one
   health and ten points, and only levels divisible by three require a perk.
4. Add failing tests for guarded mutation APIs: `spend_attack_points(id, n)`
   rejects non-positive/overspent/missing inputs, decrements points, and adds
   `n` to raw Attack; `choose_perk(id, perk_id)` accepts `bonus_move` once only
   when it is pending. Test effective hit chance is `min(raw_attack / 100.0,
   0.95)` while raw Attack itself can exceed 95.
5. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session -gexit
   ```

   Expected: the new assertions fail because no progression API exists.
6. Implement the smallest domain API. Keep `xp` as a `float`; keep authored
   base combat values and progression data in each adventurer record; expose
   copies via `get_adventurer()`; and centralize threshold, effective-hit,
   effective-health, and effective-move calculations in `GameSession`.
   Do not duplicate formulas in a screen or the battle controller.
7. Rerun the focused test green, then commit only this task's code/tests:

   ```bash
   git add scripts/autoload/game_session.gd tests/unit/test_game_session.gd
   git commit -m "feat: add adventurer progression domain"
   ```

## Milestone

The session can fairly award fractional party XP and expose a complete,
validated progression state without requiring a scene.
