# Step 10 — Bounded architecture continuation

**Objective:** Continue Stage 6 extraction only when a demonstrated change is
blocked by ownership/size, and create a new scoped plan rather than starting a
parallel rewrite.

**Dependency:** Step 09 merged. **Branch:** `docs/bounded-architecture-next`.

## Discovery tasks

1. Re-read `docs/code-findings.md`, the active Stage 6 design/plan material,
   `scripts/autoload/game_session.gd`, `scripts/battle/battle_controller.gd`,
   `scripts/content/content_catalog.gd`, and current tests. Identify one
   concrete next feature or regression whose implementation is materially
   blocked by a specific current owner.
2. Compare at least these bounded candidates: static catalog ownership,
   one durable GameSession domain service, or a Battlefield presentation seam.
   For each, list state owner, public API, migration boundary, focused tests,
   rollback boundary, and why it is smaller/safer than a wholesale rewrite.
3. Reject broad signals, full-screen/embedded detail-view unification, and a
   ContentCatalog cache unless a new reproducible stale-state/performance
   problem specifically requires it.
4. Write a new dated design and, only after user approval, a separate
   folderized implementation plan. This plan ends here; it authorizes no
   extraction code.

## Verification and handoff

Run `make check`, editor parse, and `git diff --check` for documentation/test
evidence changes. Independent review must validate source references and
ownership claims. After user signoff, locally commit/merge the discovery
artifact and delete the branch. The supervising agent then waits for explicit
approval of the new plan before implementation.
