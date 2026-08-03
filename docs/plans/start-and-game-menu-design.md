# Start Menu / Game Menu Split — Design

## Problem

`main_menu` currently serves two different purposes with the same scene: it's
shown at boot (`New Game` / `Quit`), and it's *also* what the player is
dumped into when they press Escape during gameplay — via a full
`get_tree().change_scene_to_file()` in `battlefield.gd` and `world_map.gd`,
which destroys all in-progress game/campaign state. There's no pause menu, no
save/load system, and no overlay/modal pattern anywhere in the codebase yet.

We're splitting this into two distinct menus:

- **`start_menu`** — shown once at boot, in place of today's `main_menu`.
- **`game_menu`** — a new modal overlay shown on top of gameplay when Escape
  is pressed, that doesn't destroy game state.

## Scope

- Rename `main_menu` → `start_menu` (scene, script, and the `GameManager`
  routing method/constant) to match its new, narrower purpose.
- Add a new `game_menu` overlay.
- Add a `has_saved_game` state flag, hardcoded to `false` for now (no real
  save/load system exists yet — that's future work).
- Wire Escape (`ui_cancel`) in all gameplay scenes to open `game_menu` instead
  of hard-switching to the start menu.

Out of scope: an actual save/load system. Both menus only read the hardcoded
`has_saved_game` flag; wiring it to real persistence is a separate project.

## File structure

- `scripts/ui/main_menu.gd` → `scripts/ui/start_menu.gd`
- `scenes/ui/main_menu.tscn` → `scenes/ui/start_menu.tscn`
- New: `scripts/ui/game_menu.gd`
- New: `scenes/ui/game_menu.tscn`
- `GameManager.go_to_main_menu()` → `GameManager.go_to_start_menu()`
- `GameManager.MAIN_MENU_SCENE` → `GameManager.START_MENU_SCENE`

## GameManager changes

- `var has_saved_game: bool = false` — single source of truth both menus
  read to gray out Continue/Load. Hardcoded for now; a future save system
  replaces this with a real check.
- `GameManager` instantiates `game_menu.tscn` once in `_ready()` and adds it
  as its own child (same pattern as the existing developer-tools plan's debug
  menu: `docs/plans/first-playable-campaign/developer-tools-implementation/02-debug-menu-and-routing.md`),
  so a single instance persists across scene changes instead of being
  duplicated per gameplay scene. Starts with `visible = false`.
- `open_game_menu()` — shows the overlay, sets `get_tree().paused = true`.
- `close_game_menu()` — hides the overlay, sets `get_tree().paused = false`.
- The `game_menu` `CanvasLayer` node is set to
  `process_mode = PROCESS_MODE_ALWAYS` so it keeps receiving input while the
  tree is paused — this is what lets Escape close it again (see below).

## `start_menu`

Buttons, in order: **Continue**, **New Game**, **Load**, **Quit**.

- `Continue` and `Load`: `disabled = not GameManager.has_saved_game` (both
  grayed out now, since the flag is hardcoded `false`).
- `New Game` → `GameManager.go_to_game()` (unchanged behavior).
- `Continue` → also calls `GameManager.go_to_game()`. There's no save data to
  resume from yet, so this is a placeholder that satisfies "Continue returns
  to the game" and gets replaced with real resume-from-save logic once a
  save system exists.
- `Load` → no click handler needed; it's always disabled right now, and
  disabled buttons don't emit `pressed`.
- `Quit` → `GameManager.quit_game()` (unchanged).
- New translation keys: `menu.continue`, `menu.load` (existing:
  `menu.title`, `menu.new_game`, `menu.quit`).

## `game_menu`

`game_menu.tscn`: `CanvasLayer` root (draws above whatever scene is active),
containing:

- A full-screen semi-transparent `ColorRect` — dims the background and
  blocks mouse input from reaching the scene underneath.
- A centered `Panel` → `VBoxContainer` with buttons **Return**, **Save**,
  **Load**, **Quit**, plus a `StatusLabel` (empty, hidden by default).

Behavior:

- `Return` → `GameManager.close_game_menu()`.
- `Save` → stays enabled (not data-dependent); on press, sets
  `StatusLabel.text = tr("menu.not_implemented")` and shows it.
- `Load` → `disabled = not GameManager.has_saved_game` (same flag as
  `start_menu`; no click handler needed since it's disabled).
- `Quit` → `GameManager.quit_game()` (same as `start_menu`'s Quit).
- `game_menu.gd` has its own `_unhandled_key_input` that watches for
  `ui_cancel` while `visible == true` and calls
  `GameManager.close_game_menu()`. This is what lets Escape close the menu
  even while the tree is paused — the underlying gameplay scene's own script
  stops receiving unhandled input once paused, so the overlay has to handle
  its own dismissal.
- New translation key: `menu.not_implemented` ("Not implemented yet"). No
  new key needed for `Quit` (reuses `menu.quit`) or `Return` (`menu.return`
  is still new).

## Escape wiring across gameplay scenes

- `battlefield.gd`, `world_map.gd`: replace the existing
  `ui_cancel` → `GameManager.go_to_main_menu()` handler with
  `ui_cancel` → `GameManager.open_game_menu()`.
- `encampment.gd`, `party_manager.gd`, `starting_settlement.gd`: currently
  have no Escape handling at all; add the same
  `ui_cancel` → `GameManager.open_game_menu()` handler.

## Testing

GUT tests under `tests/unit/`:

- New `test_start_menu.gd`: Continue/Load disabled when
  `has_saved_game == false`; New Game/Quit wired to the right `GameManager`
  calls.
- New `test_game_menu.gd`: Return/Save/Load/Quit exist and are wired
  correctly; Load's disabled state matches `has_saved_game`; pressing Save
  sets the status label text.
- Update `test_game_manager.gd`: fix source-scan assertions for the
  `go_to_main_menu` → `go_to_start_menu` rename; add coverage for
  `open_game_menu()` / `close_game_menu()` pausing/unpausing the tree and
  toggling overlay visibility.
