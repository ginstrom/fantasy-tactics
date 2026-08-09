# Step 3: Encampment Location

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Branch:** `encampment-location`

**Goal:** Move the starting Encampment from the World Map's corner `(0, 0)`
to its center, and grow the World Map from 5×5 to 7×7 so a centered
Encampment still leaves room to move in every direction. The grid size and
settlement position are each declared in two places that must move
together (`GameSession` and `world_map.gd` — see `docs/dev/code-map.md`'s
note that `world_map.gd`'s `GRID_WIDTH`/`GRID_HEIGHT` mirror
`GameSession.WORLD_GRID_WIDTH`/`WORLD_GRID_HEIGHT`), plus a wide set of
tests that currently hardcode `Vector2i(0, 0)` to mean "the settlement."

**Explicitly out of scope:** the three `EXPEDITIONS` positions
(`goblin_camp` (4,4), `orc_outpost` (4,0), `ruined_fortress` (0,4)) are
*not* moved — the spec only asks to relocate the Encampment and grow the
map, not to rebalance travel distance to each site. Moving the settlement
to the center does make every site closer than before (rather than
diagonally across the whole board); that's an accepted, visible consequence
of this change, not a bug to route around.

**Files:**
- Modify: `scripts/autoload/game_session.gd`
- Modify: `scripts/world/world_map.gd`
- Modify: `tests/unit/test_world_map.gd`
- Modify: `tests/unit/test_game_session.gd`

## Step 1: Update the tests that hardcode the old grid geometry

These are all red-step edits — run the verification command in Step 2 to
confirm they fail before touching any production code.

### `tests/unit/test_game_session.gd`

Three occurrences of `Vector2i(0, 0)` mean "the settlement" (the default
`world_position` a fresh/deployed party sits at) and must track the new
constant instead of staying hardcoded. A fourth occurrence is unrelated
(it exists only to prove a returned array is a copy, not a settlement
reference) and must NOT change.

1. The `_party()` test-fixture helper near the top of the file:

   ```gdscript
   		"world_position": Vector2i(0, 0),
   ```

   becomes:

   ```gdscript
   		"world_position": GameSessionScript.STARTING_SETTLEMENT_WORLD_POSITION,
   ```

2. In `test_deploy_and_return_change_only_the_selected_party_state`:

   ```gdscript
   	assert_eq(session.get_deployed_party_position(), Vector2i(0, 0))
   ```

   becomes:

   ```gdscript
   	assert_eq(session.get_deployed_party_position(), GameSessionScript.STARTING_SETTLEMENT_WORLD_POSITION)
   ```

3. In the test asserting a saved route doesn't move the party (search for
   `"Saving a route must not move the party"`):

   ```gdscript
   	assert_eq(session.get_deployed_party_position(), Vector2i(0, 0), "Saving a route must not move the party")
   ```

   becomes:

   ```gdscript
   	assert_eq(
   		session.get_deployed_party_position(),
   		GameSessionScript.STARTING_SETTLEMENT_WORLD_POSITION,
   		"Saving a route must not move the party"
   	)
   ```

4. Leave `test_get_active_encounters_returns_a_copy_that_cannot_mutate_the_session`
   untouched — its `active[0].position = Vector2i(0, 0)` only needs *some*
   value that differs from the real `(4, 4)` to prove copy-safety; it has
   nothing to do with the settlement.

### `_choose_encounter_position()`'s fallback-scan regression test

`test_encounter_refill_fallback_scan_avoids_near_settlement_positions`
asserts an *exact* refill position, computed against the old 5×5,
corner-settlement geometry. Recompute it for the new 7×7 grid with the
settlement at `(3, 3)`:

The scan walks `y` from `WORLD_GRID_HEIGHT - 1` down to `0`, and for each
`y`, `x` from `WORLD_GRID_WIDTH - 1` down to `0` — i.e., far corner first.
With Goblin Camp still active at `(4, 4)` (Orc Outpost was just cleared)
and the settlement now at `(3, 3)`, the very first candidate the scan
visits, `(6, 6)`, is free, isn't the settlement, and isn't Orc Outpost's
own documented `(4, 0)` — so it's returned immediately.

Change:

```gdscript
	assert_eq(
		new_orc_position,
		Vector2i(3, 4),
		"A far-corner-first fallback scan should land the refill beside the far corner, not the settlement"
	)
	assert_ne(
		new_orc_position,
		Vector2i(1, 0),
		"The refill must not land one tile from the settlement"
	)
	assert_ne(
		new_orc_position,
		Vector2i(0, 1),
		"The refill must not land one tile from the settlement"
	)
```

to:

```gdscript
	assert_eq(
		new_orc_position,
		Vector2i(6, 6),
		"A far-corner-first fallback scan should land the refill at the far corner it starts from"
	)
	assert_ne(
		new_orc_position,
		Vector2i(4, 3),
		"The refill must not land one tile from the settlement"
	)
	assert_ne(
		new_orc_position,
		Vector2i(3, 4),
		"The refill must not land one tile from the settlement"
	)
```

Also update that test's own doc comment (the block above
`func test_encounter_refill_fallback_scan_avoids_near_settlement_positions`)
— it currently explains the far-corner-first design as defending against
landing "one tile from `STARTING_SETTLEMENT_WORLD_POSITION` at `(0, 0)`".
Reword the last two sentences to:

```gdscript
## The scan must instead search far-corner-first so a refilled site keeps
## landing away from the map's center — where the Encampment now sits —
## rather than immediately adjacent to it.
```

Leave `test_encounter_refill_does_not_reuse_the_original_cleared_tile`
untouched — it only asserts the new position differs from the exact tile
that was cleared, which holds regardless of grid size.

### `tests/unit/test_world_map.gd`

Eight occurrences of `Vector2i(0, 0)` mean "the settlement tile" — replace
each with `WorldMapScript.SETTLEMENT_POSITION` (the file already uses that
constant at line 604, and `GameSession.STARTING_SETTLEMENT_WORLD_POSITION`
at line 577 — both are fine; use whichever constant the surrounding test
already favors, `WorldMapScript.SETTLEMENT_POSITION` unless the test is
already reading through `GameSession`). Find each by its unique assertion
message or surrounding call and replace only the `Vector2i(0, 0)` literal:

- `test_party_cannot_move_to_a_non_adjacent_tile`: the
  `"Rejected move must not change position"` assertion.
- `test_clicking_an_adjacent_tile_without_selecting_does_not_move_the_party`:
  the `"The party should not move without first being selected"` assertion.
- `test_clicking_an_adjacent_tile_after_selecting_sets_a_route_without_moving`:
  the `"Setting a route must not move the party"` assertion.
- `test_clicking_deployed_party_at_settlement_selects_it_before_entry`: its
  single `world_map._handle_tile_click(Vector2i(0, 0))` call.
- `test_clicking_selected_party_at_settlement_emits_settlement_activated`:
  both of its `world_map._handle_tile_click(Vector2i(0, 0))` calls.
- `test_pressing_end_turn_advances_the_turn_without_a_route`: its trailing
  `assert_eq(world_map.party_position, Vector2i(0, 0))`.

Example (the first one):

```gdscript
	assert_false(moved, "Party should not jump to a non-adjacent tile")
	assert_eq(world_map.party_position, Vector2i(0, 0), "Rejected move must not change position")
```

becomes:

```gdscript
	assert_false(moved, "Party should not jump to a non-adjacent tile")
	assert_eq(world_map.party_position, WorldMapScript.SETTLEMENT_POSITION, "Rejected move must not change position")
```

Apply the same substitution at each of the other six call sites listed
above.

Leave every other `Vector2i(0, 0)`/`Vector2i(4, 4)` in this file alone —
`test_party_cannot_move_to_a_non_adjacent_tile`'s `try_move_party(Vector2i(4, 4))`
target, and `test_build_route_orders_horizontal_then_vertical_steps`'s
`build_route(Vector2i(0, 0), Vector2i(2, 1))` origin, are arbitrary
in-bounds grid coordinates unrelated to the settlement (`build_route` is a
pure pathfinding helper with no settlement awareness).

One occurrence needs a different fix, not a settlement substitution — the
grid grew, so an endpoint that used to be out of bounds may not be anymore.
In `test_build_route_rejects_an_out_of_bounds_endpoint`:

```gdscript
	assert_eq(world_map.build_route(Vector2i(0, 0), Vector2i(5, 5)), [] as Array[Vector2i])
```

`(5, 5)` was out of bounds on the old 0-4 range but is now a valid tile on
the new 0-6 range. Change the target to something still out of bounds:

```gdscript
	assert_eq(world_map.build_route(Vector2i(0, 0), Vector2i(7, 7)), [] as Array[Vector2i])
```

## Step 2: Run the tests to verify they fail

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_world_map.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gexit
```

Expected: every test edited above FAILS against today's `(0, 0)`/5×5
production code (everything else in both files still passes).

## Step 3: Move the settlement and grow the grid

In `scripts/autoload/game_session.gd`:

```gdscript
const STARTING_SETTLEMENT_WORLD_POSITION := Vector2i(3, 3)
```

and, further down (search for `WORLD_GRID_WIDTH`):

```gdscript
const WORLD_GRID_WIDTH := 7
const WORLD_GRID_HEIGHT := 7
```

Update the doc comment on `_choose_encounter_position()` too — it currently
says the far-corner-first scan keeps refills away from
`STARTING_SETTLEMENT_WORLD_POSITION at (0, 0)`. Change that clause to:

```gdscript
## STARTING_SETTLEMENT_WORLD_POSITION, now at the map's center, which a
## settlement-first scan would otherwise hand out on literally every refill
```

(keep the rest of that comment block as-is — the "far-corner-first" scan
order and the "skip the current template's own documented_position" guard
are unchanged).

In `scripts/world/world_map.gd`:

```gdscript
const GRID_WIDTH := 7
const GRID_HEIGHT := 7
```

```gdscript
const SETTLEMENT_POSITION := Vector2i(3, 3)
```

(`PARTY_START := SETTLEMENT_POSITION` on the next line needs no edit — it
derives from the constant above it.)

## Step 4: Run the tests to verify they pass

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_world_map.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gexit
```

Expected: `N/N passed.` for both files.

## Full local verification

```
make check
```

Expected: `N/N passed.` and `---- All tests passed! ----`, exit 0. If any
test outside these two files fails, it's almost certainly another
hardcoded settlement/grid assumption this step's search missed — find it
with:

```
grep -rn "Vector2i(0, 0)" tests/unit/*.gd
```

and decide, using the same "does this mean the settlement, or is it an
arbitrary coordinate" judgment applied above, whether it needs the same
fix.

## Manual verification

```
make play
```

1. New Game → through to the World Map (FN+F9 → **World Map** scenario is
   the fastest path).
2. Confirm the Encampment tile renders at the board's visual center, with
   open tiles on all four sides rather than only up/right.
3. Move the party a few tiles in each of the four directions and confirm
   movement still works at the new grid edges (try walking to a far
   corner and back).
4. Confirm the Goblin Camp, Orc Outpost, and (via FN+F9 → **Ruined
   Fortress**) Ruined Fortress markers still render at their usual
   relative positions and are still reachable.

## Commit

```bash
git add scripts/autoload/game_session.gd scripts/world/world_map.gd \
  tests/unit/test_world_map.gd tests/unit/test_game_session.gd
git commit -m "feat: move the Encampment to the center of a larger world map"
```

## Merge back to main

After user signoff on manual verification:

```bash
git checkout main
git merge encampment-location
git branch -d encampment-location
```
