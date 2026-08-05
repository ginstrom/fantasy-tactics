# Step 02: Route Calculation and Manual Movement

## Milestone

A World Map destination click saves/replaces a deterministic shortest Manhattan route without moving. With a saved route, clicking the selected party takes exactly one manual route step.

## Setup

Branch: `feat/world-map-route-interaction` from updated `main`; requires step 01.

## Files

- Modify: `scripts/world/world_map.gd`
- Modify: `tests/unit/test_world_map.gd`

## Red/green implementation

1. Add failing tests that `build_route(Vector2i(0, 0), Vector2i(2, 1))` returns `[(1,0), (2,0), (2,1)]`; an out-of-bounds or current-tile destination returns `[]`; a selected destination click persists that route without changing position; a second destination replaces it; and a selected-party click consumes only the first saved step.
2. Run `make test`; expected failures are missing `build_route()` and the old adjacent-click direct-move behavior.
3. Add pure `build_route(from: Vector2i, destination: Vector2i) -> Array[Vector2i]` to `world_map.gd`. On this empty grid, append horizontal steps first then vertical steps. Reject either out-of-bounds endpoint and the same tile. This ordering is intentionally stable for future terrain pathfinding replacement.
4. Update `_handle_tile_click()`:

   - a selected non-party tile builds and saves a route through `GameSession.set_deployed_party_route()`, retains selection, and redraws;
   - a selected party with a remaining route calls `GameSession.take_next_route_step()`, refreshes `party_position`, redraws, and emits `board_changed` only on success;
   - without a route, preserve current deselection and settlement/camp selection-first entry behavior.
5. Replace obsolete direct-adjacent movement assertions, retain entry regressions, then run `make check` and `git diff --check`.

## Commit and merge

Commit with `feat: set and manually advance world routes`. No manual check is required. Merge locally after review; do not push.
