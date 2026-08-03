# Settlement and First Party Design

## Purpose

Define the first playable part of the campaign: establish a settlement,
create a party from a rostered adventurer, deploy it to the world map, and
move it. This is a deliberately small foundation for later local sites,
encounters, and tactical battles.

## Player experience

A new game begins in the starting settlement. The player opens its encampment
management UI, finds one available adventurer, creates a party, and assigns
that adventurer to it. Once the party is valid, the player sends it out. The
party appears at the settlement on the world map and uses the existing
select-then-move interaction.

```text
New game
  -> starting settlement local map
  -> encampment management UI
  -> party manager UI
  -> create party and add the warrior
  -> return to encampment and depart
  -> world map: party appears at settlement
  -> move party
  -> activate settlement site to return home
```

The first version has no battle requirement in this loop. It proves that a
party, rather than an implicit map marker, is the campaign asset being moved.

## Scope

### Starting settlement

`starting_settlement` is a local-map scene under `scenes/local/`. It is the
starting location and later the world-map site the player can enter. Its
initial presentation may be simple, but it must clearly offer an encampment
action and a way to leave or return to the world map when a party is deployed.

### Encampment management

The encampment UI belongs under `scenes/ui/`. In this slice it is intentionally
thin: it explains the party's status and links to party management. It also
offers **Depart** only when a valid party exists. It is a management interface,
not a city-building system.

### Party manager

The party manager UI lets the player:

- see available adventurers;
- create the single initial party;
- add or remove its members; and
- return to the encampment UI.

The party has a name or fixed initial identifier, but no party-capacity,
formation, inventory, or multiple-party rules are needed yet. A party may
depart when it has at least one member.

### First adventurer

The player begins with exactly one rostered adventurer who is not assigned to
any party:

```text
id: warrior_001
name: Warrior
class: warrior
weapon: sword
```

For this slice, `class` and `weapon` are visible data, not combat mechanics.
They establish a stable shape for the adventurer record that tactical battle
can later consume.

### Deployment and return

Departing changes the party from being at the settlement to being deployed on
the world map. Its initial world position is the settlement's map tile. The
world map displays and moves only the deployed party. It does not create a
party automatically and must not show a party marker before deployment.

Activating the settlement tile on the world map returns the party to the
settlement. The party is no longer displayed on the world map; reopening the
settlement shows it as available at home. This makes deployment a clear state
transition rather than merely a scene change.

## Campaign-state model

`GameSession` remains the owner of durable campaign facts. The current
`party: Array[String]` field is not sufficient because it conflates a roster,
party membership, and the world-map actor. Replace it with separate concepts:

| Concept | First-version state | Later extension |
| --- | --- | --- |
| Adventurer roster | One unassigned warrior | More classes, statistics, equipment, conditions |
| Party list | Zero or one created party | Multiple parties, formations, supplies |
| Party membership | Warrior ID in the party's member IDs | Capacity and role rules |
| Party location | `starting_settlement` or deployed world position | Local sites, travel, quests |
| Selected party | The one deployed party, when applicable | Explicit player selection among parties |

The state must store the settlement identity and world position on the party,
not on an individual scene. The world map reads the deployed party's position
and writes back movement. The settlement and UI scenes request actions; they
do not own the campaign model.

## Scene and transition responsibilities

```text
StartingSettlement --open encampment--> GameManager --show--> Encampment UI
Encampment --manage party--> GameManager --show--> Party Manager UI
Encampment --depart party--> GameManager --updates GameSession--> World Map
World Map --enter settlement--> GameManager --updates GameSession--> StartingSettlement
```

`GameManager` owns named navigation and coordinates a state transition before
loading the destination scene. `GameSession` records the resulting durable
facts. A scene emits an intent or handles a local button and asks the manager
for the corresponding named action; it never chooses state changes indirectly
by editing another scene.

## Explicit non-goals

- Multiple adventurers or parties
- Party size limits beyond at least one member
- Combat statistics, attacks, equipment effects, or recruitment
- Settlement buildings, upgrades, economy, save/load, or time
- Random encounters and local dungeon maps
- Replacing the existing movement rules

## Acceptance criteria

1. Starting a new game places the player in the starting settlement, not
   directly on the world map.
2. The roster visibly contains one unassigned Warrior with a sword.
3. The player can create one party and assign the Warrior to it.
4. Depart is unavailable without a non-empty party and available after the
   Warrior is assigned.
5. Departing shows the party at the settlement position on the world map.
6. The deployed party moves using the existing select-then-move behavior, and
   the new position persists through a scene change.
7. Activating the settlement tile returns the party to the settlement and
   removes its world-map marker.
8. The complete flow has unit tests for campaign-state transitions and the
   existing world-map movement tests continue to pass.

## Deferred decisions

The following choices are intentionally left for the next design pass: the
party's displayed name, whether a returned party may immediately depart again,
whether the settlement can be entered only from its exact tile, and how battle
will validate or render the party's members. None changes the ownership or
transition boundaries above.
