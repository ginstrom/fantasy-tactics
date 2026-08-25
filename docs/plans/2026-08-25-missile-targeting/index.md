# Missile Targeting Implementation Plan

**Goal:** Keep missile attacks stationary, let shots pass through units, and report unavailable missile attacks in the battle log.

**Scope:** A bow/missile attack uses only the attacker’s current position. If the target is not in its current range, the action makes no state change and reports the existing targeting-failure message in the bottom battle log. Living units are not line-of-sight blockers for weapon targeting. Melee attacks retain their current move-and-attack fallback.

## Steps

1. [Targeting contract and controller tests](01-targeting-contract.md) — establish failing tests, implement the smallest legality/fallback change, and run focused controller tests.
2. [Battlefield feedback and documentation](02-battle-log-and-documentation.md) — log targeting failures once, align the battle-screen contract, and run focused UI tests plus the full suite.

Each step uses red/green TDD. After user manual signoff with `make play`, commit only the documented files and merge the feature branch locally to `main`.
