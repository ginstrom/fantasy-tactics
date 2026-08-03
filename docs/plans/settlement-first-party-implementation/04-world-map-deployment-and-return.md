# Step 04: World Map Deployment and Return

## Milestone

The world map always shows a settlement marker at `(0, 0)` and shows a party
marker only when a party is deployed. Existing select-then-move persists the
deployed party's position. A selected party on the settlement tile can enter
the settlement and is removed from the map.

## Setup

Steps 01 and 03 must be merged into `main`. Preserve unrelated edits.

```bash
git status --short
git checkout main && git pull --ff-only
git checkout -b feat/world-map-party-deployment
```

## Files

- Modify: `scripts/world/world_map.gd`
- Modify: `scenes/world/world_map.tscn`
- Modify: `scripts/autoload/game_manager.gd`
- Modify: `translations/en.tres`
- Modify: `tests/unit/test_world_map.gd`
- Modify: `tests/unit/test_game_manager.gd`
- Modify: `tests/unit/test_localization.gd`

## Red/green implementation

### 1. Write failing deployment and return tests

Add a helper that creates the party, assigns `warrior_001`, and deploys it.
Then add marker and signal tests:

```gdscript
func test_world_map_does_not_draw_party_marker_when_no_party_is_deployed() -> void:
    var world_map: Node2D = WorldMapScene.instantiate()
    add_child_autofree(world_map)
    assert_eq(world_map.get_node("Markers").get_child_count(), 2) # encounter + settlement

func test_clicking_deployed_party_at_settlement_selects_it_before_entry() -> void:
    _deploy_warrior_party()
    var world_map := _make_world_map()
    world_map._handle_tile_click(WorldMapScript.SETTLEMENT_POSITION)
    assert_true(world_map.party_selected)

func test_clicking_selected_party_at_settlement_emits_settlement_activated() -> void:
    _deploy_warrior_party()
    var world_map := _make_world_map()
    watch_signals(world_map)
    world_map._handle_tile_click(WorldMapScript.SETTLEMENT_POSITION)
    world_map._handle_tile_click(WorldMapScript.SETTLEMENT_POSITION)
    assert_signal_emitted_with_parameters(world_map, "settlement_activated", ["starting_settlement"])
```

Add a manager-source or behavior test proving `enter_starting_settlement()`
returns the deployed party before loading the local scene. Run `make test`;
it must fail.

### 2. Implement deployed rendering and return routing

In `world_map.gd` add:

```gdscript
signal settlement_activated(location_id: String)
const SETTLEMENT_ID := "starting_settlement"
const SETTLEMENT_POSITION := Vector2i(0, 0)
```

Connect the new signal in `world_map.tscn`. Always draw encounter and
settlement markers. Draw party marker, selection ring, and legal moves only
when `GameSession.has_deployed_party()` is true. Read position with
`get_deployed_party_position()` and persist it with
`set_deployed_party_position(party_position)`.

On the settlement tile, the first click selects the party; the second click
while it is selected emits `settlement_activated`. This prevents the deployed
party from being trapped at `(0, 0)`. Leave the existing encounter tile's
direct `encounter_activated` behavior unchanged.

Add this GameManager transition and call it from the new signal handler:

```gdscript
func enter_starting_settlement() -> Error:
    GameSession.return_deployed_party_to_settlement()
    return _change_scene(STARTING_SETTLEMENT_SCENE)
```

Update localized world-map instructions to mention the two-click settlement
return interaction.

### 3. Verify green

```bash
make check
```

Expected: all tests pass. In particular, no undeployed party is drawn or moved,
and return changes deployment status without changing membership.

### 4. Manual verification and final signoff

Run `make play` and complete:

1. New Game → Encampment → Manage Party → create party → add Warrior.
2. Depart and verify the party marker appears at settlement.
3. Select it once, move it to an adjacent tile, and verify its position persists
   after a scene change if practical.
4. Return to settlement tile; select once, then click again.
5. Verify settlement opens; revisit the world map without departing and confirm
   no party marker exists.
6. Depart again, move to the existing orange encounter, and confirm battle
   entry still works.

Obtain explicit user approval of the full loop before merging.

## Commit and handoff

```bash
git add scripts/world/world_map.gd scenes/world/world_map.tscn scripts/autoload/game_manager.gd translations/en.tres tests/unit/test_world_map.gd tests/unit/test_game_manager.gd tests/unit/test_localization.gd
git commit -m "feat: deploy parties on the world map"
```

After user signoff:

```bash
git checkout main && git merge --ff-only feat/world-map-party-deployment
git branch -d feat/world-map-party-deployment
git status --short
```

Do not push.
