# Step 02 — World Map modal input isolation

**Objective:** Make Arrival and Send Party dialogs modal: background tile
actions cannot run while either is visible, and Escape dismisses the active
dialog before the pause menu.

**Dependency:** Step 01 merged. **Branch:** `fix/world-map-modal-input`.

## Files

- Modify: `scripts/world/world_map.gd:116-160` and its modal show/hide helpers
- Modify: `scenes/world/world_map.tscn` if full-screen blockers are needed
- Modify: `tests/unit/test_world_map.gd` beside real scene/input-routing tests
- Inspect: `scripts/ui/modal_dialog.gd` before duplicating blocker behavior

## Red/green TDD

1. Use real `WorldMapScene.instantiate()` and isolated
   `Viewport.push_input()` events—not direct `_unhandled_input()` calls—to
   add four regressions: left click behind Arrival does not change route or
   selected party; Escape closes Arrival without opening `GameManager`'s game
   menu; left click behind Send Party does not change map state; Escape closes
   Send Party. Reset all touched autoload routing state in `before_each`.
2. Run the focused file command and retain failures that demonstrate current
   click-through/pause routing:
   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_world_map.gd -gexit
   ```
3. Use one modal-visibility guard as the input authority. Consume mouse and
   `ui_cancel` input before hover, route, tile, or pause handling; dismiss only
   the visible dialog. Back each dialog with a full-screen `MOUSE_FILTER_STOP`
   blocker or the existing `ModalDialog` contract. Do not change encounter or
   route ownership in `GameSession`.
4. Run focused green plus `make check`, editor parse, and `git diff --check`.

## Review, manual confirmation, merge

Reviewer verifies real input routing and that a blocker covers the screen,
not merely a panel rectangle. Manual check via `make play`: open Arrival,
click several tiles and press Escape; the route/party remains unchanged and
the dialog closes. Repeat with Send Party in a multi-party debug fixture.
After user signoff, commit as `fix(world): isolate modal input from map`,
merge locally, delete the branch, and hand off the exact test names/results.
