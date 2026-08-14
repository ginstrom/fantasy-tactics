# Step 1: Bow Weapon Catalog Definitions and Range Updates

## Goal
Update bow ranges in `GameSession.WEAPONS` to:
- Iron Shortbow: 8
- Steel Shortbow / Steel Hunting Bow: 10
- Iron Longbow: 12
- Steel Longbow: 15

Add appropriate localization strings for new bow entries, update unit tests verifying the catalog and UI range displays.

## Setup
1. `git checkout main && git pull`
2. `git checkout -b feat/bow-ranges`

## TDD Workflow
### 1. Red Phase (Write Failing Tests)
- In `tests/unit/test_scout_class_and_permissions.gd`:
  - Update `test_weapon_catalog_includes_bows_with_their_range_and_category()` to verify ranges for `shortbow_iron` (8), `shortbow_steel` (10), `hunting_bow_steel` (10), `longbow_iron` (12), and `longbow_steel` (15).
  - Verify translations for `"item.shortbow_steel"`, `"item.longbow_iron"`, `"item.longbow_steel"`.
- In `tests/unit/test_scout_recruitment_ui.gd`:
  - Update `test_unit_details_displays_scout_class_and_weapon_range()` to assert `"Range: 1–8"` for the default scout holding an iron shortbow.
- Run tests and verify failure.

### 2. Green Phase (Implement)
- Update `scripts/autoload/game_session.gd`:
  - Set `shortbow_iron.max_range = 8`.
  - Add `shortbow_steel` with `max_range = 10`.
  - Set `hunting_bow_steel.max_range = 10`.
  - Add `longbow_iron` with `max_range = 12`.
  - Add `longbow_steel` with `max_range = 15`.
- Update `translations/en.tres` with names for `item.shortbow_steel`, `item.longbow_iron`, `item.longbow_steel`.

### 3. Verification Phase
- Run `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_scout_class_and_permissions.gd -gexit`
- Run `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_scout_recruitment_ui.gd -gexit`
- Run `make check` to verify entire test suite passes.

## Manual Verification
- Run `make play`.
- Inspect a Scout in the guild hall / encampment and verify the equipment line shows "Range: 1–8".
- In battle with a Scout, verify attack range highlights extend up to 8 tiles away.

## Commit & Merge
- `git add . && git commit -m "feat(weapons): update bow ranges and catalog definitions"`
- `git checkout main && git merge feat/bow-ranges && git branch -d feat/bow-ranges`
