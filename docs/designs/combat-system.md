# Combat System

## Attacking and damage

To-hit chance is based on the attack skill minus the target's defense skill,
plus/minus buffs, clamped between 5% and 95%. 

### Melee

To-hit is goverend by the melee attack skill.

### Missile

To-hit is goverend by the missile attack skill.

## Defending

To-hit chance is based on the attack skill minus the target's defense skill,
plus/minus buffs, clamped between 5% and 95%. 

### Defense

Defense skill is subtracted from the enemy's attack score.

### Damage resistance

The damage resistance score of the unit is the reduction in incoming damage,
with a ceiling of 95%. It is mainly gained from armor, but various spells,
perks, and items can contribute.

### Dodge

A small chance of evading an incoming attack. For a melee attack, on successful
dodge there is a small chance of off-balancing the enemy's next round.

### Parry

A small chance of evading an incoming melee attack. On successful
parry there is a small chance of off-balancing the enemy's next round, and
likewise a small chance of adding a bonus to the unit's next to-hit against the
same enemy.

## Cover and flanking

### Cover

Cover has a value that is added to the unit's defense score. 

### Flanking

If a unit is attacked obliquely, the attacker gets a bonus to hit. Attacks from
behind give an even better to-hit bonus and a damage multiplier.

### Attacks of opportunity

If a unit is adjacent to an enemy and moves away from it, then the enemy gets a
bonus melee attack against the unit.

## Action points

Action points are generic and used for all battle actions: movement, attacks,
and using/sharing items.

## Enemy info

The player does not get to see all information about an enemy. The
quality/accuracy of the information depends on how close the enemy is, and the
party's best scouting score.

### Line of sight

The player does not have an omnicent view of the battlefield. They can only see
what is in their units' line of site (assuming 360 degrees).

## Conditions and buffs/debufs

Various conditions, buffs, and debugs can affect combat. Some examples:

* Spells (attack and defense bonuses/penalties)
* Perks (e.g. lock on)
* Wounds (heavier wounds decrease combat skills)

