# Classes

* Warrior
  * Knight
  * Archer
* Mage
  * Spellcaster
  * Battle Mage
* Cleric
  * Healer
  * Paladin (available only after building a high-level Temple)
* Scout
  * Ranger

## Class roles and power curves

Classes are not intended to have equal combat power at every level.

* Warriors begin strong and remain dependable front-line fighters.
* Mages begin weak and resource-constrained, but Spellcasters gain the
  highest late-game damage and control ceiling.
* Clerics deal little direct damage, but healing, protection, and debuffs
  make the party more resilient.
* Paladins are a Cleric/Warrior compromise. Their late Temple recruitment
  gate and distinctive holy perks justify a stronger late-game profile.
* Rangers are weaker direct missile fighters than Archers. Their strength is
  scouting: revealing information that improves expedition and battle choices.

# Attributes, skills, perks

## Attributes

* Strength (melee damage, carry weight)
* Agility (action points, dodge)
* Vitality (hit points)
* Intelligence (magic points, spell ability)
* Piety (clerical spell ability, defensive buffs)
* Luck (critical chance, loot drops, some other die rolls)

There are two derived attributes:

* Hit points (HP): vitality x level
* Magic points (MP): intelligence x level

## Skills

* Melee attack (raw to-hit)
* Missile attack (raw to-hit)
* Scouting

## Combat resolution

Defense and Damage Resistance are distinct defenses. All bonuses and
reductions below are percentage points unless they explicitly say otherwise.

* **Defense** reduces raw to-hit. Apply the final to-hit cap after Defense:
  `final to-hit = clamp(raw to-hit - target Defense, 5%, 95%)`.
  Raw to-hit may exceed 95%; for example, 120% raw to-hit against 50%
  Defense results in 70% final to-hit.
* **Damage Resistance** reduces damage after a successful hit. Penetration
  reduces the target's Resistance for that attack:
  `effective Resistance = clamp(target Resistance - penetration, 0%, 80%)`.
  `final damage = max(1, round(raw damage x (1 - effective Resistance)))`.
* Damage bonuses, such as Rage, modify raw damage before Damage Resistance.
  Penetration and raw-damage bonuses therefore have different jobs:
  penetration is especially valuable against resistant targets.

## Perks

There are two perk trees: one generic and largely based on attributes, one
class-specific. Additionally, units can spend perk points to raise an
attribute by 1 point.

Perks are in a tree, and some have prerequisites.

### Generic perk tree

* (root)
  * strength
    + rage 1 (+5% raw melee damage)
      -> rage 2 (+5% raw melee damage)
      -> strong back (+ carry weight)
  * agility
    + dodge 1 (+5% dodge) -> off balance (a miss leaves the enemy off
      balance) -> dodge 2 (+5% dodge)
    + speed 1 (+2 action points) -> speed 2 (+2 action points)
  * vitality
    + toughness 1 (+5% Damage Resistance) -> survivability (+5% HP)
      -> toughness 2 (+10% Damage Resistance)
  * intelligence
    + fast learner 1 (+5% XP) -> perception (+10% scouting)
      -> fast learner 2 (+10% XP)
  * piety
    + prayer 1 (+10% to defensive buffs) -> prayer 2 (+20% to defensive buffs)
  * luck
    + rabbit foot (+1% to luck rolls) -> horseshoe (+2% to luck rolls)
      -> four leaf clover (+3% to luck rolls)

### Warrior perk tree

* (root)
  * Knight (+5% melee attack)
    * parry 1 (5% chance to parry an enemy attack; a parried enemy has a 5%
      chance to become off balance for 1 round)
      -> fast attack 1 (+2 action points for melee attacks)
      -> parry 2 (10%/10% parry/off-balance)
      -> fast attack 2 (+4 action points for melee attacks)
    * shield bash (extra shield attack; low damage but off-balances)
      -> shield wall (10% chance to negate an enemy attack with a shield)
      -> chain blow 1 (on hit, 10% chance to attack a nearby enemy)
      -> chain blow 2 (on hit, 20% chance to attack a nearby enemy)
    * thrust 1 (melee attacks ignore 10% Damage Resistance)
      -> thrust 2 (melee attacks ignore 20% Damage Resistance)
  * Archer (+5% missile attack)
    * lock on 1 (+2% raw to-hit per prior consecutive attack against the same
      target, up to +4%)
      -> fast attack 1 (+2 action points for missile attacks)
      -> lock on 2 (maximum Lock On bonus becomes +8%)
      -> fast attack 2 (+4 action points for missile attacks)
    * piercing arrow 1 (missile attacks ignore 10% Damage Resistance)
      -> piercing arrow 2 (missile attacks ignore 20% Damage Resistance)
    * called shot 1 (+10% raw missile to-hit for 2 rounds; cooldown 10 rounds)
      -> called shot 2 (+15% raw missile to-hit for 3 rounds; cooldown 10 rounds)

### Mage perk tree

* (root)
  * Spellcaster (+10 MP)
    * sleep -> mass sleep -> charm -> mass charm
    * fire arrow (ignores 10% Damage Resistance) -> fire arrows (3x; ignores
      20%) -> fireball (ignores 30%) -> fire storm (ignores 30%)
    * quicken -> haste -> quicken all -> haste all
  * Battle Mage (+3% melee attack)
    * ice bolt -> ice blast -> ice storm
    * mage shield -> mage armor -> mage shell
    * magic blade (melee attacks ignore 10% Damage Resistance)
      -> enchanted blade (ignore 20%) -> eldritch blade (ignore 30%)

### Cleric perk tree

* (root)
  * Healer (+5 heal)
    * extra heal -> heal all -> extra heal all
    * bless -> prayer -> holy shield
    * curse (-5% Defense and -5% Damage Resistance) -> doom (-10% Defense
      and -10% Damage Resistance) -> paralyze -> paralyze group
  * Paladin (+5% melee attack; Temple recruitment only)
    * blessed sword (melee attacks ignore 10% Damage Resistance)
      -> holy sword (ignore 20%) -> smiting sword (ignore 30%)
    * boon -> might -> holy might

## Scout perk tree

* Ranger (+3% missile attack)
  * scout 1 (+10% scouting)
      -> tracker 1 (reveals enemy Defense and Damage Resistance before battle)
      -> scout 2 (+10% scouting)
      -> tracker 2 (also reveals enemy composition and abilities)
      -> scout 3 (+10% scouting)
  * hunter's mark (one target suffers -10% Damage Resistance from all party
      attacks for 2 rounds; cooldown 8 rounds)
