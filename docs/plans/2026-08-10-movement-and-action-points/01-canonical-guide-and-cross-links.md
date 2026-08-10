# Step 1: Canonical guide and cross-links

## Outcome

`docs/designs/movement-and-action-points.md` gives designers and implementers
one source for movement/AP semantics. The class and equipment documents link to
it without competing generic-cost tables.

## Setup

From the repository root, confirm the working branch and read the related
design documents:

```bash
git status --short --branch
sed -n '1,180p' docs/designs/class-system.md
sed -n '1,180p' docs/designs/equipment-handbook.md
```

## Red check

Before adding the guide, the following should find no canonical guide file:

```bash
test ! -f docs/designs/movement-and-action-points.md
```

## Implement

- Create `docs/designs/movement-and-action-points.md` with purpose/status,
  Round lifecycle, AP budget and costs, movement/action legality, expected UI
  feedback, concrete action sequences, and deferred extensions.
- Mark the existing movement-plus-one-attack rule as **Shipped** and generic
  AP as **Next slice**.
- Replace the generic AP tables/examples in `docs/designs/class-system.md` and
  `docs/designs/equipment-handbook.md` with links to the guide. Retain their
  class/perk and potion/item-specific text.

## Green verification

```bash
test -f docs/designs/movement-and-action-points.md
rg -n '6 AP|Move one tile|Basic attack|carried potion|multiple attacks|Next slice' \
  docs/designs/movement-and-action-points.md
rg -n 'movement-and-action-points' \
  docs/designs/class-system.md docs/designs/equipment-handbook.md
git diff --check
```

Manually inspect the guide alongside the class and equipment documents. The
reader must be able to identify current behaviour, approved AP behaviour, all
three initial costs, and where future costs/modifiers are constrained.

## Commit and handoff

Commit only the guide and its cross-link edits:

```bash
git add docs/designs/movement-and-action-points.md \
  docs/designs/class-system.md docs/designs/equipment-handbook.md \
  docs/plans/2026-08-10-movement-and-action-points/
git commit -m "docs: add movement and action point guide"
```

This is documentation-only; do not claim AP is implemented or run gameplay
tests for it. When a later implementation slice is ready, request user manual
verification with `make play`. After user signoff, merge this branch locally
into `main` and delete it; do not push unless asked.
