# Agent Workflow Notes

## Branching, not worktrees

This is a one-person learning project. Do development on a regular
**branch off `main`** in the existing working copy — do not create a git
worktree for it.

Worktrees exist to let multiple agents or a human and an agent work on
separate checkouts at once without interfering with each other. That
concern doesn't apply here: there is one person and one active line of
work at a time, so a second checkout is just overhead (extra directories
to track, extra cleanup steps, extra chances for a stray uncommitted diff
to get stuck in the wrong place) with no corresponding benefit.

Workflow for each task:

1. `git checkout main && git pull`
2. `git checkout -b <branch-name>`
3. Implement with TDD (write failing tests, confirm failure, implement,
   verify with `make check`).
4. Get manual verification from the user via `make play` when the plan
   calls for it.
5. Commit.
6. Merge back to `main` locally (`git checkout main && git merge
   <branch-name>`), then delete the branch. Only push to `origin` or open
   a PR if asked.

If a skill's default instructions call for setting up an isolated
worktree, use a plain branch in place of that step instead.
