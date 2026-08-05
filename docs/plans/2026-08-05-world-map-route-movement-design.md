# World-Map Route Movement Design

## Goal

Replace one-square-at-a-time world-map travel with a planned route that can be
advanced manually or automatically at the end of each world turn, while making
the route and estimated arrival time clear before the player commits.

## Player interaction

1. Click the deployed party to select it. The existing one-turn movement range
   remains visible.
2. While selected, move the cursor over an in-bounds tile. A deterministic
   shortest route from the party to that tile and an arrival marker show the
   number of world turns required.
3. Click an in-bounds tile to save or replace the party's route without moving.
   The displayed route becomes the remaining committed route.
4. Click the movement target again to make one manual step along that route. A
   route step uses the party's single movement allocation for the current world
   turn.
5. Press **End Turn**. The world-turn counter increases. If any movement was
   unused, the party automatically takes the next step of its route; otherwise
   it remains in place. The next turn begins with movement available again.

Arrival clears the route. A fresh destination replaces an old route. A party
on the settlement or goblin-camp tile still uses the existing selection-first,
second-click entry interaction; travel must finish before entry can occur.

## Architecture

`GameSession` remains the owner of durable campaign state. Each deployed party
will store its planned route, whether it has spent movement in the current
world turn, and the shared campaign's world-turn count. It will expose small,
testable APIs to set/clear a route, inspect its remaining steps, manually
consume its next step, and end a world turn. Ending a turn is the only API that
increments the counter and automatically consumes unused route movement.

`world_map.gd` remains the scene-level interaction and rendering layer. It
calculates a deterministic Manhattan shortest path for this empty 5x5 grid,
uses the session APIs to commit or consume it, and redraws markers/highlights
after state changes. It owns only transient selection and hover-preview state.
It must not retain the durable route itself.

The world scene receives an End Turn HUD button and labels for the current
turn, hint text, and the preview/committed route indicator. Rendered path
segments and a small destination label are intentionally simple Godot controls
for this prototype; no movement animation, terrain costs, obstacles, multiple
parties, or waypoints are included.

## Terminology

The World Map displays **Turn** because travel advances one campaign turn at a
time. The battle HUD and battle hint localization use **Round** for its
player/enemy action cycle. The existing battle action button remains **End
Turn**, because it hands control from the player to the enemy rather than
finishing a complete round.

## Error handling and boundaries

- Out-of-bounds destinations and empty/no-op routes are rejected without
  mutating campaign state.
- A route cannot include non-adjacent steps; route consumption rejects invalid
  stored data rather than teleporting the party.
- Manual and automatic movement share the same consumption rule, so they cannot
  both move a party in one world turn.
- Returning home clears transient travel state. The durable route is also
  cleared when the party arrives, preventing stale movement after map changes.

## Verification

Automated GUT tests cover state ownership, deterministic path construction,
destination replacement, one-step manual and automatic movement, turn-count
updates, persistence across a new map instance, selection/entry regression
behavior, and World Map/Battle terminology.

Manual verification with `make play`: deploy a party, preview and set a route
to the goblin camp, manually advance once, then use End Turn to finish the
route; verify exactly one tile is travelled per world turn, the estimate falls
each step, and the camp can then be entered with the existing second-click
interaction.
