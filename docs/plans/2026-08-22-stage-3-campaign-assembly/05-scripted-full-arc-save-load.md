# Step 5 — Scripted Full-Arc Save/Load

**Branch:** `test/stage-3-full-arc-save-load`

**Depends on:** Step 4 merged

**Milestone:** Defined campaign checkpoints survive a transactional export/import and continue to final victory without duplicated or lost durable state.

## Files

- Create: `tests/unit/test_stage_3_campaign_assembly.gd`
- Modify: `tests/unit/test_campaign_snapshot.gd` only if an uncovered snapshot validation path is found
- Modify: `scripts/autoload/game_session.gd` only for a demonstrated snapshot/progression defect
- Modify: `scripts/save/campaign_snapshot.gd` only for a demonstrated schema/validation defect
- Modify: `scripts/tools/campaign_sim.gd` only if a public, deterministic checkpoint helper is genuinely absent

## Red/green tasks

1. Write a failing integration journey using public `GameSession` APIs and the real `CampaignSim` battle path. Start a fresh game, create/deploy the party, complete the early arc through the approved checkpoint, export, reset, import, and assert no aliases or reward settlement occurred.
2. Continue to the pre-boss checkpoint, repeat export/reset/import, and assert objective ID/order, unlocked/cleared IDs, party/roster/HP/MP, party location/route, gold and each reward bucket, upgrades/jobs, recovery timing, and deterministic RNG injection state required by the next real action.
3. Resume through the final boss. Assert exactly one final objective completion, victory/free-play state, and a post-victory export/import that can enter repeatable play without changing authored history.
4. Run the new test first:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_stage_3_campaign_assembly.gd -gexit
   ```

   Expected: fail at the first missing/incorrect durable boundary. Repair only that boundary, rerun green, and keep the test a journey rather than a replacement simulator.
5. Add a negative import case only if the journey discovers a missing validation rule; prove failed imports leave an already-prepared live session byte-for-byte unchanged.

## Manual check

In `make play`, save at the approved pre-boss checkpoint, restart/import through the normal user path, win the boss, then save/load once more after Continue. Confirm the visible objective and free-play wording match the durable state.

## Commit and local merge

After user signoff, commit `test(campaign): prove full-arc save and victory path`, merge locally to `main`, and delete `test/stage-3-full-arc-save-load`. Do not push or open a PR.
