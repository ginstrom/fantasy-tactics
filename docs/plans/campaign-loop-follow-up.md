# Follow up implementation for first campaign loop

## Encampment view and navigation

The main camp navigation menu should be in a left pane and be visible at all times:

[Encampment]
[Units]
[Buildings]
[Trade]
[Deploy Party]
[World Map]

When you first enter the encampment, you are on the "Encampent" screen which shows basic details about the encampment: population, number of parties/units in the encampment.

Clicking on Units, Buildings, Trade takes you to those specific screens, but the encampment menu is always visible on the left panel.

Minor point: On the Parties screen, the [Create Party] button should be under the parties table, not above it (consistency with party/Add Member button)

## World map movement path bug

There is a regression here. If there is already a path set for a unit, clicking the unit cancels the path and lets you set a new one. Instead, the old path should remain visible as we set the new path. If we right click, the new path setting is canceled and the old one remains. If we left click in the map, the new path is set and the old one disappears.

## XP accounting

After defeating enemies and clearing locations, we award fractional XP to each party member equally. The displayed XP value is truncated to the integer value. When displaying a unit details, show the XP and XP needed for the next level.

## Battle balancing

Three orcs are too tough for the level 1 warriors to handle. Let's rebalance the star system:

* One star: one goblin
* Two stars: two goblins or one orc (random)
* Three stars (not yet used): three goblins or two orcs (random)

This is not permanent because we are going to make units more powerful, but this is just so we can run the game loop a few times.