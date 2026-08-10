# Step 7 — Verification and Local Merge

## Milestone

The completed approved slice is documented, mechanically verified, manually accepted, and merged locally without disturbing unrelated work.

## Checklist

1. Confirm the active feature branch is clean except for the intended slice: `git status --short` and `git diff --check`.
2. Run `make check` and `godot --headless --path . --editor --quit`.
3. Run the slice's seeded battle simulations and retain only non-sensitive, reproducible scenario/report contracts in Git.
4. Ask the user to perform the slice's `make play` manual route; record the exact role/counterplay check they accepted.
5. Commit the verified slice with a focused conventional message.
6. After approval: `git checkout main`, `git merge <feature-branch>`, and `git branch -d <feature-branch>`. Do not push or open a PR unless asked.
