# Running the Game

How to launch the game, jump straight to a specific scene or state for
manual testing, and capture a screenshot of every known scene/UI state.

## Prerequisites

- Everything in [README.md § Repository-wide prerequisites](README.md#repository-wide-prerequisites).
- For the screenshot tour only: a real or virtual display (it cannot run
  under `--headless`). On a display-less box, run it under `xvfb-run`.

## Launch the game

### Steps

1. From the repository root, run:
   ```
   make play
   ```
   This runs `godot --path .` — a debug build (`OS.is_debug_build()` is
   `true`), which matters for the debug menu below.

### Verification

- A window titled "Fantasy Tactics" opens at 1280×720 showing the Start
  Menu.

### Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `make: godot: Command not found` | `godot` isn't on `PATH` | Install Godot 4.7.1 and confirm with `godot --version` |
| Window opens then immediately closes | A script failed to compile | Run `make editor` instead and check the Output/Debugger panel for the error |

## Jump to a specific scene or state (debug menu)

The debug menu is a development-only overlay; it does not exist in a
non-debug export build.

### Steps

1. Launch the game with `make play` (see above).
2. From any campaign screen, press **FN + F9** to toggle the debug menu overlay.
3. Click one of the scenario buttons. Each one resets the session
   (`GameSession.start_new_game()`) and then applies exactly the state
   described below, closing the overlay on success:

   | Button | Resulting screen | Session state |
   |---|---|---|
   | New Campaign | Starting Settlement | Fresh session, no party |
   | Encampment | Encampment | Fresh session, no party |
   | Party Manager | Party Manager | Fresh session, no party |
   | Party Ready to Depart | Encampment | One party, staffed with the default Warrior, not yet deployed — Deploy Party is enabled |
   | Party Awaiting a Member | Encampment | One party created with no members |
   | Party on World Map | World Map | Staffed party deployed at a fixed World Map tile, away from both encounter sites |
   | Goblin Camp Battle | Battlefield | Staffed party deployed directly onto, and battling, the Goblin Camp encounter |
   | Orc Outpost Battle | Battlefield | Staffed party deployed directly onto, and battling, the Orc Outpost encounter |

4. Two more buttons act on the *current* state rather than resetting it:
   - **Super Power** — maxes out the player unit's move range, attack
     damage, and hit chance. Only has an effect while a Battlefield is on
     screen; a no-op otherwise.
   - **Recruit Adventurer** — mints and adds a debug adventurer to the
     roster immediately, bypassing the gold cost and recruitment-offer flow.

### Verification

- After clicking a scenario button, the debug menu overlay closes and the
  screen listed in the table above is showing.

### Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| F9 does nothing | Running a non-debug/exported build | Use `make play` or `make editor`, not an exported binary |
| A scenario button does nothing and the menu stays open | The scenario's precondition failed (e.g. `party_manager`'s scene failed to load) | Check the Output panel for a `push_error` from `_change_scene` |

## Capture a screenshot of every known scene/state

### Steps

1. From the repository root, run:
   ```
   make screenshots
   ```
   This runs `scripts/tools/screenshot_tour_main.gd` with a real (not
   headless) renderer, positioning the window off-screen at `(-3000, -3000)`
   so it doesn't steal focus.
2. On a machine with no display attached, prefix the command instead:
   ```
   xvfb-run make screenshots
   ```

### Verification

- `./screenshots/` contains one numbered PNG per step defined in
  `scripts/tools/screenshot_tour.gd` (e.g. `01_start_menu.png`,
  `02_starting_settlement.png`, ...).
- The terminal prints `[screenshot_tour] done: N screenshots in <dir>`.

### Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Godot exits immediately with a display/rendering error | No display available | Run under `xvfb-run` |
| A new scene/UI state you added isn't captured | `screenshot_tour.gd`'s step list wasn't updated | Add a `{"name": ..., "action": ...}` entry to `_build_steps()` in `scripts/tools/screenshot_tour.gd` — see that file's own header comment for the convention |

## Open the project in the editor

### Steps

```
make editor
```
Runs `godot --editor project.godot`.

### Verification

- The Godot editor opens with this project loaded.
