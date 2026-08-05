# Step 02: Route Calculation and Manual Movement

## Milestone

A World Map destination click saves a deterministic shortest Manhattan route without moving. Clicking that committed movement target again takes exactly one manual route step. Clicking the unit while a route exists opens route-retargeting; a later destination click replaces the prior route, while right-click cancels retargeting and keeps it.

## Setup

Branch: `feat/world-map-route-interaction` from updated `main`; requires step 01.

## Files

- Modify: `scripts/world/world_map.gd`
- Modify: `tests/unit/test_world_map.gd`

## Red/green implementation

1. Add failing tests that `build_route(Vector2i(0, 0), Vector2i(2, 1))` returns `[(1,0), (2,0), (2,1)]`; an out-of-bounds or current-tile destination returns `[]`; a selected destination click persists that route without changing position; clicking its committed destination consumes only the first saved step; clicking the party with a route enters retargeting without moving; a destination chosen in that state replaces the old route; and right-click cancels retargeting while the original route remains unchanged.
2. Run `make test`; expected failures are missing `build_route()` and the old adjacent-click direct-move behavior.
3. Add pure `build_route(from: Vector2i, destination: Vector2i) -> Array[Vector2i]` to `world_map.gd`. On this empty grid, append horizontal steps first then vertical steps. Reject either out-of-bounds endpoint and the same tile. This ordering is intentionally stable for future terrain pathfinding replacement.
4. Update `_handle_tile_click()`:

   - a selected click on the final point of a non-empty committed route calls `GameSession.take_next_route_step()`, refreshes `party_position`, redraws, and emits `board_changed` only on success;
   - a click on the party when a route exists sets transient `is_setting_route := true`; it must not move, alter, or clear that route;
   - a selected non-party tile saves a route through `GameSession.set_deployed_party_route()` only when no route exists or `is_setting_route` is true. On success it clears `is_setting_route`, retains selection, and redraws;
   - a right-click while `is_setting_route` is true clears only that transient state and hover preview, preserving the existing durable route;
   - otherwise retain current deselection and settlement/camp selection-first entry behavior.

   Provide small `get_route_destination()` and `cancel_route_setting()` helpers. The latter must never call a `GameSession` mutator. Test both directly so the click decision remains deterministic after each step shortens the route.
5. Replace obsolete direct-adjacent movement assertions, retain entry regressions, then run `make check` and `git diff --check`.

## Commit and merge

Commit with `feat: set and manually advance world routes`. No manual check is required. Merge locally after review; do not push.
