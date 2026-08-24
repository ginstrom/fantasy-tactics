# Step 5 — Domain Extraction and Stage 6 Exit Gate

**Branch:** `test/stage-6-foundations-exit`

**Depends on:** Steps 2–4 locally merged and manually signed off.

**Milestone:** The extracted boundaries are observable, the integrated fresh-campaign route is deterministic, and no UI/battle/tool path reaches retired global reward or code-authored encounter seams.

## Files

- Create as needed: `scripts/campaign/party_inventory_service.gd`, `scripts/campaign/encounter_service.gd`, `scripts/progression/progression_service.gd`.
- Modify: `scripts/autoload/game_session.gd`, `scripts/save/campaign_snapshot.gd`, direct callers in `scripts/ui/`, `scripts/world/`, `scripts/battle/`, and `scripts/tools/` only to use the new facade APIs.
- Test: create `tests/unit/test_stage_6_foundations.gd`; modify focused catalog, snapshot, campaign, World Map, battle, and scenario-runner tests.
- Modify: this plan's `index.md` and `decision-ledger.md` solely to record final evidence and remaining deferred content.

## Red/green tasks

1. Write a failing architecture/journey test through public APIs: start a fresh campaign; create two parties; resolve independent carried loot; load the migrated JSON authored encounter; choose the approved branching perk; construct the corresponding fixed-seed battle; settle both parties; export/import a current-format snapshot; and verify objective ownership and campaign bank totals.
2. Run it focused and record the first remaining direct-global or duplicate-content failure.
3. Extract only the pure domain currently responsible for that failure—catalog, party inventory, progression, or encounters—behind a `GameSession` facade method. Do not move scene routing into a service or let a service touch the scene tree.
4. Add regression tests proving `GameSession` no longer exposes/uses retired global `pending_*`/`battle_*` storage, and that production content consumers no longer read migrated encounter data from `EXPEDITIONS` or `_cover_tiles_for_encounter()`.
5. Run the full content lint, deterministic same-seed scenario replay, and a CampaignSim run. Record whether CampaignSim is still representative only; do not claim it proves manual comprehension.
6. Run all common final checks. Request read-only review of the final diff against this plan before manual playtesting.
7. Update the ledger with approved/deferred Stage 5 carry-forward decisions, catalog schema version, removed legacy seams, exact verification output, and unresolved future work.

## Manual check

After resetting to a fresh save, use `make play` to: form two parties; earn and independently return loot; travel to the JSON-authored encounter; make the first branching perk choice; observe the action/counter; save/load the current format; and complete/return to the authored campaign route. Confirm errors for a malformed content file are readable and no unrelated party state changes.

## Commit and local merge

After user signoff, commit only final extraction/tests/evidence as `test(architecture): prove Stage 6 foundations`, merge locally to `main`, and delete the branch. Do not push or open a PR.

