# Task 3: Immediate level-up UI and progression display

## Objective

Make level gains playable immediately and make persistent progression legible
outside battle.

## Files

- Create: `scenes/ui/level_up.tscn`
- Create: `scripts/ui/level_up.gd`
- Modify: `scenes/battle/battlefield.tscn`
- Modify: `scripts/battle/battlefield.gd`
- Modify: `scenes/ui/unit_details.tscn`
- Modify: `scripts/ui/unit_details.gd`
- Modify: `translations/en.tres`
- Create: `tests/unit/test_level_up.gd`
- Modify: `tests/unit/test_battlefield.gd`
- Modify: `tests/unit/test_unit_details.gd`
- Modify: `tests/unit/test_localization.gd`

## Steps

1. Write failing scene tests for a `LevelUp` modal: it receives one adventurer
   ID, displays integer-facing XP, level, health gain, raw/effective Attack,
   and unspent points; its +/- controls cannot overspend; it cannot close with
   a required level-3 perk unchosen; and it emits a completion intent rather
   than changing scenes itself.
2. Write failing battlefield tests that a queued level-up locks board and End
   Turn input, processes multiple leveled party members in stable party order,
   and resumes battle/result routing only after the last modal completes.
3. Write failing Unit Details/localization tests replacing `TBD` labels with
   actual XP, Attack, health, skill-point, and Bonus Move data.
4. Run the focused tests red:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_level_up,test_battlefield,test_unit_details,test_localization -gexit
   ```

5. Implement a reusable modal overlay attached to `Battlefield`. The
   battlefield owns queueing and input lock/unlock; `LevelUp` reads fresh
   `GameSession` data and calls only validated session mutation APIs. For an
   ordinary level, allow the player to keep unspent points; for a third-level
   perk, require Bonus Move before Continue. Apply a level's health increase
   to the active unit before showing the modal.
6. Render the same derived data in Unit Details. Add semantic translations;
   do not hard-code English in GDScript. Run Godot's editor scan so new script
   `.uid` files are generated and tracked intentionally.
7. Rerun focused tests green, then commit:

   ```bash
   godot --headless --path . --editor --quit
   git add scenes/ui/level_up.tscn scripts/ui/level_up.gd scripts/ui/level_up.gd.uid \
     scenes/battle/battlefield.tscn scripts/battle/battlefield.gd \
     scenes/ui/unit_details.tscn scripts/ui/unit_details.gd translations/en.tres \
     tests/unit/test_level_up.gd tests/unit/test_battlefield.gd \
     tests/unit/test_unit_details.gd tests/unit/test_localization.gd
   git commit -m "feat: add immediate adventurer level-up UI"
   ```

## Milestone

A player sees and resolves every level-up safely at the moment it is earned,
and can later inspect the exact persistent result.
