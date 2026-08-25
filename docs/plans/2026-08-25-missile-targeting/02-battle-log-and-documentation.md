# Step 2: Battle-log feedback and documentation

**Depends on:** Step 1.

**Files:**

- Modify: `tests/unit/test_battlefield.gd`
- Modify: `scripts/battle/battlefield.gd`
- Modify: `docs/designs/battle-screen.md`

## Red

Add a Battlefield test proving a rejected missile target click appends the targeting-failure text to the bottom log and does not duplicate the same failure during a single board update.

Run the selected UI test and confirm it fails because failures currently update only the status line.

## Green

Use the existing localized targeting-failure description for both the status message and a deduplicated battle-log line. Update the durable battle-screen rule to describe stationary missile attacks and the retained melee auto-move behavior.

## Verification

Run the focused Battlefield test, `make check`, `godot --headless --path . --editor --quit`, and `git diff --check`. Then run `make play` and verify: (1) a bow fires through a unit, (2) a distant bow click neither moves nor spends AP and writes the log, and (3) a melee unit still moves then attacks when it can afford both.

After user signoff, commit the scoped files, merge `fix/missile-attack-targeting` locally into `main`, and delete the feature branch. Do not push or open a PR.
