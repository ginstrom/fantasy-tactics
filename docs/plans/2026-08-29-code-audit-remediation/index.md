# Code Audit Remediation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Resolve the confirmed defects in `docs/code-findings.md`, then harden the identified boundaries only where a policy or measured regression justifies it.

**Architecture:** Keep `GameSession` as the durable-state/rules owner, `GameManager` as navigation owner, and UI nodes as presentation/input owners. Each Phase 1 defect is a separate behavior branch. Phase 2 and Phase 3 have explicit approval gates so they cannot turn into speculative refactors.

**Tech Stack:** Godot 4.7.1, GDScript, GUT 9.7.1, Make targets, JSON campaign snapshots.

---

## Source contracts

- [Code audit findings](../../code-findings.md) is the authoritative problem
  statement and phase ordering.
- [Plan design](design.md) records the approved execution shape and unresolved
  decisions.
- [Developer docs](../../dev/README.md), [testing](../../dev/testing.md), and
  [running the game](../../dev/running-the-game.md) define commands and manual
  routes.
- `AGENTS.md` controls the branch, TDD, independent-review, manual-signoff,
  local-merge, and no-push workflow.

## Universal execution contract

Every implementation step is serial; begin it only after the preceding step
has been locally merged to `main` and its handoff is recorded. Before changing
code, the supervising agent must read this index, the one assigned step, its
linked source contracts, `docs/dev/README.md`, and `git status --short --branch`.

For every code-bearing step:

1. Start from a clean, current `main` with `git fetch origin && git merge
   --ff-only origin/main` when an update is needed. Create the exact regular
   branch named by the step; do not create a worktree. If unrelated local work
   exists, preserve it and stop rather than stashing, resetting, or merging it.
2. Add the named focused GUT regression first, run the stated `-gselect` or
   `-gunit_test_name` command, and retain the expected red failure.
3. Make the minimum ownership-respecting implementation, rerun the focused
   test green, then run `make check`, `godot --headless --path . --editor
   --quit`, and `git diff --check`.
4. Hand a different, read-only reviewer the step file, base/branch commits,
   implementation report, command output, and `git diff <base>...HEAD`. The
   reviewer returns severity-ordered file/line findings and an explicit
   recommendation. Material repairs require re-review.
5. Present the documented manual check to the user when the step calls for
   one. Only user signoff authorizes `git add` of the listed files, a local
   commit, `git checkout main && git merge <branch>`, and branch deletion. Do
   not push or open a PR.
6. Record the merged commit, verified behavior, commands, manual result, and
   outstanding follow-ups in the next step's handoff before continuing.

## Dependency map

```
01 reaction status → 02 modal input → 03 recruitment → 04 MP snapshots
→ 05 playback decision → 06 playback repair → 07 key policy
→ 08 defensive query → 09 route-preview evidence
→ 10 bounded architecture gate
```

Steps remain serial even where arrows do not require it: this protects the
one-person checkout, makes the verification evidence auditable, and respects
the execution policy in `AGENTS.md`.

## Steps and approval gates

| Order | Step | Phase | Gate |
|---:|---|---|---|
| 01 | [Reaction-step status safety](01-reaction-step-status.md) | 1 | Review + battle manual check |
| 02 | [World Map modal input isolation](02-world-map-modal-input.md) | 1 | Review + modal manual check |
| 03 | [Guild Hall recruitment capacity](03-guild-hall-recruitment-capacity.md) | 1 | User confirms immediate-fill policy |
| 04 | [Configurable MP snapshot validation](04-configurable-mp-snapshots.md) | 1 | Persistence regression review |
| 05 | [Enemy playback design decision](05-enemy-playback-decision.md) | 1 | User approves one implementation approach |
| 06 | [Enemy playback state repair](06-enemy-playback-state.md) | 1 | Review + visual manual check |
| 07 | [Numeric-key persistence policy](07-numeric-key-persistence-policy.md) | 2 | User chooses persisted-key policy |
| 08 | [Selected-party defensive query](08-selected-party-defensive-query.md) | 2 | Query-contract review |
| 09 | [World Map hover-preview evidence](09-world-map-hover-preview.md) | 2 | Measured baseline + behavior regression |
| 10 | [Bounded architecture continuation](10-bounded-architecture-continuation.md) | 3 | Concrete blocker + a separately approved follow-up plan |

## Completion definition

Phase 1 is complete only when all five documented defects have a reproducing
regression, passing focused/full/static checks, acceptable independent review,
and the required manual signoffs. Phase 2 is complete only for decisions the
user explicitly approves. Phase 3 ends with a scoped, evidence-backed next
plan—not an unbounded refactor committed under this plan.
