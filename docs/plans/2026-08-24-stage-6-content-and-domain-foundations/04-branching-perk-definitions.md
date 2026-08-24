# Step 4 — Branching Perk Definitions

**Branch:** `refactor/branching-perks`

**Depends on:** Step 3 locally merged; G3 approved; G1 approved if Rogue is included.

**Milestone:** A real class can present a prerequisite-gated branch and resolve its approved typed effect through shared rules, with no flat-list assumption or new per-perk controller mode.

## Files

- Create: `scripts/progression/perk_catalog.gd` and `scripts/battle/perk_effect_resolver.gd` if the approved boundary cannot live as a small pure module under existing files.
- Modify: `scripts/autoload/game_session.gd`, `scripts/battle/unit.gd`, `scripts/battle/battle_controller.gd`, `scripts/tools/battle_scenarios/scenario_contract.gd`, `scripts/tools/battle_scenarios/battle_state_factory.gd`, `scripts/ui/level_up.gd`, `scripts/ui/unit_details.gd`, `scenes/ui/level_up.tscn`, `scenes/ui/unit_details.tscn`, and `translations/en.tres`.
- Modify: `scripts/save/campaign_snapshot.gd` only for the current fresh-format perk record.
- Test: `tests/unit/test_game_session.gd`, `test_level_up.gd`, `test_unit_details.gd`, `test_battle_controller.gd`, `test_battle_state_factory.gd`, `test_scenario_contract.gd`, plus a new `test_perk_catalog.gd` and fixed-seed scenario fixture.

## Red/green tasks

1. Write failing pure-catalog tests for: unavailable child before parent; legal child after parent; mutually exclusive sibling rejection; duplicate/rank rejection; unknown effect/action rejection; and deterministic serialization of the chosen nodes.
2. Run only those tests red. Do not change existing perk behavior before the test proves the flat catalog cannot represent the approved branch.
3. Define `PerkDefinition` with stable id, owner eligibility, prerequisite ids, excludes, rank/cost policy, name/effect translation keys, and one bounded effect/action descriptor. Initial descriptors must cover only already-shipped behavior needed by the approved first branch (for example stat modifier, granted spell, or parameterized attack modifier); new descriptors need a separate decision row.
4. Replace `CLASS_PERKS`/`SPECIALIZATION_PERKS` array selection and global `PERK_TREE_SIZE` cap with catalog queries for earned slots and eligible nodes. Preserve every existing shipped perk id and result through regression tests; UI receives an ordered eligible node list, never evaluates prerequisites itself.
5. Route active effect/action execution through `PerkEffectResolver` and a generic capability/action query. Remove the first approved bespoke `ActionMode`/boolean feature-flag path only when shared resolver tests prove identical AP, targeting, status, and log behavior.
6. Add one approved branching choice to a real class. If Rogue is approved, implement only its approved decision/counter/encounter contract; otherwise use the approved non-Rogue branch and leave Rogue explicitly deferred.
7. Add snapshot current-format validation, a fixed-seed `ScenarioContract` fixture for each descriptor used, and an end-to-end UI test showing locked, eligible, and excluded nodes accessibly.
8. Run focused tests green and the common final checks.

## Manual check

In `make play`, level an eligible adventurer to the branch point. Confirm the child is locked before its prerequisite, selecting one sibling clearly excludes the other, and the selected node produces its stated combat/strategic result and counter without debug output.

## Commit and local merge

After review and user signoff, commit the perk catalog/resolver, approved branch, UI, snapshots, and tests as `refactor(progression): support branching perk definitions`, merge locally to `main`, and delete the branch.

