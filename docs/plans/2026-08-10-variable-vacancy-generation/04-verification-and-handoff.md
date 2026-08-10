# Step 4: Verify and Hand Off for Local Merge

## Milestone

Automated behavior, editor loading, documentation integrity, and player-facing
behavior confirm the change before local merge.

## Setup

Work from the feature branch with Steps 1–3 committed. Confirm `git status
--short` contains only intended work. Read `docs/dev/running-the-game.md`.

## Automated Verification

Run `godot --version`, `make check`, `godot --headless --path . --editor
--quit`, `git diff --check`, and `git status --short`.

Expected: Godot is 4.7.1; tests end in `All tests passed`; editor scan and
whitespace check exit 0; only planned work is present.

## Manual Verification for User Signoff

Run `make play`. In a debug build, use F9 scenarios or normal play to:

1. Clear an active encounter and record the World Map turn on which one
   replacement appears (10–20 turns). Confirm it does not occupy the cleared
   site tile and may use a different weighted star tier.
2. Purchase a recruit, then record the replacement offer's return turn
   (25–35 turns).
3. Reach level 2 through normal/debug play and confirm Warrior max HP is 20
   (vitality 10 × level 2).
4. Confirm a full cap adds nothing and unresolved battle state still blocks
   End Turn.

Record the observed turns and scenario in the implementation handoff. Ask the
user for explicit manual-verification signoff.

## Commit and Local Merge After Signoff

Commit any final verification documentation separately. Only after approval,
run `git checkout main`, merge `feature/variable-vacancy-generation`, and
delete that feature branch. Do not push or create a PR unless asked.

## Completion Check

Local `main` has jittered timing, unchanged generation safeguards, accurate
durable documentation, passing automation, and user-verified gameplay.
