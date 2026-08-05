# 01 — Recruitment Domain and Routes

## Milestone

`GameSession` safely exposes and purchases exactly three fixed Warrior candidates; `GameManager` opens Roster and Recruitment without stale route context.

## Files

- Modify: `scripts/autoload/game_session.gd`
- Modify: `scripts/autoload/game_manager.gd`
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/unit/test_game_manager.gd`

## Steps

1. **Red:** add `test_game_session.gd` cases that the initial deep-copied candidate query returns `warrior_002`, `warrior_003`, and `warrior_004`, each an available level-1 Warrior costing 10; reset restores all three.
2. **Red:** add cases that `purchase_recruit("warrior_002")` fails without funds and for unknown/already-purchased IDs without changing gold, candidates, or adventurers; with 10 gold it deducts exactly 10, removes only that candidate, and appends the expected adventurer.
3. **Red:** in `test_game_manager.gd`, require `go_to_roster()` and `go_to_recruitment()` scene routes that clear `route_context_id` and detail-origin state. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session,test_game_manager -gexit
   ```

   Expected: failure because the candidate/purchase APIs and routes do not exist.
4. **Green:** add a fixed template array (unique IDs/names, Warrior fields, `cost: 10`) and `recruitment_candidates` to `game_session.gd`; reset with deep copies. Implement `get_recruitment_candidates()` as a deep-copy query and `purchase_recruit(id) -> bool` as the only normal transaction: validate current candidate and funds, deduct candidate cost, remove it, append an adventurer copy without `cost`.
5. **Green:** preserve `recruit_adventurer()` only for existing debug tools if needed; normal UI must call the purchase transaction. Add route constants/methods in `game_manager.gd`, clearing all transient context before changing scene.
6. Re-run the focused command; expected: all selected tests pass. Commit:

   ```bash
   git add scripts/autoload/game_session.gd scripts/autoload/game_manager.gd tests/unit/test_game_session.gd tests/unit/test_game_manager.gd
   git commit -m "feat: add recruitable adventurer candidates"
   ```
