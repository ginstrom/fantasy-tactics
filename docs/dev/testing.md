# Testing

How to run the automated test suite, and the conventions this codebase's
tests follow when you write a new one.

Tests use [GUT](https://github.com/bitwes/Gut) 9.7.1
(`addons/gut/`), configured by `.gutconfig.json` at the repo root: test files
live under `res://tests/`, subdirectories included, matched by
`test_*.gd`.

## Prerequisites

- Everything in [README.md § Repository-wide prerequisites](README.md#repository-wide-prerequisites).
- No display needed — tests run with `--headless`.

## Run the full suite

### Steps

```
make test
```
(`make check` is an alias for the same target.) This runs:
```
godot --headless -s addons/gut/gut_cmdln.gd -gexit
```

### Verification

- Output ends with `N/N passed.` followed by `---- All tests passed! ----`
  and the process exits `0`.
- A run that fails prints `[Failed]` lines identifying the file, test name,
  and assertion, and exits non-zero.

### Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `X Orphans` warning after a script's tests | A node was instantiated but not freed via `add_child_autofree`/`autofree` | Not necessarily a failure — see [Orphan node warnings are usually benign](#orphan-node-warnings-are-usually-benign) below before treating it as a bug |
| A single test hangs indefinitely | An `await` is waiting on a signal/timer that never fires (e.g. a coroutine that never completes) | Re-check the awaited condition; see [Waiting for a fire-and-forget coroutine](#waiting-for-a-fire-and-forget-coroutine) below |

## Run a subset of tests

### Steps

- **One file**, by filename substring:
  ```
  godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_world_map.gd -gexit
  ```
- **One test function**, by name substring (matches across all files):
  ```
  godot --headless -s addons/gut/gut_cmdln.gd -gunit_test_name=completes_the_full_game_loop -gexit
  ```
- Full option list: `godot --headless -s addons/gut/gut_cmdln.gd -gh`

### Verification

- Same as the full suite, scoped to the selected script(s)/test(s): a
  `Scripts` count of 1 (for `-gselect`) or the expected number of matching
  tests (for `-gunit_test_name`) in the summary table.

## Writing a new test

Each test file mirrors one script under `scripts/` (e.g.
`tests/unit/test_world_map.gd` tests `scripts/world/world_map.gd`). Follow
the conventions already established in that file's siblings rather than
inventing a new style. The patterns below are the non-obvious ones, learned
while adding `tests/unit/test_first_campaign_ui_flow.gd`'s full-loop test.

### Always reset `GameSession` in `before_each`

`GameSession` and `GameManager` are autoloads — singletons that persist
state across tests in the same run. Every test file starts its `before_each`
with `GameSession.reset()`, and clears any `GameManager` routing fields
(`route_context_id`, `unit_details_origin`, `add_member_return_party_id`)
it touches, so state from one test cannot leak into the next.

### Instantiate the real `.tscn` when you need real signal wiring

A scene's `.tscn` file wires UI signals to handler methods (e.g.
`world_map.tscn` connects `encounter_activated` to `_on_encounter_activated`,
which is what actually calls `GameManager.enter_battle`). Two different
instantiation styles exist in this codebase, and they are not
interchangeable:

- `SomeScene.instantiate()` (the `.tscn` `preload`) — gets the real signal
  connections. Use this to prove a full click-to-navigation path works.
- `SomeScript.new()` (the bare `.gd` script) — skips scene-level signal
  wiring entirely. Several `world_map.gd` tests use this to test movement
  math (`try_move_party`, `build_route`) in isolation, faster and without
  needing the signal to fire anywhere.

If a test asserts on a signal's *effect* (a scene change, a `GameManager`
call), instantiate the `.tscn`. If it asserts only on the signal being
*emitted*, either works.

### Jump state directly instead of re-driving something already tested elsewhere

`test_world_map.gd` already exhaustively covers turn-by-turn party movement
(routing, one-tile-per-turn stepping, cancel/reroute). A test in a different
file that merely needs the party to be standing on a given tile should set
that directly rather than replaying eight turns of clicks:

```gdscript
GameSession.set_deployed_party_position(GameSession.get_expedition(GameSession.GOBLIN_CAMP_ID).position)
```

This is the same shortcut `test_world_map.gd`'s own encounter-activation
tests use (e.g. `test_clicking_selected_party_on_goblin_camp_emits_encounter_activated`).
The rule of thumb: only replay a mechanic step-by-step in the test whose job
*is* that mechanic; everywhere else, jump straight to the state you need and
spend the test's assertions on what's actually new.

### Forcing a deterministic battle outcome

Combat has two sources of randomness: `BattleController.hit_roll` (defaults
to `randf()`) and enemy AI targeting. To make a kill deterministic in a test:

```gdscript
battlefield.grid.hit_roll = func() -> float: return 0.0  # every attack hits
battlefield.grid.apply_super_power()                     # player unit: 100 move range, 100 damage, 100% hit
```

(`battlefield.grid` is the `BattleController` instance — the `Grid` node in
`battlefield.tscn` — not the `GridScript` tile-geometry helper of the same
name nested inside it.) `apply_super_power()` is the same debug affordance
the in-game debug menu's "Super Power" button calls; using it in a test is
not a hack particular to tests.

To then drive a real kill through the real input path (not the private
`_apply_battle_outcome()` hook some tests call directly to isolate reward/XP
math), replay actual clicks:

```gdscript
battlefield.grid._handle_tile_click(battlefield.grid.WARRIOR_START)   # select
battlefield.grid._handle_tile_click(adjacent_to_goblin)               # move
battlefield.grid._handle_tile_click(battlefield.grid.GOBLIN_START)    # attack, kills, wins
```

### Waiting for a fire-and-forget coroutine

`Battlefield._on_board_changed()` calls `_resolve_battle(victory)` — an
`async` function — *without* `await`, because it runs from a signal
handler. That coroutine suspends at `await get_tree().create_timer(...).timeout`
and resumes on a later frame; your test's next line runs immediately, before
`GameManager.complete_battle()` (or `fail_battle()`) has actually happened.

Two things make this test-friendly rather than flaky:

1. Set `battlefield.enemy_turn_beat_seconds = 0.0` before instantiating, so
   the timer is as short as possible.
2. Poll a state change that only happens once the coroutine finishes, with a
   frame cap so a genuine regression fails fast instead of hanging the
   suite:
   ```gdscript
   var settle_frames := 0
   while GameSession.selected_encounter != "" and settle_frames < 30:
       await get_tree().process_frame
       settle_frames += 1
   ```
   `GameSession.selected_encounter` is a good sentinel here because
   `GameManager.complete_battle()`/`fail_battle()` are the only things that
   clear it.

### Private (underscore-prefixed) methods are fair game

GDScript doesn't enforce the leading-underscore convention as real privacy.
Existing tests call `_handle_tile_click`, `_apply_battle_outcome`,
`_select_unit`, etc. directly to drive or isolate a specific internal
transition without simulating a full `InputEvent`. Follow the same
convention rather than routing everything through synthetic input events.

### Orphan node warnings are usually benign

GUT prints an `N Orphans` warning per script when a `Node` was created but
never freed by the time the test tree tears down. This suite's existing,
passing tests already produce dozens of these per file (visible in a normal
`make test` run) — they come from scenes instantiated deeper in a call chain
(e.g. `GameManager`'s own persistent `_game_menu`/`_debug_menu` children) and
are not, by themselves, evidence your new test is wrong. Only treat a
sudden, large jump in orphan count on a change you made as worth
investigating.
