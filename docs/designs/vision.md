# Game Vision

## About

A deep tactical/strategic turn-based RPG in a fantasy setting.

The player controls units organized into parties. Battles provide strategic benefits (stronger units, loot) while strategic decisions affect game play (buildings, bonuses, units, equipment).

The game features a deep unit development aspect, such that losing a unit must hurt. Strategic choices have real impact on game play, as do tactical decisions on the progress of the game.

The game has an economic system based around trade and loot. As the player develops their encampment, they can craft high-level items to equip their units and sell for profit. In addition traders bring in passive income.

## Story

The game starts with a simple encampment. The player got a grant of land in exchange for quelling the monster incursions on the borderlands. Gradually the player gets enough strength and scouting ability to find and conquer dungeons. 

As the story unfolds, we find that dungeons are being generated through some magical means by an unknown foe. As the player conquers dungeons and explores, they find clues that lead them to the source of the incursions. A final climactic battle defeats the monster threat for good, although the player can continue the game, developing the town, and clearing out wandering monsters and naturally occurring dungeons.

## Gameplay

Turn based. Very deep both strategically and tactically, with many possible decions, but the gameplay loop itself is quite fast. The game ruthlessly eliminates any UI annoyances that get in the way of the action. For example, dialogs and modal choices are kept to the absolute minimum, and can usually be bypassed altogether. One example is battle themselves can be auto-resolved, or during a battle the control can be passed to the AI.

## RPG elements

Class system combined with attributes/skills/perks in line with Fallout 1/2.

## Tactical D&D style battles

Turn-based tactical combat in a fantasy setting. Think mix between XCOM and D&D.
Character development is heavily inspired by XCOM/Xenonauts and Fallout 1/2. In short:
* XP to level up
* On level up, skill points are distributed
* Every 3 levels, character can choose a perk (including chance to increase attribute score)

The other way to improve character power is through gear, which can be found through adventuring or crafted as town buildings lefvel up.

### Fog of war

On the battlefield, the player's view is limited to the line of sight of the units (but assume 360 degree view). Different units have different perception capabilities, which affects how far they can see and what they can perceive. The map status out of the player's line of sight grows "stale," so enemies might move into locations that the player has already seen.

### Dungeon crawling

In dungeons, players can move on the local map in a turn-based manner until entering a battle. Users can drag-select or CTL-select groups of units to move in unison--these will try to maintain the formation you have set for them, like in Baldur's Gate 1/2. Moving in and out of combat is like Fallout 1/2, but unlike Fallout 2, movement is still turn based out of combat.

### Action points

Unstead of set movement/attack phases, units get generic action points like XCOM or Fallout 1/2. Like XCOM, the player can choose a "move and attack" movement radius, which will show the moves the unit can make and still attack. Action points are a function of the Agility attribute.

### Healing

Units heal naturally over time, more if they don't move, and more if they are in the encampment. Various buffs can speed healing, including healing potions (found, bought or made), clerics, and presence of temple in encampment.

## Party management

The player starts with a single party of 4 members, but various research and buildings can increase the number and size of parties. I envision creating specialized parties like scouts, bandit hunting, and dungeon diving.

A rich unit and party UI is required, inspired by XCOM/Xenonauts: Recruitment, development/skill point/equipment, party formation, stats.

As the town develops, units become available for recruitment. The numbers and types of units depend on the town size and various buildings. For example, building and upgrading a temple attracts clerics and later paladins; building and upgrading a fighter's guild attracts warriors, and so on.

## Town management

The player starts out with a bare encampment. As they accumulate gold, they can attract various NPCs such as shopkeepers, blacksmiths, alchemists, and scholars. Various buildings give bonuses, provide gear, unlock spells and other abilities, provide training to recruits, and so on. Items and gold from dungeon diving fund the initial growth of the encampment into a settlement, but eventually the settlement becomes self sufficient and its income outpaces adventuring income. 

The player must tame and settle the area around the settlement for further growth, clearing out bandits and wandering monsters, protecting trade routes, and so on.

As trade routes are developed, traders come to the town. The number, quality, and types of traders depend on the safety of the trade routes, size of the town, and types of buildings (e.g. trader's guild). The player can also organize trading caravans which must be protected, with guards and/or patrols along trade routes.

Town management needs its own rich UI, although a true town-building experience is not needed. Something like the card-based town building in Rome: Total War is better. For example, building a temple to a certain god will attract clerics of that deity, and leveling up the temple will allow the recruitment of higher-level clerics/paladins and training for low-level recruits.

## World map

The world should play somewhat like Civ, although instead of warring against other nations, the player wars against the monster threat.

### Fog of war

There is a fog of war on the world map. The city has a fixed vision radius, which can be improved with buildings (watchtowers & upgrades). Beyond the vision radius, information about enemy parties and POIs becomes increasingly vague.

Units also have vision ability, enhanced by various unit capabilities. Scout/thief type units should have a major value here which somewhat compensates for their relatively poor combat ability.