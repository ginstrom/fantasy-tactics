# Step 03: Starting Settlement and Encampment

## Milestone

New Game opens the starting settlement. Its Encampment action opens an
encampment screen; that screen opens party management and enables Depart only
for a formed, non-empty party. Depart updates state before opening the world
map.

## Setup

Steps 01 and 02 must be merged into `main`. Preserve unrelated edits.

```bash
git status --short
git checkout main && git pull --ff-only
git checkout -b feat/starting-settlement
```

## Files

- Create: `scenes/local/starting_settlement.tscn`
- Create: `scripts/local/starting_settlement.gd`
- Create: `scripts/local/starting_settlement.gd.uid`
- Create: `scenes/ui/encampment.tscn`
- Create: `scripts/ui/encampment.gd`
- Create: `scripts/ui/encampment.gd.uid`
- Create: `tests/unit/test_starting_settlement.gd`
- Create: `tests/unit/test_encampment.gd`
- Modify: `scripts/autoload/game_manager.gd`
- Modify: `translations/en.tres`
- Modify: `tests/unit/test_game_manager.gd`
- Modify: `tests/unit/test_localization.gd`

## Red/green implementation

### 1. Write failing scene and manager tests

Add a route test asserting `go_to_game()` targets
`res://scenes/local/starting_settlement.tscn`. Add a manager behavior test that
creates and staffs the party, calls `depart_selected_party()`, and asserts
`GameSession.has_deployed_party()` before checking its scene-change result.

Add scene tests:

```gdscript
func test_settlement_has_an_encampment_action() -> void:
    var settlement: Control = StartingSettlementScene.instantiate()
    add_child_autofree(settlement)
    assert_eq(settlement.get_node("Center/VBox/EncampmentButton").text, "settlement.encampment")

func test_encampment_disables_depart_until_party_has_a_member() -> void:
    var screen: Control = EncampmentScene.instantiate()
    add_child_autofree(screen)
    assert_true(screen.get_node("Center/VBox/DepartButton").disabled)
    GameSession.create_party()
    GameSession.assign_adventurer_to_selected_party("warrior_001")
    screen.refresh()
    assert_false(screen.get_node("Center/VBox/DepartButton").disabled)
```

Run `make test`; it must fail because these scenes and departure route do not
yet exist.

### 2. Implement named transitions and scenes

Add `STARTING_SETTLEMENT_SCENE` and this state-first transition:

```gdscript
func go_to_game() -> Error:
    GameSession.start_new_game()
    return _change_scene(STARTING_SETTLEMENT_SCENE)

func depart_selected_party() -> Error:
    if not GameSession.depart_selected_party():
        return ERR_INVALID_DATA
    return _change_scene(WORLD_MAP_SCENE)
```

Create a simple settlement `Control` local-map scene with title, description,
and `EncampmentButton`; its handler calls `GameManager.go_to_encampment()`.
Create encampment with title, status, `ManagePartyButton`, and `DepartButton`.
Its `_ready()` calls `refresh()`, which uses
`GameSession.can_depart_selected_party()` to set `DepartButton.disabled`.
Manage Party calls `open_party_manager`; Depart calls
`depart_selected_party` and performs no local scene change.

Add translation keys and localization expectations for all new text.

### 3. Verify green

```bash
make check
```

Expected: all tests pass. Invalid departure must leave the party undeployed and
return `ERR_INVALID_DATA`.

### 4. Manual verification

Run `make play` and check:

1. New Game opens the settlement, not the world map.
2. Encampment opens and Depart is disabled.
3. Manage Party lets the player create a party and add Warrior.
4. Back returns to Encampment, where Depart becomes enabled.
5. Depart opens the world map.

Ask for user approval before merging.

## Commit and handoff

```bash
git add scenes/local/starting_settlement.tscn scripts/local/starting_settlement.gd scripts/local/starting_settlement.gd.uid scenes/ui/encampment.tscn scripts/ui/encampment.gd scripts/ui/encampment.gd.uid scripts/autoload/game_manager.gd translations/en.tres tests/unit/test_starting_settlement.gd tests/unit/test_encampment.gd tests/unit/test_game_manager.gd tests/unit/test_localization.gd
git commit -m "feat: add settlement encampment flow"
```

After user signoff:

```bash
git checkout main && git merge --ff-only feat/starting-settlement
git branch -d feat/starting-settlement
git status --short
```

Do not push.
