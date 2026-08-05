# World-Map Route Movement Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Let a deployed party plan a single route, move one step manually or automatically per World Map turn, and show a clear path and arrival estimate before committing.

**Architecture:** `GameSession` owns the durable route, movement-spent flag, and world-turn count. `world_map.gd` computes deterministic empty-grid Manhattan routes, translates clicks and End Turn into session API calls, and renders transient hover/selection state. Battle keeps its action flow but changes player-facing cycle language to Round.

**Tech Stack:** Godot 4.7, GDScript, GUT, Make.

---

## Approved design

Read [the approved design](../2026-08-05-world-map-route-movement-design.md) before implementing. It defines the click priority: the first destination click sets/replaces a route, clicking that movement target again takes one manual route step, and End Turn consumes only unused movement before advancing the counter.

## Plan order

| Step | Milestone | Depends on | Manual check |
| --- | --- | --- | --- |
| [01](01-session-world-travel-state.md) | Durable route, movement allocation, and turn APIs work independently of the scene. | None | No |
| [02](02-world-route-calculation-and-interaction.md) | Map clicks set/replace a deterministic route and manually consume one step. | 01 | No |
| [03](03-world-map-route-preview-and-turn-ui.md) | Cursor preview, remaining-route display, estimate, and End Turn make planned travel visible and automatic. | 01, 02 | Yes |
| [04](04-battle-round-terminology.md) | Battle HUD/hints use Round while World Map uses Turn. | None | No |
| [05](05-end-to-end-regression-and-handoff.md) | The completed route-to-camp loop is verified and merged after user signoff. | 01-04 | Yes |

Steps 01 through 03 are sequential. Step 04 is independent, but must merge before step 05. Do not add waypoints, terrain costs, animation, obstacles, or multi-party scheduling in this slice.

## Shared workflow

For every step, branch from updated `main`, write the stated failing test, demonstrate red with `make test`, implement minimally, then run `make check` and `git diff --check`. For manual steps, pause for user signoff before merge. Do not push or open a PR unless asked.

## Definition of done

- A destination click saves/replaces an in-bounds deterministic route without moving.
- A second click on the committed movement target and End Turn can consume only one route step per World Map turn.
- Position, remaining route, world turn, and movement availability persist across a new World Map instance.
- Selected hover shows the path and turns-to-arrival; End Turn and current World Map turn are visible.
- Arrival clears the route, and settlement/camp selection-first entry still works.
- Battle uses Round terminology; World Map uses Turn.
- `make check`, `git diff --check`, and the specified `make play` flow pass.
