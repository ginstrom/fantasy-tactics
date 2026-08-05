# Step 01: Durable World-Travel State

## Milestone

`GameSession` stores a deployed party's remaining route, whether it has spent movement this World Map turn, and the campaign world-turn count. A shared route-step method prevents manual and automatic movement from both moving the party.

## Setup

Branch: `feat/world-travel-state` from updated `main`.

## Files

- Modify: `scripts/autoload/game_session.gd`
- Modify: `tests/unit/test_game_session.gd`

## Red/green implementation

1. Add failing GUT tests for initial `world_turn == 1`; deployment initializing an empty route and unspent movement; saving a valid adjacent route; rejecting an empty or non-adjacent route; consuming one next route step; refusing a second step; End Turn automatically stepping only when movement is unused; and clearing the route on arrival/return home.
2. Run `make test`. The new tests must fail because the fields and APIs do not yet exist.
3. In `reset()`, initialize `world_turn: int = 1`. In `create_party()`, add `travel_route: [] as Array[Vector2i]` and `movement_spent: false`.
4. Add these APIs:

   ```gdscript
   func get_deployed_party_route() -> Array[Vector2i]
   func set_deployed_party_route(route: Array[Vector2i]) -> bool
   func clear_deployed_party_route() -> void
   func take_next_route_step() -> bool
   func end_world_turn() -> bool
   ```

   `set_deployed_party_route()` must reject empty data and require each step to be orthogonally adjacent to the prior position. `take_next_route_step()` must reject no party, spent movement, or no route; update `world_position`, remove only the first step, set `movement_spent`, and clear a completed route. `end_world_turn()` consumes a step only while movement is unspent, increments `world_turn`, resets `movement_spent` for the next turn, and returns whether it auto-moved.
5. Run `make check` and `git diff --check`; both must pass.

## Commit and merge

Commit with `feat: persist world travel routes`. No manual check is required. Merge locally after review; do not push.
