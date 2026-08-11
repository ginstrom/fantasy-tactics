# Alchemy Workshop Design

## Scope

The first Alchemy Workshop slice is deliberately limited to healing
consumables. Accuracy and Guard tonics, permanent alchemical enhancements,
temporary effects, and Level 3 behavior remain future work.

## Workshop and recipes

Build the Level 1 Alchemy Workshop for 50 gold. It has one crafting slot: a
job completes after seven World Map Turns and places its result in Encampment
Stores. Upgrade from Level 1 to Level 2 for 50 gold.

| Level | Recipe | Inputs | Result |
| --- | --- | --- | --- |
| 1 | Healing Potion | 10 gold, 1 mana crystal | Restore 1-6 HP |
| 2 | Greater Healing Potion | 20 gold, 1 tier-2-or-higher mana crystal | Restore 2-8 HP |

Recipe validation and resource mutation are atomic. A workshop can run only
one job at a time. Jobs advance only when `GameSession.end_world_turn()`
advances the World Map Turn, and must survive snapshot export/import.

## Stores, carried inventory, and battle actions

Encampment Stores is the virtual party store for loot and crafted outputs; it
does not grant items free access during a battle. Before deployment, each
adventurer carries at most ten items in total. Weapons, armor, and each
potion each occupy one slot. Existing active weapon and armor pointers remain
the selections used for combat statistics.

In battle, a carried item belongs to its carrier. The active living player
unit may transfer one carried item to a living allied unit with a free slot
for 2 AP. Failed transfer attempts leave AP and every inventory unchanged.

A player uses a Healing Potion or Greater Healing Potion held by that same
unit with a separate 2-AP action. It rolls its listed healing range, restores
only the acting living unit up to its maximum health, and consumes the item.
It cannot revive. A full-health, inactive, defeated, insufficient-AP, or
otherwise invalid use leaves both AP and the potion unchanged.

## Deferred behavior

The Level 3 workshop, crafted tonics, Basic/Advanced Accuracy, temporary
effect storage, duration/refresh rules, and their UI are not part of this
slice. Design those together when Level 3 has a defined cost and recipes.
