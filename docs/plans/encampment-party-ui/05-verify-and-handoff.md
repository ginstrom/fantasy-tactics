# Step 05: Verify, document, and locally merge

## Milestone

The complete UI slice is automated-checked, manually verified by the user,
documented as a deliberate first slice, and merged locally without altering
the untracked screen-reference file.

## Setup

1. Start from merged `main` after Step 04 and create
   `docs/encampment-party-ui-handoff` only if follow-up documentation changes
   are needed; otherwise perform verification on the Step 04 branch before its
   approved merge.
2. Confirm `git status --short`. `docs/party-screens.txt` is user-owned and
   must remain untracked unless explicit permission to add it is received.

## Files

- Modify only if stale: `README.md`
- Modify only if acceptance language needs clarification:
  `docs/plans/first-playable-campaign/game-design.md`
- Test/inspect: all modified scene, script, translation, and GUT test files

## Verification

Run and record the exit status for:

```bash
make check
godot --headless --path . --editor --quit
git diff --check
git status --short
```

Expected: automated tests pass, editor scan has no parse errors, diff has no
whitespace errors, and only intended tracked changes plus the pre-existing
untracked `docs/party-screens.txt` remain.

## User manual verification

Ask the user to run `make play` and verify:

```text
New Game -> Starting Settlement -> Encampment
-> Units -> Parties -> Party 1 -> select Warrior -> View
-> Back -> Encampment -> Deploy Party -> Party 1 -> World Map
```

They should also confirm player name/gold remain visible on every slice scene,
View never deploys a party, and an empty/all-unavailable party is not shown by
Deploy Party.

## Commit and merge after approval

After the user explicitly approves manual verification:

```bash
git add README.md docs/plans/first-playable-campaign/game-design.md
git commit -m "docs: record encampment UI slice"
git checkout main
git merge --ff-only <verified-feature-branch>
git branch -d <verified-feature-branch>
```

If final documentation commits are on a separate branch, merge them after the
feature branch. Do not push to `origin`, create a PR, add the untracked
reference file, or delete unrelated user changes.
