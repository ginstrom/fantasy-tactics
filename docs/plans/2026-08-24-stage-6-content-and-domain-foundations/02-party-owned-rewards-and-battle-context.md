# Step 2 — Party-Owned Rewards and Battle Context

**Branch:** `refactor/party-owned-rewards`

**Depends on:** Step 1 locally merged; G4 closed.

**Milestone:** Two deployed parties can carry and settle independent rewards, while exactly one explicit battle context safely owns a live battle.

## Files

- Modify: `scripts/autoload/game_session.gd`, `scripts/autoload/game_manager.gd`, `scripts/save/campaign_snapshot.gd`.
- Modify: `scripts/battle/battle_controller.gd`, `scripts/battle/battlefield.gd`, `scripts/ui/battle_result.gd`, `scripts/ui/party_details.gd`, `scripts/ui/information_panel.gd`, `scripts/ui/stores.gd`, `scripts/ui/victory_screen.gd`, and any scene/script that reads `pending_*` or `battle_*`.
- Modify: `scripts/tools/campaign_sim.gd` and only the scenario fixtures needed to pass explicit party/battle ids.
- Test: `tests/unit/test_game_session.gd`, `tests/unit/test_campaign_snapshot.gd`, `tests/unit/test_party_details.gd`, `tests/unit/test_battle_result.gd`, `tests/unit/test_campaign_recovery.gd`, `tests/unit/test_game_manager.gd`, and a new focused two-party journey test.

## Red/green tasks

1. Add failing unit tests that create two deployed parties, give each distinct carried gear/crystals/gold, then prove one party's deposit, retreat, wipe, and equip action cannot alter the other's carry.
2. Run each focused GUT test with `-gselect` and record the red failure caused by the current global `pending_reward`, `pending_gear`, and `pending_mana_crystals` state.
3. Add `carry` to each party record and a single `battle_context` durable record. Replace no-argument reward APIs with explicit owner-party/battle-context APIs. Keep campaign bank fields (`gold`, banked gear/crystals) campaign-owned.
4. Migrate encounter enter/complete/abandon, retreat, battle result routing, party recovery, and victory settlement through `BattleContext.owner_party_id`. Reject a second claim before mutation; selection changes must not alter the current battle's owner.
5. Update snapshot export/import for the new fresh format. Intentionally reject earlier versions with a clear unsupported-format error, but prove malformed fresh-format carry/context data rejects before any live state assignment.
6. Update UI callers to render the requested party's carry and the current battle context snapshot, never a global bucket. Add real-scene tests for selecting either party and returning from a battle result.
7. Thread explicit ownership through CampaignSim, preserving per-iteration seeded randomness. Add a deterministic two-party fixture: party A resolves/banks loot while party B retains its own carry unchanged.
8. Run focused tests green, then the common final checks.

## Manual check

In `make play`, send two parties to separate encounters. Resolve one, inspect its carried loot and the other party's unchanged inventory, return only one party to the Encampment, then resolve/return the other. Verify retreat/wipe never transfers either party's carry to the other.

## Commit and local merge

After review and user signoff, commit only the ownership refactor and its tests as `refactor(campaign): make carried rewards party-owned`, merge locally to `main`, and delete the branch.

