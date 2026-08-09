# Minor fixes to game

## Random name choice

When starting the game, the player is prompted for a name. Add a [Random] button with a dice emoji (if possible) below the text box. The [Random] name is a choice between "The Black Company" and "Company of Saints".

Currently the party name is hard coded to "Party 1". Also prompt the player to name the party, and provide a [Random] button below the text box. Here, the choices are "Party 1" and "Alpha Party".

## Warrior hit points

Warriors start the game with 10 hit points, and gain 10 more per level.

## Encampment location

The encampment should start in the middle of the map. Make the starting world map slightly larger to enable more movement.

## Selling Loot

There should be [Sell] buttons on each loot row, and an [Equip] button for equipment.
If there is more than one item, the [Sell] button should bring up a dialog like this:

```
Sell [loot item]
[  <text box, integer input> ] [-10][-]/[+][+10] [ALL]
[Cancel] [OK]
```

The interface should be inspired by the Rimworld trading UI.

## Encounter loot

Every enemy kill already queues its own gold amount. On top of that, clearing
an encounter now also queues a small flat gold bonus of its own: 0-5 gold
per point of the encounter's star difficulty (a 1-star Goblin Camp adds 0-5,
a 3-star Ruined Fortress adds 0-15), rolled once when the encounter is
cleared.

The victory summary screen and the World Map's Party Details screen show
loot (mana crystals and gear) as a table in the same format as the Stores
screen (name, type, count, price columns), reusing the same table
component. Neither shows a [Sell] action. The victory summary is a
read-only record of that encounter's own drops — no [Equip] action there,
since the screen shows a frozen snapshot rather than the party's live,
mutable stock. Party Details keeps an [Equip] action for gear rows
(assignment limited to the current party's own members, not the full
roster), since it reads the party's actual carried loot live.

The victory screen's table lists only the loot from that encounter. The
World Map's Party Details table lists everything the party is currently
carrying (all loot pending since it last visited the Encampment). The
Encampment's Party Details screen shows no loot table at all — by the time a
party is back at the Encampment its loot has already banked into the
Encampment's Stores, so it belongs to Stores, not to Party Details.
