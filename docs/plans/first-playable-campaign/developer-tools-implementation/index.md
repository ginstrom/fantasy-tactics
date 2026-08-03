# Developer Tools Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Provide a development-only scenario menu that creates valid campaign states and jumps quickly to campaign checks.

**Architecture:** `DebugScenarios` builds state only through public `GameSession` APIs. `GameManager` applies a named scenario and remains the only owner of scene routing. A `CanvasLayer` menu is instantiated only in a debug build.

**Tech Stack:** Godot 4.7, GDScript, GUT, Make.

---

## Scope and timing

Implement this after [Campaign State](../../settlement-first-party-implementation/01-campaign-state.md) is merged and before [Party Manager UI](../../settlement-first-party-implementation/02-party-manager-ui.md). It depends on the new public party APIs rather than mutating dictionaries itself.

This is not a gameplay screen, save/load system, console, cheat framework, or release-export filter. It is available only when `OS.is_debug_build()` is true.

## Scenarios

| ID | Label | State and destination |
| --- | --- | --- |
| `new_campaign` | New Campaign | Fresh campaign at the starting settlement. |
| `encampment` | Encampment | Fresh campaign, encampment UI. |
| `party_manager` | Party Manager | Fresh campaign, party manager UI. |
| `party_ready` | Party Ready to Depart | Warrior-staffed undeployed party, encampment UI. |
| `world_map` | Party on World Map | Valid deployed party at `(1, 0)`, world map. |
| `monster_encounter` | Monster Encounter | Valid deployed party at the existing encounter, then ordinary battlefield route. |

Each scenario calls `GameSession.start_new_game()` before setup. A failed mutation returns `false` and must never route to a misleading scene.

## Plan order

| Step | Outcome | Prerequisite | Manual check |
| --- | --- | --- | --- |
| [01](01-debug-scenarios.md) | Repeatable, unit-tested named scenario state. | Campaign State | No |
| [02](02-debug-menu-and-routing.md) | `F9` debug overlay invokes scenarios through `GameManager`. | 01; Party Manager UI; Starting Settlement | Yes |

The helper can merge after campaign state. The menu waits until all its real scene destinations exist.

## Shared workflow

Each numbered document is one mergeable feature branch. Follow [AGENTS.md](../../../AGENTS.md): branch from updated `main`, use red/green TDD, run `make check`, obtain specified `make play` verification, commit, and merge locally only after user signoff. Do not push unless asked.

## Overall Definition of Done

- In debug builds, `F9` opens and closes the menu from campaign scenes and every scenario reaches its documented destination.
- In non-debug builds, no overlay is created and `F9` has no campaign effect.
- Scenarios use public campaign APIs; scene/UI scripts do not directly mutate party dictionaries.
- `make check` passes, and both a focused jump and the ordinary settlement-to-world route are manually checked.
