# Card Navigation Design

## Goal

Every detailed entry opened from a player-visible list uses one centered card
shell with `<` and `>` buttons, a position label, and Close/Escape return to
the originating list. Navigation wraps in both directions.

## Chosen architecture

`CardNavigator` is a reusable full-screen `Control`, separate from
`ModalDialog`. It owns only presentation and navigation: dim backdrop,
centered dominant card, previous/next controls, focus, Escape/Close, and a
snapshot of ordered stable IDs. The caller provides a card presenter and
continues to own its data, mutations, routes, and list refresh.

Opening a card snapshots the current visible ordered IDs after the list's
filter/sort rules have already been applied. It starts at the activated ID.
`previous` maps index `0` to the final ID; `next` maps the final index to
`0`. One-entry sessions show the count but disable both arrows. The navigator
emits the newly selected ID for the caller to render and emits the last ID on
close; the originating screen refreshes and restores that selection when it
still exists. A stale/deleted ID never causes an action against another row:
the caller closes the navigator and refreshes its list.

`CardNavigator` does not add keyboard next/previous shortcuts. The requested
interaction is explicit `<` / `>` buttons, avoiding collisions with the
battle screen and existing shortcuts. It is also deliberately not a new
route-context owner: `GameSession` remains durable-state owner, `GameManager`
remains scene-routing owner, and each screen retains screen-local selection.

## Card contract

Each card body is a small reusable `Control` which exposes `show_for_id()` or
`show_for_row()` and emits only screen-level intents (for example, equip,
recruit, or choose perk). The shell supplies a uniform title area, `N of M`,
arrows, and Close. Content cards render data freshly from `GameSession` or
from the list's supplied row; they never retain a second authoritative copy.

The initial integrations are unit cards from roster, Add Member, and Party
Details; recruitment candidates; shop/store/party-carry loot; Journal entries;
and the Battle Outcome level-up list. Non-detail tables (Buildings, Trade,
and Deploy Party) remain ordinary action/destination lists unless they gain a
detail action. The final audit records every `TableView` and `LootTable`
caller and either adopts the navigator or documents this exclusion.

## Required-perk exception

Level-up cards remain gameplay-gated: a pending perk keeps that card's
Continue action disabled. Close/Escape returns to Battle Outcome without
discarding the pending choice; Battle Outcome itself remains unable to finish
the battle until all required choices are resolved. Thus the universal return
behavior is preserved without silently changing progression rules.
