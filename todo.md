# Todo

## World map encounter selection

Standing on an encounter tile currently only lets you activate it (clicking
the tile enters battle); there's no way to select and move the party unit
while it's on that tile.

- Allow moving away from an encounter tile instead of always activating it.
  Entering battle may need to be mandatory in some cases (TBD which ones).
- Once an encounter is complete, its tile should no longer be enterable.

## World map turns

Add turn-based play to the world map, with its own turn counter independent
of the local battle map's turn counter.

- Naming: call world map turns "turns" and local (battle) map turns "rounds"
  to keep the two concepts distinct.

## Multiple parties and location state

The current `GameSession.current_location` is unused. Do not treat it as a
single global party location when multiple player parties are introduced.

- Give each party its own `world_position` and, when needed, a `location_id`
  for a named location or encounter.
- Add an `active_party_id` to `GameSession` for the party currently selected
  by the player.
- Keep scene-specific state separate, using identifiers such as
  `active_encounter_id` rather than a global `current_location`.
