# Agent Workflow Notes

Before touching code, see [docs/dev/README.md](docs/dev/README.md) for how
to run the game, run the test suite, and a map of the codebase.

# Developer docs

Check @docs/dev/ for developer documentation.

## Branching, not worktrees

This is a one-person learning project. Do development on a regular
**branch off `main`** in the existing working copy — do not create a git
worktree for it.

Workflow for each task:

1. `git checkout main && git pull`
2. `git checkout -b <branch-name>`
3. Implement with TDD (write failing tests, confirm failure, implement,
   verify with `make check`).
4. Get manual verification via `make play` when the plan calls for it. If the
   user explicitly requests it, a coding agent may perform and report that
   check instead of the human.
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

## Implementing folderized plans with delegated review

For a plan such as `docs/plans/2026-08-22-stage-3-campaign-assembly`, use one
supervising agent to coordinate a **single serial step** at a time. This keeps
the supervisor's context small and makes each handoff independently auditable.

1. The supervisor reads the plan `index.md`, identifies the next unblocked step,
   checks the active checkout and `git status`, and passes the implementation
   agent only that step file, its source-contract links, the current branch/base
   commit, and any relevant review findings from the preceding step. Do not ask
   an implementation agent to absorb the whole plan unless the step explicitly
   requires it.
2. The implementation agent reads `docs/dev/README.md` and the assigned step,
   works only on that step's branch, follows its red/green TDD instructions, and
   reports: changed files, the failing and passing test evidence, all required
   verification output, remaining risks, and the exact manual-check request.
   It must not merge, delete the branch, push, or broaden scope.
3. Before manual verification or merge, hand the step to a different review
   agent. Give it the step file, source-contract links, base/branch commits,
   implementation report, and `git diff <base>...HEAD`. The reviewer checks the
   diff against the step's acceptance criteria, ownership boundaries, TDD and
   verification evidence, regressions, and unrelated changes. It reports
   findings ordered by severity with file/line evidence, plus a clear
   `approve`, `approve with follow-ups`, or `changes requested` recommendation.
   Review is read-only: it does not fix code or merge.
4. The supervisor is the only agent that reconciles the review. It sends
   focused fixes back to the implementation agent (or a fresh repair agent),
   requests re-review for material changes, and presents the documented manual
   check to the user only after the review is acceptable. User signoff—not an
   agent review—authorizes the plan's local commit and merge.
5. After signoff, the supervisor confirms the step's commit contains only its
   documented files, merges it locally to `main`, deletes the step branch, and
   records a compact handoff summary for the next step: merged commit, verified
   behavior, outstanding follow-ups, and any user-approved decisions. Start the
   next step only after this handoff and its declared dependency are satisfied.

Keep handoffs compact and factual: link to the single plan step and relevant
files instead of pasting broad repository context. Preserve pre-existing local
changes, and keep plan steps serial when their index declares dependencies.
