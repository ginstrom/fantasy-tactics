# Step 1 — Stage 5 Readiness and Decision Contract

**Branch:** `docs/stage-5-readiness-contract`

**Depends on:** clean `main`; recorded Stage 4 exit signoff

**Milestone:** A reviewer can identify the shipped baseline, the exact order of Stage 5 work, and every product decision that must be approved before a runtime branch starts.

## Files

- Modify: `docs/plans/2026-08-23-stage-5-strategic-roster-expansion/index.md`.
- Modify: `docs/designs/intelligence.md`, `docs/designs/combat-system.md`, `docs/designs/class-system.md`, and `docs/designs/world-map-and-encounters.md` only to record a user-approved decision; do not silently redesign them.
- Create: a dated decision/evidence ledger outside Git, or a Git-tracked design appendix only if the user explicitly approves its durable location.

## Red/green tasks

1. Read the Stage 4 exit record, `docs/dev/README.md`, this index, and the five source contracts. Compare the contracts against `GameSession`, `CampaignSnapshot`, `world_map.gd`, `BattleController`, `BattleStateFactory`, `CampaignSim`, and their unit tests. Record each existing seam and each absent feature with file evidence.
2. Run the protected baseline before changing documentation: `make campaign-sim`, `make check`, `godot --headless --path . --editor --quit`, and `git diff --check`. Store generated reports outside Git and record the command/result paths in the ledger.
3. Write the failing documentation review checklist: it must reject any later slice missing all six required fields—new player decision, counterplay, authored/repeatable encounter use, durable-state/snapshot change, deterministic scenario assertion, and manual acceptance check.
4. Run a targeted Markdown/link/reference check and confirm it fails against a deliberately incomplete draft row; remove the probe rather than committing it.
5. Create decision rows for: intelligence quest duration/reward/cadence; terrain representation/distribution and reaction ordering; the first Mage spell/counter encounter; specialization delivery order and promotion eligibility; and multi-party cap, battle-party selection, and time-escalation rule. Mark every unapproved row `blocked`; do not substitute a balance value.
6. Update the index's live audit only with verified facts and rerun the reference check plus `git diff --check`.

## Manual check

Review the ledger with the user. Confirm that the first approved runtime slice is optional intelligence/quests and that no later slice can start until its named decisions have an explicit acceptance record.

## Commit and local merge

After signoff, stage only the Stage 5 plan/approved decision-document changes; commit `docs(plan): define Stage 5 decision gates`, merge locally to `main`, and delete `docs/stage-5-readiness-contract`.
