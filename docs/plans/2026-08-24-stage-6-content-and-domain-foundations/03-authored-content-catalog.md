# Step 3 — Authored Content Catalog

**Branch:** `refactor/authored-content-catalog`

**Depends on:** Step 2 locally merged; G2 approved.

**Milestone:** One real authored encounter is editable as validated JSON and drives the World Map, production Battlefield, scenario construction, and CampaignSim without a duplicate code-authored definition.

## Files

- Create: `config/content/catalog.json`, `config/content/encounters/<first-approved-id>.json`, and `scripts/content/content_catalog.gd`.
- Modify: `scripts/autoload/game_session.gd`, `scripts/autoload/game_manager.gd`, `scripts/world/world_map.gd`, `scripts/battle/battle_controller.gd`, `scripts/tools/campaign_sim.gd`, `scripts/tools/battle_scenarios/scenario_contract.gd`, and `scripts/tools/battle_scenarios/battle_state_factory.gd`.
- Modify only when an approved value is tunable: `scripts/autoload/game_config.gd`, `config/game_config.json`.
- Test: create `tests/unit/test_content_catalog.gd`; modify `test_game_session.gd`, `test_world_map.gd`, `test_battle_controller.gd`, `test_battle_state_factory.gd`, `test_scenario_contract.gd`, and `test_campaign_sim_main.gd` as needed.

## Red/green tasks

1. Write failing catalog tests for valid loading and for duplicate ids, missing template references, malformed coordinates, invalid formation/terrain/reward shapes, unknown objective prerequisites, and an encounter file not listed by the catalog manifest.
2. Run `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gselect=test_content_catalog.gd -gexit` and record red failures before adding a loader.
3. Implement a pure `ContentCatalog` loader/normalizer. JSON uses stable ids and `{ "x": n, "y": n }` coordinates; it returns immutable deep copies/normalized dictionaries and structured diagnostics. Do not embed `Vector2i`, scene paths, executable callbacks, or balance literals in JSON.
4. Define the first bounded schema: encounter identity/display keys, world position, objective metadata/prerequisite, enemy template ids and counts, explicit battle board/cover/spawns, and approved reward references. Keep class/enemy/item templates in catalog registries or existing typed registries behind catalog lookups; do not create a second stat system.
5. Migrate exactly one approved authored encounter from `GameSession.EXPEDITIONS` and `BattleController._cover_tiles_for_encounter()` into JSON. Delete its production fallback/match entry only after the live World Map, `BattleController`, and objective route load it from the catalog.
6. Make CampaignSim derive its production encounter scenario from the normalized record. Keep `config/campaign_scenarios.json` as explicit test data, but have ScenarioContract validation ask the catalog for known template ids instead of maintaining a separate hand-written list.
7. Add a content-lint test that loads every catalog file and asserts every objective/encounter/template/reward reference resolves. Add a fixed-seed production-vs-scenario parity test for the migrated encounter.
8. Run focused tests green and the common final checks.

## Manual check

Edit only a harmless display key or Cover coordinate in the approved JSON encounter, run `make play`, and confirm the World Map/Battlefield reflects it. Restore the approved content before signoff. Confirm a malformed JSON reference stops at a readable startup/test diagnostic rather than creating a partial encounter.

## Commit and local merge

After review and user signoff, commit the catalog, migrated encounter, loader, tests, and only required runtime consumers as `refactor(content): load authored encounter catalog`, merge locally to `main`, and delete the branch.

