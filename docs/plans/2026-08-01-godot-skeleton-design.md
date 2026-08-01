# Fantasy Tactics — Godot Skeleton Design

**Date:** 2026-08-01  
**Status:** Approved

## Summary

Lean recommended starter for a 2D turn-based tactics game in Godot 4.7.1 / GDScript. Public GitHub repo (`fantasy-tactics`) with MIT license. Scene flow and folder conventions only — no gameplay systems yet.

## Goals

- Open cleanly in Godot 4.7.1
- Clear folder layout for scenes, scripts, and assets
- Boot → main menu → game scene flow via a thin autoload
- Git + public GitHub + MIT from day one

## Non-goals

Grid, units, turns, combat, save/load, audio, art, tests/CI, addons.

## Engine & repo

| Item | Choice |
|------|--------|
| Engine | Godot 4.7.1 (stable), 2D |
| Language | GDScript |
| Display | 1280×720, windowed, keep aspect |
| License | MIT |
| Visibility | Public GitHub |
| Approach | Lean recommended starter (no GUT/CI yet) |

## Layout

```
fantasy-tactics/
├── project.godot
├── README.md
├── LICENSE
├── .gitignore
├── docs/plans/
├── scenes/
│   ├── boot/boot.tscn
│   ├── ui/main_menu.tscn
│   └── game/game.tscn
├── scripts/
│   ├── autoload/game_manager.gd
│   ├── ui/
│   └── game/
└── assets/
    ├── sprites/
    ├── audio/
    └── fonts/
```

Asset folders hold `.gitkeep` placeholders only.

## Scene flow

1. **Boot** (`scenes/boot/boot.tscn`) — main scene; init then hand off to main menu
2. **Main menu** (`scenes/ui/main_menu.tscn`) — title, New Game, Quit
3. **Game** (`scenes/game/game.tscn`) — empty battlefield root + HUD stub

All scene changes go through **GameManager** autoload (`scripts/autoload/game_manager.gd`).

## Conventions

- `snake_case` for files and nodes
- Pair scene/script names where helpful
- Input: rely on built-in `ui_accept` / quit for now; game actions later

## Success criteria

- `project.godot` opens in Godot 4.7.1 without errors
- Boot lands on main menu; New Game opens game scene; Quit exits
- Repo is initialized, committed, and published to GitHub as public with MIT
