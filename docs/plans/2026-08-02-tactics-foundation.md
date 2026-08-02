# Tactics Foundation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a small, playable square-grid battle, then connect it to a minimal world-map loop while keeping the project ready for localization.

**Architecture:** Keep presentation in Godot scenes and rules in small, testable GDScript objects. A `GameSession` autoload owns only persistent campaign state (party and current location); the battle scene owns its temporary board and turn state. Start with a fixed demo map and placeholder units, then add data only when the next interaction needs it.

**Tech Stack:** Godot 4.7.1, GDScript, Godot scenes, GUT, Makefile.

---

## Scope decisions

- Use a **square grid** for the first implementation. Hex grids are a separate design choice and should not be mixed into this slice.
- Implement movement before attacks, abilities, experience, inventory, procedural maps, or save files.
- Keep the initial world map to one party marker and one enterable location.

### Task 1: Create the battle vertical slice

**Files:**
- Create: `scripts/battle/grid.gd`, `scripts/battle/unit.gd`, `scripts/battle/battle_controller.gd`, `tests/unit/test_grid.gd`, `tests/unit/test_battle_controller.gd`
- Modify: `scenes/game/game.tscn`, `scripts/game/game.gd`

1. Write GUT tests for square-grid bounds, four-direction adjacency, and a unit moving only to an unoccupied adjacent tile.
2. Run `make test`; the new tests should fail because the battle types do not exist.
3. Implement a fixed-size grid, two placeholder units, click/select feedback, legal movement highlighting, and an explicit **End Turn** control.
4. Run `make check`, then manually run `make play`: select a unit, move it once, end a turn, and return to the menu with Esc.
5. Commit: `feat: add playable battle movement slice`.

**Reviewer should expect:** A Game scene that visibly renders a fixed square board with two distinguishable units, selectable movement destinations, and an End Turn control. It is a demo slice: units move one tile and no attack or campaign state exists yet.

**Manual verification:**
1. Run `make play`, choose **New Game**, and confirm the fixed board and two units appear.
2. Select a unit and confirm only its legal adjacent, empty tiles are highlighted.
3. Select one highlighted tile and confirm the unit moves there.
4. Press **End Turn**, then press Esc and confirm the main menu appears without an error.

### Task 2: Add the minimal game-state foundation

**Files:**
- Create: `scripts/autoload/game_session.gd`, `tests/unit/test_game_session.gd`
- Modify: `project.godot`, `scripts/autoload/game_manager.gd`

1. Write tests for a new session's default party, current world location, and `reset()` restoring those defaults.
2. Run `make test`; the session tests should fail.
3. Add `GameSession` as an autoload. Store only party identifiers and current location; expose `start_new_game()`/`reset()` and avoid serialisation or scene-node references.
4. Make **New Game** initialise the session before changing scenes.
5. Run `make check` and manually confirm that starting a new game produces a fresh session.
6. Commit: `feat: add minimal game session state`.

**Reviewer should expect:** A `GameSession` autoload that owns only non-visual, persistent-in-process state: the initial party and current world location. Starting a new game always replaces prior session state; there is no save/load system.

**Manual verification:**
1. Run `make play` and start a new game.
2. Exercise the available movement/turn controls to establish that the game scene works with a session present.
3. Return to the menu with Esc and choose **New Game** again.
4. Confirm the game starts from its initial state rather than carrying over the preceding session.

### Task 3: Complete the first battle rules

**Files:**
- Modify: `scripts/battle/grid.gd`, `scripts/battle/unit.gd`, `scripts/battle/battle_controller.gd`, `scenes/game/game.tscn`, `tests/unit/test_grid.gd`, `tests/unit/test_battle_controller.gd`

1. Write tests for movement range, occupancy, active-side turn order, and rejecting an invalid move.
2. Run `make test`; the new rule tests should fail.
3. Add movement points, turn ownership, active-unit state, and a clear HUD message. Keep combat out of this task unless movement and turns are fully stable.
4. Run `make check`; manually play two alternating turns and verify a unit cannot cross occupied or out-of-range tiles.
5. Commit: `feat: enforce battle movement and turns`.

**Reviewer should expect:** Movement rules are now enforced rather than merely demonstrated: the HUD identifies the active side/unit, movement is limited by its allowance, and invalid destinations do not change game state. Combat remains intentionally absent.

**Manual verification:**
1. Start a new game and select the active side's unit.
2. Confirm an out-of-range or occupied tile cannot be selected as a destination.
3. Move within the displayed allowance, then attempt a second move if movement is exhausted; confirm it is rejected.
4. End the turn, confirm the opposing side becomes active, and repeat the movement check.

### Task 4: Add the world-map-to-battle loop

**Files:**
- Create: `scenes/world/world_map.tscn`, `scripts/world/world_map.gd`, `tests/unit/test_world_map.gd`
- Modify: `scripts/autoload/game_manager.gd`, `scripts/autoload/game_session.gd`, `scenes/ui/main_menu.tscn`, `scripts/ui/main_menu.gd`

1. Write tests for moving the party marker to an adjacent world tile and entering only the designated encounter location.
2. Run `make test`; the world-map tests should fail.
3. Add a small fixed world grid, a party marker, and one local-map destination. Make `GameManager` move from the world scene to the battle scene while `GameSession` retains the selected location.
4. Add a temporary battle-complete action that returns to the world map and marks the encounter complete.
5. Run `make check`; manually verify New Game → world map → battle → world map, including Esc behaviour from every scene.
6. Commit: `feat: add world map battle loop`.

**Reviewer should expect:** **New Game** opens a small world map with a movable party marker and one clearly marked encounter. Entering that location opens the existing local battle; the temporary battle-complete control returns to the world and marks the encounter finished.

**Manual verification:**
1. Run `make play`, choose **New Game**, and confirm the world map—not the battle scene—opens.
2. Move the party marker to the encounter and activate it; confirm the local battle opens.
3. Use the temporary battle-complete control; confirm the world map returns and the encounter shows completed.
4. Press Esc from the world map and battle scene at least once; confirm each returns safely to the main menu.

### Task 5: Establish localization conventions

**Files:**
- Create: `translations/en.translation`, `translations/ja.translation` (only if Japanese is an intended first language)
- Modify: `project.godot`, `scenes/ui/main_menu.tscn`, `scenes/game/game.tscn`, `scenes/world/world_map.tscn`, relevant scripts, `README.md`

1. Inventory player-visible text and replace hard-coded UI strings with stable translation keys such as `menu.new_game` and `battle.end_turn`.
2. Add English translations and configure Godot's locale/translation resources.
3. Add a second locale only when its copy is available; do not add empty or machine-translated content as a placeholder.
4. Run `make check`; switch the editor/project locale and manually verify no keys are shown to players.
5. Document how to add a key and translation in `README.md`.
6. Commit: `feat: localize player-facing UI`.

**Reviewer should expect:** Menus, battle HUD, and world-map text are sourced from translation keys rather than literal player-facing strings. English is complete; a second language is included only if its reviewed copy has been provided.

**Manual verification:**
1. Run `make check`.
2. Launch the project with the English locale and visit the menu, world map, and battle; confirm normal copy appears rather than keys such as `battle.end_turn`.
3. If a second locale was added, switch to it in Project Settings or the test control and repeat the scene check.
4. Confirm `README.md` explains how to add both a new key and its translation.

## Completion criteria

- A new game begins on a one-location world map.
- The party can enter a fixed local battle, move units on alternating turns, and return to the world map.
- Core rules are covered by headless GUT tests run through `make check`.
- Player-facing text uses translation keys before menus and battle HUD copy grow further.
