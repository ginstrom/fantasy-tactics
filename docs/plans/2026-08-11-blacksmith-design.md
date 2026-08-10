# Blacksmith Level and Job Design

## Purpose

Define the first Blacksmith's economy, unlocks, and World Map Turn-based
production contract for the equipment-and-crafting implementation.

## Building levels

| Level | Cost to reach | Unlock |
|---|---:|---|
| 1 | 50 gold | Sharpening |
| 2 | 50 gold | Iron weapon crafting |
| 3 | 100 gold | Steel weapon crafting |

Higher-level capacity and stronger treatments are deferred.

## Production jobs

The Blacksmith has two independent job slots:

- One craft job at a time. Each normal weapon craft takes 5 World Map Turns.
- One sharpening job at a time. Each sharpening takes 20 World Map Turns.

The two slots run in parallel. Jobs advance only through successful World Map
Turns, using `GameSession.end_world_turn()` as the sole clock. A job records
its completion World Map Turn and remains durable in campaign snapshots.

## Economy and results

Normal crafting costs `ceil(sale_price * 0.9)` gold. This preserves integer
gold and prevents a craft-and-sell profit loop. The recipe uses no additional
materials in this initial slice.

Sharpening costs twice the base weapon sale price and consumes one banked
normal weapon. On completion it creates one owned item instance with
`treatment_id: "sharpened"`. Sharpened adds exactly +1 raw weapon damage
after the base weapon roll and before future Might and Resistance modifiers.

All gate, resource, slot, and ownership checks complete before a job mutates
gold or inventory. Failed starts leave campaign state unchanged.

## UI and scope

Buildings lists the Blacksmith and routes to its dedicated Encampment screen.
That screen shows its level, current jobs, remaining World Map Turns, and only
the actions legal at that level. The step ships one normal weapon recipe plus
Sharpened; additional recipes, capacity upgrades, treatments, and effects are
deferred.
