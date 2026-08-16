# Step 2: Canonical Campaign Snapshot Fixtures

## Objective

Represent every baseline debug scenario as a complete `CampaignSnapshot` fixture and apply it atomically through `GameSession.import_campaign_snapshot()`. This is the shared seam with the save system.

## Setup

```bash
git checkout main && git pull
git checkout -b feat/debug-scenario-snapshot-fixtures
```

Read `scripts/autoload/game_session.gd` around `export_campaign_snapshot()` and `import_campaign_snapshot()`, `scripts/save/campaign_snapshot.gd`, and the Step 1 manifest contract.

## Red / green work

1. Add failing tests in `tests/unit/test_debug_scenarios.gd` for each baseline ID: `new_campaign`, `encampment`, `party_manager`, `party_ready`, `party_empty`, `world_map`, `goblin_camp`, `orc_outpost`, `ruined_fortress`, and `stocked_stores`.
2. For each test, compare `GameSession.export_campaign_snapshot()` with its approved fixture after `DebugScenarios.apply(id)`. Preserve display order separately from state comparison.
3. Add failure tests proving an invalid embedded snapshot or unknown scenario returns `{ok: false, errors: [...]}` and leaves an already-populated `GameSession.export_campaign_snapshot()` byte-for-byte equivalent.
4. Run the focused test and confirm red.
5. Generate each complete JSON-safe fixture from the established baseline state using `export_campaign_snapshot()`; store it as that scenario's `campaign_snapshot`. Use the canonical field names, including party `world_position`, `deployed`, `travel_route`, `movement_spent`, `location_id`, and `metadata`.
6. Implement `DebugScenarios.apply(id)` so it reads a deep copy of the scenario snapshot and calls `GameSession.import_campaign_snapshot()` exactly once. Return its error details; never reset first and never set durable fields directly.
7. Rerun the focused tests and `make check`.

## Constraints

Do not add unit shorthand, direct inventory assignment, or an alternate item-instance model. The existing snapshot import validates workshop jobs, carried inventory, and unique-item ownership. Rewards must remain in precisely the fixture buckets; applying or viewing a fixture must not deposit or merge them.

## Milestone and manual check

With `make play`, run `Stocked Stores` and verify its fixture values appear. Run `Ruined Fortress` and verify its configured three-member party and selected encounter state. Capture exported snapshots in test assertions, not checked-in generated runtime reports.

## Handoff

After user sign-off, run `godot --headless --path . --editor --quit` and `git diff --check`, commit `feat: apply debug scenarios as campaign snapshots`, merge `feat/debug-scenario-snapshot-fixtures` locally into `main`, and delete the branch. Do not push.
