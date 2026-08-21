# Game Vision

## About

A deep tactical/strategic turn-based RPG in a fantasy setting. The first
complete experience is a compact, 60–90 minute Borderlands campaign: recruit
and deploy a party, clear authored objectives, return with loot to improve the
Encampment, and ultimately defeat the source of the incursions. See the
[Borderlands Campaign Loop](campaign-loop.md) for its locked progression,
defeat, and recovery contract.

The player controls units organized into parties. Battles provide strategic benefits (stronger units, loot) while strategic decisions affect game play (buildings, bonuses, units, equipment).

The game features a deep unit development aspect. Units start out relatively weak, but gradually gain enough power for a party of 5-6 heroes to take on entire monster armies.
The progression should feel hard-earned such that losing a unit is painful. 

Strategic choices have real impact on game play, as do tactical decisions on the progress of the game.

The game has an economic system based around trade and loot. As the player develops their encampment, they can craft high-level items to equip their units and sell for profit. In addition traders bring in passive income.

## Story

The game starts with a simple encampment. The player got a grant of land in exchange for quelling the monster incursions on the borderlands. Gradually the player gets enough strength and scouting ability to find and conquer dungeons. 

As the story unfolds, we find that dungeons are being generated through some magical means by an unknown foe. As the player conquers dungeons and explores, they find clues that lead them to the source of the incursions. A final climactic battle defeats the monster threat for good, although the player can continue the game, developing the town, and clearing out wandering monsters and naturally occurring dungeons.

## Gameplay

Turn based. Very deep both strategically and tactically, with many possible decions, but the gameplay loop itself is quite fast. The game ruthlessly eliminates any UI annoyances that get in the way of the action. For example, dialogs and modal choices are kept to the absolute minimum, and can usually be bypassed altogether. One example is battle themselves can be auto-resolved, or during a battle the control can be passed to the AI.

## RPG elements

Class system combined with primary attributes (`Strength`, `Agility`, `Vitality`, `Intelligence`, `Piety`, `Luck`) rolled at creation (1-10 within class-specific ranges) to determine initial combat stats (e.g. base `melee`/`missile` hit % = `agility * 10 * class_multiplier %`), alongside a standardized combat attribute profile (`max_health`, `might`, `melee`, `missile`, `guard`, `spellcasting`, `magic_resistance`, `resistance`, `action_points`), skills, and perks.

## Tactical D&D style battles

Turn-based tactical combat in a fantasy setting. Think mix between XCOM and D&D.
Character development is heavily inspired by XCOM/Xenonauts and Fallout 1/2. In short:
* XP to level up
* On level up, class-appropriate skills advance automatically (random roll within tier ranges). A unit only
  advances skills its class uses—for example, only Scouts develop Scouting.
* Every 3 levels, character can choose a perk (including a chance to increase
  an attribute score)

The other way to improve character power is through gear, which can be found through adventuring or crafted as town buildings level up.

### Fog of war

On the battlefield, the player's view is limited to the line of sight of the units (but assume 360 degree view). Different units have different perception capabilities, which affects how far they can see and what they can perceive. The map status out of the player's line of sight grows "stale," so enemies might move into locations that the player has already seen.

### Dungeon crawling

In dungeons, players have free party movement out of combat (moving in formation, like Baldur's Gate 1/2) until a battle is triggered (usually upon establishing line of sight with an enemy or entering a trigger distance), at which point tactical turn-based combat begins.

### Action points

Instead of set movement/attack phases, units get a generic action point budget (fixed base of 6 AP for all units). Like XCOM, the player can choose a "move and attack" movement radius, which will show the moves the unit can make and still attack.

### Healing

Units recover 1 HP/2 MP while moving, 2 HP/4 MP while stationary, and 3 HP/6
MP while in the Encampment each World Map Turn. Each Temple tier adds 1 HP to
Encampment recovery. Healers can spend their MP from their details view to
restore a party member's HP in the field or an adventurer's HP at the
Encampment, creating a useful medic-corps role for Clerics. Healing potions
and a future mana-recovery potion can speed this recovery. See the
[Borderlands Campaign Loop](campaign-loop.md#encampment-progression-and-economy-floor)
for the authoritative recovery rules and deferred healing balance.

## Party management

The first campaign has exactly one active party. It begins with three
deployable slots; Guild Hall upgrades raise that to four and then five. The
initial roster may contain more adventurers than can deploy. Multi-party
coordination is a core strategic design, but remains deferred implementation
work beyond the first campaign.

A rich unit and party UI is required, inspired by XCOM/Xenonauts: recruitment,
development/skills/equipment, party formation, and stats.

As the town develops, units become available for recruitment. The numbers and types of units depend on the town size and various buildings. The Guild Hall provides the first Warrior/Scout recruitment; Temple recruitment and its later Cleric/Paladin path remain deferred campaign-slice work.

## Unit development

Each unit class has a role which can be further developed through perks.

Warriors are all-around damanage dealers, who can specialize into ranged damage delears or front-line damage dealers/absorbers.

Clerics are a support class who can specialize into healers/buff dealers or front-liners with powerful personal buffs that make them very tough (paladins). Paladins are unique in that they require a high Temple tier level in order to be available for recruitment or level-up path.

Mages are very vulnerable but provide offensive buffs and AOE attacks. They can specialize into a pure magic class or a hybrid mage/melee class that covers defensive holes with powerful buffs.

The Scout is an intelligence-gathering/luck-based class that can specialize
into Ranger or the deferred Rogue. Rangers emphasize Scouting and pre-battle
information; Rogues are luck-based critical dealers with weaker Scouting. Both
retain some ability to spot encounters and learn about them before engaging,
but the Ranger is the scouting specialist.

## Town management

The player starts out with a bare Encampment. As they accumulate gold, they can
improve the Guild Hall, Temple, Blacksmith/Workshops, and Shop/Stores. Each
upgrade has a visible cost, completion rule, prerequisite, and concrete unlock.
Items and gold from dungeon diving fund that growth, while Shop income and
recruitment/recovery progression ensure a setback cannot permanently end a
campaign. The exact building and economy contract is in the
[Borderlands Campaign Loop](campaign-loop.md#encampment-progression-and-economy-floor).

The player must tame and settle the area around the settlement for further growth, clearing out bandits and wandering monsters, protecting trade routes, and so on.

As trade routes are developed, traders come to the town. The number, quality, and types of traders depend on the safety of the trade routes, size of the town, and types of buildings (e.g. trader's guild). The player can also organize trading caravans which must be protected, with guards and/or patrols along trade routes.

Town management needs its own rich UI, although a true town-building experience is not needed. Something like the card-based town building in Rome: Total War is better. The Temple's exact recruitment and upgrade effects are deferred; they must not be represented as shipped behaviour before that decision is made.

## World map

The world should play somewhat like the XCOM world map. Encounter locations
appear through optional Guild Hall quests or through Scout and Watchtower
intelligence. The first campaign keeps its one-party implementation boundary;
the core future model supports multiple independently travelling parties. See
the [Intelligence System](intelligence.md) and [World Map and
Encounters](world-map-and-encounters.md).

On the world map, time advances in **Turns** (the unit of time governing encounter repopulation, recruit availability, crafting, etc.). In tactical combat, time advances in **Rounds**. World map turn time is frozen while a party is engaged in an encounter; players can view the map, encampment, and trade, but world turns cannot advance until the battle resolves.

The first campaign uses authored, prerequisite-gated objectives rather than
repeatable vacancies for required progress. After final victory, repeatable
free play can refill vacancies without changing the completed campaign state.
Threat rises at a campaign pace and is displayed as a one-to-five-star World
Map risk signal.

### Fog of war

World Map fog of war is location- and intelligence-based, not a geometric city
vision radius. Each live encounter receives independent, repeated discovery
checks from the Encampment, eligible Scouts, and Watchtowers. Distance reduces
the chance multiplicatively; discovered encounters then reveal their details
in ordered scouting tiers. Scouts therefore have major strategic value even
when their combat contribution is lower. See the [Intelligence
System](intelligence.md) for the canonical formulas.
