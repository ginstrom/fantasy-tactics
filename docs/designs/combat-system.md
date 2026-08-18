# Combat System

## Time Units & Environment

* **Combat Round:** In combat, the unit of time is **Round**. Every eligible unit acts during a Round.
* **World Map Turn:** On the world map, time advances in **Turns**. World map turn time is frozen while a party is in an encounter; players can manage inventory, encampment, and shop, but world map turns do not advance until the battle resolves.

## Attacking and Damage

Physical to-hit chance is based on the attacker's hit attribute (`melee` or `missile`) minus the target's `guard`, plus/minus modifiers, clamped between 5% and 95%:
```text
final hit chance = clamp(attacker melee_or_missile - defender guard, 5%, 95%)
```

### Melee Attacks
To-hit chance is governed by the `melee` attribute versus defender `guard`.

### Missile Attacks
To-hit chance is governed by the `missile` attribute versus defender `guard`.

### Spells and Magic Resistance
Guard applies exclusively to physical attacks and does not affect spells. Spells initially succeed automatically (future design will use `spellcasting` to determine success for high-level spells relative to unit level). Defenders roll `magic_resistance` (`(magic_resistance - spellcasting) / 100`). A successful roll negates or reduces the spell effect (e.g., Fire Bolt damage reduced by half). Future immunities (e.g., Fire Immunity) cannot be overcome by spellcasting level.

## Defending

### Guard
Unit `guard` subtracts percentage points directly from an attacker's hit chance. Effective Guard is calculated as `base_guard + armor_guard_bonus` (e.g., base Guard 30 + armor Guard 15 = 45% hit subtraction, capped at 95% total Guard). (Note: Future armor bulk will add movement and dodge penalties, but is deferred for initial implementation).

### Damage Resistance
Damage resistance reduces incoming physical damage after a hit lands, capped at 95%:
```text
final damage = max(1, round(raw damage × (1 - defender damage resistance / 100)))
```
It is mainly provided by armor, but can be modified by spells, perks, and items.

### Critical Hits

Any successful weapon hit has a natural 5% chance to land a criticl hit. This increases the inflicted damage by 50% and reduces enemy damage resistance by 20%.

### Dodge
A small chance of evading an incoming attack. On a successful dodge, the attacker becomes off-balanced during their next round (-10% Guard).

### Parry
A small chance of evading an incoming melee attack. On a successful parry, the attacker is off-balanced (-10% Guard), and the defender gains a counter-bonus (+10% `melee` to-hit against that same attacker on their next turn).

## Cover, Flanking, and Opportunity Attacks

### Cover
Cover provides a direct bonus to `guard` against missile attacks:
* **Low Cover:** +25% Guard against missile attacks.
* **High Cover:** +50% Guard against missile attacks.

### Facing

Units face left, right, up, or down. This impacts flanking and attacks of opportunity (see below).

A player can chang the facing of a unit during their turn by right clicking in the direction the selected used should be faced.

Also, if a unit is hit by an attack, its facing will automatically be changed to the direction of the attack. The facing can only be changed in this way once during a round.

Ths facing mechanic models the mechanic in Xenonauts.

### Flanking
Attack angles provide tactical modifiers:
* **Side / Oblique Flank:** -20% defender Guard, +20% critical hit chance.
* **Rear Flank:** -50% defender Guard and +50% critical hit chance.

Flanking works as follows.

F = front, S = side, R = rear

Facing left:
```
  F S S
  F < R
  F S S
```
Facing up:
```
  F F F
  S ^ S
  S R S
```

Note that attacks from diagonal are allowed, although not movement.

### Attacks of Opportunity
If a unit moves out of a tile adjacent to an enemy, that enemy immediately gets a free melee attack against the moving unit at a -10% `melee` hit penalty.

## Action Points & Item Costs

Action points are a generic budget (fixed base of 6 AP per unit per Round) used for tactical actions:
* **Movement:** 1 AP per tile.
* **Basic Attack:** 3 AP.
* **Consume Potion:** 2 AP.
* **Use Tactical Item:** 2 AP.
* **Transfer Item to Adjacent Unit:** 2 AP.

## Enemy Info & Line of Sight

### Line of Sight
Players do not have omniscient vision of the battlefield. Visibility is limited to the units' line of sight (assuming 360-degree view). Out-of-sight areas grow "stale."

### Enemy Info
The accuracy and detail of enemy status depend on proximity and the party's best scouting score.

## Conditions, Wounds, and Status Effects

Conditions and debuffs alter combat attributes.
* **Spells & Perks:** Apply temporary combat bonuses or penalties.
* **Wounds:** Physical degradation based on current health:
  * **50% or less Max HP:** -10% to all combat stats, available AP, and world map movement speed.
  * **Under 20% Max HP:** -25% to all combat stats, available AP, and world map movement speed.


