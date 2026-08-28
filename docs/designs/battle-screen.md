# Battle screen layout and fuction

**Implementation status:** this is the target battle-information layout.
Elements not present in the current Battlefield, including its full party and
unit-detail presentation, are **to implement**. See the [design status
legend](README.md#implementation-status-legend).

```
+--------------------------------------------------------------------|
|                 Goblin Encampment Battle                           |
+-----+---------------------------------------------+----------------+
| [1]   |                                           |                |
| 10/10 |           X  X  X                         |                |
| [2]   |                                           | Globlin archer |
| 8/10  |                                           | Wounded        |
| [3]   |                                           |                |
| 8/10  |                                           | Warrior        |
| [4]   |                                           | HP: 10/10      |
| 6/6   |           1  2                            | AP: 3/9        |
|       |           3  4                            | Longsword      |
|       |                                           |                |
+--------------------------------------------------------------------|
| Warrior hits orc 1 for 8 points.                                   |
| Warror 2 misses orc                                                |
+--------------------------------------------------------------------|
| [M] [A]                                                            |
+--------------------------------------------------------------------|
```

The battle screen is inspired by Baldur's Gate 1/2.

On the left we have the portrait of each unit in the party, with HP overlaid.

On the right we have details about the selected and hovered units/objects.

On the bottom we have battle log text, scrollable. New text is added to the
bottom, and the field scrolled to show the final row whevenver new text is
added.

On the very bottom we have a row of action buttons. Move and Action are
button-only modes; they do not introduce keyboard shortcuts, preserving WASD
movement controls. I can select a unit (e.g. 1) and then click Move and the
destination. I can also click Action and a target. A melee unit may move to
within range then attack automatically. A missile unit never auto-moves: if
the target is outside its current range, no action occurs and the reason is
written to the bottom battle log. Units do not block line of sight for attacks.

I should see a green range that shows how far I can move and still
attack. The full range beyond my move-and-attack range is shown in yellow.

## Retreat

The bottom panel has a **Retreat** button at its lower left, alongside Move,
Action, and End Turn. This is **Battle Retreat**, a campaign-level
battle-resolution action rather than an AP action. It ends the encounter,
discards unbanked/pending rewards, and applies the nearest-enemy consequence
defined in the
[Borderlands Campaign Loop](campaign-loop.md#defeat-death-and-retreat).
Survivors remain at the encounter location with a committed route to the
Encampment. The distinct pre-battle **Withdraw** action is defined in [World
Map and Encounters](world-map-and-encounters.md#arrival-and-withdrawal).
