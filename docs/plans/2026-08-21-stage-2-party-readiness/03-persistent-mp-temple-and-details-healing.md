# Step 3 — Persistent MP, Temple Recovery, and Details Healing

**Branch:** `feat/stage-2-cleric-recovery`
**Depends on:** Step 2 merged
**Milestone:** Cleric MP survives save/load and battles, recovery uses the approved capped rates, and Unit Details can execute only a legal, atomic **Heal party member** request.

## Files

- Modify: `scripts/autoload/game_session.gd`
- Modify: `scripts/save/campaign_snapshot.gd`
- Modify: `scripts/battle/battle_controller.gd`
- Modify: `scripts/battle/battlefield.gd`
- Modify: `scripts/tools/battle_scenarios/scenario_contract.gd`
- Modify: `scripts/tools/battle_scenarios/battle_state_factory.gd`
- Modify: `scripts/ui/unit_details.gd`
- Modify: `scenes/ui/unit_details.tscn`
- Modify: `translations/en.tres`
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/unit/test_campaign_snapshot.gd`
- Modify: `tests/unit/test_battle_controller.gd`
- Modify: `tests/unit/test_battlefield.gd`
- Modify: `tests/unit/test_battle_state_factory.gd`
- Modify: `tests/unit/test_unit_details.gd`
- Modify: `tests/unit/test_localization.gd`

## Design

Add class-owned `mp`/`max_mp` only to spell-capable adventurers, with accessors that return zero/no-op for other classes. `GameSession` owns `recover_adventurers_on_world_turn()` behavior and a validated `heal_party_member(caster_id, target_id)` transaction. Battle start reads durable MP, and battle aftermath writes each surviving caster’s remaining MP before ordinary HP/death handling; the scenario contract uses explicit optional MP fields so deterministic scenarios never rely on ambient session state.

## Red/green tasks

1. Add failing `test_game_session.gd` cases for default Cleric MP, no MP fields on Warrior/Scout, each approved moving/resting/Encampment rate, Temple HP bonus, independent HP/MP caps, and no recovery for a dead/unknown record.
2. Add failing transaction tests for legal encamped and deployed targets, insufficient MP, full-health target, cross-party target, dead target, unknown ids, and atomic failure. Inject the approved heal amount only if Step 1 selected a random range; otherwise assert the fixed value.
3. Run `test_game_session.gd`; implement only durable fields, recovery, and the transaction until green.
4. Add failing snapshot tests proving current/max MP survives export/import and invalid MP shapes/ranges reject without mutating the existing session. Implement the versioned normalizer/default migration.
5. Add failing battle/controller/factory tests: an explicit scenario MP value hydrates a Cleric, a spell reduces it once, an aftermath preserves it, and seeded spell healing remains reproducible. Keep battle units and scenarios on the same public rules.
6. Add failing Unit Details scene tests that instantiate the real scene, render current/max MP for a Cleric, list only legal targets, invoke the transaction through the button signal, refresh both rows, and show a localized reason for failure. Implement the UI as an intent surface; it must never assign health or MP itself.
7. Run focused suites, then `make check`, editor scan, and `git diff --check`.

## Manual signoff and merge

In `make play`, build a Temple, recruit a Cleric, form a mixed party, damage a member, and use **Heal party member** both at the Encampment and while deployed. Advance turns in each state and verify the approved HP/MP recovery, Temple bonus, caps, and save/load persistence. After user signoff, commit `feat(cleric): persist mp and add campaign healing`, merge locally, and delete the branch.
