# Game Polish Implementation Plan

This implementation plan breaks down the playtesting polish requirements from [`docs/polish.md`](../../polish.md) into 6 modular, TDD-driven steps.

## Overview & Scope

The plan covers six focused improvements across the game UI, combat rewards, unit presentation, and debug shortcuts:

1. **Party Creation Flow**: Direct navigation from the New Game / Encampment "First Party" dialog straight into the Party Creation name entry sub-view.
2. **Units Screen Redesign**: Transitioning the Units hub from a redundant list of link buttons to a structured summary display showing counts and `[View]` buttons for Parties, Roster, and Recruitable units.
3. **Recruiting Flow & Double-Click**: Returning to Party Details when recruiting for a target party, supporting double-click recruiting on table rows, and navigating to Roster when recruiting without a target party.
4. **Combat Rewards Rebalance**: Scaling encounter completion gold rewards so Tier 1 encounters average 25 gold and Tier 2 encounters average 50 gold (not including dropped gear/crystals).
5. **Unit Details Presentation**: Updating terminology ("Hit points", "Action points", "Damage resistance", "Magic resistance", "Effects"), formatting skills as an indented multi-line list, and formatting perks as a bulleted list or `Perks: None`.
6. **Debug Menu Orc Battle Scenario**: Updating the Orc battle debug shortcut to set up 4 warriors against 2 orcs.

---

## Steps & Milestones

| Step | Plan File | Focus Area | Key Milestone |
|---|---|---|---|
| 1 | [`step-1-party-creation-flow.md`](step-1-party-creation-flow.md) | Party Creation Flow | "Create Party" dialog on new game/encampment opens party creation input directly |
| 2 | [`step-2-units-screen-redesign.md`](step-2-units-screen-redesign.md) | Units Hub UI | Units screen displays unit/party/recruit counts with `[View]` buttons |
| 3 | [`step-3-recruiting-flow-and-double-click.md`](step-3-recruiting-flow-and-double-click.md) | Recruiting Flow | Double-click recruiting works; target party returns to Party Details; non-target recruits route to Roster |
| 4 | [`step-4-combat-rewards-rebalance.md`](step-4-combat-rewards-rebalance.md) | Combat Rewards | Encounter gold rewards average 25g (Tier 1) and 50g (Tier 2) |
| 5 | [`step-5-unit-details-formatting.md`](step-5-unit-details-formatting.md) | Unit Details Formatting | Multi-line skills, bulleted perks list / `Perks: None`, and updated HP/AP/Resistances terminology |
| 6 | [`step-6-debug-menu-orc-scenario.md`](step-6-debug-menu-orc-scenario.md) | Debug Scenario | Orc battle debug shortcut fields 4 warriors vs 2 orcs |

---

## Execution Principles

- **Branching Workflow**: Perform each step on a dedicated feature branch off `main` (e.g. `feat/party-creation-flow`, `feat/units-screen-redesign`, etc.).
- **TDD (Red/Green)**: Write unit tests first in `tests/unit/`, confirm test failure, implement the feature, and verify green with `make check`.
- **Manual Verification**: Run `make play` or specific GUT commands for visual/flow verification before requesting user sign-off.
- **Local Branch Merge**: After user sign-off, merge the step branch back into `main` locally and clean up the feature branch.
