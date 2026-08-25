# Information Design

## Status

Approved 2026-08-25. This document is the product contract for the
information-design implementation; it does not itself change runtime behavior.

## Goal

Replace overlapping, ad-hoc information surfaces with three deliberate
levels: persistent information panels, single-purpose blocking modals, and an
Encampment Journal for durable history and quests.

## Information hierarchy

### 1. Information panels

Panels are passive, concise context. They must not overlap one another or
obscure the playable board.

* The top panel presents current campaign objective and progress.
* The right panel presents player resources plus the selected Party or World
  Map encounter's relevant facts.
* The bottom panel presents controls and a short contextual hint.

The World Map must not display overlapping tutorial cards, objective blocks,
and status panels. Guidance that is not currently actionable belongs in the
Journal Log rather than an additional floating panel.

### 2. Large modals

Modals are centered, large, and block the underlying screen. Each has an
explicit action button and supports Escape to dismiss when no required choice
is outstanding.

Use modals only for consequential outcomes or choices. A battle produces one
Battle Outcome modal, rather than a sequence of automatic interruptions. It
shows the outcome, XP, kills, queued loot, and any level ups. Each leveled
adventurer has a `View` action that opens that adventurer's level-up modal;
closing it returns to the Battle Outcome modal. Multiple level ups are never
auto-presented one after another for a single battle.

The existing first-party and other important dialogs should use this same
presentation so the game has one modal language.

### 3. Journal

Encampment's left navigation gains `Journal`, with two sub-screens:

* `Quests` lists Guild Hall quests the player has accepted. Until acceptance
  becomes durable runtime behavior, it explicitly renders an empty-state
  placeholder.
* `Log` is chronological history for important events, initially encounter
  discoveries, battle outcomes, received loot, and level ups.

## Acknowledgement and badges

Journal records are individually unread until viewed. An unread record carries
`!`; Log or Quests carries `!` when it contains an unread child; Journal carries
`!` when either child has unread content. Opening a section does not mark all
its records read. Viewing one record acknowledges only that record.

## Ownership and persistence

`GameSession` owns durable journal records, their read state, and accepted
quest state. `CampaignSnapshot` persists both. Game-event owners append
records at the time they resolve; views only render records and request
acknowledgement. `GameManager` continues to own routing only.

Guild Hall acceptance will create/update accepted-quest records when that
runtime behavior is implemented. The initial Journal may render the empty
accepted-quests state while the quest board remains its existing offer surface.

## Verification contract

Automated coverage must prove journal ordering, unread propagation and
individual acknowledgement, snapshot round trips, one battle interruption for
multiple level-ups, level-up return to the outcome modal, and the empty Quests
state. The implementation also requires `make check`, editor validation,
`git diff --check`, screenshot coverage, and manual World Map-to-battle-to-
Journal verification.
