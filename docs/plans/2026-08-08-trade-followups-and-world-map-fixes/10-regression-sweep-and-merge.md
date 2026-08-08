# Task 10: Regression sweep, manual verification, and merge

## Objective

Confirm the whole plan holds together, get the user's manual sign-off on
Phase B's changes, confirm Phase A's status with them, and merge back to
`main`.

## Files

- None expected to change; this task is verification-only unless the
  sweep in step 2 turns up a straggler.

## Depends on

Tasks 03-09, all committed on `fix/trade-followups-and-world-map`. Phase A
(Tasks 01-02) should also be committed, though — per this plan's own
Phase A note — it may conclude in "diagnostics added, evidence pending"
rather than a landed fix; confirm which with the user before merging (see
step 6).

## Steps

### Full regression sweep

1. Confirm every task's commit landed and the branch is clean:

   ```bash
   git log --oneline main..HEAD
   git status
   ```

   Expected: one commit per task actually completed (up to 9: Tasks
   01-02, 03-09), no uncommitted changes.

2. Run the full suite:

   ```bash
   make test
   ```

   Expected: `---- All tests passed! ----`, exit code 0.

3. Grep for anything the individual tasks may have missed — every
   reference to the removed `set_adventurer_weapon`/`set_adventurer_armor`
   methods, and every remaining use of the old shared weapon translation
   keys:

   ```bash
   grep -rn "set_adventurer_weapon\|set_adventurer_armor" scripts tests
   grep -n "\"item\.dagger\":\|\"item\.shortsword\":\|\"item\.longsword\":\|\"item\.two_handed_sword\":" translations/en.tres
   ```

   Expected: no matches for either. If a real straggler turns up, fix it
   and rerun `make test`.

4. Confirm the project still opens cleanly in the editor:

   ```bash
   godot --headless --path . --editor --quit
   ```

5. Run `git diff --check main` to catch stray whitespace/conflict markers
   before manual verification.

6. Regenerate the screenshot tour and skim `screenshots/unit_details.png`
   (should now show the equipment row) and the Stores frame (should now
   show Sell enabled):

   ```bash
   make screenshots
   ```

### Manual verification

7. Run `make play`. Walk through Phase B's changes by hand:
   - Trading Post: confirm every weapon's name distinguishes Iron from
     Steel (e.g. "Iron Dagger" vs. "Steel Dagger"), not just its price.
   - Stores: same check for any banked weapon.
   - Roster (or wherever a party member's Unit Details is reachable):
     confirm the equipment row shows the equipped weapon's name/range and
     armor's name/defense/resistance, and that it updates after using
     Assign Equipment to change gear.
8. Report the manual pass (or any deviation) to the user and wait for
   explicit sign-off on Phase B before merging.
9. Separately, confirm Phase A's status with the user: if they reproduced
   one of the three World Map symptoms using Task 02's diagnostic logging
   and shared the evidence, a concrete fix task should be added to this
   plan (or a follow-up) and landed before merging that part. If no new
   evidence has arrived, confirm with the user whether they're comfortable
   merging Phase A as "diagnostics landed, root cause still open" (the
   symptoms are pre-existing on `main`, not a regression this branch
   introduces, so merging without a fix doesn't make anything worse) or
   would rather hold the whole branch until evidence arrives.

### Merge

10. Once approved:

    ```bash
    git checkout main
    git pull
    git merge fix/trade-followups-and-world-map
    git branch -d fix/trade-followups-and-world-map
    ```

    Do not push to `origin` or open a PR unless the user asks.

## Milestone

The full test suite is green end to end, the editor opens the project
without errors, the user has manually confirmed Phase B's UX changes work
as designed, Phase A's status (fixed or explicitly deferred) is confirmed
with the user, and the branch is merged into `main`.
