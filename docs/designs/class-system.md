# Classes

* Warrior
  * Knight
  * Archer
* Mage
  * Spellcaster
  * Battle mage
* Cleric
  * Healer
  * Paladin
* Scout

# Attributes, skills, perks

## Attributes
* Strength (melee damage, carry weight)
* Agility (action points, dodge)
* Vitality (hit points)
* Intelligence (mana points, mage spell ability)
* Piety (clerical spell ability)
* Luck (critical chance, loot drops, some other die rolls)

## Skills
* Melee attack (hit chance)
* Missile attack (hit chance)
* Scouting
* Find traps
* Open locks

## Perks

There are two perk trees: one generic and largely based on attributes, one class-specific.
Additionally, units can spend perk points to raise an attribute by 1 point.

Perks are in a tree, and some have prerequisites.

### Generic perk tree

* (root)
  * strength
    + damage 1 (+5%) -> shield bash -> damage 2 (+10%) -> strong back (+ carry weight)
  * agility
    + dodge 1 (+5% dodge) -> off balance (miss leaves enemy off balance) -> dodge 2 (+10% dodge)
  * vitality
    + toughness 1 (+5% damage resistance) -> survivability (+5% HP) -> toughness 2 (+10% dr)
  * intelligence
    + fast learner 1 (+5% XP) -> perception (+10% scouting) -> fast learner 2 (+10% xp)
  * piety
    + prayer 1 (+10% to defensive buffs) -> prayer 2 (+20% to defensive buffs)
  * luck
    + rabbit foot (+1% to luck rolls) -> horseshoe (+2% to luck rolls) -> four leaf clover (+3% to luck rolls)

### Warrior perk tree

* (root)
  * Knight
    * Parry 1 (5% chance to parry enemy attack, 5% for enemy off-balance 1 round when missed)
      -> fast attack 1 (+2 action points for melee attacks)
      -> parry 2 (10%/10% parry/off-balance)
      -> fast attack 2 (+4 action points for melee attacks)
  * Archer
    * Lock on 1 (+5% to hit rolls for 2nd and subsequent attack against same foe)
      -> fast attack 1 (+2 action points for missile attacks)
      -> lock on 2 (+10% to hit rolls for 2nd and subsequent attack against same foe)
      -> fast attack 2 (+4 action points for missile attacks)