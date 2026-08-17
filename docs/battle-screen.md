# Battle screen layout and fuction

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

On the very bottom we have a row of action buttons. At first, we just have move
and attack buttons. So I can select a unit (e.g. 1) and then click move, and
the move destination. I can also click attack, and a target. If the target is
not in range, I will move to within range then attack automatically. 

I should see a green range that shows how far I can move and still
attack. The full range beyond my move-and-attack range is shown in yellow.
