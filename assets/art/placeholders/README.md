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

| Target file | Original path in pack | SHA-256 |
| --- | --- | --- |
| `microfantasy/world_party.png` | `characters/knight_blue/knight_blue_idle_01.png` | `e3ff5ed414afc8a90a96db2885a0f025d029a16176893918371b212276ec7922` |
| `microfantasy/player_warrior.png` | `characters/knight_blue/knight_blue_idle_01.png` | `e3ff5ed414afc8a90a96db2885a0f025d029a16176893918371b212276ec7922` |
| `microfantasy/player_scout.png` | `characters/barbarian/barbarian_idle_01.png` | `977c27709dd49abc44355f2bc94c8ecb939d0353e1f2d894cf1543251d293539` |
| `microfantasy/player_cleric.png` | `characters/wizard/wizard_idle_01.png` | `cd177c8e48fe51600fa9e0c41b970d5f4bf95a24928e1404130baf2029514228` |
| `microfantasy/enemy_goblin.png` | `characters/dwarf/dwarf_idle_01.png` | `10842e10ebd62a0166b5421f96cc9927686767c12c9f596f6f58876bf5c40a46` |
| `microfantasy/enemy_kobold.png` | `characters/lizard/lizard_idle_01.png` | `164278da73d8cb7e10dba5bd7528d8483216dc14d7b37bbabc92a2a07ea4fd4e` |
| `microfantasy/enemy_orc.png` | `characters/mooseman/mooseman_idle_01.png` | `702e53e59827f8419d519185cab749a851b140a8e22a019254ea05badcbfc560` |
| `microfantasy/enemy_hobgoblin.png` | `characters/guard/guard_idle_01.png` | `92bef71a68883fc8b3fa3094cc3ef5015d64574d160f2d5229c88b06a4f17277` |
| `microfantasy/enemy_ogre.png` | `characters/troll/troll_idle_01.png` | `a6bf86b2ce6e5707bc6471f99cd285b4e5b55619231ad32e3ba70fc8b119b914` |

## Scope note

Only the files listed above were imported from either pack. No other
character, tile, item, or tileset asset from either source was copied
into this repository.
