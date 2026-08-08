# Game Trading System

## Trade screen

Make sure Trade screens have the encampment navigation menu on the left, and we follow the @docs/UI-Layout-Design-Guidelines.md 

This screen starts with a [Stores] menu option, and an option to purchase a Trading Post for 50 gold.

### Stores screen

From here we can go do a table view of the company stores: things we have purchased and loot brought back. The table includes the item name, type (e.g. weapon), count, and sale price. The sale price starts at half the purchase price.

From this table, if we have a Trading Post, we can sell items from here. If we have recruited units, we can assign equipment to units from here. Assign --> unit list --> assign to unit.

### Trading Post screen

The Trading Post generates passive income of 1 gold per turn, and allows us to buy and sell equipment/loot. As with the Guild Hall, we will be able to upgrade the trading post over time for more income and better gear to buy.

## Equipment system

Instead of damage being an attribute of a unit, it is a function of weapons.

Iron:
dagger: 1-4 (kobold)
short sword: 1-6 (goblin)
longsword: 1-8 (warrior, orc)
two-handed sword: 1-10 (hobgoblin)

Steel weapons give +1 damage. Warriors start with iron weapons as do enemies.

Armor has two protections: defense and resistance.
Defense lowers enemy's to-hit chance, to a minimum of 5%. Defense of 10 reduces to-hit by 10%.
Resistance reduces incoming damage by that %. A resistance of 10% reduces incoming damage by 10%, so 10 damage becomes 9. Damage is calculated as fractional values but rounded to nearest integer when applied.

Leather armor: 10/10
Chainmail armor: 15/20
Split armor: 15/25
Platemail armor: 15/30
Full plate armor: 15/35

Warriors start with leather armor.

Prices:
Weapon               |  Iron   Steel
Dagger               |  10     30
Shortsword           |  20     60
Longsword            |  30     90
Two-handed sword     |  35     105

Leather armor: 10
Chainmail armor: 30
Split armor: 50
Platemail armor: 200
Full plate armor: 500

## Loot 

This replaces the current reward system for clearing encounters. Instead, enemies drop loot which is recovered after winning the encounter. In the future, we will also find loot in chests for dungeons.

### Mana crystals

Enemies drop mana crystals, which can be sold or used to craft magical items.

Tier / value / enemy types
1      5       kobold, goblin
2      15      orc, hobgoblin

### Gold and items

In addition to mana crystals, enemies have a chance to drop gold and loot
Gold is always dropped, while gear has a 25% drop chance (this will be modified in the future by the luck ability).

Enemy / gold / loot
kobold / 0-5 / dagger
goblin / 1-6 / short sword
orc / 1-5 x 2 / longsword
hobgoblin / 1-4 x 3 / two-handed sword

### Storing loot

When a party wins an encounter, the loot they carry appears in the party view.

When a party returns to the encampment with loot, the loot, including gold is banked in the encampment. The gold appears in the encampment view as now, but players can also go to Trade -> Stores and view all stored gear, including the banked loot. the Stores screen also shows mana crystals.
