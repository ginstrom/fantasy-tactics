# Step 1: Two-Tier Movement (Green/Yellow) and Attack Range Highlights

## Objective

Implement two-tier movement range calculations and grid highlights:
- **Green Range**: Tiles the selected unit can reach and still have sufficient Action Points (AP) to execute a basic attack (`remaining_ap - distance * MOVE_COST >= BASIC_ATTACK_ACTION_POINT_COST`).
- **Yellow Range**: Tiles the selected unit can reach with remaining AP, but will not have enough AP left to attack (`remaining_ap - distance * MOVE_COST < BASIC_ATTACK_ACTION_POINT_COST`).
- **Attack Highlights**: Attackable enemy targets within direct weapon range/LoS and tiles in range.

## Setup

```bash
git checkout main && git pull
git checkout -b feat/battle-two-tier-range-highlights
```

Read:
- `docs/battle-screen.md`
- `scripts/battle/battle_controller.gd`
- `tests/unit/test_battle_controller.gd`
- `tests/unit/test_battlefield.gd`

## Red / Green Work

1. In `tests/unit/test_battle_controller.gd`, add failing tests:
   - `get_move_and_attack_tiles(unit)` returns all tiles where movement distance allows at least `BASIC_ATTACK_ACTION_POINT_COST` remaining.
   - `get_dash_tiles(unit)` returns all tiles where movement distance spends too many AP to attack, but does not exceed available AP.
   - For a unit with 6 AP and 3 AP attack cost: movement distance `<= 3` tiles are in move-and-attack range; distance `4..6` are in dash range.
   - For a unit with 3 AP and 3 AP attack cost: the origin is absent from both movement arrays (selection ring represents it); distances `1..3` are dash range.
   - For a unit with 2 AP: all reachable movement tiles are in dash range; move-and-attack range is empty.
   - Verify `_update_highlights()` creates distinct highlights: green for move-and-attack destinations, yellow for dash destinations, red for direct attack targets, and orange for reachable-but-not-direct attack targets. Verify overlays use the documented precedence and the origin receives no movement fill.
2. Run focused tests:
   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd -gexit
   ```
   Confirm new tests fail.
3. In `scripts/battle/battle_controller.gd`:
   - Define constants:
     - `LEGAL_MOVE_AND_ATTACK_COLOR := Color(0.3, 0.85, 0.35, 0.45)` (Green range)
     - `DASH_MOVE_COLOR := Color(0.9, 0.85, 0.25, 0.45)` (Yellow range)
     - `MOVE_AND_ATTACK_TARGET_COLOR := Color(1.0, 0.65, 0.1, 0.65)` (Orange indirect target)
   - Implement `get_move_and_attack_tiles(unit) -> Array[Vector2i]`.
   - Implement `get_dash_tiles(unit) -> Array[Vector2i]`.
   - Update `_update_highlights()`:
     - Render move-and-attack tiles with `LEGAL_MOVE_AND_ATTACK_COLOR`.
     - Render dash-only tiles with `DASH_MOVE_COLOR`.
     - Render direct red targets and orange indirect targets after movement fills, in the documented precedence order.
4. Rerun focused tests and `make check`.

## Milestone and Manual Check

- `make check` passes completely.
- Manual check using `make play`: Select a party member in battle with 6 AP. Verify tiles within 3 steps show green highlights, tiles from 4 to 6 steps show yellow highlights, and adjacent/in-range enemies show red attack highlights. Move 4 steps (leaving 2 AP); verify all remaining reachable movement tiles switch to yellow.

## Handoff

After user sign-off:
1. Run `godot --headless --path . --editor --quit` and `git diff --check`.
2. Commit `feat: add two-tier green and yellow movement range highlights`.
3. Merge `feat/battle-two-tier-range-highlights` locally into `main` and delete the branch. Do not push.
