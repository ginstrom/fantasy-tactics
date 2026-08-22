# Step 4 — Authored Arc Economy and Boss Tuning

**Branch:** `feat/stage-3-arc-tuning`

**Depends on:** Steps 1–3 merged

**Milestone:** The approved vertical slice reaches the boss with intended preparation choices, without hidden rules or scope expansion.

## Files

- Modify: `scripts/autoload/game_session.gd`
- Modify: `config/game_config.json`
- Modify: `docs/designs/campaign-loop.md` only to record approved values and evidence references
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/unit/test_campaign_sim.gd`
- Modify: `config/campaign_scenarios.json` only if an existing canonical fixture must reflect an approved authored composition
- Modify: `tests/unit/test_battle_state_factory.gd` when a fixture composition changes

## Red/green tasks

1. From Step 2’s baseline report, write failing deterministic assertions for the approved checkpoints: objective order, final pre-boss/boss composition, expected party level band near 6, required meaningful upgrades, resource/recovery budget, and representative victory outcomes. Avoid assertions on a single accidental damage roll.
2. Run the focused tests. Record the first contract divergence exactly (objective, seed, resource/level/upgrade/value); do not change several knobs before reproducing one failure.
3. Tune only approved constants/definitions in the smallest causal group: authored rewards/compositions, existing building costs, recruitment, Shop income, workshop access, or recovery. Preserve the shared tactical-profile baseline unless Step 1 explicitly approved a final-ascent change.
4. After each candidate change, run the relevant focused domain test and `make campaign-sim`; compare its structured report to the Step 2 baseline. Retain the report artifact, with its seed list, outside Git unless the user asks to version evidence.
5. Run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_campaign_sim.gd -gexit
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gexit
   make campaign-sim
   make check
   ```

   Expected: each approved representative seed reaches victory within its contract bands; any remaining outlier is visible and approved, never silently omitted.

## Manual check

Play the campaign in `make play` through at least one tier transition and the pre-boss debug scenario. Confirm costs, unlocks, rewards, recovery, and the final encounter’s stated counterplay are understandable from the UI; record confusing timing or a dominant purchase for Stage 4 rather than broadening this step.

## Commit and local merge

After user signoff, commit `feat(campaign): tune authored Borderlands arc`, merge locally to `main`, and delete `feat/stage-3-arc-tuning`. Do not push or open a PR.
