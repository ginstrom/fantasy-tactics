# Step 5 — Shared Tactical Profile Migration

**Branch:** `feat/stage-2-shared-tactical-profile`
**Depends on:** Step 4 merged
**Milestone:** Starter adventurers and initial monster templates use the same explicit tactical-profile vocabulary, while before/after deterministic combat outputs remain unchanged until Step 6 intentionally tunes them.

## Files

- Modify: `scripts/autoload/game_session.gd`
- Modify: `scripts/battle/unit.gd`
- Modify: `scripts/battle/battle_controller.gd`
- Modify: `scripts/tools/battle_scenarios/scenario_contract.gd`
- Modify: `scripts/tools/battle_scenarios/battle_state_factory.gd`
- Modify: `scripts/ui/unit_details.gd`
- Modify: `scripts/battle/unit_info_panel.gd`
- Modify: `translations/en.tres`
- Modify: `tests/unit/test_game_session.gd`
- Modify: `tests/unit/test_battle_controller.gd`
- Modify: `tests/unit/test_battle_state_factory.gd`
- Modify: `tests/unit/test_scenario_contract.gd`
- Modify: `tests/unit/test_unit_details.gd`
- Modify: `tests/unit/test_unit_info_panel.gd`
- Modify: `tests/unit/test_localization.gd`

## Design

Represent the profile fields from `class-system.md` explicitly—HP, might, melee, missile, guard, spellcasting, magic resistance, resistance, and action points—on immutable authored templates and copied battle units. Keep weapon/natural attack damage and range as attack properties. Define a single adapter in the factory/controller path so legacy enemy `hit_chance`/`attack_damage` data is normalized once, then remove duplicate formula derivation only after parity tests exist.

## Red/green tasks

1. Capture deterministic baseline fixtures for level-1 starter Warrior/Scout/Cleric and each original Goblin/Orc/Kobold/Hobgoblin: profile values, attack legality, hit chance, raw/post-resistance damage, AP, and outcome under fixed rolls.
2. Add failing `ScenarioContract` validation tests rejecting malformed profile fields and accepting explicit profile fixtures. Add factory/controller tests proving the same profile hydrates in scene-free and live battle routes.
3. Implement the profile fields and one normalization/hydration boundary. Preserve current numeric outputs exactly; a changed expected output is a defect unless Step 6 carries an approved balance change.
4. Add UI tests that panels show the meaningful effective values without incorrectly calling defense “damage resistance” or exposing missing spell values as real stats. Localize new labels.
5. Re-run baseline fixtures, focused suites, `make check`, editor scan, and `git diff --check`.

## Manual signoff and merge

Run `make play` with starter gear and inspect a Warrior, Scout, Cleric, and original enemy. Confirm displayed AP, weapon/armour, wound, resistance/guard, and class resources agree with battle outcomes. After user signoff, commit `feat(combat): migrate shared tactical profiles`, merge locally, and delete the branch.
