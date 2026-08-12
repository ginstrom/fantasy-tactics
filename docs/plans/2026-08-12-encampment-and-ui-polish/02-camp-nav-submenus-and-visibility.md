# Step 2: Explicit Camp Navigation Categories

> **Branch:** `feat/camp-nav-submenus` (off updated local `main`)

## Setup

```bash
git checkout main && git pull
git checkout -b feat/camp-nav-submenus
```

## Goal

Render the correct left-aligned, indented CampNav submenu on every Units,
Buildings, and Trade descendant screen, without guessing current state from
the scene tree.

## Files

- Modify: `scripts/ui/camp_nav.gd`, `scenes/ui/camp_nav.tscn`
- Modify: every scene that instances CampNav: the Units/Roster/Parties/
  Recruitment/Add Member/Party Details/Unit Details group; Buildings and four
  workshop scenes; Trade/Stores/Shop/Assign Equipment scenes; plus the
  top-level screens that must explicitly provide `NONE`.
- Test: `tests/unit/test_camp_nav.gd` and one representative scene test per
  category.

## Contract and TDD

1. Add a failing test for an exported `category: CampNav.Category` configured
   by the parent scene (`UNITS`, `BUILDINGS`, `TRADE`, or `NONE`). Assert the
   exact submenu container visibility and left alignment/indentation, rather
   than relying on current-scene path timing.
2. Add failing scene-instantiation tests proving Roster, a workshop, Stores,
   and Shop select their intended category. Include sub-button routes to every
   listed destination.
3. Preserve the design's literal visibility rule: hide Deploy Party only when
   `GameSession.parties.is_empty()`. It may remain visible but disabled when
   no party is deployable; add tests for no party, empty party, deployable
   party, and deployed party.
4. Build the submenu nodes with translation keys, `horizontal_alignment =
   HORIZONTAL_ALIGNMENT_LEFT`, and a nested margin/container for indentation;
   wire the routes through existing GameManager methods and the new Shop route.
5. Run focused GUT red/green checks, then editor cache refresh, `make check`,
   `git diff --check`, manual `make play`, user signoff, local merge, and
   branch deletion.

## Manual milestone

Visit each descendant category (not only its top-level list). Its submenu is
visible only in that category, indented and left-aligned; Shop appears under
Trade. Verify Deploy Party is absent before a party exists and visible once one
exists.
