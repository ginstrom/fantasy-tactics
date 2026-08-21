# Step 2 — Withdraw Save and Recovery Regressions

**Branch:** `test/stage-1-withdraw-regressions`
**Depends on:** Step 1 merged
**Milestone:** A withdrawn party's exact campaign/recovery state round-trips through the real save path and remains able to recover from the legal zero-gold/no-party state.

## Files

- Modify: `tests/unit/test_campaign_snapshot.gd`
- Modify: `tests/unit/test_game_manager.gd`
- Modify: `tests/unit/test_campaign_recovery.gd`
- Modify: `tests/unit/test_world_map.gd`
- Modify only if a red test exposes a real bug: `scripts/autoload/game_session.gd`, `scripts/autoload/game_manager.gd`, `scripts/save/campaign_snapshot.gd`

## Setup

```bash
git checkout main && git pull
git checkout -b test/stage-1-withdraw-regressions
make check
```

Proceed only after Step 1 is merged locally and the user has signed off on its
manual check. This step runs in the existing working copy, not a worktree.

## Design and ownership

Do not bump snapshot format or duplicate snapshot fields: withdraw changes existing party health, deployment position, travel route, movement state, selected encounter, and reward buckets, all already owned by `CampaignSnapshot`. The purpose is to lock their combined behavior at the new route boundary. A failed import must remain all-or-nothing; save/load must not bank a reward or clear an authored objective as a side effect.

## Red/green tasks

1. Add a failing `test_campaign_snapshot.gd` round-trip fixture: create a deployed party at an authored encounter, resolve a deterministic Withdraw, export, reset, import, then assert HP, encounter availability, current objective, position, destination/route, and each reward bucket exactly match the pre-export state.
2. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_campaign_snapshot.gd -gunit_test_name=withdraw -gexit
   ```

   Expected: fail until Step 1 state is represented consistently by the existing snapshot path; repair only the demonstrated omitted/aliased field.
3. Add a failing `test_game_manager.gd` real repository save/load test. Assert `go_to_loaded_campaign()` returns the withdrawn deployed party to World Map rather than silently routing home, clearing the route, or settling rewards.
4. Add a failing `test_world_map.gd` test that the restored party remains at the encounter tile but can advance World Map turns toward the Encampment.
5. Add a recovery regression to `test_campaign_recovery.gd`: after a withdrawn party becomes non-deployable and gold is zero, World Map turns still produce the documented Shop income, an affordable offer appears, and a newly formed party can target the unchanged current objective. Reuse the canonical `end_world_turn()` and recruitment APIs; do not fabricate state by editing arrays directly.
6. Run focused suites, make only the smallest red-test-driven repair if needed, then run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_campaign_snapshot.gd,test_game_manager.gd,test_campaign_recovery.gd,test_world_map.gd -gexit
   make check
   godot --headless --path . --editor --quit
   git diff --check
   ```

## Manual signoff

In `make play`, Withdraw from the first objective, save from the World Map, quit/relaunch, and load. Verify the party is still travelling from the encounter and the objective remains active. Return to Encampment, take turns until health/gold change, and confirm the same objective can still be attempted.

## Commit and local merge

After user signoff, stage only the listed tests plus any demonstrably required production files, commit `test(campaign): lock withdraw save and recovery invariants`, merge locally to `main`, and delete `test/stage-1-withdraw-regressions`.
