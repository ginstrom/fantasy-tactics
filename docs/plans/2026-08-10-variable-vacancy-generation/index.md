# Variable Vacancy and Encounter Generation Implementation Plan

## Goal

Make encounter and recruitment vacancy delays vary by a bounded jitter, retain
the existing power-weighted encounter-instance generation, and reconcile the
durable campaign documentation with approved vitality-based health and shipped
scope.

## Approved Design

See [design.md](design.md). Each opened vacancy resolves one inclusive uniform
delay: encounter base 15 ±5 turns and recruitment base 30 ±5 turns. The roll
is made once at vacancy creation, then the existing World Map turn clock,
capacity guard, no-catch-up rule, weighted template selection, and distinct
spawn-position rules continue unchanged. Maximum HP is `Vitality × level`; a
Warrior has vitality 10.

## Scope

In scope: configurable jitter, a test seam for it, regression coverage,
comment/doc corrections, and manual verification. Out of scope: recruit
dismissal UI/model changes, new encounter templates, procedural maps,
duplicate active templates, terrain, save/load, and any combat rebalance.

## Execution Order

1. [01-vacancy-jitter-tests.md](01-vacancy-jitter-tests.md) establishes
   deterministic red tests for the new timing contract.
2. [02-vacancy-jitter-implementation.md](02-vacancy-jitter-implementation.md)
   adds configuration and the `GameSession` implementation.
3. [03-documentation-reconciliation.md](03-documentation-reconciliation.md)
   fixes durable documentation and stale source comments without changing the
   approved gameplay boundary.
4. [04-verification-and-handoff.md](04-verification-and-handoff.md) performs
   the full automated and player-facing checks, then obtains signoff before a
   local merge.

## Invariants

- `GameSession` owns vacancy creation, population timing, and all randomness
  seams; `GameManager` and scenes do not calculate delays.
- A vacancy stores its resolved `turns_remaining` and never rerolls while
  waiting.
- A successful World Map End Turn is the only clock tick. An unresolved battle
  still blocks it.
- An expired vacancy fills only if below its category cap, then is discarded;
  it does not catch up later.
- Encounter refills keep the current power-weighted inactive-template choice,
  unique instance ids, and in-bounds unoccupied spawn positions.

## Definition of Done

- Both vacancy categories roll exactly once within their inclusive base ±5
  bounds and the chosen values are deterministic in unit tests.
- Existing refill, cap, no-catch-up, weighted-template, and position tests
  continue to pass.
- `game-design.md` describes vitality-by-level health, variable timing, actual
  encounter generation, and no unsupported recruit-dismiss action; it no
  longer links to deleted dated plans.
- `make check`, `godot --headless --path . --editor --quit`, and `git diff
  --check` pass. A player has manually verified jittered encounter/recruitment
  refill timing using `make play` before the branch is locally merged.
