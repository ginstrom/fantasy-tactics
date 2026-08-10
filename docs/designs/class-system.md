# Classes

## Purpose and status

This is the long-term class vision for Fantasy Tactics. It is deliberately broader than the currently playable Warrior-only campaign. A heading marked **Shipped** describes live behaviour; **Next slice** is the approved order of delivery; **Future** is design intent only and must not be presented as a current game feature.

The design grows a balanced party through four complementary roots, rather than fully implementing one class tree before the other roles exist:

| Root class | Party role | Tactical emphasis | Earliest playable purpose |
|---|---|---|---|
| Warrior | Front line | Health, Might, Guard | Holds space and survives attacks. |
| Scout | Ranged pressure and reconnaissance | Accuracy, Action Points | Attacks safely at range and reveals expedition risk. |
| Cleric | Sustain and protection | Health, Guard, Resistance | Restores allies and prevents attrition. |
| Mage | Control and burst | spell Accuracy, Action Points | Trades durability for area damage and control. |

Specializations build on a proven root role: Warrior becomes Knight or Archer, Mage becomes Spellcaster or Battle Mage, Cleric becomes Healer or Paladin, and Scout becomes Ranger. A specialization never arrives before its root's core combat loop and counterplay are playable.

## Shared tactical attributes

Every combatant—adventurer or monster—uses one compact tactical profile. An adventurer persists base values in `GameSession`; equipment, perks, effects, and class features produce effective values when a battle unit is created. Monster templates are immutable data and are likewise copied into runtime `Unit` instances.

| Attribute | Type | Meaning |
|---|---:|---|
| `max_health` | integer | Damage capacity; a unit at zero is defeated. |
| `might` | integer | Adds to melee or natural-attack raw damage. |
| `accuracy` | integer | Base chance to hit, expressed in percentage points. |
| `guard` | integer | Percentage points subtracted from an attacker's Accuracy. |
| `resistance` | integer percent | Reduces damage after a hit. |
| `action_points` | integer | Generic budget for movement, attacks, items, and future abilities during a Round. |

`attack_damage`/weapon damage remains an attack property, not a seventh unit attribute. This keeps a sword, a bow, a spell, and a monster bite able to use the same attributes while retaining their own range, damage, and tags.

### Combat resolution

All accuracy, guard, and resistance values are percentage points.

```text
final hit chance = clamp((attacker accuracy - defender guard) / 100, 5%, 95%)
raw damage       = rolled attack damage + attacker might
final damage     = max(1, round(raw damage × (1 - defender resistance / 100)))
```

**Shipped compatibility:** the live game calls `accuracy` `attack` and `guard` `defense`; player Might is effectively zero; and weapon/natural damage is already rolled before Resistance. Its movement-plus-one-attack turn is intentionally replaced by the generic Action Point foundation below. The current 95% Resistance cap remains the temporary balance rule; make it a configurable combat rule before effects can modify it.

### Generic Action Points (Next slice)

The shared [Movement and Action Points](movement-and-action-points.md) guide
defines the Round lifecycle, initial 6-AP budget, action costs, legality,
player feedback, and extension constraints. Classes may change effective AP
only through an explicit, tested feature; they do not introduce a separate
class-specific action economy.

### Long-term concepts that are not yet attributes

The earlier Strength, Agility, Vitality, Intelligence, Piety, and Luck list described useful class fantasy, but it mixed immediate combat data with systems that do not exist. These concepts are retained as future design vocabulary, not persisted attributes:

| Concept | First supported expression | Deferred until |
|---|---|---|
| Strength | Might and melee equipment | carrying capacity |
| Agility | Action Points and Guard | dodge |
| Vitality | max_health and Resistance | no additional system required |
| Intelligence | Mage spell access | magic points and spellcasting |
| Piety | Cleric spell access | healing/buff system and Temple gate |
| Luck | none | critical hits and loot-roll modifiers |

No magic points, carry weight, dodge, critical hits, or luck rolls are added merely to complete this table.

## Advancement and perks

**Shipped:** a level grants 10 skill points. They currently raise raw Attack, which becomes `accuracy` in the shared tactical model. The level-3 Bonus Move perk remains live until the generic AP migration; its approved replacement is `+1 Action Point`.

**Next slice:** retain one skill-point currency and permit only investments whose battle effect is implemented and tested. Accuracy is the sole spend until another permitted statistic is live. Class-specific perks are choices from data-backed trees, with prerequisites, rather than separate attribute systems.

**Future:** perks can alter raw damage before Resistance, grant penetration, add movement, or introduce an active ability only with the supporting combat primitive. A perk description alone does not enable a mechanic.

### Generic perk themes

- **Might:** Rage increases raw melee damage; Strong Back waits for inventory weight.
- **Action Points/Guard:** Speed grants Action Points; Dodge waits for an avoidance system.
- **Health/Resistance:** Toughness increases Resistance; Survivability increases max health.
- **Knowledge:** Fast Learner may modify XP; perception waits for scouting.
- **Faith and luck:** Prayer and luck perks wait for their owning systems.

### Class perk inventory (Future unless its primitive is shipped)

- **Warrior / Knight:** Parry, Shield Bash, Shield Wall, Chain Blow, and Thrust. Thrust is the first candidate once penetration exists.
- **Warrior / Archer:** Lock On, Piercing Arrow, and Called Shot. This branch waits for ranged attacks, line/range rules, and target persistence.
- **Mage / Spellcaster:** sleep/charm control, elemental damage, and haste. This branch owns MP and spell effects when the Mage slice begins.
- **Mage / Battle Mage:** elemental attacks, temporary Guard, and enchanted weapon penetration.
- **Cleric / Healer:** healing, defensive buffs, curses, and paralysis.
- **Cleric / Paladin:** Temple-gated recruitment, holy melee, and boons.
- **Scout / Ranger:** scouting, pre-battle enemy information, and Hunter's Mark. The first Ranger slice must make scouting information useful before adding its deeper perk tree.

## Incremental delivery roadmap

Every slice must add an encounter pattern that rewards its role, automated combat/balance coverage, and a manual `make play` check. Do not introduce a class solely as a different stat line.

| Slice | Roster | Capability added | Balance gate |
|---|---|---|---|
| 0 — **Shipped** | Warrior | adjacent attack, gear, health, accuracy, defense/resistance, movement | One Warrior can fight current monsters at their documented roles. |
| 1 | Warrior | generic AP, potion action foundation, item-instance contract | AP choices must be readable and retain a three-tile move plus attack option. |
| 2 | Warrior + Scout/Ranger | ranged attacks, range/line-of-sight, basic scouting | Ranger pressure is valuable but cannot replace a front line. |
| 3 | + Cleric/Healer | targeted healing, protection, durations | Healing offsets attrition but cannot make a Warrior unkillable. |
| 4 | + Mage/Spellcaster | MP, spells, area/control effects | Mage has powerful output/control but poor durability and limited resources. |
| 5 | root specializations | Knight, Archer, Battle Mage, Paladin | Each specialization changes decisions, not merely a percentage bonus. |
| 6 | advanced perk branches | reactions, penetration, marks, cooldowns, multi-target effects | Effects have clear counters, stack limits, and scenario coverage. |

The matching implementation plan lives in [`docs/plans/2026-08-10-class-attributes-and-monsters/`](../plans/2026-08-10-class-attributes-and-monsters/index.md).
