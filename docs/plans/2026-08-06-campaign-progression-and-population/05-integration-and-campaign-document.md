# Task 5: Integration, manual campaign check, and design record

## Objective

Verify the complete progression/population loop, update the enduring design
record, and integrate only after user signoff.

## Files

- Modify: `docs/plans/first-playable-campaign/game-design.md`
- Modify: `tests/unit/test_localization.gd` (only if new copy needs coverage)
- Generated and reviewed: `screenshots/` (do not commit generated output)

## Steps

1. Reconcile `game-design.md` with shipped reward/recruitment behavior and
   record the approved progression and active-population rules. Preserve any
   unrelated uncommitted edits in that file; review the diff before staging.
2. Run the complete automated suite and static scan:

   ```bash
   make check
   godot --headless --path . --editor --quit
   git diff --check
   ```

   Expected: all GUT tests pass, intended `.uid` files exist, and whitespace
   checks are clean.
3. Capture optional regression states:

   ```bash
   make screenshots
   ```

   Inspect the progression, recruitment, and world-map states; do not add the
   generated screenshots unless the user explicitly requests them.
4. Ask the user to run `make play` and verify this route without debug-only
   controls: create/deploy a party, clear Goblin Camp, resolve any level-up,
   return to Encampment for gold, spend Attack points, advance 15 World Map
   turns after an encounter vacancy, observe exactly one new site, purchase a
   recruit, and observe its 30-turn refill behavior. Also verify Escape →
   World Map remains safe during a battle.
5. After explicit user signoff, commit the design record while excluding
   unrelated edits:

   ```bash
   git add docs/plans/first-playable-campaign/game-design.md
   git commit -m "docs: record campaign progression and population loop"
   ```

6. Merge locally only after signoff:

   ```bash
   git checkout main
   git merge <feature-branch>
   git branch -d <feature-branch>
   ```

   Do not push to `origin` or open a PR unless the user asks.

## Milestone

The documented first campaign accurately matches a manually verified,
repeatable progression and bounded-population loop.
