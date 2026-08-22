# Step 6 — Stage 3 Exit Gate

**Branch:** `test/stage-3-campaign-assembly-exit-gate`

**Depends on:** Step 5 merged

**Milestone:** Automated evidence and user play evidence establish a complete first Borderlands campaign, with its limits stated honestly.

## Files

- Modify: `tests/unit/test_stage_3_campaign_assembly.gd`
- Modify: `tests/unit/test_campaign_sim.gd` only if the approved representative/report assertions are missing
- Modify: `docs/dev/running-the-game.md` only for a permanent evidence command

## Red/green tasks

1. Add the final failing exit-gate assertions to the full-arc journey: all twelve authored IDs complete exactly once in order; the boss routes to one victory; save/load at each approved checkpoint remains valid; repeatable post-victory activity leaves the authored ledger unchanged.
2. Add a representative-report assertion against Step 1’s explicit bands. It must report individual seed failures and comparison fields rather than asserting a universal completion percentage.
3. Run focused checks, then the full deterministic evidence set:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_stage_3_campaign_assembly.gd -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_campaign_sim.gd -gexit
   make campaign-sim
   make check
   godot --headless --path . --editor --quit
   git diff --check
   ```

   Expected: all commands exit 0; the campaign report names its exact representative seeds and preserves comparison data. A sweep may be attached as exploratory evidence only.
4. Preserve terminal output and one structured report with the implementation handoff. State any intentionally unmeasured balance property as a Stage 4 question, not as a pass.

## Manual exit-gate signoff

From New Game in `make play`, form and prepare a Warrior–Scout–Cleric party, complete the complete authored arc through the Ogre, and use at least one recovery/upgrade/purchase decision that the contract predicts. Verify objective messaging, loss explanation, save/load checkpoint, Victory Screen, and clearly labelled optional free play. Capture screenshots only when a disputed UI/readability issue needs review.

## Commit and local merge

After user signoff, commit `test(campaign): prove Stage 3 campaign assembly`, merge locally to `main`, and delete `test/stage-3-campaign-assembly-exit-gate`. Do not push or open a PR.
