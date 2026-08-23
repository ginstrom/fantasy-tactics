# Step 6 — Stage 4 Exit Gate

**Branch:** `test/stage-4-exit-gate`

**Depends on:** Steps 3–5 merged

**Milestone:** The final evidence package demonstrates a clearer, more appealing first campaign or identifies the exact bounded Stage 4 iteration still required.

## Files

- Modify: `tests/unit/test_campaign_sim.gd` only for approved regression assertions introduced by shipped Stage 4 tuning.
- Modify: `tests/unit/test_first_campaign_ui_flow.gd` for the approved objective/onboarding/victory/free-play route expectations.
- Modify: focused World Map, Battlefield, sprite, and audio test files changed by Steps 4–5.
- Modify: `docs/dev/running-the-game.md` only if final evidence commands changed.
- Create: no tracked player records, screenshots, saves, or generated campaign reports.

## Red/green tasks

1. Review every approved finding row from Step 2 onward. Add a failing regression test only for a shipped behavior that lacks one; link each test to its finding ID in a concise comment. Do not encode subjective enjoyment as a unit-test assertion.
2. Run the focused tests for every shipped finding and record the green results. Then run the final deterministic evidence set:

   ```bash
   make campaign-sim
   make check
   godot --headless --path . --editor --quit
   git diff --check
   ```

   Expected: named representative seeds are 5/5; all tests/checks exit 0; the report remains local and names the exact mode/seeds.
3. Re-run at least the approved number of complete fresh manual campaigns (never fewer than three) on the final merged build. Use the same template/checkpoints as Step 2. Include the approved accessibility/audio-off checks and record any new finding rather than dismissing it.
4. Create a compact local exit summary: build commit; report path and headline comparison; each repeated/severe finding with fixed/rechecked/deferred disposition; the D9 observations; and any proposed Stage 5 item. A deferral must name its evidence, why it is outside Stage 4, and why it does not block the first campaign.
5. Present the exit summary and raw records to the user. If the user cannot sign off, create a new bounded Stage 4 iteration from the highest-priority unresolved record; do not start Stage 5.

## Manual exit-gate signoff

From New Game in `make play`, form the intended party, complete the full authored arc, make recovery/upgrade/retreat decisions, save/load once, defeat the Ogre, and enter labelled free play. Without developer explanation, state the current objective/next unlock, risk and retreat consequences, target/mode/wound feedback, and the victory/free-play boundary. Repeat the required accessibility check with the approved non-audio/non-colour cues. The user signs off only if repeated confusion and dominant strategies have a fixed or explicit disposition.

## Commit and local merge

After user signoff, stage only missing regression tests and durable command documentation; commit `test(campaign): prove Stage 4 engagement exit gate`, merge locally to `main`, and delete `test/stage-4-exit-gate`. If no tracked files changed, make no empty commit and record the signoff handoff. Do not push or open a PR.
