# Parties

## party creation on new game

If the player does not have any parties, when they land on the encampment main screen, show them a dialog prompting to create a party:

```
Create your first party.
You need to create a party before you can venture into the world.

[Create] [Dismiss]
```

This takes us to the Create Party screen.

## party creation -> party details

After creating a party, take us to the Party Details screen instead of the Party List screen. We want to optimize the flow of creating a party and venturing into the world.

## recruiting from party details screen

From this screen, we can either add new members from our roster, or recruit members directly into the party.

Currently there is an [Add Member] menu selection. Instead, under the table we will have two buttons:

[Add from Roster] [Recruit]

Grey them out if there are no members in the roster or no available units to recruit, respectively.

# Recruitment

From the recruting page, after recruiting a unit, don't take us to the roster. Keep us on the recruiting page so we can continue to recruit units, but add a link to the roster at the bottom of the screen.

# Sub-navation

Currently the left navigation menu for the encampment looks like this:

```
[Encampment]
[Units]
[Buildings]
[Trade]
[Deploy Party] (should only appear if there is a party)
[World Map]
```

If we enter the Units, Buildings, or Trade screens, show a sub-menu navigation for these.
For example, if we go to the Units screen, the navigation menu should look like this:

```
[Encampment]
[Units]
  [Roster]
  [Parties]
  [Recruitment]
[Buildings]
[Trade]
[Deploy Party] (should only appear if there is a party)
[World Map]
```
Likewise for the Buildings screen:
```
[Encampment]
[Units]
[Buildings]
  [Guild Hall]
  [Blacksmith]
  [Alchemy Workshop]
  [Runic Workshop]
[Trade]
[Deploy Party] (should only appear if there is a party)
[World Map]
```
For Trade, show Stores and Shop items.

Note that the navigation menu items should be left-aligned. Sub-menu items should be indented.

# Starting buildings

The following buildings should be present from the game start:
* Guild Hall
* Shop

These are available from the game start, but can be upgraded.

## Shop economy

The Shop is available from the start of every new campaign and keeps its own
gold pool, separate from the player's gold.

* Level 1 starts with 100 Shop gold and sells iron weapons only.
* Upgrade to level 2 costs the player 50 gold, raises the Shop-gold cap to
  200, and adds steel weapons to its catalogue. Do not lower Shop gold if it
  was already above the new cap (it cannot be in the normal level-1 flow, but
  saves and future rules must be safe).
* Selling an item transfers its normal sale price from the Shop pool to the
  player. A sale is unavailable and leaves all state unchanged when the Shop
  cannot afford that full price.
* Buying an item transfers its normal purchase price from the player to the
  Shop pool.
* After a successful World Map End Turn that advances the world turn to a
  multiple of 10, refill Shop gold only up to the current cap. Never reduce an
  above-cap balance.
* Keep the Shop's existing passive income: it is paid to the player's gold on
  every successful World Map End Turn, independently of the Shop pool.

# Stores interface

Currently, we have to view an item in the stores to sell/equip.

Instead, when an item in the stores is selected, activate three buttons at the bottom of the table:

[View] [Sell] [Equip]

These should be grayed as applicable: view when no item is selected, sell when no item is selected, equip when no item is selected or the item is unequippable (e.g. mana crystal)
