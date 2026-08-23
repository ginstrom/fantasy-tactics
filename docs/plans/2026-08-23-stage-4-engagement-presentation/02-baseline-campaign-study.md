# Step 2 — Baseline Campaign Study

**Branch:** `test/stage-4-baseline-study`

**Depends on:** Step 1 merged and the user-approved session protocol

**Milestone:** The unmodified Stage 3 campaign has a reproducible automated baseline and enough complete manual-session records to prioritize one bounded iteration without guessing.

## Files

- Modify: `tests/unit/test_campaign_sim.gd` only if it lacks assertions for every protocol-required Stage 3 report field.
- Modify: `docs/dev/running-the-game.md` only if Step 1’s commands prove inaccurate when run.
- Create: no tracked runtime evidence files.

## Red/green tasks

1. Inspect the approved protocol and existing `test_campaign_sim.gd` before changing it. List the report fields required by the protocol and map each to the existing `CampaignSim`/metrics producer. Do not add human-satisfaction scores to simulation output.
2. If a required deterministic field is missing, write the smallest focused failing test in `test_campaign_sim.gd` for its report shape and run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_campaign_sim.gd -gexit
   ```

   Expected: failure names the missing report key or invalid value.
3. Extend the existing producer/metrics path only enough to make that test pass. Keep campaign construction on `ScenarioContract`/`BattleStateFactory`, preserve per-iteration seeded RNG, and update the documented report description if its durable local format changes.
4. Rerun the focused test, then record one immutable baseline outside Git:

   ```bash
   make campaign-sim
   make check
   godot --headless --path . --editor --quit
   git diff --check
   ```

   Expected: 5/5 named representative victories; all checks exit 0; the report is stored at the approved local evidence path with commit hash and command output.
5. Run the minimum approved number of fresh `make play` campaigns (at least three), completing the arc or recording the exact blocking point. Use the approved template at every required checkpoint. Do not “fix while playing”; record first, then rank findings by severity/repeat count.
6. Produce a short local findings summary from the records: evidence paths, repeated findings, single severe findings, deterministic corroboration or divergence, suspected owner, and one recommended next action per finding. Mark content requests that need a product choice as approval gates.
7. Stop for user review of the baseline summary and its ordered findings. No Stage 3/4 tune, UI change, or asset change is authorized until the user selects the next finding(s).

## Manual check

The user reviews the raw session records and local report beside the summary. Confirm the summary preserves surprising or negative observations rather than converting them into a favourable average.

## Commit and local merge

If the report-shape test/documentation changed, after user review stage only those code/test/doc files and commit `test(campaign): lock Stage 4 baseline evidence`. If no tracked file changed, make no empty commit; record the approved baseline handoff instead. In either case, only after the user directs it, merge the branch locally when it has a commit and delete it. Do not push or open a PR.
