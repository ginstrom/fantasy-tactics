# Step 6 — Multi-Party Strategy

**Branch:** `feat/stage-5-multi-party`

**Depends on:** Step 5 merged; approved party cap, selection/deployment, battle ownership, simultaneous-scouting, and bounded time-escalation rows

**Milestone:** Multiple parties can be formed, selected, dispatched, routed, and saved independently; strategic time advances safely and no battle/quest/objective state is attributed to the wrong party.

## Files

- Modify: `scripts/autoload/game_session.gd`, `scripts/autoload/game_manager.gd`, `scripts/save/campaign_snapshot.gd`, `scripts/autoload/game_config.gd`, and `config/game_config.json`.
- Modify: `scripts/world/world_map.gd`, `scenes/world/world_map.tscn`, `scripts/ui/party_manager.gd`, `scenes/ui/party_manager.tscn`, `scripts/ui/deploy_party.gd`, `scenes/ui/deploy_party.tscn`, `scripts/ui/information_panel.gd`, `scenes/ui/information_panel.tscn`, `scripts/ui/guild_hall.gd`, `scenes/ui/guild_hall.tscn`, and `translations/en.tres`.
- Modify/Create: `tests/unit/test_game_session.gd`, `tests/unit/test_campaign_snapshot.gd`, `tests/unit/test_world_map.gd`, `tests/unit/test_party_manager.gd`, `tests/unit/test_deploy_party.gd`, `tests/unit/test_information_panel.gd`, `tests/unit/test_campaign_recovery.gd`, and a multi-party journey/scenario test.

## Red/green tasks

1. Write failing `GameSession` and snapshot tests for more than one party with distinct member ids, locations, routes, selected-party state, and battle/quest ownership. Include malformed/duplicate member/route imports to prove the import remains transactional.
2. Run focused tests and record red output. Audit every current `FIRST_PARTY_ID`, `selected_party_id`, `has_deployed_party`, reward deposit, retreat, arrival, and `end_world_turn()` use before changing the cap; list each one-party assumption in the ledger.
3. Replace assumptions with explicit party-id APIs in `GameSession`, preserving the original first campaign's single-party save behavior. A party may not share an adventurer, have two destinations, enter a battle while another selected party owns it, or progress a quest/reward on behalf of another party.
4. Implement World Map party selection and the documented Send Party modal using real-scene tests and the production route-preview/commit path. Render each destination/remaining turns; selecting a new destination replaces only that party's route.
5. Add simultaneous independent scouting only through the intelligence API, retaining per-source independent checks and deterministic seed order. Implement the approved bounded time escalation in `GameSession.end_world_turn()` with config defaults and a counter/expiry UI; it must not make an authored objective unavailable.
6. Add focused integration tests for two parties travelling on the same turn, one arriving/withdrawing/battling while another continues, quest completion/reward attribution, wipe recovery, save/load mid-route, and selected-party UI refresh through real input.
7. Extend campaign simulation only when it can drive the real multi-party state without a parallel planner. Label any multi-party bot policy assumptions in report output; never use its success rate alone as balance proof.
8. Run focused tests and the common final checks.

## Manual check

In `make play`, form two parties, send them to different destinations, switch selection, advance turns, inspect independent routes/scouting, resolve an encounter with one while the other remains valid, save/load mid-travel, and verify time/quest feedback cannot hide the authored objective.

## Commit and local merge

After signoff, commit only the multi-party state/snapshot/config/UI/tests/scenario changes as `feat(strategy): add multi-party travel`, merge locally to `main`, and delete `feat/stage-5-multi-party`.
