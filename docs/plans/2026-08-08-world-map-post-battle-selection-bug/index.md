# Investigation: World Map party still not selectable after a battle

**Status:** RESOLVED. The real root cause was found and fixed -- see "The
actual root cause and fix" below, added after the session that picked this
investigation back up. The stale-cursor-position bug documented in "What
was found and fixed" was also real and worth keeping, but it was not what
the user was hitting; this document is kept for the full trail.

## The actual root cause and fix

**Confirmed via `Viewport.push_input()` on a fully-instantiated scene**
(exactly the "concrete next step" this doc had proposed, see below): a real
click, pushed through Godot's actual GUI input pipeline rather than calling
`_unhandled_input()` directly, silently failed to reach `world_map.gd`'s
`_unhandled_input()` at all when the party sat anywhere on the board except
the top strip near the settlement. `gui_get_hovered_control()` after the
push showed the culprit directly: `HUD/Margin/VBox/Spacer`.

`Spacer`, in `scenes/world/world_map.tscn`, is declared `type="Control"` --
a bare `Control`, not a layout container. Bare `Control`'s default
`mouse_filter` is `MOUSE_FILTER_STOP`. Every *container* in the same HUD
chain (`Margin` a `MarginContainer`, `VBox` a `VBoxContainer`, `TopRow` an
`HBoxContainer`, etc.) defaults to `MOUSE_FILTER_PASS` instead, which is why
the Control-absorption hypothesis below looked plausible but a synthetic
test clicking the *settlement* tile (0,0) kept passing even before any fix
-- (0,0) sits under `TopRow`, a container, which never blocked anything.
`Spacer` has `size_flags_vertical = 3` (expand-to-fill) and covers the rest
of the VBox's vertical space beneath `TopRow`, which in practice is most of
the board underneath it, including every encounter tile. A battle always
ends with the party sitting on the encounter tile, never back at the
settlement -- so this bug was invisible from the very first tile the game
puts the party on, and every earlier click-based repro attempt in this
investigation happened to test the one safe tile.

**Fixed** by adding `mouse_filter = 2` (`MOUSE_FILTER_IGNORE`) to `Spacer`
in `scenes/world/world_map.tscn` -- a one-line scene change. A repo-wide
grep confirmed no other scene has this pattern: every other bare
`type="Control"` node in `scenes/` is the root of a full-screen UI scene,
where blocking clicks is the correct, intended behavior.

**Regression coverage**, both using `Viewport.push_input(event, true)` (the
`true` is required -- `push_input`'s default `in_local_coords=false`
re-derives local coordinates from the viewport's screen transform, which
does not reproduce real click coordinates in a headless test run):
- `test_a_pushed_click_event_selects_the_party_through_the_real_gui_pipeline`
  in `tests/unit/test_world_map.gd` -- a synthetic scene, party moved to the
  Goblin Camp tile (4,4) specifically so the click lands under `Spacer`.
- `test_a_real_click_after_the_real_post_victory_scene_change_selects_the_party`
  in `tests/unit/test_first_campaign_ui_flow.gd` -- the test that actually
  reproduced the bug: a real battle fought to victory, a real
  `change_scene_to_file()` transition, then a real pushed click on the live
  post-victory World Map.

Both were verified with a genuine red/green cycle (stashed the `Spacer`
fix, confirmed both fail; restored it, confirmed both pass). Full suite:
734/734 passing.

## Original investigation (kept for the trail)

**Original status when this section was written:** OPEN. A real, confirmed
bug in the same area was found and fixed (see "What was found and fixed"
below), but the user has verified the original symptom still reproduces
after that fix. This document exists so the next session doesn't have to
re-derive the last two weeks of investigation from scratch.

## The symptom

After winning a battle and returning to the World Map, the deployed party
cannot be selected by clicking it. Reported originally as one of three
World Map symptoms during the `2026-08-08-trade-equipment-loot-and-ui`
plan's manual verification; confirmed present on `main` before that plan's
branch existed (not a regression from it). The other two originally
reported symptoms (a set route seeming to "disappear" after one End Turn;
walking to an encounter and clicking not entering the battle) were not
re-verified after the fix described below — trying it once evidence on
symptom 1 is in would be efficient, since a shared root cause is plausible
for at least the "clicking doesn't enter the battle" one.

## Reproduction

1. `make play`.
2. F9 → "Goblin Camp Battle" (or deploy a party normally and walk it to the
   Goblin Camp).
3. Win the battle (attack until the goblin is defeated).
4. On the World Map that appears afterward, click the party's tile.//
   **Expected:** the party becomes selected (a white ring highlight
   appears, `InformationPanel` shows party context). **Actual:** nothing
   happens.

## What was found and fixed (real bug, confirmed, but insufficient)

`scripts/world/world_map.gd`'s `_unhandled_input()` computed the clicked
tile from `board.get_local_mouse_position()` — the `Viewport`'s **tracked**
cursor position, which Godot only refreshes on `InputEventMouseMotion`
events — instead of from the `InputEventMouseButton`'s own `.position`.
Godot does not synthesize a `MouseMotion` event just because the scene
changed under a stationary cursor, so right after a scene transition (e.g.
Battlefield → World Map on victory), if the player's mouse hasn't
*physically* moved since their last click on the old scene, the tracked
position is stale — carried over from the old scene — until the next real
mouse movement.

This was confirmed by building a test that, unlike every earlier attempt
(including this investigation's own first two rounds), dispatches a real
`InputEventMouseButton` through `_unhandled_input()` rather than calling
`_handle_tile_click()` directly (which bypasses the buggy code path
entirely — this is why the "faithful" real-scene-transition test added
earlier in this investigation, `test_the_real_post_victory_scene_change_produces_a_selectable_world_map`
in `test_first_campaign_ui_flow.gd`, passed cleanly despite the bug still
being present: it calls `_handle_tile_click()` directly too). With a real
event dispatched, `board.get_local_mouse_position()` returned `(0.0,
-280.0)` while the actual click event's `.position` was `(288.0, 288.0)` —
direct proof of the stale-position mechanism.

**Fixed** in two places (same pattern, same root cause):
- `scripts/world/world_map.gd` (commit `30b6104`) — World Map clicks/hover.
- `scripts/battle/battle_controller.gd` (commit `22cd350`) — Battlefield
  grid clicks, found by grepping for the same pattern after fixing the
  first instance.

Both use `CanvasItem.make_input_local(event).position` instead of
`get_local_mouse_position()`/`get_viewport().get_mouse_position()`. Both
have permanent regression tests
(`test_a_real_click_event_selects_the_party_even_when_the_tracked_cursor_position_is_stale`
in `test_world_map.gd`;
`test_a_real_click_event_selects_the_correct_unit_even_when_the_tracked_cursor_position_is_stale`
in `test_battle_controller.gd`), each verified with a genuine red/green
cycle (stashed the fix, confirmed the test fails; restored it, confirmed
it passes). A repo-wide grep after both fixes found zero remaining
`get_local_mouse_position`/`get_global_mouse_position` calls anywhere in
`scripts/`.

**This fix is real and worth keeping regardless of what's found next** —
it closes a genuine, previously-untested class of bug. But the user
re-tested after it landed and the original symptom still reproduces. So
either there's a second, independent cause, or this mechanism isn't what's
actually firing in real play. Both are plausible; see below.

## Why the fix might not be the whole story

**A structural gap in every test built so far, including the ones that
"confirmed" the fix**: every test in this investigation — the ones that
originally failed to reproduce the bug, and the ones that later did —
calls `_unhandled_input(event)` **directly** on the `WorldMap`/
`BattleController` node. That never goes through Godot's real input
pipeline (`Viewport` → GUI `_gui_input` propagation → `_unhandled_input`
only if no Control consumed it first). A directly-invoked
`_unhandled_input()` call is guaranteed to run; a real click is not — if
any `Control` node covering the party's screen position has a
`mouse_filter` that stops the event, `_unhandled_input()` never fires at
all in real play, no matter how correct its internal logic is. This is a
structurally different failure mode than the one just fixed, and no test
built so far — including the ones proving the fix works — can distinguish
it, because they all skip the part of the pipeline where it would happen.

This is now the leading hypothesis, for two reasons:
1. It would explain the fix being real, verified, and still insufficient —
   the fixed code may simply never run.
2. `scenes/world/world_map.tscn`'s `HUD` `CanvasLayer` contains a
   `MarginContainer` with `anchors_preset = 15` (full-rect, covering the
   entire 1280×720 viewport, including the board area in the top-left
   where the party actually renders) holding a `VBoxContainer` →
   `TopRow` → `TurnLabel`/`EndTurnButton`/`InformationPanel`. Nothing in
   `world_map.tscn` or `debug_menu.tscn` sets `mouse_filter` explicitly
   anywhere (`grep -n mouse_filter` on both files returns nothing) — every
   Control is on Godot's default, which for several Container types stops
   mouse input by default rather than passing it through. If any layer of
   that container chain claims the full rect rather than shrinking to its
   visible children, it could be silently absorbing clicks over the board
   before `_unhandled_input()` ever sees them.

**Concrete next step:** build a test that goes through the real pipeline
instead of calling `_unhandled_input()` directly —
`get_viewport().push_input(event)` (or `Input.parse_input_event()` for a
true OS-level injection) on the fully-instantiated `WorldMapScene`, then
check whether `world_map.party_selected` changed. If it doesn't, the
absorption hypothesis is confirmed, and the fix is either adding an
explicit `mouse_filter = MOUSE_FILTER_IGNORE` to the HUD's container chain
(or narrowing the `MarginContainer`'s rect so it doesn't cover the board),
or moving to `_gui_input`-based handling instead of `_unhandled_input`. If
`push_input` *does* select the party, the absorption hypothesis is
falsified and the mystery deepens — see "Other hypotheses" below.

## Other hypotheses, roughly in order of how likely they seem

1. **Control absorption (above) — leading hypothesis, untested.**
2. **The user wasn't running the fixed build.** Worth a direct, simple
   check before anything else: confirm `git log -1` on whatever checkout
   `make play` was run from includes commits `30b6104`/`22cd350`, and that
   Godot's script cache/hot-reload didn't serve a stale compiled version
   (a full editor restart before `make play` would rule this out
   definitively). Cheap to check, easy to rule out, should be step zero of
   the next session.
3. **Something about the debug-menu entry path specifically.** All three
   original reports mention "via debug menu." `DebugMenu` is instanced as
   a child of the `GameManager` autoload (`game_manager.gd:63-64`), so it
   persists across every scene change rather than being recreated per
   scene. It sets `visible = false` after a successful scenario run
   (`debug_menu.gd:15-16`), and Godot's GUI input system does not deliver
   `_gui_input` to invisible Controls, so this seems unlikely to be
   involved — but it's untested, and every repro so far (by both the user
   and this investigation) has gone through the debug menu, not the real
   "walk there and enter normally" path. Worth trying the normal path (no
   F9) once, to see if the symptom is debug-menu-specific.
4. **Real-window mouse/coordinate mapping** (`stretch/mode="canvas_items"`
   in `project.godot`, window resizing, HiDPI scaling). Originally the
   leading hypothesis before the stale-cursor-position bug was found; still
   possible but now lower priority given a concrete, confirmed bug was
   found in the same area. Unreachable from a headless test either way —
   would need the user to try a specific window size/resolution and report
   back, or a screen-recorded repro.
5. **A UX misunderstanding rather than a bug** (entering an encounter
   needs a *second* click after the first selects) was the original
   working theory for symptom 3, not symptom 1 — selecting shouldn't need
   a double click, so this doesn't explain symptom 1's current report. Kept
   here only as a reminder it's still open for symptom 3 once revisited.

## What's already ruled out

- The underlying `GameSession` state (`has_deployed_party()`,
  `party_position`, `get_deployed_party_route()`) is correct after a real,
  full battle-to-victory flow — confirmed via `test_first_campaign_ui_flow.gd`'s
  tests, which inspect the actual live post-transition scene via
  `get_tree().current_scene`, not a synthetic copy.
- The real `GameManager.complete_battle()` → `go_to_world_map()` →
  `get_tree().change_scene_to_file()` transition itself completes
  correctly and produces a live `WorldMap` node with correct state.
- `world_map.gd`'s and `battle_controller.gd`'s own click-resolution logic
  is now correct, verified against a real dispatched event's `.position` —
  see "What was found and fixed" above.
- This is not a regression from the `2026-08-08-trade-equipment-loot-and-ui`
  or `2026-08-08-trade-followups-and-world-map-fixes` branches — confirmed
  present on `main` by the user directly, before either branch existed.

## Suggested next session

1. Confirm the user is running the fixed build (hypothesis 2) — fastest
   possible thing to rule out.
2. Write the `get_viewport().push_input()`-based test described above to
   test the Control-absorption hypothesis (hypothesis 1). If it reproduces
   the miss, that's the real second bug; fix and verify same as the first
   two.
3. If that test *doesn't* reproduce a miss, ask the user to try the normal
   (non-debug-menu) walk-and-enter path once, to narrow whether this is
   specific to the debug-menu entry point (hypothesis 3).
4. Only after 1-3 are exhausted, fall back to asking the user for a
   screen recording or the exact window size/resolution they're running at
   (hypothesis 4).
