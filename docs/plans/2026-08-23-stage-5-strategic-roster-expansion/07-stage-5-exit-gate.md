# Step 7 — Stage 5 Exit Gate

**Branch:** `test/stage-5-exit-gate`

**Depends on:** all accepted Step 2–6 slices locally merged

**Milestone:** A fresh and migrated campaign can exercise every delivered Stage 5 decision deterministically and manually, with no regression in the original campaign safety boundary.

## Files

- Modify/Create: `tests/unit/test_stage_5_strategic_roster_expansion.gd`, `tests/unit/test_campaign_snapshot.gd`, `tests/unit/test_game_session.gd`, `tests/unit/test_battle_state_factory.gd`, `tests/unit/test_scenario_runner.gd`, and only focused regressions exposed by the exit journey.
- Modify only if required for observable simulation proof: `scripts/tools/campaign_sim.gd`, `scripts/tools/campaign_sim_metrics.gd`, `scripts/tools/campaign_sim_main.gd`, and their tests.
- Modify: `docs/plans/2026-08-23-stage-5-strategic-roster-expansion/index.md` solely to record final evidence/signoff.

## Red/green tasks

1. Write one end-to-end failing journey test through public `GameSession`/`GameManager` contracts: begin a fresh campaign, retain guaranteed objective discovery, gain optional intelligence/quest data, resolve an approved tactical/Mage/specialization choice and counter, operate two parties if Step 6 shipped, snapshot/import mid-route, and verify correct aftermath/reward/objective ownership.
2. Run the focused journey test with `-gselect=test_stage_5_strategic_roster_expansion.gd -gexit`; record the first violated cross-slice invariant.
3. Repair only the owning production seam and add a focused unit/regression test. Do not hide a failure by weakening the journey assertion or special-casing the simulator.
4. Add seeded scenario runs for each shipped mechanic and a same-seed replay assertion for every new random source. Run the protected representative campaign-sim set and compare its safety/budget assertions with the Stage 4 baseline.
5. Run the common final checks from `index.md`; capture reports, screenshots, and manual notes outside Git.
6. Update the index with evidence, deferred branches/content, user signoff date, and merged commits. Do not call an unapproved specialization or deferred mechanic shipped.

## Manual check

In `make play`, perform the user-approved Stage 5 acceptance route end to end: optional scouting/quest decision, tactical visibility/reaction decision, Mage and delivered specialization counterplay, two-party travel/selection if delivered, save/load, victory/free-play distinction, and a final return to the original authored route. Confirm all states remain legible without debug output.

## Commit and local merge

After user signoff, stage only exit tests, necessary report-code tests, and the evidence record; commit `test(campaign): prove Stage 5 strategic expansion`, merge locally to `main`, and delete `test/stage-5-exit-gate`.
