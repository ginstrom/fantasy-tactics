# Step 2: Battlefield Placeholder Sprites

**Status:** proposed  
**Branch:** `feat/placeholder-battlefield-sprites`  
**Depends on:** Step 1 merged  
**Part of:** [CC0 Placeholder Sprites plan](index.md)

## Outcome

Battlefield tiles and every fielded unit render catalog textures, while 64px
grid math, shadows, layering, facing, input, combat, and deterministic
scenarios remain unchanged.

## Files

- Modify: `scripts/battle/unit.gd`
- Modify: `scripts/battle/battle_controller.gd`
- Modify: `tests/unit/test_battle_controller.gd`
- Create: `tests/unit/test_battle_sprite_rendering.gd`

## Setup

```bash
git checkout main && git pull
git checkout -b feat/placeholder-battlefield-sprites
git status --short --branch
make check
```

Confirm the Step 1 catalog/assets exist; leave unrelated modifications alone.

## Red → green

1. Write failing tests before implementation. In `test_battle_controller.gd`,
   assert that hydration assigns `player_<class-id>` to player units and an
   `enemy_<family>` key from untranslated enemy data (`id`, otherwise
   `loot_id`). In `test_battle_sprite_rendering.gd`, instantiate
   `battlefield.tscn`, supply player/enemy units on different rows, call
   `_draw_units()`, and assert:

   - one `Sprite2D` with a catalog texture and `Vector2(4, 4)` scale exists
     per living unit;
   - each sprite is bottom-anchored to the existing shadow baseline;
   - the lower row is drawn over the upper row;
   - each retains a correctly placed, high-contrast `FacingIndicator`; and
   - all 36 tiles use non-null alternating catalog textures.
2. Confirm red:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_sprite_rendering.gd -gexit
   ```

   Expected: failures identify missing visual keys and texture-backed nodes;
   existing combat assertions stay green.
3. Add `var visual_key := ""` to `Unit` only—do not alter the constructor.
   In BattleController's player construction loop, derive the existing class
   ID and set `player_<class-id>`. In the enemy loop, derive a stable raw
   family from `id`/`loot_id`, normalize variant IDs to the catalog's five
   families, and set `enemy_<family>`. Never derive a key from translated
   `enemy_type_name`, and never serialize it.
4. Replace only renderer rectangles. `_draw_tiles()` creates texture-backed
   ground at unchanged `Vector2(x, y) * TILE_SIZE` positions. `_draw_units()`
   keeps current shadows and y-sort, then creates a 4× `Sprite2D` from the
   catalog on the existing bottom-center baseline. Keep the facing cue above
   the sprite. Do not change `_to_grid_position`, input handlers,
   `get_unit_at`, gameplay state, or combat resolution.
5. Confirm green:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_controller.gd -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battle_sprite_rendering.gd -gexit
   godot --headless --path . --editor --quit
   make check
   git diff --check
   ```

## Manual verification

Run `make play`; use **Goblin Camp Battle** and **Ruined Fortress Battle**.
Move and attack, then let enemies act. Confirm sharp/unclipped sprites, feet
meeting shadows, distinct silhouettes, legible facing/overlays, and original
cell targeting.

## Commit and merge after owner sign-off

```bash
git add scripts/battle/unit.gd scripts/battle/battle_controller.gd tests/unit/test_battle_controller.gd tests/unit/test_battle_sprite_rendering.gd
git diff --cached --check
git commit -m "feat(battle): render units and terrain with placeholder sprites"

# Only after owner approval:
git checkout main
git merge feat/placeholder-battlefield-sprites
git branch -d feat/placeholder-battlefield-sprites
```

Do not push or open a pull request.
