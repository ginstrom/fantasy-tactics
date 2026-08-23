# Step 2 — Optional Intelligence and Guild Hall Quests

**Branch:** `feat/stage-5-intelligence-quests`

**Depends on:** Step 1 merged; approved quest duration/reward/cadence and Watchtower balance rows

**Milestone:** Optional encounter instances accumulate save-safe intelligence and may become optional quests, while every authored objective remains guaranteed-discovered.

## Files

- Modify: `scripts/autoload/game_session.gd`, `scripts/autoload/game_config.gd`, `config/game_config.json`, `scripts/save/campaign_snapshot.gd`, and `scripts/autoload/game_manager.gd` only for durable rules, config, validation, and thin wrappers.
- Modify: `scripts/world/world_map.gd`, `scenes/world/world_map.tscn`, `scripts/ui/information_panel.gd`, `scenes/ui/information_panel.tscn`, `scripts/ui/guild_hall.gd`, `scenes/ui/guild_hall.tscn`, and `translations/en.tres` for rendering and player intent.
- Modify/Create: `tests/unit/test_game_session.gd`, `tests/unit/test_campaign_snapshot.gd`, `tests/unit/test_world_map.gd`, `tests/unit/test_information_panel.gd`, `tests/unit/test_guild_hall.gd`, `tests/unit/test_game_config.gd`, and one focused Stage 5 journey test under `tests/unit/`.

## Red/green tasks

1. From the approved row, write failing `GameSession` tests for turn-distance retention, independent eligible-source detection rolls, ordered information tiers, no-decay persistence, removal-on-clear, and forced discovery of newly unlocked `obj_*` objectives. Inject rolls; never call global randomness in these rules.
2. Run only those tests with `-gselect=test_game_session.gd -gexit`; record red failures for absent state/API.
3. Add the smallest encounter-keyed intelligence record and quest record owned by `GameSession`. Key them by live encounter instance id, resolve one attempted next tier per World Map turn, and keep authored discovery separate from optional detection.
4. Add `GameConfig` keys and matching defaults for only the approved tunables. Extend snapshot export, strict normalize/validation, migration, and transactional import tests before wiring UI.
5. Write failing real-scene tests proving that the World Map exposes only known details, an accepted quest reveals only its documented initial information, expired quests remain visible but reward nothing, and authored objective UI still identifies the required route.
6. Implement Watchtower purchase/rendering and Guild Hall posting/acceptance/completion intent through `GameSession` APIs. A quest completes only when its target clears and the party returns to the Encampment; it must not create a route around normal loot/recovery handling.
7. Add deterministic scenario fixtures and campaign-sim telemetry only when the approved slice needs them. A fixture must construct the real state through `ScenarioContract`/`BattleStateFactory`; test that repeat runs with the same seed produce byte-identical intelligence/quest outcomes.
8. Run focused tests, then the common final checks from `index.md`.

## Manual check

In `make play`, advance several World Map turns with and without a Scout/Watchtower; verify details accumulate in order, a quest is optional and expires visibly, its reward waits for return to Encampment, and the next authored objective remains immediately visible after an unlock.

## Commit and local merge

After user signoff, stage only the listed state/config/snapshot/UI/tests/scenario files; commit `feat(strategy): add optional intelligence and quests`, merge locally to `main`, and delete `feat/stage-5-intelligence-quests`.
