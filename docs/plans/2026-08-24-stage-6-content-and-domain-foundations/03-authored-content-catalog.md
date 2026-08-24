# Step 3 — Authored Content Catalog

**Branch:** `refactor/authored-content-catalog`

**Depends on:** Step 2 locally merged; G2 approved.

**Milestone:** One real authored encounter and its battlefield configuration (including spawns and cover tiles) are editable as validated JSON, driving the World Map, production Battlefield, scenario construction, and CampaignSim from a single source of truth.

## Files

- Create: `config/content/catalog.json`, `config/content/encounters/<first-approved-id>.json`, and `scripts/content/content_catalog.gd`.
- Modify: `scripts/autoload/game_session.gd`, `scripts/autoload/game_manager.gd`, `scripts/world/world_map.gd`, `scripts/battle/battle_controller.gd`, `scripts/tools/campaign_sim.gd`, `scripts/tools/battle_scenarios/scenario_contract.gd`, and `scripts/tools/battle_scenarios/battle_state_factory.gd`.
- Modify only when an approved value is tunable: `scripts/autoload/game_config.gd`, `config/game_config.json`.
- Test: create `tests/unit/test_content_catalog.gd`; modify `test_game_session.gd`, `test_world_map.gd`, `test_battle_controller.gd`, `test_battle_state_factory.gd`, `test_scenario_contract.gd`, and `test_campaign_sim_main.gd` as needed.

## Red/green tasks

1. **Write failing catalog tests:**
   - Test loading valid catalog manifest and encounter JSON files.
   - Test rejection of duplicate IDs, missing file paths, non-integer or out-of-bounds `{ "x": n, "y": n }` coordinates (e.g. outside 7×7 grid), duplicate spawn points, overlapping cover and spawn tiles, unknown enemy template IDs, and circular objective prerequisites.
2. **Run catalog tests red:**
   - `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gselect=test_content_catalog.gd -gexit`
3. **Implement `ContentCatalog` Loader and Normalizer (`scripts/content/content_catalog.gd`):**
   - Pure, stateless loader exposing immutable dictionaries and structured validation errors.
   - JSON format specifications:
     - `config/content/catalog.json`:
       ```json
       {
         "version": 1,
         "encounters": [
           "res://config/content/encounters/obj_tier1_1_goblin_outpost.json"
         ]
       }
       ```
     - `config/content/encounters/<id>.json`:
       ```json
       {
         "id": "obj_tier1_1_goblin_outpost",
         "name_key": "encounter.goblin_outpost.name",
         "tier": 1,
         "category": "authored_objective",
         "world_position": { "x": 3, "y": 4 },
         "grid_size": { "width": 7, "height": 7 },
         "player_spawns": [{ "x": 0, "y": 3 }, { "x": 0, "y": 2 }, { "x": 0, "y": 4 }],
         "enemy_spawns": [{ "x": 6, "y": 3 }, { "x": 6, "y": 2 }, { "x": 6, "y": 4 }],
         "cover_tiles": [{ "x": 3, "y": 2 }, { "x": 3, "y": 4 }],
         "enemy_composition": [
           { "template_id": "goblin", "count": 1 },
           { "kobold": "kobold", "count": 2 }
         ],
         "clear_xp": 15,
         "reward_bonus_multiplier": 1,
         "prerequisite_objective_id": ""
       }
       ```
4. **Migrate Encounter and Cover Definitions:**
   - Migrate the first approved encounter from `GameSession.EXPEDITIONS` and `BattleController._cover_tiles_for_encounter()` into JSON.
   - Remove hardcoded cover tile matching functions in `battle_controller.gd`; have `BattleController` read `cover_tiles`, `player_spawns`, and `enemy_spawns` directly from the encounter definition supplied by `ContentCatalog`.
5. **Unify Runtime and Tool Consumers:**
   - `WorldMap`: Place active encounter nodes on the map based on `ContentCatalog.get_encounter_definition(id)`.
   - `BattleController`: Initialize board dimensions, cover, and unit placement from the catalog definition.
   - `ScenarioContract` / `BattleStateFactory`: Validate enemy templates and encounter structures against `ContentCatalog`.
   - `CampaignSim`: Derive simulated battles from the normalized catalog definition.
6. **Add Content Linting & Parity Tests:**
   - Add automated test validating that every catalog reference resolves, every string key exists in `translations/en.tres`, and all coordinates fit within board bounds.
   - Add deterministic scenario parity test asserting that a battle constructed via `ContentCatalog` matches the exact state of the previously hardcoded setup under identical seeds.
7. **Run Focused Tests Green & Common Final Checks:**
   - `make campaign-sim`
   - `make check`
   - `godot --headless --path . --editor --quit`
   - `git diff --check`

## Manual check

In `make play`:
1. Edit a non-critical field (e.g. cover tile coordinate or display name key) in the migrated encounter JSON.
2. Launch the game and confirm the World Map and Battlefield immediately reflect the JSON change without recompilation.
3. Revert the file back to approved content.
4. Intentionally introduce an invalid coordinate in the JSON file and verify that the game logs a clear startup diagnostic error rather than crashing or creating broken battle state.

## Commit and local merge

After review and user signoff, commit the catalog loader, JSON encounter, migrated consumers, and tests as `refactor(content): load authored encounter catalog`, merge locally to `main`, and delete the branch.
