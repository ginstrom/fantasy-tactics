# Step 2 — Class Progression and Perks

**Branch:** `feat/stage-2-progression-perks`
**Depends on:** Step 1 merged
**Milestone:** Every third level exposes valid data-backed class perk choices, while automatic owned-skill progression remains the only advancement path and Warrior/monster baselines are reproducible.

## Files

- Modify: `scripts/autoload/game_session.gd`
- Modify: `scripts/autoload/game_config.gd`
- Modify: `scripts/save/campaign_snapshot.gd`
- Modify: `scripts/ui/level_up.gd`
- Modify: `scenes/ui/level_up.tscn`
- Modify: `scripts/ui/unit_details.gd`
- Modify: `translations/en.tres`
- Modify: `docs/designs/monster-manual.md`
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/unit/test_campaign_snapshot.gd`
- Modify: `tests/unit/test_level_up.gd`
- Modify: `tests/unit/test_unit_details.gd`
- Modify: `tests/unit/test_localization.gd`

## Setup and design

Create a normal branch from merged `main` and run `make check`. Replace `BONUS_MOVE_PERK_ID`-only validation with a class-data lookup and query APIs such as `get_available_perks(adventurer_id)` and `get_perk_definition(perk_id)`. Keep `progression.perks` as the persisted selected-ID array unless Step 1 approved a schema extension. Effects belong in explicit `GameSession.get_effective_*` readers; no UI may apply a perk directly.

## Red/green tasks

1. In `test_game_session.gd`, write failing tests for: only declared skills advance; injected `skill_gain_roll` stays within approved ranges; a level 3/6 adventurer sees only its own eligible perks; invalid class, unmet prerequisite, duplicate, and full-slot selections leave state unchanged; and each approved effect changes only its named effective stat.
2. Add a failing snapshot round-trip/migration test. It must preserve valid new perk IDs, reject malformed/foreign IDs atomically, and normalize the prior lone `bonus_move` save without granting an extra slot.
3. Run the two focused files. Expected: failure because choice resolution is hard-coded and the second slot cannot be resolved.
4. Implement the smallest data schema, validation/query methods, migration, and effective-stat readers. Preserve `skill_points` removal and compatibility with old saves.
5. Add failing `test_level_up.gd`/`test_unit_details.gd` scene tests using real `.tscn` signal wiring: the modal renders each eligible localized choice and stays blocked until one succeeds; details show only owned skills and selected perk effects. Implement dynamic option controls rather than a class-name switch or a hard-coded second button.
6. Update translations and add localization assertions. Rerun the focused suites green.
7. Recalculate the two Warrior reference rows in `monster-manual.md` from the approved automatic gains. Add a deterministic regression assertion against that declared level/gear baseline; do not adjust a monster merely to hide a failed comparison.
8. Run `make check`, editor scan, and `git diff --check`.

## Manual signoff and merge

In `make play`, award enough XP to reach two perk slots for one Warrior, Scout, and Cleric. Verify each sees only its own available choices, the selected effect appears in Unit Details and battle UI where relevant, and no generic point-allocation control appears. After user signoff, commit `feat(progression): add class-owned perk choices`, merge locally, and delete the branch.
