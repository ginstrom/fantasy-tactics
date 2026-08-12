# Step 3: Scout Recruitment & Roster Integration

> **Branch:** `feat/scout-ranger-class` (or step-specific branch off `main`)

## Goal
Integrate **Scout** adventurers into recruitment candidate generation, Guild Hall / Recruitment UI displays, and party management.

---

## Technical Design

1. **Recruitment Candidate Generation (`scripts/autoload/game_session.gd`)**:
   - Update `_generate_recruitment_candidate()`: Randomly roll between `warrior` and `scout` class templates (or based on active buildings).
   - Candidate generator generates appropriate starting equipment (Scout gets `shortbow_iron` + `leather_armor`).

2. **Recruitment & Guild Hall UI (`scenes/ui/recruitment.tscn` / `guild_hall.tscn`)**:
   - Render class badge/label (e.g., "Scout" vs "Warrior") in candidate cards and table views.
   - Display starting weapon and stats appropriate for the class.

3. **Party Manager & Unit Details UI**:
   - Update `scenes/ui/unit_details.tscn` and `scenes/ui/party_details.tscn` to show unit class name clearly.
   - Show active weapon range (`Range: 1–3` vs `Range: 1`) on the equipment display.

---

## TDD Milestones

### Red Phase (Failing Tests First)
Create `tests/unit/test_scout_recruitment_ui.gd`:
- `test_recruitment_candidates_can_include_scouts()`: Generating candidate pool can yield a candidate with `class: "scout"`.
- `test_scout_recruitment_purchases_valid_scout_adventurer()`: Purchasing a Scout candidate adds a valid Scout adventurer to `GameSession.adventurers` and deducts recruitment cost.
- `test_unit_details_displays_scout_class_and_weapon_range()`: Opening `unit_details.tscn` with a Scout displays "Scout" class label and weapon range (e.g. 1–3).
- `test_assigning_scout_to_party_succeeds()`: Adding a Scout to `party_001` succeeds and updates party member arrays.

### Green Phase (Implementation)
1. Update candidate generation logic in `scripts/autoload/game_session.gd`.
2. Update `scripts/ui/recruitment.gd` and `scripts/ui/guild_hall.gd` to render candidate class labels.
3. Update `scripts/ui/unit_details.gd` to display class name and weapon range.

---

## Verification & Milestone

- **Automated Tests**: All tests in `test_scout_recruitment_ui.gd` pass.
- **Verification Command**:
  ```bash
  godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_scout_recruitment_ui.gd
  make check
  ```
- **Manual Verification**: Launch game (`make play`), navigate to Guild Hall / Recruitment screen, verify Scout candidates can be recruited, viewed in Unit Details, and assigned to a party.
- **Local Merge**: Commit changes, merge branch back to `main` after user signoff.
