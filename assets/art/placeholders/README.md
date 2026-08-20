# Placeholder sprite provenance

This directory holds a small, hand-selected subset of two CC0 asset packs,
used as placeholder art for the World Map and Battlefield screens. No
wholesale pack, ZIP archive, or new final-art system is committed here —
only the individual files listed below, copied byte-for-byte from the
source packs and renamed to the stable catalog names consumed by
`scripts/presentation/sprite_catalog.gd`.

CC0 (Creative Commons Zero) needs no attribution. This table exists purely
so the origin of every file can be re-verified later.

## Kenney Tiny Dungeon

- Source page: https://kenney.nl/assets/tiny-dungeon
- Direct download used: https://kenney.nl/media/pages/assets/tiny-dungeon/f8422efb44-1674742415/kenney_tiny-dungeon.zip
- License: CC0 1.0 Universal — https://creativecommons.org/publicdomain/zero/1.0/
  (declared in the pack's own `License.txt` and on the source page)
- Pack version / date: 1.0, created 2022-07-05 (per `License.txt`)
- Downloaded: 2026-08-20

| Target file | Original path in pack | SHA-256 |
| --- | --- | --- |
| `kenney_tiny_dungeon/ground_light.png` | `Tiles/tile_0048.png` | `63519065228f5f8af6200d979fa54cd7f00650034ceea10a1609203a34b3ff9b` |
| `kenney_tiny_dungeon/ground_dark.png` | `Tiles/tile_0000.png` | `ebf91e6638d484dc6bdaec5f30e91589252125146b70c2911f11fac7ebe17090` |

## 0x72 µFantasy Tileset

- Source page: https://0x72.itch.io/microfantasy
- License: CC0 — declared on the source page, linking to
  https://www.tldrlegal.com/license/creative-commons-cc0-1-0-universal
  (canonical deed: https://creativecommons.org/publicdomain/zero/1.0/).
  No license file ships inside the pack archive; the declaration lives on
  the itch.io page only.
- Pack version / date: microFantasy.v0.4, uploaded 2019-05-02 (per itch.io
  file listing)
- Downloaded: 2026-08-20

Each target file below is a single static idle frame (frame 1 of that
character's idle animation), chosen for a clear, distinct silhouette at
4x scale. `world_party.png` and `player_warrior.png` intentionally share
the same source frame (`knight_blue`) — one file is the World Map party
marker, the other is the Battlefield warrior unit.

Four of the nine source frames (`player_scout`, `player_cleric`,
`enemy_goblin`, `enemy_hobgoblin`) ship in the pack on a canvas larger than
their actual silhouette — e.g. `barbarian_idle_01.png` is an 20x20 PNG file,
but only a 12x13 region of it is non-transparent. A final review caught
that this padding made those four sprites 18-22px wide by this catalog's
own file dimensions, violating the plan's 16px/4x-integral-scale invariant
and rendering 4-12px wider than the 64px cell in-game. Fixed by cropping
each to its true opaque bounding box with ImageMagick's `-trim` (which by
definition only removes fully-transparent border rows/columns, so it
cannot cut into visible silhouette detail) before committing. The "Original
path in pack" column below still names the untrimmed upstream file; the
SHA-256 is of this repo's trimmed copy, not the pack's own file.

| Target file | Original path in pack | SHA-256 |
| --- | --- | --- |
| `microfantasy/world_party.png` | `characters/knight_blue/knight_blue_idle_01.png` | `e3ff5ed414afc8a90a96db2885a0f025d029a16176893918371b212276ec7922` |
| `microfantasy/player_warrior.png` | `characters/knight_blue/knight_blue_idle_01.png` | `e3ff5ed414afc8a90a96db2885a0f025d029a16176893918371b212276ec7922` |
| `microfantasy/player_scout.png` | `characters/barbarian/barbarian_idle_01.png` (trimmed to its 12x13 opaque bounding box, see note above) | `a484b9be87e5d20f84e622f7bed50673a19c5189cb944089a6b794eb3bf78840` |
| `microfantasy/player_cleric.png` | `characters/wizard/wizard_idle_01.png` (trimmed to its 11x14 opaque bounding box, see note above) | `b289d0f9a90d07787e95913b54e14a03b1fe16d7664d6a3e97d8d0f3b950a152` |
| `microfantasy/enemy_goblin.png` | `characters/dwarf/dwarf_idle_01.png` (trimmed to its 10x9 opaque bounding box, see note above) | `65b120b5b663dc3a055c78a3f6ba18dab27a570672985d5bc0604e46f4935786` |
| `microfantasy/enemy_kobold.png` | `characters/lizard/lizard_idle_01.png` | `164278da73d8cb7e10dba5bd7528d8483216dc14d7b37bbabc92a2a07ea4fd4e` |
| `microfantasy/enemy_orc.png` | `characters/mooseman/mooseman_idle_01.png` | `702e53e59827f8419d519185cab749a851b140a8e22a019254ea05badcbfc560` |
| `microfantasy/enemy_hobgoblin.png` | `characters/guard/guard_idle_01.png` (trimmed to its 10x14 opaque bounding box, see note above) | `9887329ac884cedf0262a66b47404c0099f6c9b78e35b817077ad6b41451cffa` |
| `microfantasy/enemy_ogre.png` | `characters/troll/troll_idle_01.png` | `a6bf86b2ce6e5707bc6471f99cd285b4e5b55619231ad32e3ba70fc8b119b914` |

## Scope note

Only the files listed above were imported from either pack. No other
character, tile, item, or tileset asset from either source was copied
into this repository.
