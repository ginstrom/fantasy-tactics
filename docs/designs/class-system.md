# Classes

## Purpose and status

This is the long-term class vision for Fantasy Tactics. It is deliberately broader than the currently playable Warrior-and-Scout campaign. A heading marked **Shipped** describes live behaviour; **Next slice** is the approved order of delivery; **Future** is design intent only and must not be presented as a current game feature. The campaign roadmap locks the Warrior/Scout/Cleric triad as the first three-class composition, but Scout reconnaissance details and the Cleric/Temple slice are still deferred decisions; see [Borderlands Campaign Loop](campaign-loop.md#deferred-roadmap-decisions).

The design grows a balanced party through four complementary roots, rather than fully implementing one class tree before the other roles exist:

| Root class | Party role | Tactical emphasis | Earliest playable purpose |
|---|---|---|---|
| Warrior | Front line | Health, Might, Guard | Holds space and survives attacks. |
| Scout | Ranged pressure and reconnaissance | Accuracy, Action Points | Attacks safely at range; reconnaissance details are deferred. |
| Cleric | Sustain and protection | Health, Guard, Resistance | Proposed targeted healing/protection; exact slice is deferred. |
| Mage | Control and burst | spell Accuracy, Action Points | Trades durability for area damage and control. |

Specializations build on a proven root role: Warrior becomes Knight or Archer, Mage becomes Spellcaster or Battle Mage, Cleric becomes Healer or Paladin, and Scout becomes Ranger. A specialization never arrives before its root's core combat loop and counterplay are playable.

## Shared tactical attributes

Every combatant—adventurer or monster—uses one compact tactical profile. An adventurer persists base values in `GameSession`; equipment, perks, effects, and class features produce effective values when a battle unit is created. Monster templates are immutable data and are likewise copied into runtime `Unit` instances.

### Primary Attributes & Initial Character Creation
Character creation rolls primary attributes on a 1–10 scale based on class-specific ranges:
* **Warrior:** Strength 6–8, Intelligence 1–4 (higher Strength & Agility)
* **Scout:** Strength 4–6, Intelligence 3–5 (higher Agility)
* **Mage:** Strength 1–3, Intelligence 6–8 (higher Intelligence)
* **Priest:** Strength 4–5, Intelligence 4–6 (higher Piety)

Initial combat skills are calculated directly from primary attributes and class multipliers:
* **Base hit chance (`melee` and `missile`):** `(agility × 10 × class_multiplier)%`
  * Class multipliers: Warrior: 1.5, Paladin: 1.25, Scout: 1.0, Priest: 0.8, Mage: 0.5.
* **Max Health:** `vitality × level × perk_modifiers` (e.g., `Robust` and `Tank` perks grant percentage HP bonuses; `Glass Cannon` grants spell damage at the expense of a percentage HP penalty).

| Attribute | Type | Meaning |
|---|---:|---|
| `max_health` | integer | Damage capacity; a unit at zero is defeated (`vitality × level × modifiers`). |
| `might` | integer | Adds to melee or natural-attack raw damage. |
| `melee` | integer | Base chance to hit with melee weapons, expressed in percentage points. |
| `missile` | integer | Base chance to hit with missile weapons, expressed in percentage points. |
| `guard` | integer | Percentage points subtracted from an attacker's hit chance (`base_guard + armor_guard`, capped at 95%). |
| `spellcasting` | integer | Percentage points for spell capability and future high-level spell success. |
| `magic_resistance` | integer | Percentage points for negating or reducing effects of magic. |
| `resistance` | integer percent | Reduces damage after a hit (capped at 95%). |
| `action_points` | integer | Fixed base budget of 6 AP for movement, attacks, items, and abilities per Round. |

`attack_damage`/weapon damage remains an attack property, not a seventh unit attribute. This keeps a sword, a bow, a spell, and a monster bite able to use the same attributes while retaining their own range, damage, and tags.

### Skills leveled up by class

```
class             might |  melee | missile | guard | spellcasting
warrior           med      med     med       low     n/a
knight            med      hi      low       low     n/a
archer            low      low     hi        low     n/a
mage              n/a      n/a     low       n/a     med
spellcaster       n/a      n/a     low       n/a     hi
battlemage        low      med     low       low     med
scout/ranger      low      low     hi        low     n/a
priest            low      low     low       low     med
healer            low      low     low       low     hi
paladin           med      med     low       med     med      
```
Upon leveling up, skill point gains within specified tiers are determined by a **random roll** in the tier range:
* `low` = 1–2 points (random roll)
* `med` = 3–4 points (random roll)
* `hi`  = 4–5 points (random roll)

On level up, a dedicated **Level Up Screen** displays the increased skills. If the adventurer earns a perk point, a button is presented allowing the player to select a perk immediately (or defer selection to choose from the Unit Details screen at any time).

### Combat resolution

All accuracy, guard, and resistance values are percentage points.

```text
final hit chance = clamp(attacker melee_or_missile - defender guard, 5%, 95%)
raw damage       = rolled attack damage + attacker might
final damage     = max(1, round(raw damage × (1 - defender resistance / 100)))
```

* **Guard Stacking:** Armor Guard adds directly to unit Base Guard as a percentage (e.g., base Guard 30 + armor Guard 15 = 45% hit subtraction, capped at 95% total Guard).
* **Spell Resolution:** Guard applies exclusively to physical attacks. Basic spells always land (future high-level spells will check `spellcasting` vs unit level), but the defender rolls `magic_resistance` (`(magic_resistance - spellcasting) / 100`). A successful roll negates or reduces the spell effect (e.g., Fire Bolt damage halved). Future design includes total spell immunities (e.g., Fire Immunity) that cannot be overcome.
* **Maximum Resistance Cap:** Defender physical damage resistance and Guard subtraction are capped at 95%.

### Generic Action Points (Shipped foundation)

The shared [Movement and Action Points](movement-and-action-points.md) guide
defines the Round lifecycle, initial fixed 6-AP budget, action costs, legality,
player feedback, and extension constraints. Classes may change effective AP
only through an explicit, tested feature; they do not introduce a separate
class-specific action economy.

### Long-term concepts and Primary Attributes

Primary stats (`Strength`, `Agility`, `Vitality`, `Intelligence`, `Piety`, `Luck`) act as starting attribute generation rolls (1–10) and scaling foundations:

| Concept | Primary Attribute Role | Combat / Game Expression |
|---|---|---|
| Strength | Rolled 1–10 (Warrior 6–8, Mage 1–3) | Determines raw Might growth and future carrying capacity. |
| Agility | Rolled 1–10 (high for Warrior & Scout) | Determines base `melee` and `missile` hit % (`agility × 10 × class_multiplier`) and Dodge. |
| Vitality | Rolled 1–10 (high for Warrior) | Determines `max_health` (`vitality × level × modifiers`). |
| Intelligence | Rolled 1–10 (Mage 6–8) | Unlocks Mage spells and scales `spellcasting`. |
| Piety | Rolled 1–10 (Priest 4–6, Paladin high) | Unlocks Cleric/Paladin spells and healing potency. |
| Luck | Rolled 1–10 | Governs critical hits and loot-roll modifiers. |

## Advancement and perks

**Shipped compatibility:** a level currently grants 10 skill points. They raise raw Attack, which becomes `accuracy` in the shared tactical model. This manual allocation is a temporary implementation, not the target advancement model. The level-3 Bonus Move perk grants `+1 Action Point`.

**Approved replacement:** levels advance class-owned skills automatically; the player does not allocate a generic skill-point currency. A class declares the skills it owns and their level-up progression. Skills that do not belong to a class do not appear or advance for that adventurer—for example, Scouting belongs only to Scouts. Melee, missile, dodge, spellcasting, and scouting are examples of skill domains, not a required universal list.

The first implementation slice must define, in class data, each applicable skill's starting value, per-level gain, combat or campaign effect, UI presentation, save migration, and balance coverage. It must remove the manual Attack-spending flow rather than keeping two competing advancement systems.

**Perks:** every third level still grants one perk choice. Class-specific perks are choices from data-backed trees, with prerequisites, rather than separate attribute systems.

**Future:** perks can alter raw damage before Resistance, grant penetration, add movement, or introduce an active ability only with the supporting combat primitive. A perk description alone does not enable a mechanic.

### Generic perk themes

- **Might:** Rage increases raw melee damage; Strong Back waits for inventory weight.
- **Action Points/Guard:** Speed grants Action Points; Dodge waits for an avoidance system.
- **Health/Resistance:** Toughness increases Resistance; `Robust` (+% max HP) and `Tank` (+% max HP) increase health; `Glass Cannon` increases spell damage at the expense of a percentage penalty to `max_health`.
- **Knowledge:** Fast Learner may modify XP; perception waits for scouting.
- **Faith and luck:** Prayer and luck perks wait for their owning systems.

### Class perk inventory (Future unless its primitive is shipped)

- **Warrior / Knight:** Parry, Shield Bash, Chain Blow, and Thrust. Thrust is the first candidate once penetration exists.
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
