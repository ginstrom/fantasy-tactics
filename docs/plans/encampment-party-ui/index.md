# Encampment Party UI Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Replace the minimal encampment screen with a party-oriented hub,
selection-aware information panel, and explicit eligible-party deployment.

**Architecture:** `GameSession` gains durable data fields and named queries;
`GameManager` adds routes/actions; each new scene script keeps its transient
selection local and refreshes the shared `InformationPanel`. The first slice
implements Units, Parties, Party Details, Unit Details, and Deploy Party only.
Buildings, Trade, Roster, Recruitment, and Add Member remain clearly labelled
TBD/deferred per the campaign design document.

**Tech Stack:** Godot 4 scenes and GDScript, GUT unit/scene tests, English
translation resource, Makefile (`make check`, `make play`).

## Scope and acceptance map

| Player outcome | Delivery step |
| --- | --- |
| Party/adventurer records have future-compatible names, statuses, and queries | [01-session-data-and-deployability.md](01-session-data-and-deployability.md) |
| Player/gold are persistent panel context; selected party/unit yields a View action | [02-information-panel-and-routes.md](02-information-panel-and-routes.md) |
| Encampment resembles the supplied hub and its Units path works | [03-encampment-and-party-browsing.md](03-encampment-and-party-browsing.md) |
| A member can be inspected and a valid party can be chosen and deployed | [04-details-and-deploy-party.md](04-details-and-deploy-party.md) |
| The UI has a user-verified vertical slice and clean local merge | [05-verify-and-handoff.md](05-verify-and-handoff.md) |

## Explicitly deferred

No functional Buildings, Trade, Roster, Recruitment, or Add Member systems;
no multi-party rendering or concurrent world-map turns; no combat-stat,
inventory, death, or incapacitation mechanics beyond the `available` status
contract and placeholders. See
[the campaign design](../first-playable-campaign/game-design.md#deferred-encampment-surfaces-and-data).

## Sequence

Complete steps 01 through 04 serially: scenes depend on the public session API
and routes introduced before them. Step 05 follows user manual signoff. Every
step starts from a branch off current `main`, commits its verified work, and
only merges back locally after the user approves the stated manual check. Do
not push or open a pull request.
