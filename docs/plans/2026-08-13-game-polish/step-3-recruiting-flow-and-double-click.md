# Step 3: Recruiting Flow and Double-Click Support

## Overview

This step implements the playtest feedback for the recruitment flow:
1. **Targeted Recruitment Return**: When navigating to Recruitment from the Party Details screen, purchasing a recruit (via button or double-click) returns the player directly to the Party Details screen for that party.
2. **Double-Click Recruiting**: Double-clicking a candidate row in `recruitment_table` purchases/recruits that candidate immediately.
3. **Roster Integration Verification**: Ensures a unit recruited directly to a party is removed from `recruitment_candidates` and added to both `adventurers` (the roster) and the party member list.
4. **Untargeted Recruitment Navigation**: When opening Recruitment from the Units screen (with no target party set), purchasing a recruit adds the unit to the roster and automatically navigates to the Roster screen (`roster.tscn`).

---

## Setup Instructions

1. Check out `main` and pull the latest changes:
   ```bash
   git checkout main && git pull
   ```
2. Create and check out a new branch:
   ```bash
   git checkout -b feat/recruiting-flow-and-double-click
   ```

---

## Test-Driven Development (TDD) Plan

### 1. Write Failing Tests (Red Phase)

Add unit tests in [`tests/unit/test_recruitment.gd`](file:///home/ryan/play/fantasy-tactics/tests/unit/test_recruitment.gd):

- **Double-click row activation test**:
  Emit `row_activated` on `recruitment_table` with a valid candidate ID and verify purchase is executed.
- **Targeted recruit navigation test**:
  Set `GameManager.recruitment_target_party_id = "party_001"`, trigger recruit via button or double-click, and verify navigation returns to `party_details.tscn` with `party_001`.
- **Roster & candidate list state test**:
  Verify candidate is removed from `recruitment_candidates` and present in `adventurers` and party `member_ids`.
- **Untargeted recruit navigation test**:
  Clear `GameManager.recruitment_target_party_id = ""`, trigger recruit via button or double-click, and verify navigation routes to `roster.tscn`.

Run tests to confirm failure:
```bash
godot --headless -s --path . addons/gut/gut_cmdln.gd -gselect=test_recruitment.gd
```

### 2. Implementation (Green Phase)

1. **Modify [`scripts/ui/recruitment.gd`](file:///home/ryan/play/fantasy-tactics/scripts/ui/recruitment.gd)**:
   - In `_ready()`, connect `recruitment_table.row_activated.connect(_on_row_activated)`.
   - Implement `_on_row_activated(row_id: Variant) -> void:` that triggers recruitment of `str(row_id)`.
   - Refactor candidate purchase completion in `_on_information_panel_recruit_selected(candidate_id: String)` and `_on_row_activated`:
     ```gdscript
     func _perform_recruitment(candidate_id: String) -> void:
         if GameManager.recruitment_target_party_id != "":
             var target_id := GameManager.recruitment_target_party_id
             if GameManager.purchase_recruit_for_target_party(candidate_id) == OK:
                 GameManager.go_to_party_details(target_id)
                 return
         else:
             if GameManager.purchase_recruit(candidate_id) == OK:
                 GameManager.go_to_roster()
                 return
         selected_candidate_id = ""
         refresh()
     ```

2. **Verify `GameManager` and `GameSession` handling**:
   - Ensure `purchase_recruit_for_target_party` returns `OK` and `GameManager.go_to_party_details(target_id)` transitions cleanly.

---

## Concrete Verifiable Milestone

Run the test suite:
```bash
make check
```
All GUT tests in `test_recruitment.gd` and the overall test suite pass cleanly.

---

## Manual Verification

1. Launch `make play`.
2. Navigate: Party Details -> Recruit button -> double-click or click Recruit on a candidate -> verify automatic return to Party Details with unit added.
3. Navigate: Units -> Recruitment -> double-click or click Recruit on a candidate -> verify automatic navigation to Roster screen.
