# Step 2: Units Screen Redesign

## Overview

The current Units screen (`scenes/ui/units.tscn`) displays a plain stack of navigation buttons ("Roster", "Parties", "Recruitment"), which is redundant with the `CampNav` side menu.

This step updates `units.tscn` and `units.gd` to display key unit counts with dedicated `[View]` buttons:
```
Parties: 2 [View]
Units in roster: 13 [View]
Recruitable units: 2 [View]
```

---

## Setup Instructions

1. Check out `main` and pull the latest changes:
   ```bash
   git checkout main && git pull
   ```
2. Create and check out a new branch:
   ```bash
   git checkout -b feat/units-screen-redesign
   ```

---

## Test-Driven Development (TDD) Plan

### 1. Write Failing Tests (Red Phase)

Update [`tests/unit/test_units.gd`](file:///home/ryan/play/fantasy-tactics/tests/unit/test_units.gd):

- **Test labels display correct counts**:
  - Set up session state with 2 parties, 5 adventurers, and 3 recruits.
  - Instantiate `units.tscn` and verify the row labels display:
    - Parties count label: `"Parties: 2"`
    - Roster count label: `"Units in roster: 5"`
    - Recruitable count label: `"Recruitable units: 3"`
- **Test button routing**:
  - Clicking `PartiesViewButton` routes to `GameManager.go_to_parties()`.
  - Clicking `RosterViewButton` routes to `GameManager.go_to_roster()`.
  - Clicking `RecruitmentViewButton` routes to `GameManager.go_to_recruitment()`.

Run tests to confirm failure:
```bash
godot --headless -s --path . addons/gut/gut_cmdln.gd -gselect=test_units.gd
```

### 2. Implementation (Green Phase)

1. **Modify [`scenes/ui/units.tscn`](file:///home/ryan/play/fantasy-tactics/scenes/ui/units.tscn)**:
   - Replace plain navigation buttons with 3 `HBoxContainer` rows:
     - `PartiesRow`: `PartiesLabel` (Label) + `PartiesViewButton` (Button: "View")
     - `RosterRow`: `RosterLabel` (Label) + `RosterViewButton` (Button: "View")
     - `RecruitmentRow`: `RecruitmentLabel` (Label) + `RecruitmentViewButton` (Button: "View")
   - Retain `BackButton` ("Back").

2. **Modify [`scripts/ui/units.gd`](file:///home/ryan/play/fantasy-tactics/scripts/ui/units.gd)**:
   - On `refresh()`, update label texts:
     - `parties_label.text = tr("units.parties_count") % GameSession.parties.size()` (or `"Parties: %d" % GameSession.parties.size()`)
     - `roster_label.text = tr("units.roster_count") % GameSession.adventurers.size()`
     - `recruitment_label.text = tr("units.recruitment_count") % GameSession.get_recruitment_candidates().size()`
   - Connect button pressed signals for the three `View` buttons to `_on_parties_pressed()`, `_on_roster_pressed()`, and `_on_recruitment_pressed()`.

3. **Update Localization / Strings**:
   - Add/verify keys `units.parties_count`, `units.roster_count`, `units.recruitment_count` in localization if applicable.

---

## Concrete Verifiable Milestone

Run the test suite:
```bash
make check
```
All GUT unit tests pass cleanly.

---

## Manual Verification

1. Launch `make play` or open Units screen in Godot.
2. Navigate to `Units` from Encampment side menu.
3. Confirm the screen displays:
   - `Parties: X [View]`
   - `Units in roster: Y [View]`
   - `Recruitable units: Z [View]`
4. Click each `[View]` button and confirm proper navigation.
