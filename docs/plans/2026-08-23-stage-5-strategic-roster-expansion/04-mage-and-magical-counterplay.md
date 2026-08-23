# Step 4 — Mage and Magical Counterplay

**Branch:** `feat/stage-5-mage-counterplay`

**Depends on:** Step 3 merged; approved first-spell, MP cost/range/targeting, resistance behavior, and counter-encounter rows

**Milestone:** A recruitable Mage makes one MP-backed offensive/control choice that is useful, readable, and countered by a real enemy/encounter.

## Files

- Modify: `scripts/autoload/game_session.gd`, `scripts/autoload/game_manager.gd`, `scripts/tools/battle_scenarios/battle_state_factory.gd`, `scripts/battle/unit.gd`, `scripts/battle/battle_controller.gd`, `scripts/battle/battlefield.gd`, and `config/game_config.json`/`scripts/autoload/game_config.gd`.
- Modify: `scripts/ui/recruitment.gd`, `scenes/ui/recruitment.tscn`, `scripts/ui/unit_details.gd`, `scenes/ui/unit_details.tscn`, `scenes/battle/battlefield.tscn`, `scripts/battle/unit_info_panel.gd`, and `translations/en.tres` as required by the approved UI path.
- Modify/Create: `tests/unit/test_game_session.gd`, `tests/unit/test_battle_controller.gd`, `tests/unit/test_battle_state_factory.gd`, `tests/unit/test_recruitment.gd`, `tests/unit/test_unit_details.gd`, `tests/unit/test_battlefield.gd`, and a deterministic Mage scenario/Stage 5 journey test.

## Red/green tasks

1. Write failing state/factory tests for Mage recruitment, class-owned MP, spell data hydration, save/load validation, and an exact fixed-seed spell result. Prove a non-Mage cannot obtain a Mage action merely by carrying MP-shaped data.
2. Run focused tests and record red failures.
3. Add only the approved Mage class/recruitment and durable resource fields through `GameSession`; add config keys/default parity tests for tunable values. Keep spell definitions/data separate from scene controls.
4. Write failing controller tests for target/range/visibility validation, AP+MP spending only after a legal cast, magic-resistance resolution, and clear counter result metadata. Implement the smallest action path using the established button-driven action-mode/UI conventions.
5. Add the approved resistant/control-counter monster or encounter composition through immutable content/factory data. It must demonstrate why the spell is not the universally dominant action; do not add a broad spell tree.
6. Add a seeded scenario proving the Mage's intended success case and the counter case, plus a regression that a same-seed factory build has identical spell/resource outcomes.
7. Run focused tests and the common final checks.

## Manual check

In `make play`, recruit a Mage, read its AP/MP and spell cost before casting, cast in the approved encounter, observe the counter outcome, finish the encounter, and verify recovery/save/load preserves MP without granting a spell to another class.

## Commit and local merge

After signoff, commit only Mage state/config/content/UI/scenarios/tests as `feat(classes): add Mage counterplay slice`, merge locally to `main`, and delete `feat/stage-5-mage-counterplay`.
