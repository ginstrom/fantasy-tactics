# Step 01 — Reaction-step status safety

**Objective:** Prevent an enemy-turn opportunity-attack reaction dictionary
from reaching the movement fallback in `Battlefield._describe_step()`.

**Dependency:** None. **Branch:** `fix/reaction-step-status` from `main`.

## Files

- Modify: `scripts/battle/battlefield.gd:672-734`
- Modify: `tests/unit/test_battlefield.gd` beside the existing
  `_describe_step()` cases around line 117
- Possibly modify: `translations/en.tres` only if an existing translation key
  cannot accurately describe a reaction; prefer a present combat-status key.

## Red/green TDD

1. Add a scene-level test that instantiates `BattlefieldScene`, uses the same
   deterministic controller fixture as the existing opportunity-attack tests,
   drives `run_enemy_turn()` until its returned steps contain a
   `{type: "reaction", reactor, mover, damage}` entry, and passes that exact
   entry to `_describe_step()`. Assert no error and text naming the reactor or
   its side and the moved unit as appropriate. Do not manufacture a fake
   `unit` field: the regression must retain the real step shape.
2. Run:
   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_battlefield.gd -gexit
   ```
   Expected red result: the new test reports the invalid Nil `side` access.
3. Add one explicit `step.type == "reaction"` branch before the movement
   fallback. It must read only keys guaranteed by the reaction contract and
   must not mutate battle state or re-run combat rules.
4. Re-run the focused command green, then `make check`,
   `godot --headless --path . --editor --quit`, and `git diff --check`.

## Review, manual confirmation, merge

Reviewer checks that reaction presentation is not confused with a normal
attack, the fallback remains valid for movement, and the regression executes
the real enemy-turn producer. Manual check: run `make play`, enter a debug
battle with an opportunity attack, and confirm the status line advances
through the reaction without a debugger error or freeze. After user signoff,
commit only the listed production/test/translation files as
`fix(battle): describe enemy-turn reaction steps`, merge locally, delete the
branch, and record evidence.
