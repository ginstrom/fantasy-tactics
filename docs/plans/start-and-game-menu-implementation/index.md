# Start Menu / Game Menu Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Split the current `main_menu` (boot-time menu, also destructively reused
as an Escape menu) into a `start_menu` shown once at boot, and a `game_menu`
modal overlay shown on top of gameplay when Escape is pressed.

**Architecture:** `GameManager` gains a hardcoded `has_saved_game` flag that
both menus read to gray out Continue/Load, and owns a single persistent
`game_menu` overlay instance (a paused-aware `CanvasLayer`, added as its own
child so it survives scene changes) with `open_game_menu()` /
`close_game_menu()` choke points, following the same pattern as every other
scene transition in this codebase.

**Tech Stack:** Godot 4.7, GDScript, GUT, Make.

**Learning Tool:** Because this is a learning project, keep good documentation
including code comments and READMEs. Don't go overboard, but document the code
such that a newcomer to Godot and game development can follow — in
particular, the `process_mode = ALWAYS` trick that lets the overlay keep
receiving input while the tree is paused is not obvious and deserves a
one-line comment.

---

## Source design and boundaries

This plan implements [Start Menu / Game Menu Split Design](../start-and-game-menu-design.md).
It deliberately does not implement a real save/load system — both menus only
read a hardcoded `has_saved_game = false` flag. Wiring that flag to real
persistence is future work.

## Plan order

| Step | Outcome | Prerequisite | Manual check |
| --- | --- | --- | --- |
| [01](01-start-menu-split.md) | `main_menu` is renamed to `start_menu` and gains Continue/Load buttons, grayed out via a new hardcoded `has_saved_game` flag. Escape still returns to the start menu, unchanged in behavior. | None | Yes |
| [02](02-game-menu-overlay.md) | A new `game_menu` modal overlay opens on Escape from every gameplay scene, pauses the game underneath, and offers Return/Save/Load/Quit. | 01 | Yes |

## Shared workflow

Each numbered document is one mergeable feature branch. Follow
[AGENTS.md](../../../AGENTS.md): branch from updated `main`, use red/green
TDD, run `make check`, obtain the specified user verification through
`make play` (or `make editor` for a specific scene), commit, merge locally
into `main` only after the user signs off, and delete the branch. Do not push
unless asked.

## Overall Definition of Done

- Both steps are merged locally into `main` after their individual user
  signoffs.
- `make check` passes after the final merge.
- `start_menu` shows at boot with Continue/New Game/Load/Quit, Continue and
  Load grayed out.
- Pressing Escape in any gameplay scene (battlefield, world map, encampment,
  party manager, starting settlement) opens `game_menu` as an overlay without
  losing game state; Return (or Escape again) closes it and resumes exactly
  where the player left off.
- `game_menu` offers Return/Save/Load/Quit; Save shows "Not implemented yet";
  Load is grayed out via the same hardcoded flag as `start_menu`.
