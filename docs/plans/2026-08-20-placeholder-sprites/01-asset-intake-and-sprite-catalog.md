# Step 1: Asset Intake and Sprite Catalog

**Status:** proposed  
**Branch:** `feat/placeholder-sprite-catalog`  
**Depends on:** `main`  
**Part of:** [CC0 Placeholder Sprites plan](index.md)

## Outcome

Create an auditable CC0 subset and one presentation-only texture catalog. No
game scene changes occur in this step.

## Files

- Create: `assets/art/placeholders/README.md`
- Create: `assets/art/placeholders/kenney_tiny_dungeon/ground_light.png`
- Create: `assets/art/placeholders/kenney_tiny_dungeon/ground_dark.png`
- Create: `assets/art/placeholders/microfantasy/world_party.png`
- Create: `assets/art/placeholders/microfantasy/player_warrior.png`
- Create: `assets/art/placeholders/microfantasy/player_scout.png`
- Create: `assets/art/placeholders/microfantasy/player_cleric.png`
- Create: `assets/art/placeholders/microfantasy/enemy_goblin.png`
- Create: `assets/art/placeholders/microfantasy/enemy_kobold.png`
- Create: `assets/art/placeholders/microfantasy/enemy_orc.png`
- Create: `assets/art/placeholders/microfantasy/enemy_hobgoblin.png`
- Create: `assets/art/placeholders/microfantasy/enemy_ogre.png`
- Create: `scripts/presentation/sprite_catalog.gd`
- Create: `tests/unit/test_sprite_catalog.gd`

Track only generated `.import` metadata for those PNGs if Godot creates it;
never add `.godot/` or source ZIP archives.

## Setup

```bash
git checkout main && git pull
git checkout -b feat/placeholder-sprite-catalog
git status --short --branch
make check
```

Leave unrelated changes, including any `project.godot` modification, unstaged.

## Red → green

1. Download the packs from the source URLs in `index.md` and re-confirm CC0.
   Select crisp 16px silhouettes, copy them to the exact names above, and
   write `README.md` mapping target, pack, original path, source page, CC0
   URL, download version/date, and SHA-256. State that only this subset was
   imported.
2. Write `test_sprite_catalog.gd` first. It must assert non-null `Texture2D`
   results for `world_party`, each player class, and the five enemy families;
   unknown unit keys return a non-null fallback; and light/dark tile textures
   are both non-null and distinct.
3. Confirm red:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_sprite_catalog.gd -gexit
   ```

   Expected: missing catalog/preload failure.
4. Implement `SpriteCatalog` as a `RefCounted` script—not an autoload—with
   preloaded selected images and exactly:

   ```gdscript
   static func get_unit_texture(visual_key: String) -> Texture2D
   static func get_tile_texture(is_light: bool) -> Texture2D
   ```

   Map `world_party`, `player_warrior`, `player_scout`, `player_cleric`, and
   `enemy_goblin|kobold|orc|hobgoblin|ogre` to the matching file. Unknown
   keys return the `enemy_goblin` texture. This catalog must not write saves
   or affect gameplay state.
5. Confirm green:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_sprite_catalog.gd -gexit
   godot --headless --path . --editor --quit
   make check
   git diff --check
   ```

## Manual verification

Inspect every selected PNG in Godot's FileSystem dock: it is the intended
16px art, has no blur, and matches the provenance record.

## Commit and merge after owner sign-off

```bash
git add assets/art/placeholders scripts/presentation/sprite_catalog.gd tests/unit/test_sprite_catalog.gd
git diff --cached --check
git commit -m "feat(presentation): add curated CC0 placeholder sprite catalog"

# Only after owner approval:
git checkout main
git merge feat/placeholder-sprite-catalog
git branch -d feat/placeholder-sprite-catalog
```

Do not push or open a pull request.
