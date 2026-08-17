# Step 4: Dual Hovered and Selected Unit Detail Panel

## Objective

Refactor the right-side `UnitInfoPanel` to display details for **both** the currently hovered unit/object AND the currently selected unit simultaneously, including HP, AP, equipped weapon/attack name, and wound status.

## Setup

```bash
git checkout main && git pull
git checkout -b feat/battle-dual-unit-info-panel
```

Read:
- `docs/battle-screen.md`
- `scripts/battle/unit_info_panel.gd`
- `scripts/battle/battlefield.gd`
- `tests/unit/test_battlefield.gd`

## Red / Green Work

1. In `tests/unit/test_battlefield.gd`, add failing tests:
   - `UnitInfoPanel` has distinct sub-containers: `HoveredSection` and `SelectedSection`.
   - When a player unit is selected and mouse hovers over an enemy:
     - `HoveredSection` displays the enemy's name and wound tier ("Wounded").
     - `SelectedSection` simultaneously displays the player unit's name ("Warrior"), `HP: %d/%d`, `AP: %d/%d`, and equipped weapon name ("Longsword").
   - When hovering ends (mouse over empty tile): `HoveredSection` clears/hides, while `SelectedSection` remains pinned and visible.
   - When AP is spent on movement or attack: `SelectedSection`'s AP display immediately updates to reflect remaining AP.
   - When a unit takes damage or heals: HP display and wound tiers update immediately.
   - When no unit is selected and no unit is hovered: displays appropriate empty/hint text.
2. Run focused tests:
   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield.gd -gexit
   ```
   Confirm new tests fail.
3. In `scripts/battle/unit_info_panel.gd`:
   - Structure the panel into `HoveredContainer` and `SelectedContainer` (separated by a horizontal separator).
   - Implement `update_panel(hovered_unit, selected_unit)`:
     - In `HoveredContainer`: show name and wound status / HP if `hovered_unit != null && hovered_unit != selected_unit`.
     - In `SelectedContainer`: show selected unit name, class, level, `HP: %d/%d`, `AP: %d/%d`, weapon/attack name (`unit.attack_name` or effective weapon name), and active statuses.
   - Support translation keys for weapon, AP, HP, and wound tiers.
4. In `scripts/battle/battlefield.gd`:
   - Connect focus and board changes to call `update_panel(grid.hovered_unit, grid.selected_unit)`, so a spent AP value updates even while the hover target is unchanged.
5. Add translation strings if needed in `translations/en.tres` (e.g. `"battle.unit_info.ap": "AP: %d/%d"`, `"battle.unit_info.weapon": "Weapon: %s"`).
6. Rerun focused tests and `make check`.

## Milestone and Manual Check

- `make check` passes completely.
- Manual check using `make play`: Select a party member. Hover the mouse over an enemy on the battlefield. Verify the right panel shows the hovered enemy's name and wound status in the top section, while simultaneously showing the selected party member's name, HP, AP, and weapon in the bottom section. Move 1 step and verify AP in the panel drops by 1 immediately.

## Handoff

After user sign-off:
1. Run `godot --headless --path . --editor --quit` and `git diff --check`.
2. Commit `feat: display dual hovered and selected unit details in battle info panel`.
3. Merge `feat/battle-dual-unit-info-panel` locally into `main` and delete the branch. Do not push.
