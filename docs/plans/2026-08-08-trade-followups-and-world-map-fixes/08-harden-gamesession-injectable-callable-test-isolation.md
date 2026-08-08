# Task 08: Harden test isolation for GameSession's shared injectable Callables

## Objective

`GameSession.enemy_composition_roll`, `loot_gold_roll`, and `loot_gear_roll`
are injectable `Callable`s on the `GameSession` **autoload singleton** —
unlike `BattleController.hit_roll`/`damage_roll`, which live on a fresh
`BattleController`/`Battlefield` instance created per test and are
naturally test-scoped, these three are shared process-wide. `GameSession.reset()`
deliberately never clears them (a test is expected to set them
immediately before its own call, same convention across the codebase), so
a test that stubs one directly on the `GameSession` singleton and never
restores it leaves that stub live for every later test in the same
`godot ... -gexit` run, across file boundaries. `make test` is legitimately
green today — nothing downstream currently depends on real randomness
after one of these stubs — but it's a fragile, easy-to-silently-break
convention: a future test relying on real randomness after one of these
five files runs would get a silently deterministic value instead and might
never notice. Restore each of the three callables to its real default
after every test that stubs it directly on the shared singleton.

This does not touch `BattleController.hit_roll`/`damage_roll` — those are
correctly scoped per-instance already and need no change.

## Files

- Modify: `tests/unit/test_battlefield.gd`, `tests/unit/test_first_campaign_ui_flow.gd`,
  `tests/unit/test_game_manager.gd`, `tests/unit/test_battle_controller.gd`,
  `tests/unit/test_game_session.gd`

## Depends on

None.

## Produces

Each of the five files restores `GameSession.enemy_composition_roll`/
`loot_gold_roll`/`loot_gear_roll` to their real default `Callable`s in an
`after_each()` hook, added where one doesn't already exist or extended
where one does.

## Steps

This task is test-infrastructure hardening, not a behavior change — there
is no new user-facing behavior to TDD, so there's no red/green cycle here.
Instead: make the change, then verify the full suite is still green
(nothing before this task exercised real randomness after one of these
stubs, so nothing should change).

The real default for each callable (for reference — copy these exact
expressions):

```gdscript
GameSession.enemy_composition_roll = func(option_count: int) -> int: return randi() % option_count
GameSession.loot_gold_roll = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
GameSession.loot_gear_roll = func() -> float: return randf()
```

1. **`tests/unit/test_battlefield.gd`** stubs `enemy_composition_roll`
   (twice) and `loot_gold_roll`/`loot_gear_roll` (once), and already has
   an `after_each()`:

   ```gdscript
   func after_each() -> void:
   	GameManager.close_game_menu()
   ```

   Extend it:

   ```gdscript
   func after_each() -> void:
   	GameManager.close_game_menu()
   	GameSession.enemy_composition_roll = func(option_count: int) -> int: return randi() % option_count
   	GameSession.loot_gold_roll = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
   	GameSession.loot_gear_roll = func() -> float: return randf()
   ```

2. **`tests/unit/test_first_campaign_ui_flow.gd`** stubs `loot_gold_roll`/
   `loot_gear_roll` and has a `before_each()` but no `after_each()` yet.
   Add one:

   ```gdscript
   func after_each() -> void:
   	GameSession.loot_gold_roll = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
   	GameSession.loot_gear_roll = func() -> float: return randf()
   ```

3. **`tests/unit/test_game_manager.gd`** stubs `loot_gold_roll`/
   `loot_gear_roll` and already has an `after_each()`:

   ```gdscript
   func after_each() -> void:
   	# A failed assertion in an open_game_menu test can skip its manual
   	# close_game_menu() cleanup, leaving the tree paused for later tests.
   	get_tree().paused = false
   	GameManager.add_member_return_party_id = ""
   ```

   Extend it:

   ```gdscript
   func after_each() -> void:
   	# A failed assertion in an open_game_menu test can skip its manual
   	# close_game_menu() cleanup, leaving the tree paused for later tests.
   	get_tree().paused = false
   	GameManager.add_member_return_party_id = ""
   	GameSession.loot_gold_roll = func(min_value: int, max_value: int) -> int: return randi_range(min_value, max_value)
   	GameSession.loot_gear_roll = func() -> float: return randf()
   ```

4. **`tests/unit/test_battle_controller.gd`** stubs `enemy_composition_roll`
   (twice) and has a `before_each()` (which already calls
   `GameSession.reset()`, but `reset()` doesn't touch this callable) with
   no `after_each()` yet. Add one:

   ```gdscript
   func after_each() -> void:
   	GameSession.enemy_composition_roll = func(option_count: int) -> int: return randi() % option_count
   ```

5. **`tests/unit/test_game_session.gd`** stubs `enemy_composition_roll` in
   five places directly on the shared `GameSession` singleton (not the
   fresh `GameSessionScript.new()` instances several other tests in this
   file use, which are already test-scoped and don't need this) and has
   no `before_each()`/`after_each()` at all yet. Add:

   ```gdscript
   func after_each() -> void:
   	GameSession.enemy_composition_roll = func(option_count: int) -> int: return randi() % option_count
   ```

6. **Run the full suite.**

   ```bash
   make test
   ```

   Expected: `---- All tests passed! ----`, exit code 0, same test count as
   before this task (this is a hygiene fix, not new coverage — no new
   tests were added).

7. **Commit** only this task's files:

   ```bash
   git add tests/unit/test_battlefield.gd tests/unit/test_first_campaign_ui_flow.gd tests/unit/test_game_manager.gd tests/unit/test_battle_controller.gd tests/unit/test_game_session.gd
   git commit -m "test: restore GameSession's shared injectable Callables after every test that stubs them"
   ```

## Milestone

None of `enemy_composition_roll`/`loot_gold_roll`/`loot_gear_roll` can leak
a deterministic stub from one test file into a later one anymore — a
future test that depends on real randomness after any of these five files
runs will actually get it, instead of silently inheriting a stale stub.
