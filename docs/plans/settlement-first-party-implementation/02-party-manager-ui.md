# Step 02: Party Manager UI

## Milestone

The player can see the Warrior's name, class, and sword; create the one party;
assign or remove the Warrior; and return to encampment. The screen derives all
state from `GameSession`.

## Setup

Step 01 must be merged into `main`. Preserve unrelated working-tree edits.

```bash
git status --short
git checkout main && git pull --ff-only
git checkout -b feat/party-manager-ui
```

## Files

- Create: `scenes/ui/party_manager.tscn`
- Create: `scripts/ui/party_manager.gd`
- Create: `scripts/ui/party_manager.gd.uid`
- Create: `tests/unit/test_party_manager.gd`
- Modify: `scripts/autoload/game_manager.gd`
- Modify: `translations/en.tres`
- Modify: `tests/unit/test_game_manager.gd`
- Modify: `tests/unit/test_localization.gd`

## Red/green implementation

### 1. Write failing UI and route tests

Add `test_party_manager.gd`, preload the scene, reset `GameSession` in
`before_each()`, and instantiate the scene. Assert its controls use translation
keys and change availability after state changes:

```gdscript
func test_new_party_manager_shows_unassigned_warrior_and_create_action() -> void:
    var screen: Control = PartyManagerScene.instantiate()
    add_child_autofree(screen)
    assert_eq(screen.get_node("Center/VBox/WarriorSummary").text, "party.warrior.summary")
    assert_false(screen.get_node("Center/VBox/AddWarriorButton").visible)

func test_refresh_shows_remove_after_assignment() -> void:
    GameSession.create_party()
    GameSession.assign_adventurer_to_selected_party("warrior_001")
    var screen: Control = PartyManagerScene.instantiate()
    add_child_autofree(screen)
    assert_true(screen.get_node("Center/VBox/RemoveWarriorButton").visible)
```

In `test_game_manager.gd`, assert the source includes `open_party_manager()`
and `go_to_encampment()`. Extend localization tests with expected English
labels. Run `make test`; it must fail because the scene, routes, and keys do
not yet exist.

### 2. Add the screen, script, translations, and routes

Use the existing main-menu `Control` pattern:

```text
PartyManager
  Center/VBox
    Title
    WarriorSummary
    PartyStatus
    CreatePartyButton
    AddWarriorButton
    RemoveWarriorButton
    BackButton
```

Implement `_ready()` and `refresh()` in `party_manager.gd`. `refresh()` reads
only `GameSession`: Create is disabled after party creation; Add is visible only
for an unassigned Warrior after creation; Remove is visible only when assigned.
Handlers call the Step 01 state methods then `refresh()`. Back calls
`GameManager.go_to_encampment()`.

Add `PARTY_MANAGER_SCENE`, `ENCAMPMENT_SCENE`, `open_party_manager()`, and
`go_to_encampment()` to `GameManager`. Step 03 creates the encampment scene, so
do not manually use Back before that step. Add translation keys:

```text
party.title, party.warrior.summary, party.status.empty,
party.status.unassigned, party.status.assigned, party.create,
party.add_warrior, party.remove_warrior, ui.back
```

### 3. Verify green

```bash
make check
```

Expected: all tests pass, including party-manager and localization tests.

### 4. Manual verification

Run `make play`. Until Step 03 makes the screen reachable, use the Godot editor
to run `party_manager.tscn` directly. Confirm Warrior / warrior / sword is
visible; Create works once; Add and Remove update the screen; and a second
party cannot be created. Close without committing generated files.

## Commit and handoff

```bash
git add scenes/ui/party_manager.tscn scripts/ui/party_manager.gd scripts/ui/party_manager.gd.uid scripts/autoload/game_manager.gd translations/en.tres tests/unit/test_party_manager.gd tests/unit/test_game_manager.gd tests/unit/test_localization.gd
git commit -m "feat: add party manager UI"
```

After user signoff:

```bash
git checkout main && git merge --ff-only feat/party-manager-ui
git branch -d feat/party-manager-ui
git status --short
```

Do not push.
