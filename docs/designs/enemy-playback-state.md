# Enemy Playback State Model

**Status:** Proposed for Step 05 approval

## Decision

Use a **recorded visual timeline** for the Battlefield only. `BattleController`
continues to resolve an enemy turn synchronously through its existing public
`run_enemy_turn() -> Array` contract. While resolving each returned enemy step,
it records an immutable, presentation-only frame. `Battlefield._play_enemy_turn()`
asks the controller to draw that paired frame instead of redrawing the
controller's final `units` collection.

The timeline is transient battle-local state: it is neither campaign state nor
part of a save/snapshot. It does not decide targeting, movement, combat,
randomness, turn ownership, or battle outcomes.

## Reproduction and evidence

The deterministic GUT fixture used two enemies and one 1-HP player on a 6x6
board. The first enemy moves from `(3, 1)` to `(1, 0)` and the later attack
defeats the player. With synchronous resolution, the recorded log is:

```
initial: mover=(3, 1) finisher=(1, 2) player=(1, 1) units=3
step_1=move   final_units=2 player_health=0 player_present=false mover=(1, 0) finisher=(1, 2)
step_2=attack final_units=2 player_health=0 player_present=false mover=(1, 0) finisher=(1, 2)
```

`Battlefield._play_enemy_turn()` calls `grid.run_enemy_turn()` once, then
calls `grid._draw_units()` before every wait. `_draw_units()` iterates
`grid.units`; an attack immediately erases a defeated target from that array.
The current first movement beat therefore already has the player removed. This
test-state log directly proves the renderer reads final state, not beat-one
state.

## Timeline frame and renderer boundary

Keep `run_enemy_turn()`'s return type and callers unchanged. Add a separate
ephemeral timeline that is cleared at the next enemy turn. Each item pairs the
existing result dictionary with a fully resolved rendering frame:

```
{
  "step": <existing move/attack/reaction dictionary>,
  "visible_units": [
    {
      "id": <Unit.get_instance_id() captured as an integer>,
      "side": <player or enemy>,
      "grid_position": <Vector2i>,
      "health": <int>,
      "max_health": <int>,
      "facing": <Vector2i>,
      "visual_key": <String>
    }
  ],
  "stale_enemy_markers": [
    { "unit_id": <integer>, "grid_position": <Vector2i>, "visual_key": <String> }
  ]
}
```

The captured values—not `Unit` references or shallow Dictionaries—remain
immutable when later actions mutate position, facing, health, or membership.
The integer only associates a stale marker with a snapshot sprite; it is never
saved or used for rules.

`BattleController` remains both the state source and owner of the existing
`_draw_units()` renderer. Step 06 adds a narrow controller render entry point
that consumes one complete frame; `Battlefield` only selects that frame while
running its existing delay loop. That entry point must use only `visible_units`
and `stale_enemy_markers`, never live `units`, `get_player_visible_tiles()`, or
`get_stale_enemy_markers()`. A frame thus captures fog-of-war as well as unit
state. Normal live rendering resumes after playback.

## Exact move and reaction ordering

Rules resolve opportunity attacks inside `try_move_selected_unit()` before
assigning the destination, but `_take_enemy_unit_actions()` returns the move
result before reaction results. The timeline preserves that result order
without moving rules, changing RNG consumption, or creating a second rules
path:

1. Before invoking a move, build a **move projection** from the pre-action
   visual state with the mover placed at its chosen destination and its normal
   post-move facing/AP presentation values. This post-move/pre-reaction frame
   is paired with the existing `move` result.
2. In `_trigger_opportunity_attacks_along_path()`, directly after each
   `_resolve_opportunity_attack()` returns, build a **reaction projection**:
   that reaction's results, with the mover projected at the same destination
   if alive. A lethal reaction omits the mover. Pair each with its current
   reaction result in the existing order.
3. For attacks and no-reaction moves, capture the frame immediately after the
   existing rule action finishes.

The builder calculates visible units and stale enemy markers from the
projection plus a copied battlefield-memory map, not later live state. It is a
pure presentation projection: it writes no units, memory, AP, statuses,
results, or rolls.

## Cost and affected callers

The reproduction records five live-unit records across two frames (three for
the move and two for the attack), plus any stale-marker records. Cost is
`O(playback frames × current fielded units)` and is released after the turn;
it is never serialized. The legacy fallback has five player and eight enemy
spawns (13 units), but catalog definitions can supply a different number of
spawn positions, so 13 is not a global bound. This is smaller than cloning a
controller or replaying combat rules.

`run_enemy_turn()` has three direct non-test callers: `Battlefield` (the only
playback consumer), the campaign simulator, and the deterministic scenario
policy. `BattleBot` is an indirect consumer through the simulator's turn loop;
it does not call this method. Retaining the `Array` return preserves simulator
and policy final-state behavior and deterministic result dictionaries.

## Test seam and Step 06 acceptance checks

Add focused controller tests for immutable timeline values and a Battlefield
test using the reproduction above. Before the later killing attack's frame,
the rendered snapshot contains the player at `(1, 1)` and the mover only at
the position reached by that beat; the killing frame omits the player.

Add controller and Battlefield regressions for both a surviving and a lethal
opportunity reaction: the move frame is post-move/pre-reaction, each reaction
frame reflects exactly the reactions resolved through that point, and a lethal
frame omits its mover. These tests also prove recording does not change result
order, unit state, RNG rolls, or the Step 01 reaction rendering path. Retain
the existing controller, BattleBot, scenario, and simulator tests for rules
parity and assert a stale enemy stays a stale marker rather than leaking its
final position during playback.

## Alternatives rejected

**Incremental simulation** would make timing natural, but changes the
synchronous controller contract used by the simulator and policy, adds input
cancellation/lifecycle concerns, and risks two resolution paths or altered RNG
consumption. The measured defect is presentation-only, so it is not the
smallest safe change.

**Do nothing** is rejected: the deterministic reproduction shows the first
displayed beat reads the final two-unit state after the second beat has killed
the player.

## Approval requested

Approve this recorded-timeline model before Step 06 changes code. Approval
authorizes committing this record locally as
`docs(battle): choose enemy playback state model`; it does not authorize Step
06 automatically.
