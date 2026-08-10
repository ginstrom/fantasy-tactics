# Movement and Action Points

## Purpose and status

This is the canonical rule reference for tactical movement and Action Points
(AP). It governs shared turn economy for every combatant. Class features,
equipment, potions, spells, and monsters refer here for generic movement and
action rules; their own documents own their specific effects.

**Shipped** describes the current movement-plus-one-attack battle turn.
**Next slice** is approved design for the AP foundation, not live behaviour.
Later sections are constraints for future features, not permissions to add
them early.

## Terms

| Term | Meaning |
|---|---|
| Round | One combat cycle in which every eligible unit takes a turn. Do not call a World Map Turn a Round. |
| AP | A unit's generic action budget for its current Round. |
| Legal action | An action that satisfies normal targeting, range, occupancy, status, and available-resource rules in addition to its AP cost. |
| Action cost | The AP deducted only after an action passes its legality checks and resolves successfully. |

Selecting a unit or inspecting a target is not an action and never spends AP.
Selection-before-activation remains intact: a click that only selects a unit,
enemy, or destination cannot move, attack, or consume an item.

## Shipped movement baseline

The live battle grants movement range and one attack opportunity on a unit's
turn. This document does not reinterpret that behaviour as AP before the AP
foundation is implemented. Existing range, occupancy, target, and turn-order
rules remain the live authority until that migration.

## Generic AP model — Next slice

At the start of each eligible unit's Round, set its available AP to its
effective `action_points`. The initial effective value is **6 AP** for every
unit. Do not carry unused AP across Rounds. When a player chooses End Turn,
remaining AP is forfeited and the normal turn sequence continues.

| Action | AP cost |
|---|---:|
| Move one tile | 1 |
| Basic attack | 3 |
| Use a carried potion | 2 |

AP is generic: it replaces a hidden distinction between movement, an attack,
and an item-use allowance. A unit may take any sequence of legal actions while
it can pay every cost. It may make as many basic attacks as its AP permits;
there is no separate once-per-turn attack limit.

## Movement and action legality

1. A movement action chooses one legal adjacent tile and costs 1 AP for that
   tile. A route is resolved tile by tile: a unit stops before a tile it cannot
   legally enter or cannot afford.
2. A basic attack first passes the normal attack target and range rules, then
   costs 3 AP. A miss still resolves an attempted attack and spends its AP.
3. Using a carried potion first passes its inventory, target, and effect rules,
   then costs 2 AP and consumes exactly one potion at the campaign/battle
   boundary. A failed availability, target, or AP check changes neither AP nor
   inventory.
4. An action that lacks AP is unavailable. The interface must not allow it to
   partially resolve, and it must not deduct a negative AP balance.
5. Effects that make a unit unable to act prohibit their stated actions even
   if it has AP. They do not silently erase the shared AP accounting rule.

The first slice preserves the flat-grid rule: every legal tile costs 1 AP.
Terrain costs, forced movement, reactions, opportunity attacks, and pathing
bonuses require their own approved rules and test coverage.

## Representative sequences

| Sequence | AP spent | Result |
|---|---:|---|
| Move 3 tiles, then basic attack | 3 + 3 = 6 | Preserves the current practical baseline. |
| Basic attack twice while stationary | 3 + 3 = 6 | Both attacks are legal if each target check passes. |
| Move 1 tile, use a potion, basic attack | 1 + 2 + 3 = 6 | Demonstrates that items share the same budget. |
| Move 4 tiles, then attempt a basic attack | 4; 2 remain | Attack is unavailable because it costs 3 AP. |

## Player feedback and control

The AP migration must make the active unit's available and maximum AP visible.
It must show an action's AP cost before confirmation and clearly explain why an
action is unavailable (insufficient AP versus an ordinary target/range rule).
Movement preview shows how many tiles the unit can currently afford. End Turn
remains explicit; it displays that unused AP will be lost.

Battle controls express intent. The synchronous battle rules validate AP and
legality, deduct AP, and report outcomes; UI code must not directly mutate AP.
AI uses the same costs and legality checks as the player.

## Extensions and balance constraints

Spells, active perks, items, terrain, and status effects may introduce a cost,
refund, discount, or AP increase only as an explicit data-backed effect with a
defined timing and cap interaction. The level-3 Bonus Move perk's approved AP
replacement is `+1 Action Point`.

No future effect may create a parallel free-action pool or bypass normal
legality merely because it has an AP cost. Each new action must specify its AP
cost, targeting/range constraints, resolution order, failure behaviour, UI
feedback, AI treatment, and automated scenario coverage.

## Related design documents

- [Classes](class-system.md) defines `action_points` as a shared attribute and
  assigns class/perk consequences.
- [Equipment Handbook](equipment-handbook.md) defines potions, enhancements,
  and item ownership. Its potion effects use this guide's 2-AP item-use rule.
- [Monster Manual](monster-manual.md) supplies monster combat profiles; its
  future templates use this guide's shared action economy.
