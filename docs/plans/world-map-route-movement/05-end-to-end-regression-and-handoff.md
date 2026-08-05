# Step 05: End-to-End Regression and Handoff

## Milestone

The new travel UX and battle terminology are validated together, including the full settlement-to-goblin-camp route.

## Setup

Branch: `chore/verify-world-route-movement` from current `main`; requires steps 01-04 merged.

## Files

- Modify only if verification finds a defect: the smallest relevant source and regression-test file from steps 01-04.

## Verification

1. Run `make check` and `git diff --check`; both must pass.
2. Run `make play`, deploy the Warrior, and verify:

   1. Selecting the party still shows one-turn legal moves.
   2. Hovering to camp shows stable horizontal-then-vertical route and 8 turns.
   3. Destination click commits without movement.
   4. A second click on the committed camp target manually moves one tile; clicking the party does not. End Turn increments without an extra move.
   5. Seven more End Turns advance exactly one tile each, reduce the estimate, and clear route on arrival.
   6. Camp entry still uses selection then second click; battle displays Round text while retaining End Turn.
   7. Returning/resolving without a route does not cause stale automatic movement; settlement return still works.

3. If a defect appears, write the smallest failing GUT regression test first, demonstrate red with `make test`, fix it, then restart this verification. Do not expand scope to waypoints or animation.

## Commit and merge

If a correction was needed, commit it as `fix: preserve world route turn behavior`. Ask for user signoff after manual verification, merge the branch locally, delete it, and do not push.
