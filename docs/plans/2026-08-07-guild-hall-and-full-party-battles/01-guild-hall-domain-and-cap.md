# Task 1: Guild Hall domain and the party-size cap

## Objective

Give `GameSession` a Guild Hall level, the party-size cap it drives, and the
upgrade rule — and make `assign_adventurer_to_party()` actually enforce that
cap for the first time (see design.md §1 "Party size cap").

## Files

- Modify: `scripts/autoload/game_session.gd`
- Modify: `tests/unit/test_game_session.gd`

## Steps

1. Add failing tests for the new state and derived cap:
   - A fresh session starts at `guild_hall_level == 1`.
   - `reset()` restores `guild_hall_level` to `1` (mirror the existing
     `test_reset_restores_the_default_player_name`-style test, but set
     `guild_hall_level = 2` first).
   - `get_max_party_size()` returns `4` at level 1 and `5` after setting
     `guild_hall_level = 2`.
2. Add failing tests for the upgrade rule:
   - `upgrade_guild_hall()` with `gold = 50`: returns `true`, leaves
     `guild_hall_level == 2`, `gold == 0`, `get_max_party_size() == 5`.
   - `upgrade_guild_hall()` with `gold = 49`: returns `false`, level and gold
     unchanged.
   - `upgrade_guild_hall()` called a second time after a successful upgrade
     (now at max level) with `gold = 100`: returns `false`, gold is not
     deducted again (still `50`, from the one successful upgrade).
   - `can_upgrade_guild_hall()` is `false` with no gold, `true` once
     `gold = 50`, and `false` again once already at max level.
3. Add failing tests for the capacity enforcement in
   `assign_adventurer_to_party()`:
   - Fill a level-1 party to exactly 4 members (the seeded `warrior_001` plus
     three appended test adventurers — reuse the file's existing
     `_adventurer(id, availability_status)` helper); a 5th assignment is
     rejected and `member_ids.size()` stays at `4`.
   - After `upgrade_guild_hall()` (with `gold = 50` first), the same party
     can accept a 5th member, reaching `member_ids.size() == 5`.
4. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session -gexit
   ```

   Expected: the new assertions fail (missing state/methods, and the old
   `assign_adventurer_to_party()` accepts unlimited members).
5. Implement in `game_session.gd`:
   - New constants next to the existing `GUILD_HALL`-adjacent block (place
     near `PERK_LEVEL_INTERVAL`/`BONUS_MOVE_PERK_ID`, since this is the same
     kind of domain-rule constant group):
     `GUILD_HALL_LEVEL_1_PARTY_CAP := 4`, `GUILD_HALL_LEVEL_2_PARTY_CAP := 5`,
     `GUILD_HALL_UPGRADE_COST := 50`, `GUILD_HALL_MAX_LEVEL := 2`.
   - New state `var guild_hall_level: int = 1`, declared next to `var gold`,
     reset to `1` in `reset()` in the same place `gold = 0` is reset.
   - `get_max_party_size() -> int`: returns `GUILD_HALL_LEVEL_2_PARTY_CAP` if
     `guild_hall_level >= GUILD_HALL_MAX_LEVEL`, else
     `GUILD_HALL_LEVEL_1_PARTY_CAP`.
   - `can_upgrade_guild_hall() -> bool`: `guild_hall_level < GUILD_HALL_MAX_LEVEL
     and gold >= GUILD_HALL_UPGRADE_COST`.
   - `upgrade_guild_hall() -> bool`: if not `can_upgrade_guild_hall()`, return
     `false` with no changes; otherwise deduct `GUILD_HALL_UPGRADE_COST` from
     `gold`, increment `guild_hall_level`, return `true`.
   - In `assign_adventurer_to_party()`, add one more disjunct to the existing
     rejection `if`:
     `or parties[party_index].member_ids.size() >= get_max_party_size()`.
6. Rerun the focused test green, then commit only this task's files:

   ```bash
   git add scripts/autoload/game_session.gd tests/unit/test_game_session.gd
   git commit -m "feat: add guild hall level and enforce the party-size cap"
   ```

## Milestone

`GameSession` can answer "how big can a party get" and "can the Guild Hall
be upgraded", and actually refuses to over-fill a party — all without
touching any screen yet.
