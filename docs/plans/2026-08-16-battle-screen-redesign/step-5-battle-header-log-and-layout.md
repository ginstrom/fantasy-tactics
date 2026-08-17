# Step 5: Battle Header Title, Full-Width Auto-Scrolling Log & Layout Integration

## Objective

Integrate the complete Baldur's Gate 1/2 inspired battle screen layout:
- **Top Header**: Title bar displaying `<Encounter Name> Battle` (e.g. "Goblin Camp Battle") and round indicator.
- **Left Column**: Stack of party unit portraits with overlaid HP and click-to-select.
- **Center Area**: Tactical combat grid.
- **Right Column**: Dual unit detail panel (hovered and selected).
- **Bottom Section**: Full-width combat log with automatic scroll-to-bottom on new messages, positioned directly above the action button row.

## Setup

```bash
git checkout main && git pull
git checkout -b feat/battle-header-log-and-layout-integration
```

Read:
- `docs/battle-screen.md`
- `scenes/battle/battlefield.tscn`
- `scripts/battle/battlefield.gd`
- `tests/unit/test_battlefield.gd`
- `tests/unit/test_localization.gd`

## Red / Green Work

1. In `tests/unit/test_battlefield.gd` and `tests/unit/test_localization.gd`, add failing tests:
   - Battlefield displays a top header label containing `<Encounter Name> Battle` for the active encounter.
   - For Goblin Camp: title text matches `"Goblin Camp Battle"`.
   - For Orc Outpost: title text matches `"Orc Outpost Battle"`.
   - Combat log occupies a full-width container in the bottom section.
   - Adding a combat log entry triggers auto-scroll to the bottom of `LogScroll`.
   - After at least one layout frame, layout geometry keeps the top and bottom panels clear of the 6x6 grid (no overlap) at the supported viewport size.
   - Preserve the existing vertical party portrait stack and HP overlays with its current regression tests; do not re-implement it as part of the layout migration.
2. Run focused tests:
   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield.gd -gexit
   ```
   Confirm new tests fail.
3. In `scenes/battle/battlefield.tscn` and `scripts/battle/battlefield.gd`:
   - Add `BattleTitleLabel` centered in the top header row displaying `tr("battle.title") % tr(expedition.name_key)`.
   - Reconfigure `HUD/Margin/VBox` hierarchy:
     - `TopRow`: Centered battle title with Round and turn indicators.
     - `BodyRow`: `PortraitPanel` (left), centered `Grid` container / spacer, `UnitInfoPanel` (right).
     - `BottomPanel`: Full-width `LogScroll` container and `ActionBar` (Move, Attack, existing Item actions, and `End Turn`).
   - In `_append_log_line()`, ensure `call_deferred("_scroll_log_to_bottom")` reliably scrolls to `max_value`.
4. In `translations/en.tres`:
   - Add `"battle.title": "%s Battle"`.
5. Rerun focused tests and `make check`.

## Milestone and Manual Check

- `make check` passes completely.
- Manual check using `make play`: Enter battle at Goblin Camp. Verify the top header shows "Goblin Camp Battle", party portraits appear on the left with HP overlays, the tactical grid is centered, the unit inspection panel is on the right, the combat log spans full width across the bottom, and the action buttons sit cleanly at the bottom. Perform several attacks and verify log lines scroll automatically to the newest message.

## Handoff

After user sign-off:
1. Run `godot --headless --path . --editor --quit` and `git diff --check`.
2. Commit `feat: integrate battle header, full-width auto-scrolling log, and layout`.
3. Merge `feat/battle-header-log-and-layout-integration` locally into `main` and delete the branch. Do not push.
