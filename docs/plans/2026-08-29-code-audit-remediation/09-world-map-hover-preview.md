# Step 09 — World Map hover-preview evidence

**Objective:** Avoid redundant route-node rebuilds for repeated mouse motion
on the same tile while retaining the intentional live preview behavior.

**Dependency:** Step 08 merged. **Branch:** `perf/world-map-hover-preview`.

## Evidence gate

Before optimization, add a lightweight debug/profile measurement or test spy
that records `_draw_routes()` calls across repeated same-tile mouse motion and
motion to a new tile. Capture baseline evidence in the implementation report;
do not replace route rendering with pooling/canvas work unless the measurement
shows a real cost beyond redundant calls.

## Files

- Modify: `scripts/world/world_map.gd:116-125,318-323`
- Modify: `tests/unit/test_world_map.gd` around `_update_hover_route()` cases
- Create only if justified: a small, ignored/local profiling artifact; never
  commit customer or generated runtime data

## Red/green TDD

1. Add a behavior regression proving repeated hover on the same valid tile
   leaves the preview correct without invoking the redraw path again, while a
   different tile and selection/cancel transitions still redraw/clear exactly
   as today. Use real scene state when verifying node changes.
2. Run the focused World Map test red.
3. Cache the last previewed tile/route at the World Map presentation layer;
   invalidate it on every existing route, selection, and modal transition that
   changes what should be drawn. Do not cache `ContentCatalog` or alter rules.
4. Run focused green, full/static/diff checks, and repeat the baseline measure.

Reviewer compares before/after evidence and checks no stale preview remains.
Manual check via `make play`: set a route, move across and within a tile, then
cancel/repath; preview remains responsive and never sticks. After user
signoff, commit `perf(world): skip unchanged hover route redraws`, merge/delete
the branch, and attach the before/after measure.
