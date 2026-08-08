# Task 02: World Map debug diagnostics and evidence gathering

## Objective

Add small, permanent, debug-build-only diagnostic logging to
`scripts/world/world_map.gd` at the two points a real click or End Turn
press flows through, so the next time the user reproduces one of the three
reported symptoms via `make play`, the Godot console output gives an
engineer real evidence (actual mouse position, computed tile position,
party/route state at the moment of the click) instead of another round of
guessing.

**This task is diagnostic-only and does not end in a code fix — that is
intentional, not an oversight.** Extensive investigation already ruled out
every code-level explanation reachable by automated testing (see this
plan's `index.md` Phase A note and Task 01): isolated logic tests pass,
and a maximally faithful real-scene-transition integration test (Task 01)
also passes. The remaining plausible explanations — real mouse-to-tile
coordinate mapping in an actual window, or a UX clarity gap around the
required select-then-activate double click — can only be confirmed with
evidence from an actual reproduction, which this task's logging exists to
capture.

## Files

- Modify: `scripts/world/world_map.gd`

## Depends on

None.

## Produces

Two `OS.is_debug_build()`-gated `print()` calls: one in `_unhandled_input()`
logging every processed left-click's raw mouse position, computed tile
position, and current party/route state; one in `_on_end_turn_pressed()`
logging the route immediately before and after `GameSession.end_world_turn()`
runs.

## Steps

1. **Add the click diagnostic.** In `scripts/world/world_map.gd`, in
   `_unhandled_input()`, the existing left-click handling is:

   ```gdscript
   	var tile_pos := _to_grid_position(board.get_local_mouse_position())
   	if not grid.is_in_bounds(tile_pos):
   		return

   	get_viewport().set_input_as_handled()
   	_handle_tile_click(tile_pos)
   ```

   Replace it with:

   ```gdscript
   	var tile_pos := _to_grid_position(board.get_local_mouse_position())
   	if not grid.is_in_bounds(tile_pos):
   		return

   	get_viewport().set_input_as_handled()
   	if OS.is_debug_build():
   		print(
   			"[world_map click] mouse_local=%s tile_pos=%s party_position=%s party_selected=%s has_deployed_party=%s route=%s"
   			% [
   				board.get_local_mouse_position(), tile_pos, party_position, party_selected,
   				GameSession.has_deployed_party(), GameSession.get_deployed_party_route()
   			]
   		)
   	_handle_tile_click(tile_pos)
   ```

2. **Add the End Turn diagnostic.** The existing `_on_end_turn_pressed()`
   is:

   ```gdscript
   func _on_end_turn_pressed() -> void:
   	if GameSession.selected_encounter != "":
   		return
   	GameSession.end_world_turn()
   	party_position = GameSession.get_deployed_party_position()
   	_draw_markers()
   	_draw_routes()
   	_update_highlights()
   	_update_turn_label()
   	_refresh_turn_controls()
   	board_changed.emit()
   ```

   Replace it with:

   ```gdscript
   func _on_end_turn_pressed() -> void:
   	if GameSession.selected_encounter != "":
   		return
   	if OS.is_debug_build():
   		print(
   			"[world_map end_turn] before: party_position=%s route=%s"
   			% [party_position, GameSession.get_deployed_party_route()]
   		)
   	GameSession.end_world_turn()
   	party_position = GameSession.get_deployed_party_position()
   	if OS.is_debug_build():
   		print(
   			"[world_map end_turn] after: party_position=%s route=%s"
   			% [party_position, GameSession.get_deployed_party_route()]
   		)
   	_draw_markers()
   	_draw_routes()
   	_update_highlights()
   	_update_turn_label()
   	_refresh_turn_controls()
   	board_changed.emit()
   ```

3. **Run the full suite** — this is a pure logging addition; no behavior
   changed, so no test should need updating, but confirm nothing broke:

   ```bash
   make test
   ```

   Expected: `---- All tests passed! ----`, exit code 0.

4. **Commit** only this task's file:

   ```bash
   git add scripts/world/world_map.gd
   git commit -m "debug: log World Map click and End Turn state for pathing-bug diagnosis"
   ```

5. **Hand reproduction back to the user.** This step has no code — it is
   the actual deliverable of this task. Ask the user to run `make play`
   from a terminal (so console output is visible), reproduce any of the
   three symptoms, and paste back the `[world_map click]`/
   `[world_map end_turn]` lines around the moment it happened. Specifically
   useful to know per symptom:
   - **Party not selectable after a debug-menu battle:** does a
     `[world_map click]` line print at all when clicking the party tile?
     If it prints, do `tile_pos` and `party_position` match?
   - **Route disappears after one End Turn:** was the route longer than
     one tile? Compare the `before`/`after` route arrays — did it shrink
     by exactly one step (expected: one End Turn takes one step) or did it
     empty out entirely from a longer route (unexpected)?
   - **Clicking doesn't enter the battle after walking there:** does
     clicking the arrival tile actually select the party first
     (`party_selected=false` in one click's log line, `true` in the next
     click's), or is the player expecting one click to both select and
     enter? Compare against `_handle_tile_click`'s documented
     select-then-activate requirement.

## Milestone

The next live reproduction of any of the three symptoms produces console
evidence instead of another guess. Once that evidence arrives, add a new
task to this plan (or a follow-up plan) with the concrete fix — do not
attempt Task 02b speculatively before that evidence exists.
