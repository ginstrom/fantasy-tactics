# Step 5: Unit Details Formatting

## Overview

This step updates the formatting and terminology on the Unit Details screen (`scenes/ui/unit_details.tscn` / `scripts/ui/unit_details.gd`):
1. **Multi-line Skills List**: Formats skills as an indented multi-line list rather than a single line.
2. **Terminology & Stats Alignment**:
   - Uses "Hit points: X / Y" instead of "Health: X / Y".
   - Displays "Action points: 6".
   - Displays "Damage resistance: X%" and "Magic resistance: Y%".
   - Displays "Effects: None".
3. **Perks Formatting**:
   - Shows "Perks: None" when no perks are learned.
   - Shows a bulleted list (`* Perk Name`) when perks are present.

---

## Setup Instructions

1. Check out `main` and pull the latest changes:
   ```bash
   git checkout main && git pull
   ```
2. Create and check out a new branch:
   ```bash
   git checkout -b feat/unit-details-formatting
   ```

---

## Test-Driven Development (TDD) Plan

### 1. Write Failing Tests (Red Phase)

Update [`tests/unit/test_unit_details.gd`](file:///home/ryan/play/fantasy-tactics/tests/unit/test_unit_details.gd):

- **Test Hit Points & AP & Resistance strings**:
  Verify the screen displays `"Hit points: 20 / 20"`, `"Action points: 6"`, `"Damage resistance: 0%"`, `"Magic resistance: 0%"`, and `"Effects: None"`.
- **Test multi-line skills formatting**:
  Verify `skills_label.text` contains:
  ```
  Skills:
     Melee: 60%
     Missile: 60%
     Guard: 0%
     Might: 0%
  ```
- **Test perks formatting**:
  - When perks array is empty: `perks_label.text` equals `"Perks: None"`.
  - When unit has perks (e.g. `bonus_move`): `perks_label.text` contains `Perks:\n* Bonus Move`.

Run tests to confirm failure:
```bash
godot --headless -s --path . addons/gut/gut_cmdln.gd -gselect=test_unit_details.gd
```

### 2. Implementation (Green Phase)

1. **Modify [`scripts/ui/unit_details.gd`](file:///home/ryan/play/fantasy-tactics/scripts/ui/unit_details.gd)**:
   - In `_show_adventurer(adventurer)`:
     - Reformat stats block with "Hit points", "Action points", "Damage resistance", "Magic resistance", and "Effects".
     - Format `skills_label` as an indented multi-line string:
       ```gdscript
       var skills_lines: Array[String] = ["Skills:"]
       for skill in ["melee", "missile", "guard", "might"]:
           skills_lines.append("   %s: %d%%" % [skill.capitalize(), adventurer.stats.get(skill, 0)])
       skills_label.text = "\n".join(skills_lines)
       ```
     - Format `perks_label`:
       ```gdscript
       var perks: Array = adventurer.progression.get("perks", [])
       if perks.is_empty():
           perks_label.text = "Perks: None"
       else:
           var perk_lines: Array[String] = ["Perks:"]
           for perk_id in perks:
               perk_lines.append("* %s" % _get_perk_display_name(perk_id))
           perks_label.text = "\n".join(perk_lines)
       ```

2. **Update UI scene layout if needed**:
   - Ensure labels in `scenes/ui/unit_details.tscn` allow multi-line rendering without clipping.

---

## Concrete Verifiable Milestone

Run the unit test suite:
```bash
make check
```
All unit tests in `test_unit_details.gd` pass cleanly.

---

## Manual Verification

1. Run `make play` or open unit details via debug scenario.
2. Navigate to Unit Details screen for any adventurer.
3. Confirm the layout matches playtest specs:
   - Hit points, Action points, Damage resistance, Magic resistance, Effects displayed clearly.
   - Multi-line indented skills list displayed.
   - Perks displayed as `Perks: None` or bulleted list.
