# Encampment Party UI Design

## Goal

Turn the Encampment into a readable strategic hub and deliver a first
party-management vertical slice: Units -> Parties -> Party Details -> Unit
Details, plus explicit party deployment to the World Map.

## Navigation

```text
Encampment
├─ Units
│  └─ Parties
│     └─ Party Details
│        └─ Unit Details
└─ Deploy Party
   └─ eligible encamped party
      └─ World Map
```

Buildings, Trade, Roster, Recruitment, and Add Member are acknowledged by the
design and campaign roadmap, but are intentionally not functional in this
slice.

## Presentation and interaction

The Encampment presents Units, Buildings, Trade, and Deploy Party. Units is
available; the other non-slice destinations are visibly TBD. Deploy Party is
disabled when no eligible party is in the encampment. It opens a list of only
eligible parties rather than exposing non-deployable entries.

The shared right-side information panel always displays player name and banked
gold. Selection is local to each screen: selecting a party updates the panel
with that party's name, member count, and View action; selecting a member
updates it with basic unit information and View. View performs the deliberate
navigation to details. Selecting a row alone never changes the currently
deployed strategic party.

## State boundaries

`GameSession` remains the owner of durable party and adventurer records. It
gets public lookup and eligibility queries plus a single deployment command
that validates an encamped party, makes it the active strategic party, marks
it deployed, and returns success/failure. `GameManager` owns every scene
transition. Screens own their temporary selected row IDs and refresh the
information panel from those IDs.

Party data gains a display name and explicit future-facing placeholder fields.
Adventurer data gains level and availability status plus placeholder
progression/stat fields. The current eligibility predicate is: a party is not
deployed, is at the starting encampment, and contains at least one adventurer
whose status is `available`. Future death/incapacitation changes only the
adventurer status and uses the same predicate.

## Verification boundary

Every state/API change starts with a focused GUT regression test. Each scene
has scene-level tests for layout, selection, View routing intent, and disabled
or filtered deployment behavior. Final automated checks are `make check`, a
headless Godot editor scan, and `git diff --check`; manual signoff covers the
complete encampment-to-world-map route with a ready and an ineligible party.
