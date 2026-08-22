# Step 1 — Stage 3 Balance and Boundary Contract

**Branch:** `docs/stage-3-campaign-contract`

**Depends on:** clean `main`

**Milestone:** Canonical design and tunable data state exactly what a successful first arc may spend, earn, unlock, and present; implementation cannot invent values later.

## Files

- Modify: `docs/designs/campaign-loop.md`
- Modify: `docs/designs/monster-manual.md` only if the approved Ogre/last-ascent composition changes a canonical monster row
- Modify: `docs/designs/equipment-handbook.md` only if an approved campaign-required upgrade/consumable changes its canonical cost or unlock
- Modify: `config/game_config.json` only for approved globally tunable values
- Modify: `tests/unit/test_game_config.gd` if configuration schema/validation changes

## Red/green tasks

1. Write the Stage 3 decision table in `campaign-loop.md` before changing runtime data. For each of the twelve IDs, state intended counterplay, reward budget, threat/star, and expected party-level/Encampment checkpoint; state the total expected gold, upgrades, and target level near 6 before the Ogre.
2. In the same contract, decide D8: exact Ogre formation and reward presentation; Victory-screen headline/stats and Continue label; whether free play begins immediately on Continue; and which repeatable templates may fill post-victory vacancies. State that required IDs never reappear.
3. Define approval bands rather than a fabricated universal win rate: the exact representative seed set, required victory count, allowed level/resource/upgrade ranges, maximum simulated world turns, and which deviations require user approval.
4. If a new `GameConfig` key is necessary, first add a focused schema/fallback test and run:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_config.gd -gexit
   ```

   Expected: fail only for the missing key/schema, then pass after the smallest loader/config update. Do not duplicate a literal in `CampaignSim`.
5. Review the table against the current `EXPEDITIONS`, building APIs, Shop rates, and equipment catalog. Mark every still-unapproved number as an approval gate; do not start Step 2 until the user accepts the contract.

## Manual check

Read the campaign table beside a fresh `make play` Encampment. Confirm each listed improvement and its cost/unlock is visible or explicitly scheduled for a later implementation step; do not judge balance yet.

## Commit and local merge

After user approval, stage only the contract/config/test files; commit `docs(campaign): lock Stage 3 arc contract`, merge locally to `main`, and delete `docs/stage-3-campaign-contract`. Do not push or open a PR.
