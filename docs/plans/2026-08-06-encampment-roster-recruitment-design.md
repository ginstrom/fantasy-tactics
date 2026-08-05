# Encampment Roster and Recruitment Design

## Purpose

Complete the next usable encampment decision layer: recruit a finite set of
adventurers with banked gold, inspect the full roster, and assign a unit to an
encamped party from that unit's detail screen. This extends the existing
party-first Add Member route; it does not replace it.

## Scope

The slice activates the Units hub's Roster and Recruitment destinations.
Roster is a `TableView` showing Name, Class, Level, Status, and Party. It
lists every `GameSession` adventurer, renders `Unassigned` when appropriate,
and opens the existing Unit Details screen through stable adventurer IDs.

When Unit Details is opened from Roster, an available, unassigned unit sees a
picker of eligible encamped parties and an Add to Party action. A successful
assignment returns to Roster, whose Party column now names that party. The
picker and action are absent for assigned or unavailable units, and a roster
unit with no eligible party presents an explanatory disabled action.

Recruitment is a `TableView` over three fixed, individually identified
Warrior candidates. Each costs 10 gold. Selecting a candidate shows the
cost; an explicit Recruit action remains disabled when funds are insufficient.
On success, the transaction deducts gold once, removes the candidate, adds
the adventurer to the roster, and routes to Roster. Invalid, unaffordable, or
stale actions change neither state nor scene.

## Ownership and routing

`GameSession` owns recruitment candidates, adventurers, parties, gold, and
all eligibility/purchase/assignment validation. `GameManager` owns named
scene changes and short-lived route context. UI controllers provide stable
row IDs to `TableView`, resolve state only through `GameSession`, and never
make `TreeItem` metadata authoritative.

The active flow is:

```text
Encampment -> Units
  -> Recruitment -> recruit an affordable candidate -> Roster
  -> Roster -> Unit Details -> choose encamped party -> Add to Party -> Roster
  -> Parties -> Party Details -> Add Member
```

Route context must preserve the Unit Details return destination and selected
target party only for the short action that needs it. It must be cleared on
invalid navigation and never stored in durable session state.

## Constraints and deferred work

All initial recruits use existing Warrior behavior. The UI may display their
class but must not imply Mage or Cleric combat rules before those exist. The
candidate record shape is intentionally extensible so future town size and
buildings can add or filter candidates.

Out of scope: random offers, search, pagination, multi-selection, inline
editing, party capacity, removal/reassignment, town/building rules,
class-specific combat, Buildings, Trade, and gold spending outside
recruitment.

## Quality bar

Use red/green GUT tests for state transitions, routing, table data, button
states, and stale requests. Retain regression coverage for party-first Add
Member. Before integration, run focused tests, `make check`, a headless Godot
editor scan, `git diff --check`, the screenshot tour, and the manual flow:
earn gold, recruit, inspect Roster, add the unit to a party, and confirm the
Roster Party column updates.
