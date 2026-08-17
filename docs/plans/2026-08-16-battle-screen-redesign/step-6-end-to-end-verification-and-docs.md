# Step 6: End-to-End Verification and Documentation

## Objective

Document the new battle screen controls and layout, run the complete regression test and simulation suites, and obtain user manual verification sign-off across all battle interactions.

## Setup

```bash
git checkout main && git pull
git checkout -b docs/battle-screen-redesign-guide
```

Read:
- `docs/battle-screen.md`
- `docs/dev/running-the-game.md`
- `docs/dev/code-map.md`
- All preceding steps in `docs/plans/2026-08-16-battle-screen-redesign/`

## Red / Green Work

1. Add documentation and regression tests:
   - Ensure all battle translation keys in `translations/en.tres` are covered in `tests/unit/test_localization.gd`.
   - Capture the updated battlefield through the supported entrypoint:
     ```bash
     make screenshots
     ```
     Confirm the generated `screenshots/*battlefield*.png` exists and visually inspect it. `screenshots/` is generated output and remains untracked.
   - Run headless battle simulator:
     ```bash
     RUNS=10 make simulate
     ```
     Confirm automated combat resolution continues to function reliably.
2. Update developer documentation:
   - In `docs/dev/running-the-game.md`, document battle controls:
     - Number keys `1-5`: Select party member.
     - Move button: Move mode (no keyboard shortcut).
     - Attack button: Attack mode (no keyboard shortcut).
     - WASD: existing direct-step movement; `A` remains move-left.
     - Auto move-and-attack by clicking reachable enemies.
     - Green vs Yellow range indicators.
     - Left portrait panel and right dual inspection panel.
   - In `docs/dev/code-map.md`, update references to battle UI components (`ActionBar`, `UnitInfoPanel`, `PortraitPanel`, `LogScroll`).
3. Run complete verification:
   ```bash
   make check
   godot --headless --path . --editor --quit
   git diff --check
   ```

## Milestone and Manual Check

Using `make play`, verify the end-to-end combat loop:
1. Deploy a party from Encampment to World Map.
2. Travel to Goblin Camp and enter battle.
3. Verify top title "Goblin Camp Battle" and round indicator.
4. Verify left portrait panel shows party members with overlaid HP.
5. Click a party member; verify Green range (move & attack) and Yellow range (move only) appear on the grid.
6. Hover over a Goblin; verify the right panel displays hovered Goblin details (name and wound status) and selected unit details (HP, AP, weapon).
7. Click the Goblin 2 tiles away; verify the unit automatically steps into melee range, strikes the Goblin, deducts 1 move + 3 attack AP, and logs the attack in the bottom combat log.
8. Switch to Move mode via its button; click an empty tile to move. Verify `A` still moves left when legal and neither `M` nor `A` switches modes.
9. Click `End Turn`; verify enemy takes actions and log appends combat events.
10. Defeat all enemies; verify victory screen and return to World Map.

## Handoff

After the user explicitly confirms the manual check:
1. Run `godot --headless --path . --editor --quit` and `git diff --check`.
2. Commit `docs: document redesigned battle screen layout and controls`.
3. Merge `docs/battle-screen-redesign-guide` locally into `main` and delete the branch. Do not push or open a PR.
