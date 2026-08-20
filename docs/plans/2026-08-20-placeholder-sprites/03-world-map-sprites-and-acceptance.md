# Step 3: World Map Placeholder Sprites and Acceptance

**Status:** proposed  
**Branch:** `feat/placeholder-world-map-sprites`  
**Depends on:** Step 2 merged  
**Part of:** [CC0 Placeholder Sprites plan](index.md)

## Outcome

World Map terrain and the deployed party use the cataloged CC0 vocabulary.
Route, settlement, encounter, selection, and Scout-intel behavior stay
unchanged; owner screenshot approval closes the slice.

## Files

- Modify: `scripts/world/world_map.gd`
- Modify: `tests/unit/test_world_map.gd`
- Create: `tests/unit/test_world_map_sprite_rendering.gd`

## Setup

```bash
git checkout main && git pull
git checkout -b feat/placeholder-world-map-sprites
git status --short --branch
make check
```

Confirm Steps 1–2 are merged; do not stage unrelated changes.

## Red → green

1. Write failing tests first. `test_world_map_sprite_rendering.gd` instantiates
   `world_map.tscn` with a deployed party and asserts 49 4× texture-backed
   tiles at existing 64px coordinates; one `world_party` `Sprite2D`
   bottom-centered in `party_position`'s cell; non-interactive marker display;
   and correct redraw after route/cancel/one-tile movement without changing
   route or activation semantics. Add a `test_world_map.gd` regression that a
   party-cell click still selects the party.
2. Confirm red:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_world_map.gd,test_world_map_sprite_rendering.gd -gexit
   ```

   Expected: failures because World Map tiles/party marker remain `ColorRect`s;
   existing route and Scout tests remain green.
3. Replace only the tile body in `_draw_tiles()` and party body in
   `_draw_markers()` with catalog textures. Preserve marker/tile containers,
   `TILE_SIZE`, route drawing, selection ring, labels, margins for non-party
   markers, and `_to_grid_position()` arithmetic. The party Sprite2D is 4×,
   bottom-centered, and non-interactive. Settlement and encounter rectangles
   deliberately remain unchanged in this slice.
4. Confirm green and capture evidence:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_world_map.gd,test_world_map_sprite_rendering.gd -gexit
   godot --headless --path . --editor --quit
   make check
   git diff --check
   make screenshots
   ```

## Manual verification and required owner sign-off

1. Run `make play` and open **Party on World Map**.
2. Select the party, set a multi-tile route, cancel with right-click, and
   select it again. Confirm behavior is unchanged.
3. End turns until it moves. Confirm sharp, cell-aligned sprites without
   selection-ring drift.
4. Inspect **Goblin Camp Battle**, **Ruined Fortress Battle**, and screenshot
   captures. Confirm both screens read coherently as 3/4 top-down yet retain
   square cells and original click targets.
5. Explicit owner approval is required before merging.

## Commit and merge after owner sign-off

```bash
git add scripts/world/world_map.gd tests/unit/test_world_map.gd tests/unit/test_world_map_sprite_rendering.gd
git diff --cached --check
git commit -m "feat(world): render party and terrain with placeholder sprites"

# Only after owner approval:
git checkout main
git merge feat/placeholder-world-map-sprites
git branch -d feat/placeholder-world-map-sprites
```

Do not push or open a pull request.
