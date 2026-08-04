# Step 01: World-Map Selection and Site Entry

## Milestone

Clicking the deployed party — on ordinary terrain, the goblin camp, or the
settlement — always selects it first. A second click while it remains
selected enters the goblin camp or the settlement; a second click on ordinary
terrain deselects it. A completed goblin camp cannot be entered even when
selected. `try_activate_current_tile()` and `_handle_tile_click()` share one
code path instead of a settlement-only special case.

## Setup

```bash
git status --short
git checkout main && git pull --ff-only
git checkout -b feat/world-map-site-entry
```

## Files

- Modify: `scripts/world/world_map.gd`
- Modify: `tests/unit/test_world_map.gd`

## Red/green implementation

### 1. Write failing tests

`world_map.gd:84-89` currently activates the goblin camp on the very first
click, before selection — the design explicitly replaces this. Delete the
existing test that locks in that behavior and add tests for the new
select-then-enter and completed-encounter rules, mirroring the settlement
tests already in the file:

Remove:

```gdscript
func test_activating_the_encounter_tile_does_not_require_selecting_first() -> void:
	var world_map := _make_world_map()
	world_map.party_position = WorldMapScript.ENCOUNTER_POSITION
	watch_signals(world_map)

	world_map._handle_tile_click(world_map.party_position)

	assert_signal_emitted_with_parameters(
		world_map, "encounter_activated", [WorldMapScript.ENCOUNTER_ID]
	)
```

Add, alongside the existing settlement click tests:

```gdscript
func test_clicking_deployed_party_on_goblin_camp_selects_it_before_entry() -> void:
	var world_map := _make_world_map()
	world_map.party_position = WorldMapScript.ENCOUNTER_POSITION

	world_map._handle_tile_click(world_map.party_position)

	assert_true(world_map.party_selected, "First click on the goblin camp must select, not enter")


func test_clicking_selected_party_on_goblin_camp_emits_encounter_activated() -> void:
	var world_map := _make_world_map()
	world_map.party_position = WorldMapScript.ENCOUNTER_POSITION
	watch_signals(world_map)

	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(world_map.party_position)

	assert_signal_emitted_with_parameters(
		world_map, "encounter_activated", [WorldMapScript.ENCOUNTER_ID]
	)


func test_selected_party_on_goblin_camp_can_move_away_instead_of_entering() -> void:
	var world_map := _make_world_map()
	world_map.party_position = WorldMapScript.ENCOUNTER_POSITION
	world_map._handle_tile_click(world_map.party_position)
	watch_signals(world_map)

	world_map._handle_tile_click(Vector2i(3, 4))

	assert_signal_not_emitted(world_map, "encounter_activated")
	assert_eq(world_map.party_position, Vector2i(3, 4), "A selected party on the camp must be able to move away")


func test_activating_a_completed_encounter_tile_does_nothing() -> void:
	var world_map := _make_world_map()
	world_map.party_position = WorldMapScript.ENCOUNTER_POSITION
	GameSession.completed_encounters.append(WorldMapScript.ENCOUNTER_ID)
	watch_signals(world_map)

	var activated: bool = world_map.try_activate_current_tile()

	assert_false(activated, "A completed encounter must reject entry")
	assert_signal_not_emitted(world_map, "encounter_activated")


func test_clicking_a_completed_encounter_after_selecting_deselects_instead_of_entering() -> void:
	var world_map := _make_world_map()
	world_map.party_position = WorldMapScript.ENCOUNTER_POSITION
	GameSession.completed_encounters.append(WorldMapScript.ENCOUNTER_ID)
	world_map._handle_tile_click(world_map.party_position)

	world_map._handle_tile_click(world_map.party_position)

	assert_false(world_map.party_selected, "A completed encounter must not stay selected forever")
```

Run:

```bash
make test
```

Expected: the two new completed-encounter tests and the two new goblin-camp
selection tests FAIL — the completed-encounter checks fail because
`try_activate_current_tile()` does not yet consult `is_encounter_complete()`,
and the goblin-camp selection tests fail because the current code still
activates on the first click. The removed test's replacement means there is
no lingering assertion for the old behavior.

### 2. Implement the shared selection-first path

In `try_activate_current_tile()`, reject a completed encounter:

```gdscript
func try_activate_current_tile() -> bool:
	if not GameSession.has_deployed_party() or party_position != ENCOUNTER_POSITION:
		return false
	if GameSession.is_encounter_complete(ENCOUNTER_ID):
		return false

	encounter_activated.emit(ENCOUNTER_ID)
	return true
```

Replace `_handle_tile_click()` so the party's own tile always requires
selection first, regardless of which special tile it is on:

```gdscript
func _handle_tile_click(tile_pos: Vector2i) -> void:
	if not GameSession.has_deployed_party():
		return

	if tile_pos == party_position:
		if not party_selected:
			party_selected = true
			_update_highlights()
			return

		if tile_pos == SETTLEMENT_POSITION:
			settlement_activated.emit(SETTLEMENT_ID)
			return

		if try_activate_current_tile():
			party_selected = false
			_draw_markers()
			_update_highlights()
			return

		party_selected = false
		_update_highlights()
		return

	if party_selected and try_move_party(tile_pos):
		party_selected = false
		GameSession.set_deployed_party_position(party_position)
		_draw_markers()
		_update_highlights()
		board_changed.emit()
```

This removes the old settlement-only special case at the top of the
function — the settlement now goes through the same "already selected" branch
as the goblin camp, and a second click on a completed goblin camp falls
through to the same deselect behavior as ordinary terrain.

### 3. Verify green

```bash
make test
make check
```

Expected: all GUT tests pass, including the existing
`test_activating_the_encounter_tile_emits_encounter_activated`,
`test_clicking_deployed_party_at_settlement_selects_it_before_entry`, and
`test_clicking_selected_party_at_settlement_emits_settlement_activated`
tests, which must keep passing unchanged.

## Commit and handoff

```bash
git add scripts/world/world_map.gd tests/unit/test_world_map.gd
git commit -m "feat: require selection before entering the goblin camp"
```

No manual check is required for this step. Ask for user approval, then:

```bash
git checkout main && git merge --ff-only feat/world-map-site-entry
git branch -d feat/world-map-site-entry
git status --short
```

Do not push.
