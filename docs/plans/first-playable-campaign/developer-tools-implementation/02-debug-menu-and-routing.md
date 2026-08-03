# Step 02: Debug Menu and Routing

## Milestone

In debug builds, `F9` toggles a compact overlay whose buttons apply a named
scenario and route through `GameManager` to the corresponding real scene. The
overlay is absent in non-debug builds.

## Setup

Steps [01](01-debug-scenarios.md), [Party Manager UI](../../settlement-first-party-implementation/02-party-manager-ui.md),
and [Starting Settlement and Encampment](../../settlement-first-party-implementation/03-settlement-and-encampment.md)
must be merged into `main`. Preserve unrelated edits.

```bash
git status --short
git checkout main && git pull --ff-only
git checkout -b feat/debug-menu
```

## Files

- Create: `scenes/debug/debug_menu.tscn`
- Create: `scripts/debug/debug_menu.gd`
- Create: `scripts/debug/debug_menu.gd.uid`
- Create: `tests/unit/test_debug_menu.gd`
- Modify: `scripts/autoload/game_manager.gd`
- Modify: `tests/unit/test_game_manager.gd`
- Modify: `translations/en.tres`
- Modify: `tests/unit/test_localization.gd`

## Red/green implementation

### 1. Write failing menu and manager tests

Create a scene test that instantiates `debug_menu.tscn`, verifies it starts
hidden, and checks for six stable-ID buttons. Use node names such as
`Panel/Rows/NewCampaignButton` and `Panel/Rows/MonsterEncounterButton`; assert
translation keys, not English rendering.

Add pure manager-mapping tests:

```gdscript
func test_debug_scenario_target_maps_known_ids() -> void:
	assert_eq(GameManager.debug_scenario_target("encampment"), GameManager.DebugTarget.ENCAMPMENT)
	assert_eq(GameManager.debug_scenario_target("party_manager"), GameManager.DebugTarget.PARTY_MANAGER)
	assert_eq(GameManager.debug_scenario_target("world_map"), GameManager.DebugTarget.WORLD_MAP)
	assert_eq(GameManager.debug_scenario_target("monster_encounter"), GameManager.DebugTarget.BATTLEFIELD)
	assert_eq(GameManager.debug_scenario_target("unknown"), GameManager.DebugTarget.NONE)
```

Add localization assertions for the title, `F9` close hint, and six labels.

```bash
make test
```

Expected: FAIL because the menu, mapping, and translation keys do not exist.

### 2. Implement the development-only overlay

Create `debug_menu.tscn` as a `CanvasLayer` with a readable `Panel` and a
vertical button list. Its script starts hidden and toggles on `F9`:

```gdscript
extends CanvasLayer

func _ready() -> void:
	visible = false

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and event.keycode == KEY_F9:
		visible = not visible
		get_viewport().set_input_as_handled()
```

Each button calls a local `_run(scenario_id)`. It calls
`GameManager.run_debug_scenario(scenario_id)` and hides only after `OK`; it
does not write session fields or change scenes itself.

In `GameManager._ready()`, after translations are installed, instantiate and
add this menu only behind `OS.is_debug_build()`:

```gdscript
if OS.is_debug_build():
	add_child(preload("res://scenes/debug/debug_menu.tscn").instantiate())
```

Declare `enum DebugTarget { NONE, SETTLEMENT, ENCAMPMENT, PARTY_MANAGER,
WORLD_MAP, BATTLEFIELD }`. Implement the tested
`debug_scenario_target(scenario_id)` mapping. `run_debug_scenario` returns
`ERR_UNAVAILABLE` outside debug builds; otherwise it applies `DebugScenarios`,
returns `ERR_INVALID_DATA` on failure, and invokes an existing manager route:

- `new_campaign`: `go_to_game()`
- `encampment`: `go_to_encampment()`
- `party_manager`: `open_party_manager()`
- `party_ready`: `go_to_encampment()`
- `world_map`: `go_to_world_map()`
- `monster_encounter`: `enter_battle(...)`

For the final route, extract the existing encounter ID to one shared constant
if necessary. Do not make the debug menu depend on a world-map scene instance.
Add only the corresponding English translation keys. Release filtering remains
deferred: no overlay is created and the manager route is unavailable when the
build is not a debug build.

### 3. Verify green

```bash
make test
make check
rg -n 'DebugScenarios|run_debug_scenario|is_debug_build|KEY_F9' scripts scenes
```

Expected: all GUT tests pass; scenario state setup is confined to
`DebugScenarios`, and menu creation is behind the debug-build guard.

### 4. Manual verification

Run `make play` and check:

1. `F9` opens and closes the menu from the starting settlement.
2. **Party Ready to Depart** opens encampment with Depart enabled.
3. **Party on World Map** shows exactly one party marker at `(1, 0)`, which
   moves normally.
4. **Monster Encounter** opens the ordinary battle scene.
5. Start again through the ordinary UI and complete settlement → party manager
   → depart → world map without developer tools.

Ask for user approval before merging.

## Commit and handoff

```bash
git add scenes/debug/debug_menu.tscn scripts/debug/debug_menu.gd scripts/debug/debug_menu.gd.uid scripts/autoload/game_manager.gd translations/en.tres tests/unit/test_debug_menu.gd tests/unit/test_game_manager.gd tests/unit/test_localization.gd
git commit -m "feat: add debug scenario menu"
```

After user signoff:

```bash
git checkout main && git merge --ff-only feat/debug-menu
git branch -d feat/debug-menu
git status --short
```

Do not push.
