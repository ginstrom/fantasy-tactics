# Agent Workflow Notes

## Branching, not worktrees

This is a one-person learning project. Do development on a regular
**branch off `main`** in the existing working copy — do not create a git
worktree for it.

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

## Writing implementation plans

* Put the plan in its own dirctory under @docs/plans
* Create an index.md which describes the overall plan and coordinates the steps
* Put each step in its own file
* Each step should be self contained, including setup, verification, and merging feature branch back to main (after user signoff)
* Use red/green TDD
* Give a concrete verifiable milestone for each step
* Include instructions for manual verification (this could be screen shots or data output as appropriate)