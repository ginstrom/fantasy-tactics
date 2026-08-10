# Movement and Action Points Guide Design

## Goal

Create one canonical, implementation-oriented reference for tactical movement
and Action Points (AP), while leaving class and equipment documents responsible
for their own systems' consequences.

## Decision

`docs/designs/movement-and-action-points.md` owns the generic tactical-turn
contract: AP refresh, action costs, movement legality, attack/use-item
legality, UI feedback, examples, and the rules for later AP modifiers. It
records the approved six-AP model without presenting it as shipped gameplay.

`class-system.md` retains the `action_points` attribute and class/perk
implications. `equipment-handbook.md` retains potion and item implications.
Both link to the guide instead of reproducing its action-cost table or action
examples.

## Constraints

- The guide must distinguish shipped movement-plus-one-attack behaviour from
  the approved next-slice AP model.
- It must preserve the approved baseline: 6 AP each Round; one AP per tile;
  three AP per basic attack; two AP to use a carried potion.
- It must permit multiple legal attacks when AP allows and make all future
  costs/modifiers explicit.
- It must not add terrain costs, reactions, spells, or a new live mechanic.

## Verification

Review cross-links and rule wording with focused `rg` checks, then run
`git diff --check`. Documentation-only work needs no gameplay test.
