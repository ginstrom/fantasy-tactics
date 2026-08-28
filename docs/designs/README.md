# Design documentation

These documents describe the intended full Fantasy Tactics experience. They
are not a list of only the features available in the current build.

## Implementation-status legend

- **Implemented** — present in the game and treated as a compatibility
  contract. Code and tests, not this label alone, are the authority.
- **To implement** — an accepted design requirement. It needs a scoped plan,
  red/green tests, automated verification, and manual play verification before
  it can be called implemented.
- **Decision pending** — direction is known but its exact rule, balance, or
  delivery scope is not locked. Do not implement it until the decision is
  resolved.

## Full-experience implementation map

| Experience area | Design source | Status |
|---|---|---|
| Borderlands authored campaign, victory, and post-victory play | [Campaign Loop](campaign-loop.md) | Implemented campaign spine; presentation and balance work continues as marked. |
| Multiple independently travelling parties and their strategic coordination | [World Map and Encounters](world-map-and-encounters.md) | **To implement**. |
| Encounter discovery, scouting, Watchtowers, and Guild Hall quests | [Intelligence System](intelligence.md) | **To implement**; quest cadence and escalation contain decision-pending balance values. |
| Four root classes, specializations, and deeper perk trees | [Classes](class-system.md) | Warrior foundation implemented; remaining classes, specializations, and unsupported perk primitives are **to implement**. |
| Full monster families, encounter roles, AI, rewards, and art | [Monster Manual](monster-manual.md) | Initial roster implemented; additions are **to implement** by encounter slice. |
| Crafting, potions, enhancements, runes, and richer item ownership | [Equipment Handbook](equipment-handbook.md) | Normal-equipment baseline implemented; later equipment layers are **to implement**. |
| Tactical movement, AP, combat, battle presentation, and inventory UI | [Movement and Action Points](movement-and-action-points.md), [Combat System](combat-system.md), [Battle Screen](battle-screen.md), and [Weapon and Armor Inventory](weapon-armor-inventory.md) | Implemented foundations plus explicitly marked extensions **to implement**. |

The [Game Vision](vision.md) connects these systems as one experience. A
feature remains planned until its owning design page and implementation work
both mark it implemented.
