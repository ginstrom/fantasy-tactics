# Intelligence System

**Implementation status:** encounter discovery, scouting, Watchtowers, and
Guild Hall quests are **to implement**. The formulas below are accepted design
requirements; quest cadence and time-based escalation remain **decision
pending**. See the [design status legend](README.md#implementation-status-legend).

Intelligence makes encounter discovery and preparation a strategic activity.
Its rules apply to live encounter instances; a new instance receives a new
knowledge record even when it uses a familiar template. An encounter record
persists whether it is undiscovered or discovered, the intelligence tiers
already known, and an optional quest id. Knowledge does not decay or become
stale. Clearing or removing an encounter removes its record.

Players gain intelligence from three sources:

- Guild Hall quests
- Scouts
- Watchtowers

## Distance and timing

The World Map retains its underlying grid for placing locations, but parties
may only travel between the Encampment and encounter locations. The distance
between two locations is their straight-line grid distance, rounded up to the
next whole number. This **turn distance** is both the displayed travel time
and the distance used for intelligence falloff.

At the start of each World Map Turn, detection and intelligence checks resolve
for every live encounter. World Map Turns remain frozen while a party is in a
Battlefield encounter. Repeated checks model intelligence gathered over time:
scouts stationed nearer to an encounter improve the chance to discover it and
to learn its next unknown detail.

```
distance_retention = clamp(1.0 - (turn_distance * 0.1), 0.0, 1.0)
```

Distance reduces a source's chance multiplicatively, never by subtracting
percentage points. At turn distance 1, `distance_retention` is `0.9`: a 50%
base chance becomes 45%. This is deliberately a retention factor, not a
"penalty" value: larger turn distances must always produce an equal or lower
factor. At the distance whose factor is `0.4`, a detection or scouting chance
is multiplied by `0.4` rather than reduced by 40 percentage points.

All chances are percentages and are clamped to the inclusive range 0–100.
The random rolls must be injectable/seeded for deterministic tests and
campaign simulation.

## Detection

An undiscovered encounter receives independent detection checks from every
eligible source each World Map Turn. One successful check permanently marks it
as discovered and makes its known information visible on the World Map.

### Encampment detection

The Encampment makes one check using its detection score plus the best
Scouting skill among Scouts currently at the Encampment:

```
encampment_detection_chance = clamp(
    (encampment_detection + best_encamped_scout_scouting) * distance_retention,
    0,
    100
)
```

`encampment_detection` is 25 without a Watchtower. A Watchtower replaces that
base value with its tier's value; the best encamped Scout is then added. For
example, no Watchtower plus a Scout with Scouting 20 gives 45 detection before
distance falloff.

| Watchtower tier | Cost | Encampment detection |
|---:|---:|---:|
| None | — | 25 |
| 1 | 50 | 50 |
| 2 | 100 | 65 |
| 3 | 200 | 75 |

### Deployed-party detection

Every deployed party containing at least one Scout makes its own independent
check. It uses the best Scouting skill in that party and no Encampment bonus:

```
party_detection_chance = clamp(
    best_party_scout_scouting * distance_retention,
    0,
    100
)
```

Several deployed scouting parties therefore provide several chances to detect
an encounter. A nearby Scout can outperform the Encampment even when its raw
Scouting value is lower.

## Accumulating scouting intelligence

Once an encounter is discovered, it receives one intelligence check per World
Map Turn. Use the highest eligible Scouting skill among the Encampment and
deployed parties, then apply distance retention. The check attempts only the
next unknown information tier, so information accumulates in order over time:

1. Tier level
2. Main monster
3. All monsters
4. Monster counts

```
intel_chance = clamp(
    scouting * information_modifier * distance_retention,
    0,
    100
)
```

| Information type | Information modifier |
|---|---:|
| Tier level | ×2 |
| Main monster | ×1 |
| All monsters | ×0.75 |
| Monster counts | ×0.5 |

For example, a Scouting score of 25 has a 50% Tier-level chance before
falloff; at turn distance 1, that becomes 45%. A failed check leaves the next
tier unknown and retries it on a later World Map Turn.

## Authored objective discovery

Discovery probability must never control whether the player can continue the
authored Borderlands campaign. When a prerequisite unlocks an authored
objective, that encounter is permanently discovered and its location is shown
as the current objective. Scout, Watchtower, and Guild Hall systems still
govern optional encounters and the progressively revealed information about
the authored encounter.

## Guild Hall quests

Quests are optional leads: they help discover encounters and grant additional
rewards, but never gate authored campaign objectives or make a missed timer
block campaign completion.

When a new live encounter instance is created, it has an initial 50% chance to
be offered as a Guild Hall quest if its star tier is eligible for the current
Guild Hall tier. This initial rate makes roughly half of eligible newly created
encounters quest targets. A later time-based escalation system may increase an
unquested encounter's chance as it remains on the World Map; that is deferred.

| Guild Hall tier | Encounter tiers eligible for quests |
|---:|---|
| 1 | 1 star |
| 2 | 1–2 stars |
| 3 | 1–4 stars |
| 4 | 1–5 stars |

Accepting a quest permanently discovers its target and reveals its Tier level
and Main monster. Its timer starts on acceptance. If the player does not
complete it before the timer expires, new quest postings are blocked for
`encounter_tier * 5` World Map Turns; already posted quests remain visible but
are expired and award no quest reward.

A quest completes only when its target is cleared and the party returns to the
Encampment. Completion grants the reward listed on the quest in addition to
normal loot. The initial reward is 50% of the encounter's expected gold and
loot value; at higher tiers it may be an item instead of gold. Quest duration,
the exact expected-value table, and quest posting cadence are balance data,
owned by `GameConfig`, when this system is implemented.

## Full-experience scope

The strategic model supports multiple parties. Multi-party dispatch,
simultaneous scouting parties, Guild Hall tier 4, and time-based quest
escalation are **to implement** for the full experience. The exact escalation
cadence remains **decision pending**. See [World Map and
Encounters](world-map-and-encounters.md) and the [Borderlands Campaign
Loop](campaign-loop.md).
