# CC0 Placeholder Sprites — Implementation Plan

**Date:** 2026-08-20  
**Status:** proposed  
**Scope:** World Map party marker and Battlefield unit/terrain placeholders only

## Goal

Replace colored-rectangle representations with a small, documented CC0 sprite
subset from Kenney Tiny Dungeon and 0x72's µFantasy Tileset. Both screens must
read as 3/4 top-down while retaining their existing orthogonal 64px grids,
input geometry, combat rules, and deterministic scenarios.

## Source contract

| Source | Use in this slice | License evidence |
| --- | --- | --- |
| [Kenney Tiny Dungeon](https://kenney.nl/assets/tiny-dungeon) | Battlefield and World Map ground/prop tiles | Creative Commons CC0 |
| [µFantasy Tileset](https://0x72.itch.io/microfantasy) | Party marker and class/enemy unit sprites | CC0 / CC0 1.0 |

Do not commit downloaded ZIP archives, a wholesale upstream pack, or a new
final-art system. Commit only selected PNGs, their Godot import metadata, and
`assets/art/placeholders/README.md`, which records original paths, source
URLs, CC0 URLs, download version/date, and SHA-256 hashes. CC0 needs no
attribution; this record supplies maintainable provenance.

## Invariants

- `world_map.gd` remains a 7×7 `TILE_SIZE == 64` board and
  `battle_controller.gd` remains a 6×6 `TILE_SIZE == 64` board. No isometric
  transform, coordinate, pathfinding, or click-target change is in scope.
- A `visual_key` is presentation-only: never use it for action legality,
  saved state, simulation output, or RNG.
- Retain the existing shadow, selection/highlight layers, facing cue,
  tooltips, and painter's-order rendering. Sprites never intercept input.
- Use only integral nearest-neighbor scale: 16px source art at 4× in the
  existing 64px cells. No filtering or fractional placement.
- Portraits, buildings, animation state machines, final art, and audio are
  out of scope.

## Delivery sequence

| # | Step | Branch | Depends on | Milestone |
| --- | --- | --- | --- | --- |
| 1 | [Asset intake and sprite catalog](01-asset-intake-and-sprite-catalog.md) | `feat/placeholder-sprite-catalog` | `main` | Auditable curated CC0 files and a tested catalog exist. |
| 2 | [Battlefield sprites](02-battlefield-sprites.md) | `feat/placeholder-battlefield-sprites` | Step 1 merged | Fielded units and tiles render catalog textures; tactical cues persist. |
| 3 | [World Map sprites and acceptance](03-world-map-sprites-and-acceptance.md) | `feat/placeholder-world-map-sprites` | Step 2 merged | Party/terrain render catalog textures; owner approves screenshots. |

The sequence is deliberately serial: the catalog owns stable texture paths,
Battlefield proves the reusable unit-rendering contract, then World Map shares
that settled vocabulary.

## Shared verification

Run each step's focused GUT test, then:

```bash
godot --headless --path . --editor --quit
make check
git diff --check
```

Before the Step 3 merge, run `make play` and `make screenshots`; inspect
**Party on World Map**, **Goblin Camp Battle**, and **Ruined Fortress Battle**.
The owner must confirm sharp, bottom-anchored sprites; legible player/enemy,
facing, selection, movement, and attack cues; and unchanged click targets.

## Risks and gates

- If either source page no longer clearly declares CC0 at asset intake, stop
  and ask the owner before importing anything.
- Upstream layouts can change: record the actual original path and copy only
  selected files to the stable target names in Step 1.
- Use Kenney only for terrain/props and µFantasy only for actors. Do not use
  µFantasy's isometric tile layout; it implies a different grid geometry.
- If a selected actor loses silhouette clarity at 4×, replace it with another
  sprite from the same CC0 pack and update the provenance table before code.
