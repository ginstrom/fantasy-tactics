# Settlement and First Party Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the first settlement-to-world-map campaign loop with one
player-created party and one Warrior.

**Architecture:** `GameSession` owns the adventurer roster, party membership,
deployment, and position. `GameManager` performs named state-and-scene
transitions. The settlement, UI, and world map only render that state and ask
the manager to perform actions.

**Tech Stack:** Godot 4.7, GDScript, GUT, Make.

---

## Goal

Implement the approved first campaign slice: begin a new game in a settlement,
form one party from an unassigned Warrior, deploy it to the world map, move it,
and return it home.

## Source design and boundaries

This plan implements [Settlement and First Party Design](../first-playable-campaign/settlement-and-first-party-design.md).
It deliberately does not add combat statistics, recruitment, economy, multiple
parties, or local dungeons. The existing wandering-monster encounter remains
available after deployment but is not expanded by this work.

The planned campaign state is intentionally small:

```text
adventurers = [{ id, name, class, weapon }]
parties = [{ id, member_ids, location_id, world_position, deployed }]
selected_party_id = "" or "party_001"
```

`GameSession` owns this state. `GameManager` makes named state-and-scene
transitions. Local, UI, and world scenes display state and ask the manager to
perform actions.

## Plan order

| Step | Outcome | Prerequisite | Manual check |
| --- | --- | --- | --- |
| [01](01-campaign-state.md) | Roster, empty party list, party formation, deployment, and return are durable and unit-tested. | None | No |
| [02](02-party-manager-ui.md) | A Party Manager visibly creates the party and assigns/removes the Warrior. | 01 | Yes |
| [03](03-settlement-and-encampment.md) | A new game opens the settlement; encampment links to management and departs a valid party. | 01, 02 | Yes |
| [04](04-world-map-deployment-and-return.md) | Only a deployed party appears and moves on the world map; it can return to the settlement. | 01, 03 | Yes |

## Shared workflow

Each numbered document is one mergeable feature branch. Before beginning it,
confirm no unrelated work is present; this repository currently may have a
user-owned `AGENTS.md` edit, which must never be staged or overwritten by an
implementation branch. Follow [AGENTS.md](../../../AGENTS.md): branch from
updated `main`, use red/green TDD, run `make check`, obtain the specified user
verification through `make play`, commit, merge locally into `main` only after
the user signs off, and delete the branch. Do not push unless asked.

## Overall Definition of Done

- All four steps are merged locally into `main` after their individual user
  signoffs.
- `make check` passes after the final merge.
- A user can manually complete the documented settlement-to-world-to-settlement
  loop without developer controls.
- Existing battle entry continues to work for a deployed party, although
  battle still does not consume adventurer data.
