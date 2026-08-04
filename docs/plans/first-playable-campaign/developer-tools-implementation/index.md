# Developer Tools Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Provide a development-only scenario menu that creates valid campaign states and jumps quickly to campaign checks.

**Architecture:** `DebugScenarios` builds state only through public `GameSession` APIs. `GameManager` applies a named scenario, then performs the matching named scene transition; it remains the only owner of both campaign-state transitions and scene routing. A `CanvasLayer` menu is instantiated only in a debug build, while the screenshot tour opens it through a small debug-only manager API rather than synthesizing keyboard input.

**Tech Stack:** Godot 4.7, GDScript, GUT, Make.

---

## Scope and timing

Implement this on the completed first playable loop: starting settlement →
encampment → party manager → deployed world-map party → goblin-camp battle →
victory back to the world map or defeat back to the settlement. It comes before
the next campaign-content slice, and depends on the public party and encounter
APIs rather than mutating dictionaries itself.

This is not a gameplay screen, save/load system, console, cheat framework, or release-export filter. It is available only when `OS.is_debug_build()` is true.

## Scenarios

| ID | Label | State and destination |
| --- | --- | --- |
| `new_campaign` | New Campaign | Fresh campaign at the starting settlement. |
| `encampment` | Encampment | Fresh campaign, encampment UI. |
| `party_manager` | Party Manager | Fresh campaign, party manager UI. |
| `party_ready` | Party Ready to Depart | Warrior-staffed undeployed party, encampment UI. |
| `world_map` | Party on World Map | Valid deployed party at `(1, 0)`, world map. |
| `goblin_camp` | Goblin Camp Battle | Warrior-staffed deployed party at the goblin-camp tile `(4, 4)`; routes through the ordinary battle entry path, so victory clears the camp and defeat returns the party home. |

Each scenario calls `GameSession.start_new_game()` before setup. `GameManager`
must route a successful `new_campaign` directly to the starting-settlement scene
without calling `go_to_game()`, because that existing route itself starts a new
game. A failed mutation returns `false` and must never route to a misleading
scene.

## Plan order

| Step | Outcome | Prerequisite | Manual check |
| --- | --- | --- | --- |
| [01](01-debug-scenarios.md) | Repeatable, unit-tested named scenario state. | Completed first playable loop | No |
| [02](02-debug-menu-and-routing.md) | `F9` debug overlay invokes scenarios through `GameManager`, is included in the screenshot tour, and is documented for developers. | 01 | Yes |

All scenario destinations now exist. Step 01 can merge independently; Step 02
waits only for Step 01.

## Shared workflow

Each numbered document is one mergeable feature branch. Follow [AGENTS.md](../../../AGENTS.md): branch from updated `main`, use red/green TDD, run `make check`, obtain specified `make play` verification, commit, and merge locally only after user signoff. Do not push unless asked.

## Overall Definition of Done

- In debug builds, `F9` opens and closes the menu from campaign scenes and every scenario reaches its documented destination.
- The **Goblin Camp Battle** scenario enters through `GameManager.enter_battle(GameSession.GOBLIN_CAMP_ID)`; winning clears `goblin_camp`, while losing returns the deployed party to the starting settlement.
- In non-debug builds, no overlay is created and `F9` has no campaign effect.
- Scenarios use public campaign APIs; scene/UI scripts do not directly mutate party dictionaries.
- `make check` and `make screenshots` pass, the README documents the debug-only shortcut, and both a focused jump and the ordinary settlement-to-world-to-goblin-camp route are manually checked.
