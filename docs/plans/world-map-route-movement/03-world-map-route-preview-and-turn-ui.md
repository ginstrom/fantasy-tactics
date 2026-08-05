# Step 03: Route Preview and World Turn UI

## Milestone

The World Map visibly previews the cursor route and remaining committed route, displays a turns-to-arrival marker, and advances unused route movement through an End Turn button.

## Setup

Branch: `feat/world-map-route-ui` from updated `main`; requires steps 01 and 02.

## Files

- Modify: `scenes/world/world_map.tscn`
- Modify: `scripts/world/world_map.gd`
- Modify: `translations/en.tres`
- Modify: `tests/unit/test_world_map.gd`
- Modify: `tests/unit/test_localization.gd` only if it inventories translation keys

## Red/green implementation

1. Add failing scene/HUD tests for `HUD/EndTurnButton`, `HUD/TurnLabel`, and `HUD/Hint`; test that the handler increments the displayed/session turn, moves exactly one unspent route step, persists it, and cannot auto-move after a manual step. Test that the committed destination marker is the click target for manual movement; clicking the party with a route starts retargeting without movement; and right-click exits retargeting without changing the persisted route. Test route/estimate helper state, not pixels: selected mouse hover yields a route and a committed route uses its remaining length as the arrival estimate.
2. Run `make test`; expected failure is missing nodes, handler, and hover state.
3. Add the three HUD controls and a `Routes` Node2D container to `world_map.tscn`. Use semantic keys such as `world_map.end_turn`, `world_map.turn`, `world_map.hint`, and `world_map.arrival_turns`; do not hard-code player text.
4. In `world_map.gd`, store transient `hover_route: Array[Vector2i]` and `is_setting_route: bool` only. Handle `InputEventMouseMotion` while the party is selected: convert the cursor to a tile, calculate `build_route()`, and redraw. A unit click with a committed route starts retargeting; the normal route target remains available for manual movement until then. Right-click in retargeting mode clears `is_setting_route` and the hover preview only. Clear both transient values when deselecting, committing/moving, or leaving the map.
5. Render hover route when non-empty, otherwise `GameSession.get_deployed_party_route()`, using non-interactive translucent segments. At its final point render a visually distinct movement-target affordance and a label equal to remaining route length. Keep the controls non-interactive so map-level click handling owns the input; use the destination tile coordinate to recognize its second click. Keep the current legal movement-range highlights.
6. Implement `_on_end_turn_pressed()`: call `GameSession.end_world_turn()`, read current position, redraw markers/routes/highlights/HUD, then emit `board_changed`. It advances the turn even with no route and never performs a second movement after manual movement is spent.
7. Run `make check`, `godot --headless --path . --editor --quit`, and `git diff --check`. Review any generated UID sidecars; none are expected for scene-only changes.

## Manual verification and merge

Run `make play`. Deploy a party, preview from settlement to camp and confirm an estimate of 8 turns. Click the camp to commit without movement. Click the camp movement target again to move one step manually. Click the party to enter retargeting, hover a new destination, then right-click: the original camp route must remain. Repeat retargeting and left-click a different destination: the route must be replaced without movement. End Turn must only increment the turn after the manual step. Complete the route with End Turn, then confirm normal camp entry is still selected-party then second click.

After user signoff, commit with `feat: preview and advance world routes`, merge locally, and do not push.
