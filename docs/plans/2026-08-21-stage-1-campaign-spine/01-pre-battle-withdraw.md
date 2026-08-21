# Step 1 — Pre-Battle Withdraw

**Branch:** `feat/stage-1-pre-battle-withdraw`
**Depends on:** clean `main`
**Milestone:** Reaching an available encounter presents **Enter** and **Withdraw**. Withdraw is deterministic when injected, nonlethal, preserves the encounter/objective, and sends survivors home without opening Battlefield.

## Files

- Modify: `scripts/autoload/game_session.gd`
- Modify: `scripts/autoload/game_manager.gd`
- Modify: `scripts/world/world_map.gd`
- Modify: `scenes/world/world_map.tscn`
- Modify: `translations/en.tres`
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/unit/test_game_manager.gd`
- Modify: `tests/unit/test_world_map.gd`
- Modify: `tests/unit/test_localization.gd`

## Setup

```bash
git checkout main && git pull
git checkout -b feat/stage-1-pre-battle-withdraw
make check
```

Confirm the baseline is clean before writing a test. Do not create a worktree;
this repository uses a normal branch in the current working copy.

## Design and ownership

Add a narrow `GameSession.withdraw_from_encounter(encounter_id, roll: Callable)` transaction. It must first validate that `encounter_id` is enterable, is at the deployed party's current location, and is not an active Battlefield selection. Iterate living party members once, using one injected `roll.call()` per member: `< 0.90` preserves HP; otherwise subtract `ceili(max_hp * 0.10)`, clamped to at least 1 HP. Clear no campaign/objective/reward state, preserve the encounter, set the party's destination/route to the Encampment using the established session route API, and return a per-member result list for UI feedback.

`GameManager.withdraw_from_encounter()` may call that transaction and route to World Map, but must not calculate HP, mutate loot, or implement death rules. Replace World Map's immediate activation route with an arrival panel. **Enter** calls the existing `GameManager.enter_battle(encounter_id)` path. **Withdraw** calls the manager wrapper, closes the panel, refreshes highlights/information, and must never load Battlefield. A cancel/close returns control to the map without changing state.

## Red/green tasks

1. In `test_game_session.gd`, write failing tests for a seeded/injected 0.0 roll and 0.95 roll. Assert one roll per living deployed member, the 10% max-HP loss rounds up and cannot kill, the current authored objective and encounter remain enterable, reward buckets remain unchanged, and a homeward route is recorded.
2. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gunit_test_name=withdraw -gexit
   ```

   Expected: the new tests fail because no withdrawal transaction exists.
3. Implement only the `GameSession` transaction and its injectable default roll. Re-run the focused command; expected: pass.
4. Add failing manager tests proving valid withdraw routes to World Map, while invalid/out-of-position requests leave session state and routing unchanged. Add failing World Map scene tests that instantiate `world_map.tscn`, click an encounter, verify the arrival panel, and invoke both real button signals.
5. Run the focused manager/map suites. Expected: fail until the panel, real signal connections, and thin manager wrapper exist.
6. Add the minimal `PanelContainer`/buttons and script state. Keep `encounter_activated` as an intent signal if useful, but it must no longer directly enter battle. Add localized keys for title, Enter, Withdraw, Cancel, and the nonlethal outcome summary; add the localization assertions.
7. Re-run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_world_map.gd,test_game_manager.gd,test_localization.gd -gexit
   make check
   godot --headless --path . --editor --quit
   git diff --check
   ```

## Manual signoff

Run `make play`, start a game, form/deploy a party, and travel to the displayed first objective. Verify arrival offers Enter/Withdraw. Cancel once (nothing changes), Withdraw once (no one dies, the marker remains, survivors start returning home), then re-enter the same marker and choose Enter (Battlefield opens). Confirm that the existing Battlefield Retreat remains its separate control.

## Commit and local merge

After user signoff:

```bash
git add scripts/autoload/game_session.gd scripts/autoload/game_manager.gd scripts/world/world_map.gd scenes/world/world_map.tscn translations/en.tres tests/unit/test_game_session.gd tests/unit/test_game_manager.gd tests/unit/test_world_map.gd tests/unit/test_localization.gd
git diff --cached --check
git commit -m "feat(world): add safe pre-battle withdraw"
git checkout main
git merge feat/stage-1-pre-battle-withdraw
git branch -d feat/stage-1-pre-battle-withdraw
```
