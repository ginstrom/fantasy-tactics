# Task 2: Battle XP events and derived stats

## Objective

Connect the progression domain to the current one-versus-one battle exactly
once per kill and once per victorious site clear.

## Files

- Modify: `scripts/battle/battle_controller.gd`
- Modify: `scripts/battle/battlefield.gd`
- Modify: `scripts/autoload/game_session.gd`
- Modify: `tests/unit/test_battle_controller.gd`
- Modify: `tests/unit/test_battlefield.gd`
- Modify: `tests/unit/test_game_session.gd`

## Steps

1. Write failing controller tests showing that the player `Unit` receives the
   selected adventurer's effective health, hit chance, and move range. Cover
   raw Attack 100 producing 0.95 hit chance and Bonus Move producing one extra
   move tile.
2. Write failing battlefield/session tests that a defeated Goblin awards 5 XP
   once, a won Goblin Camp awards its 10 clear XP once, and Orc equivalents
   award 10 and 20. Ensure defeat awards no clear XP and existing gold remains
   pending until Encampment return.
3. Run the focused tests red:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller,test_battlefield,test_game_session -gexit
   ```

4. Extend expedition records with `kill_xp` and `clear_xp`. Let the controller
   report a killed enemy to the battlefield after `try_attack_selected_unit()`;
   let the battlefield call the `GameSession` party-award API at that event and
   when victory resolves. Use per-battle/per-instance guards so repeated board
   refreshes and result timers cannot duplicate awards.
5. Build the player `Unit` from `GameSession`'s derived adventurer combat
   values. When a level is awarded during an active battle, update that unit's
   maximum and current health before the overlay in Task 3 resumes input.
   Keep enemy stats data-driven through the selected expedition.
6. Rerun focused tests green. Then commit:

   ```bash
   git add scripts/battle/battle_controller.gd scripts/battle/battlefield.gd \
     scripts/autoload/game_session.gd tests/unit/test_battle_controller.gd \
     tests/unit/test_battlefield.gd tests/unit/test_game_session.gd
   git commit -m "feat: award encounter experience in battle"
   ```

## Milestone

XP is an immediate and idempotent consequence of tactical events, while gold's
existing return-to-Encampment settlement rule is unchanged.
