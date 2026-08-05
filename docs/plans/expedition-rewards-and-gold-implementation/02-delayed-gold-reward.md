# Step 2: Delayed Gold Reward

**Milestone:** Victory queues fixed gold while the party remains on the World Map; entering Encampment pays it once and clears it.

## Setup

```bash
git checkout main
git pull --ff-only
git checkout -b feat/delayed-expedition-gold
rg -n 'ORC_OUTPOST_ID|EXPEDITIONS' scripts/autoload/game_session.gd
```

## Files

- Modify: `scripts/autoload/game_session.gd`, `scripts/autoload/game_manager.gd`
- Modify: `tests/unit/test_game_session.gd`, `tests/unit/test_game_manager.gd`, `tests/unit/test_battlefield.gd`

## Red/green TDD

1. In `test_game_session.gd`, write failing tests that new/reset state has `gold == 0` and `pending_reward == 0`; completing an entered Goblin Camp creates `pending_reward == 10`, completes the site, and leaves gold at zero. Test `deposit_pending_reward()` returns `10`, changes gold to `10`, clears pending, and then returns `0` without a second change. Test abandoning an entered Orc Outpost leaves zero gold/pending and an incomplete site.

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_game_session.gd -gexit
   ```

   Expected: FAIL because resource fields and deposit API do not exist.

2. In `game_session.gd`, add `var gold: int = 0` and `var pending_reward: int = 0`; reset both. Change `complete_current_encounter()` to resolve the selected catalog record before clearing selection, complete it once, and copy its fixed reward to pending without changing gold. Add:

   ```gdscript
   func deposit_pending_reward() -> int:
       var deposited := pending_reward
       gold += deposited
       pending_reward = 0
       return deposited
   ```

   Keep pending campaign/session-level because this slice has one deployed party. `abandon_current_encounter()` remains only a selection clear. Re-run; expected: PASS.

3. In `test_game_manager.gd`, write a red test that completes Goblin Camp, calls `go_to_encampment()` twice, and observes `gold == 10`, pending `0` after each call. In `test_battlefield.gd`, extend victory outcome coverage: `_apply_battle_outcome(true)` completes the site and queues gold but does not bank it; defeat returns home with neither kind of gold.

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_game_manager.gd -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_battlefield.gd -gexit
   ```

   Expected: FAIL because the Encampment route only changes scenes.

4. In `game_manager.gd`, call `GameSession.deposit_pending_reward()` immediately before changing to `ENCAMPMENT_SCENE` in `go_to_encampment()`. Do not deposit in battlefield, World Map, Starting Settlement, `refresh()`, or drawing code. Preserve victory’s return-to-map and defeat’s return-home routes. Re-run both focused tests; expected: PASS.

## Verification

```bash
make check
godot --headless --path . --editor --quit
git diff --check
```

All commands must exit `0`.

## Manual verification and merge

Run `make play`: win Goblin Camp, return through Starting Settlement to Encampment, then confirm reward state deposits once; reopen Encampment and confirm it cannot pay again. Separately lose to Orc Outpost and confirm no pending/banked gold and a retryable site. The visible panel arrives in Step 3.

After user signoff:

```bash
git add scripts/autoload/game_session.gd scripts/autoload/game_manager.gd tests/unit/test_game_session.gd tests/unit/test_game_manager.gd tests/unit/test_battlefield.gd
git add scripts/**/*.uid
git commit -m "feat: bank expedition gold at encampment"
git checkout main
git merge --ff-only feat/delayed-expedition-gold
git branch -d feat/delayed-expedition-gold
```

Do not push.
