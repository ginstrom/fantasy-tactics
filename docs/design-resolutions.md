# Design Resolutions

This document catalogs all ambiguities, cross-document conflicts, missing mathematical formulas, and open design questions identified across the design documentation in [`docs/designs/`](designs).

For each issue, a concise summary of the ambiguity is provided along with the design decision required. Spaces are provided under **Decision** for recording approved design choices.

---

## 1. Character Attributes & Class Progression

### 1.1 Primary Attributes (Fallout 1/2) vs. 9-Attribute Profile
* **Ambiguity / Conflict**: [`vision.md:L28, L52-53`](designs/vision.md#L28) mandates Fallout-style primary attributes (`Strength`, `Agility`, `Vitality`, `Intelligence`, `Piety`, `Luck`) where AP scales with Agility. Conversely, [`class-system.md:L20-33, L78-92`](designs/class-system.md#L20-L33) rejects primary stats as persisted variables, defining a standard 9-attribute combat profile (`max_health`, `might`, `melee`, `missile`, `guard`, `spellcasting`, `magic_resistance`, `resistance`, `action_points`) and [`movement-and-action-points.md:L28`](designs/movement-and-action-points.md#L28) mandates a fixed base 6 AP for all units.
* **Design Decision Needed**: Confirm whether primary stats (`Strength`, `Agility`, etc.) remain unpersisted abstraction vocabulary, and confirm AP is fixed at a base of 6 for all units.

**Decision**:
> The initial stats are determined by a combination of the dominating attribute(s) and class. So for example, base melee and missile to hit are `(agility * 10 * class_multiplier)%`
class multiplers:
warrior: 1.5
mage: .5
priest: .8
paladin: 1.25
scout: 1

Ability rolls are 1-10 with a range by class; higher range of strength and agility for warriors, higher agility for scouts, higher intelligence for mage, higher piety for priests

For example, 

intelligence:
* warrior: 1-4
* mage: 6-8
* priest: 4-6
* scout: 3-5

strength:
* warrior: 6-8
* mage: 1-3
* priest: 4-5
* scout: 4-6

Additionally, as characters level up their skills are increased according to their class (e.g. high might and melee for knights)

---

### 1.2 Single `accuracy` vs. Dual `melee` / `missile` Attributes
* **Ambiguity / Conflict**: [`class-system.md:L26-27`](designs/class-system.md#L26-L27) splits hit chance into `melee` and `missile`, but uses `attacker accuracy` in formulas ([`L61`](designs/class-system.md#L61)). [`monster-manual.md:L38`](designs/monster-manual.md#L38) defines a single `accuracy` attribute for monsters. [`combat-system.md:L5`](designs/combat-system.md#L5) uses generic `attack skill`.
* **Design Decision Needed**: Decide if monsters will adopt separate `melee` and `missile` attributes (or if `accuracy` acts as a fallback for both), and confirm generic formula parameter naming.

**Decision**:
> Monsters have all the skills of units, although some will be 0 if not applicable (e.g. spellcasting for goblin warriors). The same battle mechanics are applied to units and enemies, and some enemies such as brigands are actual unit types.

---

### 1.3 `max_health` Formula & Vitality
* **Ambiguity / Conflict**: [`class-system.md:L24`](designs/class-system.md#L24) defines `max_health = vitality * level`, but lines [`L80, L86`](designs/class-system.md#L80) state `Vitality` is not a persisted attribute. Level baseline tables ([`monster-manual.md:L18-20`](designs/monster-manual.md#L18-L20)) show +10 HP per level for Warriors, while perks can also increase `max_health` ([`class-system.md:L108`](designs/class-system.md#L108)).
* **Design Decision Needed**: Specify the standard `max_health` growth formula per class level independent of `vitality`.

**Decision**:
> As with character attributes above, `max_health` is calculated from Vitality (`vitality * level`) with some modifiers; e.g. `robust` and `tank` perks for knights will give a bonus % increase. Likewise a `glass canon` perk for mages will increase spell damage at the expense of applying a % penalty to `max_health`

---

### 1.4 Missing Cleric, Healer, and Paladin in Skill Progression Table
* **Ambiguity / Conflict**: [`class-system.md:L42-51`](designs/class-system.md#L42-L51) defines per-level skill gain tiers (`low`/`med`/`hi`) for Warrior, Knight, Archer, Mage, Spellcaster, Battlemage, and Scout/Ranger, but omits Cleric, Healer, and Paladin entirely.
* **Design Decision Needed**: Define the skill gain tiers (`might`, `melee`, `missile`, `guard`, `spellcasting`, etc.) for Cleric, Healer, and Paladin.

**Decision**:
> Added to @designs/class-system.md

---

### 1.5 Deterministic vs. Random Skill Gains per Level
* **Ambiguity / Conflict**: [`class-system.md:L52-54`](designs/class-system.md#L52-L54) defines skill growth tiers as point ranges: `low = 1-2 points`, `med = 3-4 points`, `hi = 4-5 points`.
* **Design Decision Needed**: Clarify whether skill points gained on level-up are deterministic fixed values per tier (e.g. `low = 1`, `med = 3`, `hi = 4`) or random rolls within the range.

**Decision**:
> Skill gain is a random roll in the specified range

On level up, we show a level up screen showing increased skills, Additionally, if the character has a perk point, a button appears allowing the unit to select a perk (or defer and choose from the unit details screen at any time).

---

## 2. Combat Resolution & Mathematical Formulas

### 2.1 Magic Resistance & Spell Hit Resolution Formula
* **Ambiguity / Conflict**: [`class-system.md:L38`](designs/class-system.md#L38) states `Chance of magic resistance = (magic_resistance - spellcasting) / 100`. It is unclear if spell success is checked first using `spellcasting` vs `guard`, how negative results are clamped, and whether `resistance` or `magic_resistance` reduces magical damage.
* **Design Decision Needed**: Define the complete spell combat resolution pipeline: spell hit roll, magic resistance roll/mitigation, damage calculation, and clamping boundaries.

**Decision**:
> Guard is only for physical attacks. In the future, spellcasting will also be used to determine success for high-level spells relative to the unit's level, but at first spells always succeed, but some may be negated or reduced in effect by a successful magic resistance. For example, fire bolt can be reduced by half.

Additionally in a future design there will be immunities that cannot be overcome by any spellcasting level (e.g. immunity to fire).

---

### 2.2 Armor Guard vs. Unit Base Guard Stacking
* **Ambiguity / Conflict**: [`equipment-handbook.md:L38-44`](designs/equipment-handbook.md#L38-L44) assigns `Defense/Guard` values to armors (e.g., Chainmail = 15). [`class-system.md:L43-51`](designs/class-system.md#L43-L51) assigns per-level base `Guard` growth to classes.
* **Design Decision Needed**: Specify whether effective unit Guard is `base_guard + armor_guard` or if armor Guard overrides base Guard.

**Decision**:
> Armor is added to guard as a percent, so guard 30 + armor 15 = 15% chance of avoiding hit, capped at 95%.

Later, armor bulk will also give a penalty to movement (world map and battle AP cost) and dodge, but not for the first implementation.

---

### 2.3 Undefined Tactical Combat Subsystems
* **Ambiguity / Conflict**: [`combat-system.md:L31-57, L81`](designs/combat-system.md#L31-L57) describes Dodge, Parry, Cover, Flanking, Attacks of Opportunity (AoO), and Wounds with qualitative phrasing ("small chance", "oblique attack", "heavier wounds") without concrete math, AP costs, or triggers.
* **Design Decision Needed**: Approve formal rules and formulas for:

**Decision**:
  1. Dodge % and off-balance trigger/effect: -10% defense
  2. Parry % and counter-bonus effect: -10% defense, +10% melee
  3. Cover defense bonuses and directionality: 25% for low cover, 50% for high cover added to defense from missile attacks
  4. Flanking angles and damage multipliers: side flank: -20% defense; rear flank: -50% defense, +50% damage
  5. Attacks of Opportunity AP/reaction consumption rules: if a unit moves from an adjacent space from an enemy, the enemy gets a free melee attack at -10% melee to-hit.
  6. Wound health thresholds and stat debuffs: 50% or less of max HP: -10% to all combat stats, AP, and speed on world map; < 20%: -25% to all

---

## 3. Equipment, Inventory & Crafting

### 3.1 Item Base IDs vs. Unique Instance Identifiers
* **Ambiguity / Conflict**: [`weapon-armor-inventory.md:L24-31`](designs/weapon-armor-inventory.md#L24-L31) assumes `weapon_inventory` stores base item IDs (`"longsword_iron"`) and stat lookup functions read string pointers directly. [`equipment-handbook.md:L48-64`](designs/equipment-handbook.md#L48-L64) introduces unique instance IDs (`"gear_00042"`) for upgraded items.
* **Design Decision Needed**: Specify whether `weapon_inventory` holds base item IDs for un-modified items and instance IDs for modified items, and define how active equipment stat queries resolve instance IDs to base definitions + modifiers.

**Decision**:
> All items have the same representation; base weapons just have their improvements slots empty and can be stacked. In the Shop we can only stack like with like, so expect to see things like:
```
Item                         Type     Qty   Sale Price
Iron Longsword               Weapon   3     10
Sharpened Iron Longsword     Weapon   1     10
```


---

### 3.2 Multiple Alchemical Enhancements in Schema
* **Ambiguity / Conflict**: [`equipment-handbook.md:L82`](designs/equipment-handbook.md#L82) states different enhancement families (e.g. Accuracy + Guard) may coexist on one item, but the instance JSON schema ([`L52-59`](designs/equipment-handbook.md#L52-L59)) only provides a single scalar field: `"enhancement_id": "accuracy_advanced"`.
* **Design Decision Needed**: Approve an updated instance JSON schema supporting multiple enhancement families (e.g. `"enhancements": ["accuracy_advanced", "guard_basic"]` or a key-value dictionary).

**Decision**:
> We can only have one enhancement of each type (or a fixed number of runes, varying by item). So it should be like this (yaml for simplicity of presentation):
```
enhancements:
    smithing: None
    enchantment: accuracy_1
    runes: [bleed]
```

---

### 3.3 Displaced Rune Outcome on Replacement
* **Ambiguity / Conflict**: [`equipment-handbook.md:L97`](designs/equipment-handbook.md#L97) states replacing a socketed rune requires an explicit result for the displaced rune (return, consume, or salvage) but does not mandate a default outcome.
* **Design Decision Needed**: Define the default rule when socketing a new rune over an existing one (e.g. Destroyed, Returned to Stores, or Salvaged into Mana Crystals).

**Decision**:
> A removed rune is returned to the Stores

Later we will add a scrapping mechanic that lets us break down items for base materials


---

## 4. Action Points & Exploration Economy

### 4.1 Out-of-Combat Dungeon Exploration AP & Movement
* **Ambiguity / Conflict**: [`vision.md:L48-49`](designs/vision.md#L48-L49) specifies turn-based dungeon exploration out of combat (Baldur's Gate / Fallout style). [`movement-and-action-points.md`](designs/movement-and-action-points.md) specifies AP strictly for active battle rounds.
* **Design Decision Needed**: Define how AP and movement function out of combat during dungeon exploration (e.g., continuous AP refresh, free party movement until line-of-sight contact, or turn-based exploration ticks).

**Decision**:
> Free party movement until battle triggered (usually line of sight of enemy, but there may be trigger distances)

---

### 4.2 In-Combat Potion & Item Usage AP Costs
* **Ambiguity / Conflict**: [`combat-system.md:L61`](designs/combat-system.md#L61) states AP is used for "using/sharing items", but [`equipment-handbook.md:L85`](designs/equipment-handbook.md#L85) states potion AP costs remain unshipped, and [`movement-and-action-points.md:L40-45`](designs/movement-and-action-points.md#L40-L45) only details movement (1 AP) and basic attacks (3 AP).
* **Design Decision Needed**: Define exact AP costs for consuming a potion, using a tactical item, and transferring an item to an adjacent unit during battle.

**Decision**:
> 
potion: 2 AP
tactical item: 2 AP
transfer: 2 AP

---

## 5. Naming & Terminology Standardization

### 5.1 Standardization of `attack`/`defense` vs. `accuracy`/`guard` vs. `melee`/`missile`
* **Ambiguity / Conflict**: Shipped code uses `attack`/`defense`; [`combat-system.md:L5`](designs/combat-system.md#L5) uses `attack skill`/`defense skill`; [`monster-manual.md:L38`](designs/monster-manual.md#L38) uses `accuracy`/`guard`; [`class-system.md:L26-28`](designs/class-system.md#L26-L28) uses `melee`/`missile` and `guard`.
* **Design Decision Needed**: Confirm official domain vocabulary across code and documentation:
  * `melee` / `missile`: Base hit percentage attributes.
  * `guard`: Attacker hit subtraction attribute.
  * `resistance`: Post-hit damage reduction percentage.

**Decision**:
> melee / missile, guard, damage resistance, spell resistance

---

### 5.2 Standardization of `Turn` vs. `Round`
* **Ambiguity / Conflict**: [`movement-and-action-points.md:L17`](designs/movement-and-action-points.md#L17) strictly reserves `Round` for combat cycles and `Turn` for World Map turns, but [`combat-system.md:L34`](designs/combat-system.md#L34) uses "next round" to refer to an individual unit's phase.
* **Design Decision Needed**: Reaffirm standard definition: `Round` = full battle cycle where all eligible units act; `Turn` = a single unit's active phase within a Round OR a World Map turn.

**Decision**:
> In combat, the unit of time is "round." On the world map, the unit of time is "turn".

Effectively "turn" time is frozen while a party is in an encounter; we can view the world map and encampment and make decisions, buy & sell, etc., but can't advance the turn until the encounter is resolved.

Turn is also the unit of time for determining repopulation of encounters, recruitable units, crafting, etc.
