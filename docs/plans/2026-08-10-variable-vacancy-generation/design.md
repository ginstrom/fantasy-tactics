# Variable Vacancy and Encounter Generation Design

## Goal

Make population pacing variable but bounded, keep encounter generation
deterministic under test control, and correct the durable campaign design so
it describes the shipped health model and only supported player actions.

## Decisions

- A vacancy resolves its delay once, when it is opened. The delay is the
  category base plus a uniformly selected integer jitter in `[-5, 5]`:
  encounters wait 10–20 World Map turns and recruitment offers wait 25–35.
  It is not rerolled while ticking.
- `GameSession` remains the sole owner of vacancy records and random seams.
  A single injectable jitter roll will allow focused tests to force each
  boundary without relying on global randomness.
- Encounter generation remains the existing bounded algorithm: choose among
  templates without a live instance using power-weighted star tiers, mint a
  new instance id, and choose an in-bounds, unoccupied tile distinct from a
  previously used template's original tile. This work does not add terrain,
  procedural map generation, duplicate active templates, or new encounter
  content.
- Adventurer maximum health is `Vitality × level`. The current Warrior has
  vitality 10, so level 1 has 10 max HP and level 2 has 20. The current
  configured +10 per level behavior is consistent with this rule; the durable
  design must replace its erroneous `+1 maximum-health point` claim.
- Recruit dismissal is not part of this slice. Remove the unsupported claim
  from the durable design rather than add recruitment UI or campaign state.

## Data and Test Boundaries

Add configurable encounter and recruitment jitter magnitudes beside their
existing base durations. Vacancy records keep the existing shape,
`{ "turns_remaining": int }`, because their resolved delay is all later
logic needs. The injectable roll receives inclusive lower and upper bounds;
tests restore it after use, following the existing composition, loot, and
weighted-tier roll seams.

## Acceptance Criteria

- Encounter and recruitment vacancies each resolve to an inclusive base ±5
  delay exactly once at creation.
- The chosen delay ticks once per successful World Map End Turn, observes the
  existing caps, and retains the current no-catch-up behavior.
- Tests deterministically prove lower, base, and upper jitter boundaries and
  that existing encounter-template/position generation remains intact.
- `game-design.md` describes variable vacancy timing, weighted encounter
  generation, vitality-by-level health, and no unsupported dismissal action.
- Dead references to deleted dated plans are removed or replaced with durable
  references.
