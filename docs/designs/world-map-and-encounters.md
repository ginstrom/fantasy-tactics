# World Map and Encounters

The World Map is an open strategic area, not a tactical movement grid. It
retains an underlying grid only to place the Encampment and encounter
locations. Parties can travel only between those locations. Straight-line grid
distance, rounded up to a whole number, is the travel time in World Map Turns.
The same turn distance is used by the [Intelligence System](intelligence.md).

## Future multi-party model

Clicking an encounter location shows every detail currently known about it. If
there are eligible parties, the right panel offers **Send Party**. Choosing it
opens a modal showing available parties, their current destinations, and their
turns to the selected location.

```
Party    Destination  Turns to selected location
-----------------------------------------------
Party 1  Goblin Camp   3
Party 2  Encampment    6
```

Parties on the map show a dotted path to their destination. Selecting a party
shows its destination and remaining travel time in the right information
panel. A selected destination replaces that party's prior destination.

The strategic model supports multiple parties, including independent travel
and scouting. The first Borderlands campaign deliberately implements one
active party; multi-party dispatch is deferred rather than contradicted by the
campaign scope.

## Arrival and withdrawal

When a party arrives at an encounter location, a dialog shows the intelligence
known for that encounter and offers:

- **Enter** — begin the Battlefield encounter.
- **Withdraw** — decline the encounter before battle begins.

Withdraw is distinct from the higher-risk **Battle Retreat** action available
after entering the Battlefield. Withdraw immediately applies one independent
outcome roll to each party member and sets surviving members' destination to
the Encampment. No battle reward exists yet, so Withdraw discards no loot.

| Outcome per unit | Chance |
|---|---:|
| No remaining-HP loss | 90% |
| Lose 10% of maximum HP | 10% |

HP loss is calculated from maximum HP, rounded up, and capped at the unit's
remaining HP. Withdraw cannot kill a unit; permanent death and its atomic
item-transfer aftermath are reserved for Battle Retreat and battle defeat. The
encounter remains available after any Withdraw.

Battle Retreat uses the distance-based, higher-risk per-unit table in the
[Borderlands Campaign Loop](campaign-loop.md#defeat-death-and-retreat). After
either outcome, survivors remain physically at the encounter location on the
World Map with a committed route to the Encampment; they travel home over
subsequent World Map Turns.
