# Game polish based on playtesting

# Party

From the Create Party dialog on new game, take the player straight to the party
creation screen instead of the party list screen.

# Units screen

The unit screen current shows a list of links to sub-screens, which is redundant with the side menu navigation.

Instead, the Units screen should show basic info about my units:

```
Parties: 2 [View]
Units in roster: 13 [View]
Recruitable units: 2 [View]
```

## Recruiting

When I click Recruit on the party details screen, after clicking Recruit I am returned to the Party Details screen.

If I go to recruit from the party details screen, and double click on a recruit, that recruit is added to the party and I am returned to the party details list.

A unit recruited straight to the party also moves from the Recruits list to the Roster list.

If I go to the recruiting screen from the Units screen, recruit/double click adds that unit to the roster and takes me to the Roster screen.

## Combat rewards

The rewards from combat need to be significantly greater, averaging 25 gold for
a tier 1 encounter and 50 gold for a tier 2 encounter, not including dropped
loot.

## Unit details

* Show skills as a list, not a single line
```
Name: Smith
Class: Warrior
Level: 2
Hit points: 20 / 20
Action points: 6
Damage resistance: 0%
Magic resistance: 0%
Effects: None
Skills
   Melee: 64%
   Missile: 64%
   Guard: 20%
   Might: 40%
Equipment
   Leather armor
   Iron longsword
Inventory
   Leather armor (equipped)
   Iron longsword (equipped)
   Healing potion x 1
```

Notice it is "hit points" and not "health"; and HP is not a skill

The same will go for "magic points"/"MP" when this is introduced.

* "Perks: None" instead of "Perks: Bonus move..."
* When unit has perks, show them as a list
    ```
    Perks:
    * Parry
    * Rage
    ```

Later, we will make a tabbed unit details view, with general info / skills / perks on one tab, and inventory on another. Inspiration for design is Baldur's Gate 2 and Fallout 2.