# Scene Taxonomy Design

## Goal

Rename the current generic tactical-game scene to a battle-specific scene and
organize future scenes by their game-domain role: boot, UI, world map, local
map, and battle.

## Approved structure

```text
scenes/
  boot/boot.tscn
  ui/main_menu.tscn
  world/world_map.tscn
  local/                 # Future local sites such as towns and dungeons.
  battle/battlefield.tscn
```

`battlefield.tscn` is the tactical combat screen. A local map such as the
future wandering-monsters site can enter it, then resume with its persistent
location state. UI contains whole screens and reusable UI components, including
future save/load dialogs.

## Scope now

Only move and rename the existing tactical scene/script from `game` to
`battle`, update scene routing and tests, and create the empty `local` folder
for the agreed structure. No local-map gameplay, persistence, or save/load UI
is implemented in this change.
