# Step 4: Recruitment Loop and Roster Link

> **Branch:** `feat/recruitment-loop-and-roster-link` (off updated local `main`)

## Setup

```bash
git checkout main && git pull
git checkout -b feat/recruitment-loop-and-roster-link
```

## Goal

Keep both ordinary and Party Details-targeted recruitment on Recruitment after a
successful purchase, refresh the candidate list, and provide an explicit Roster
link without losing target semantics.

## Files

- Modify: `scripts/ui/recruitment.gd`, `scenes/ui/recruitment.tscn`, `scripts/autoload/game_manager.gd`
- Test: `tests/unit/test_recruitment.gd`, `tests/unit/test_game_manager.gd`

## Contract and TDD

1. Write failing tests for ordinary recruitment: success remains on this scene,
   clears local selection, updates rows, and View Roster routes to Roster.
2. Write failing tests for targeted recruitment: it invokes the atomic
   party-target operation from Step 3, refreshes in place, and retains the
   target for a further purchase only while that party remains encamped and has
   capacity. A stale/full/deployed target clears to ordinary Recruitment with
   no purchase.
3. Place `ViewRosterButton` after the table/empty state and before Back in the
   `VBoxContainer`, wire its handler, and preserve the target context when
   staying in Recruitment. Decide and test that View Roster intentionally
   clears route-only target context.
4. Run focused GUT red/green tests, editor refresh, `make check`, and `git
   diff --check`. In `make play`, recruit once via Units and once via Party
   Details; confirm the former reaches Roster only via the link and the latter
   immediately appears in that party. Obtain signoff, merge locally, delete
   branch.
