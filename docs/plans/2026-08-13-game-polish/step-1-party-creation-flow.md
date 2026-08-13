# Step 1: Party Creation Flow Polish

## Overview

When a player starts a new game or lands on the Encampment screen with no active parties, the `FirstPartyDialog` offers a "Create Party" button. Currently, clicking this button takes the player to `scenes/ui/parties.tscn` displaying the party list table, requiring an extra click on the "Create Party" button to open the party name input.

This step updates `encampment.gd`, `parties.gd`, and `game_manager.gd` so that navigating to the parties screen from the First Party dialog opens the party creation name input sub-view immediately.

---

## Setup Instructions

1. Check out `main` and pull the latest changes:
   ```bash
   git checkout main && git pull
   ```
2. Create and check out a new branch:
   ```bash
   git checkout -b feat/party-creation-flow
   ```

---

## Test-Driven Development (TDD) Plan

### 1. Write Failing Tests (Red Phase)

Add unit tests in [`tests/unit/test_parties.gd`](file:///home/ryan/play/fantasy-tactics/tests/unit/test_parties.gd) and [`tests/unit/test_encampment.gd`](file:///home/ryan/play/fantasy-tactics/tests/unit/test_encampment.gd):

- **Test `GameManager.go_to_parties(create_immediately)` / flag setting**:
  Verify calling `GameManager.go_to_parties(true)` sets `create_party_on_open` to `true`.
- **Test `parties.gd` auto-open**:
  When `create_party_on_open` is true, instantiating/opening `parties.tscn` sets `party_name_entry.visible = true` and `create_party_button.visible = false` immediately upon `_ready()`.
- **Test `encampment.gd` button action**:
  Verify `_on_first_party_create_pressed()` passes `create_immediately = true` when calling `GameManager.go_to_parties()`.

Run tests to confirm failure:
```bash
godot --headless -s --path . addons/gut/gut_cmdln.gd -gselect=test_parties.gd,test_encampment.gd
```

### 2. Implementation (Green Phase)

1. **Modify [`scripts/autoload/game_manager.gd`](file:///home/ryan/play/fantasy-tactics/scripts/autoload/game_manager.gd)**:
   - Add property `var create_party_on_open: bool = false`.
   - Update `go_to_parties(create_immediately: bool = false) -> Error`:
     ```gdscript
     func go_to_parties(create_immediately: bool = false) -> Error:
         create_party_on_open = create_immediately
         _clear_detail_context()
         return _change_scene(PARTIES_SCENE)
     ```
   - Add helper `func consume_create_party_on_open() -> bool:` that returns `create_party_on_open` and resets it to `false`.

2. **Modify [`scripts/ui/parties.gd`](file:///home/ryan/play/fantasy-tactics/scripts/ui/parties.gd)**:
   - In `_ready()`, check `if GameManager.consume_create_party_on_open(): _on_create_party_pressed()`.

3. **Modify [`scripts/ui/encampment.gd`](file:///home/ryan/play/fantasy-tactics/scripts/ui/encampment.gd)**:
   - In `_on_first_party_create_pressed()`, call `GameManager.go_to_parties(true)`.

---

## Concrete Verifiable Milestone

Run the unit test suite:
```bash
make check
```
All GUT tests pass cleanly with 0 failures.

---

## Manual Verification

1. Launch game UI manually or with debug scenario:
   ```bash
   make play
   ```
2. Start a New Game or load scenario `encampment` with an empty party list.
3. On the Encampment screen, click "Create Party" on the `FirstPartyDialog`.
4. Verify that `parties.tscn` opens with the party name text box focused and visible right away.
