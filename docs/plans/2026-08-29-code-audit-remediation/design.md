# Code Audit Remediation Design

**Status:** Approved 2026-08-29

## Intent

Turn the source-verified findings in [docs/code-findings.md](../../code-findings.md)
into small, independently reversible fixes. Correctness and player-facing
behavior take precedence over a structural cleanup. The work proceeds in
strict dependency order and each implementation slice receives an independent
read-only review plus user manual signoff before its local merge.

## Chosen shape

Use one dated, folderized plan with three gated phases rather than a broad
rewrite or one plan per finding. Phase 1 contains the five demonstrated
defects. Phase 2 contains hardening work, but only after it has a concrete
policy, regression, or profiling evidence. Phase 3 preserves the existing
catalog/domain-extraction direction and explicitly forbids a speculative
`GameSession` or `BattleController` rewrite.

Two unresolved implementation choices remain deliberate gates:

- Guild Hall upgrades: the recommended policy is to fill every newly unlocked
  recruitment-offer slot immediately, preserving the existing no-vacancy
  semantics for the initial four offers.
- Enemy playback: compare a recorded visual timeline with incremental
  simulation, then obtain approval for the smallest approach that proves every
  displayed beat matches that beat's state. Do not silently choose an
  architecture during a bug-fix branch.

The numeric-key persistence policy is also a user decision gate. It must be
decided before changing JSON normalization or snapshot validation.

## Non-goals

- No wholesale controller/session rewrite.
- No broad reactive-signal framework.
- No ContentCatalog cache without a measured hitch and an explicit reload
  invalidation contract.
- No remote push or pull request. User signoff authorizes only the documented
  local commit and merge.
