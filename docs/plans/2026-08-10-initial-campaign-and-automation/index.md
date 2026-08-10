# Initial Campaign and Battle Automation Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Make the campaign approachable and safely resumable, then add a reproducible, developer-only battle-scenario runner that supplies credible balance evidence.

**Architecture:** `GameSession` remains the owner of durable campaign data and gains a versioned snapshot/import boundary. A small `SaveRepository` owns atomic files in `user://`; `GameManager` validates boundaries and owns routes, while UI only renders state and emits intents. The new runner constructs battle state from declared scenarios and named policies, emits JSONL records, then aggregates them; it never settles campaign rewards.

**Tech Stack:** Godot 4.7.1, GDScript, GUT 9.7.1, JSON/JSONL, existing `make` targets.

---

## Approved scope

The governing design is [the initial campaign and automation design](../2026-08-10-initial-campaign-and-automation-design.md). This plan implements its first delivery only.

In scope:

- Short, dismissible first-campaign guidance for party formation, deployment, route selection, battle entry, rewards, and the first improvement loop.
- One durable current-campaign save, available at Encampment or World Map when no battle is active, with Continue and Load behavior.
- Atomic, versioned snapshots that preserve all durable `GameSession` state and never mutate memory on invalid input.
- Deterministic battle scenarios, named policy adapters, JSONL records, aggregate reports, and the design’s small experiment matrix.
- Regression, editor-scan, documentation, manual campaign, and representative-battle checks.

Out of scope: multiple save slots; battlefield/modal/animation saves; campaign-level automation; automatic tuning; learned policies; new balance values; and deferred strategic systems.

## Execution order

1. [01-campaign-snapshot-contract.md](01-campaign-snapshot-contract.md) — durable schema and in-memory restoration.
2. [02-atomic-save-repository.md](02-atomic-save-repository.md) — atomic persistence and invalid-file isolation.
3. [03-save-boundaries-and-menu.md](03-save-boundaries-and-menu.md) — supported save boundaries and real UI actions.
4. [04-first-campaign-guidance.md](04-first-campaign-guidance.md) — non-blocking newcomer route.
5. [05-battle-scenario-contract.md](05-battle-scenario-contract.md) — validated, expanded scenario data and an engine adapter.
6. [06-runner-policies-and-records.md](06-runner-policies-and-records.md) — seeded legal policy execution and JSONL records.
7. [07-cli-reports-and-baseline.md](07-cli-reports-and-baseline.md) — CLI, reports, and reusable baseline scenarios.
8. [08-verification-and-local-merge.md](08-verification-and-local-merge.md) — checks, user signoff, and local merge.

Steps 1–4 are the campaign-readiness milestone; Steps 5–7 are the battle-automation milestone. Step 8 is required for either milestone.

## Cross-cutting invariants

- `GameSession` owns campaign state/snapshot conversion; it neither changes scenes nor writes files.
- `SaveRepository` owns file paths, parse/compatibility errors, and atomic replacement; it never decides if battle state is saveable.
- `GameManager` owns named routes and boundary guards; UI scripts never manipulate save files or session dictionaries.
- Save rejects non-empty `selected_encounter` and leaves memory plus existing save untouched.
- World Map carries rewards and Encampment banks them exactly once; save/load must preserve, never settle, either state.
- Scenarios contain battle inputs only and never call `DebugScenarios`, `GameManager`, or reward settlement.
- Reproduction inputs are contract/scenario/policy versions, normalized data, config fingerprint, engine version, root seed, and iteration seed.
- `stalemate` and `error` remain distinct in raw records and reports.

## Definition of done

- A new player completes a guided party-to-battle-to-improvement loop without F9.
- Save/quit/relaunch/Continue preserves supported campaign state; invalid files leave Start Menu and session unchanged; active battles cannot save.
- Identical seeded scenarios produce matching normalized records; invalid scenarios fail before execution.
- Baseline experiments produce unique directories, JSONL, and count-consistent reports.
- `make check`, editor scan, and `git diff --check` pass; the user completes Step 8 manual verification before local merge.
