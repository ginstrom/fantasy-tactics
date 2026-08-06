# Step 2: Star World Map markers

## Objective

Replace textual encounter labels with display-only star difficulty markers.

## Files

- Modify: `scripts/world/world_map.gd`
- Modify: `tests/unit/test_world_map.gd`
- Modify: `translations/en.tres` only if a semantic non-star label remains
  necessary; the approved star glyph itself requires no translation key.

## Red/green TDD

1. Add a failing map-scene test that finds the two encounter labels and asserts
   their text is exactly `★` and `★★`, keyed by their documented positions.
2. Add a failing test that asserts neither marker label includes `Goblin`,
   `Orc`, `danger`, nor `gold`.
3. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_world_map -gexit
   ```

   Expected: tests fail because labels still use
   `world_map.expedition.label` with name, danger, and reward.
4. Add a small `WorldMap` helper that clamps an encounter difficulty to 1–4
   and returns `"★".repeat(clamped_difficulty)`. Use it when creating each
   encounter label; preserve the existing label positioning/clamp that keeps
   row-zero labels below the hint bar.
5. Remove the unused `world_map.expedition.label` and danger translation
   entries only after `rg` confirms no remaining references. Do not add a
   legend or a hover panel.
6. Rerun the focused test green and commit:

   ```bash
   git add scripts/world/world_map.gd tests/unit/test_world_map.gd translations/en.tres
   git commit -m "feat: show encounter difficulty stars on world map"
   ```

## Milestone

The World Map has two readable, non-overlapping star-only site markers with
no change to encounter activation or travel controls.
