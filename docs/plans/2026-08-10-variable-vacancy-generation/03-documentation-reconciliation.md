# Step 3: Reconcile the Durable Campaign Design

## Milestone

The durable design and relevant source comments state the approved health,
variable-population, encounter-generation, and scope contracts without dead
plan links.

## Setup

Work after Step 2 is green. Read `game-design.md`; do not restore deleted dated
plans because `docs/dev/README.md` declares the durable document authoritative.

## Files

- Modify: `docs/plans/first-playable-campaign/game-design.md`
- Modify: `scripts/autoload/game_session.gd` (stale comments only, if needed)

## Changes

Replace `+1 maximum-health point` with `maximum HP = Vitality × level`; state
that Warrior vitality 10 yields 10 HP at level 1 and 20 at level 2. Specify a
single uniform resolved delay at vacancy creation: encounters 15 ±5 (10–20)
and recruits 30 ±5 (25–35). Remove the contradictory deterministic-timing
claim while retaining deterministic cap behavior after a roll.

Describe actual encounter generation: power-weighted inactive templates,
unique instance ids, and in-bounds unoccupied positions that do not visually
reopen a cleared site. Remove the unsupported recruit-dismiss sentence. Replace
links to deleted dated plan directories with durable prose or `GameSession`
references; keep only resolving links.

## Verification

Search the durable document for the stale health phrase, deterministic-timing
phrase, recruit-dismiss sentence, and deleted plan paths. They must have no
matches. Run `git diff --check` and `make check`; both must pass.

## Commit

Stage only modified design/comment files; commit as `docs: reconcile campaign
population design`.

## Completion Check

The durable document alone accurately describes health, timing, generation, and
supported recruitment scope.

## User Signoff and Merge

Do not merge before Step 4's user-approved manual check. Merge locally only;
do not push or open a PR unless asked.
