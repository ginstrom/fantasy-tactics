# Step 5 — Meaningful Specializations

**Branch:** `feat/stage-5-specializations`

**Depends on:** Step 4 merged; approved promotion eligibility/order and one decision/counter/encounter row for every branch proposed in this step

**Milestone:** Each shipped specialization changes a party-building or combat decision, carries a readable counter, and remains save-safe/deterministic; the Rogue remains deferred until its own row is approved.

## Files

- Modify: `scripts/autoload/game_session.gd`, `scripts/autoload/game_manager.gd`, `scripts/tools/battle_scenarios/battle_state_factory.gd`, `scripts/battle/unit.gd`, `scripts/battle/battle_controller.gd`, and `config/game_config.json`/`scripts/autoload/game_config.gd` only for an approved branch.
- Modify: `scripts/ui/level_up.gd`, `scenes/ui/level_up.tscn`, `scripts/ui/unit_details.gd`, `scenes/ui/unit_details.tscn`, `scripts/ui/recruitment.gd`, `scenes/ui/recruitment.tscn`, `scenes/battle/battlefield.tscn`, and `translations/en.tres` according to the accepted promotion flow.
- Modify/Create: `tests/unit/test_game_session.gd`, `tests/unit/test_level_up.gd`, `tests/unit/test_unit_details.gd`, `tests/unit/test_battle_controller.gd`, `tests/unit/test_battle_state_factory.gd`, focused ScenarioContract fixtures, and one Stage 5 branch journey test per shipped specialization.

## Red/green tasks

1. For the next approved branch only (Knight, Archer, Battle Mage, Paladin, then optionally Rogue), write a failing decision-contract test that proves its capability is unavailable before promotion, becomes available after legal promotion, persists through a snapshot round trip, and changes a real outcome rather than only a displayed stat.
2. Run the focused test red. Do not start a second branch while the first has an unresolved balance/manual finding.
3. Add the smallest class-data/progression and UI selection change owned by `GameSession`. Preserve existing root class ids and migration compatibility; do not make a scene decide eligibility or directly edit an adventurer dictionary.
4. Add the branch's approved ability/interaction only if its prerequisite primitive exists. Examples: Archer requires the ranged/visibility seam; Battle Mage requires the Mage spell path; Paladin requires the approved holy-melee/boon behavior; Rogue requires accepted luck-critical/loot counterplay and weaker scouting.
5. Create an encounter/monster counter and two fixed-seed scenarios: one where the branch is a sensible choice and one where its counter makes another choice preferable. Add UI/log feedback that explains the branch result.
6. Re-run the branch's focused tests and common final checks. Record the balance result and manual observation in the ledger, obtain user signoff, merge, and only then repeat Tasks 1–6 for the next approved branch.

## Manual check

In `make play`, promote one eligible root character, compare it with the unpromoted/root alternative, use its defining choice in its authored/repeatable encounter, observe its counter, save/load, and verify the decision remains clear. Repeat only for branches the user has approved.

## Commit and local merge

Use one commit and local merge per approved branch, for example `feat(classes): add Knight specialization`. Never bundle speculative branches; delete `feat/stage-5-specializations` only after its last user-approved branch is merged.
