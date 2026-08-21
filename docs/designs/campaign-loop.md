# Borderlands Campaign Loop

## Purpose and status

This document is the canonical design contract for the first completable
Borderlands campaign. It connects the tactical, party, Encampment, economy,
and World Map systems described elsewhere in `docs/designs/`. **Contract**
means a locked roadmap decision that a future slice must implement and test;
it is not a claim that the behaviour is already shipped. **Deferred** means
the roadmap deliberately leaves the feature-slice decision open.

## Campaign contract

The first campaign is a 60–90 minute arc of twelve required authored battles:
three tier-1 encounters, three tier-2 encounters, three tier-3 encounters, a
two-battle pre-boss sequence, and a final boss. Its loop is:

```text
Recruit and deploy -> clear the current objective -> return with loot
-> recover, equip, or upgrade the Encampment -> unlock the next objective
-> defeat the final boss -> optional free play
```

The campaign has exactly one active party, `party_001`. It begins with three
deployable slots. Guild Hall upgrades raise deployment capacity to four and
then five; they do not create additional active parties.

Each authored encounter declares a stable objective id, exact enemy
composition, prerequisite objective, reward, intended counterplay, and loss
consequence. Campaign state persists the current objective, completed
objective ids, unlocked authored encounters, final-victory state, and
post-victory free-play state. It is versioned and owned by `GameSession`.

Authored objectives never respawn or reopen when encounter vacancies refill.
After final victory, clearly labelled repeatable free play may fill vacancies,
but it never changes completed objectives or replays the victory screen.

## Objectives, gates, and encounter threat

A fresh campaign routes the player directly to party formation and states the
first objective. The campaign UI always communicates the current objective,
its next unlock, and the final victory condition.

Tier gates must be understandable preparation gates—not hidden numerical
thresholds. Tier 1 teaches formation, facing, flanking, and banking loot;
tier 2 tests scouting, ranged pressure, armour/resistance counterplay, and
potion use; tier 3 tests target priority against mixed forces. The final boss
tests the accumulated party composition, positioning, and Encampment upgrades.

Monster threat rises on a campaign pace that permits a party of five to reach
about level 6 and make several Encampment upgrades before the final boss. The
World Map displays the resulting threat as one to five stars. A star rating is
an encounter-risk signal, not an objective prerequisite and not a substitute
for the authored encounter definition.

## Encampment progression and economy floor

The Encampment is a fast, card-like strategic layer. Every building level must
show its cost, completion timing (immediate or world-turn), prerequisite, and
concrete unlock.

| Hub | Contract role |
|---|---|
| Guild Hall | General Warrior/Scout recruitment and party capacity. Tier 1 permits 10 roster members and 4 offers; tier 2 permits 15 and 6. When an arriving offer would exceed the cap, remove the oldest offer. |
| Temple | Cleric recruitment and recovery support. Each Temple tier adds 1 HP to Encampment natural recovery per World Map Turn; it does not change MP recovery. |
| Blacksmith and Workshops | Physical gear, potions, and rune upgrades; see the Equipment Handbook. |
| Shop and Stores | Sells loot and buys basic gear/provisions. It grants 2 gold per World Map Turn at tier 1, 5 at tier 2, and 10 at tier 3; the tier-3 contract includes 2–8 HP healing potions costing 20 gold. |

World Map Turns advance recovery, jobs, recruitment vacancies, and Shop income
even with no deployable party. Natural recovery is per adventurer, per World
Map Turn: a moving deployed adventurer recovers **1 HP and 2 MP**; a stationary
deployed adventurer recovers **2 HP and 4 MP**; and an adventurer at the
Encampment recovers **3 HP and 6 MP**, plus **1 HP for each Temple tier**. Thus
an Encampment with a tier-2 Temple restores 5 HP and 6 MP per turn. Recovery
cannot exceed the adventurer's maximum HP or MP. Only a class with an MP-backed
resource (Cleric) recovers MP; an adventurer with no `mp_max` always recovers
0 MP, which is a no-op, not an error. These rates live in
`config/game_config.json`'s `healing` section
(`moving_rate`/`resting_rate`/`encamped_rate` for HP,
`moving_mp_rate`/`resting_mp_rate`/`encamped_mp_rate` for MP,
`temple_hp_bonus_per_tier` for the Temple bonus) and supersede the previous
flat, Temple-blind `encamped_rate` of 4.

Cleric current MP is durable adventurer state, not a battle-local reset: a
battle start hydrates the battle unit's MP from the adventurer's durable
current/max MP (not always full), and battle aftermath writes the surviving
Cleric's remaining MP back, clamped to `cleric.mp_max` (3, `config/
game_config.json`). A dead adventurer owns no persisted MP record, the same
as HP. A save with no `mp_current` field migrates it to full (`mp_current =
mp_max`) on load.

A Healer is a deliberate recovery accelerator. The Healer's details view must
offer **Heal party member**: it targets a living member of that Healer's
deployed party, or a living adventurer at the Encampment when the Healer is
encamped, and spends the Healer's available MP to restore HP. The locked
values (`config/game_config.json`'s `cleric` section) match the existing
battle-local Heal spell exactly: **1 MP cost**, **2–8 HP restored** (random,
capped at the target's max HP). The action is a no-op — no MP spent, no HP
changed — when the Healer lacks 1 MP, the target is already at full HP, the
target is dead, or the target isn't a legal target (wrong party, or an
Encampment adventurer while the Healer is still deployed); the UI disables
the button and states the reason rather than allowing a failed attempt. A
future mana-recovery potion joins the healing potion line to speed MP
recovery.

Passing a World Map Turn is a legal, intentional recovery action, not a free
pause: it advances every stated world-turn system, including jobs, vacancies,
Shop income, and accepted Guild Hall quest timers. Future unquested-encounter
escalation will add further time pressure. The campaign must always permit an
affordable level-1 replacement and an accessible way to advance recovery after
bankruptcy or a wipe. Zero-gold, no-party, repeated-retreat, and wipe states
must lead to a legal replacement party rather than a soft lock.

## Defeat, death, and retreat

A unit at 0 HP is dead. At battle resolution, validate all aftermath state
before changing it, then remove the dead unit permanently. Its equipped,
carried, and unique modified items transfer atomically to the party loot pool;
after a successful retreat, that loot returns to the Encampment bank. A dead
id must not remain in party membership, item ownership, save data, or
battle-aftermath input.

**Battle Retreat** is an explicit player action available only after entering
the Battlefield. It ends the battle, discards all
unbanked/pending rewards, applies the nearest-enemy consequence below to each
surviving party member, and leaves the party at the encounter location.

| Nearest enemy distance | No remaining-HP loss | 10% loss | 50% loss | Death |
|---|---:|---:|---:|---:|
| 1–3 | 10% | 30% | 30% | 30% |
| 4–6 | 20% | 50% | 10% | 10% |
| 7+ | 50% | 30% | 10% | 10% |

The distance is measured when Battle Retreat resolves. Each row is a complete,
mutually exclusive per-unit outcome distribution and totals 100%.

After Battle Retreat, surviving members appear on the World Map at the
encounter location with their destination set to the Encampment. They travel
home over subsequent World Map Turns. The lower-risk pre-battle **Withdraw**
action is defined separately in [World Map and
Encounters](world-map-and-encounters.md#arrival-and-withdrawal).

A party wipe returns the party to the Encampment, permanently resolves deaths,
and loses all gold and loot. It also discards unbanked/pending rewards. It must
not erase completed campaign objectives or upgrades.

## Deferred roadmap decisions

The following are intentionally not implementation contracts yet:

- **Scout reconnaissance (D6):** discovery, scouting reveals, Watchtowers,
  and optional Guild Hall quests are defined in the [Intelligence
  System](intelligence.md). Their multi-party and time-escalation portions
  remain deferred from the first campaign implementation.
- **Cleric and Temple scope (D7):** the recovery and details-view healing
  contract above is locked, including exact MP cost, HP range, and targeting
  for the details-view heal. A targeted in-battle heal and temporary
  protection remain the proposed first slice; broader Temple effects beyond
  the HP recovery bonus above (e.g. a second Temple tier) remain to be
  decided.
- **Final encounter and free-play presentation (D8):** victory is required,
  but the final composition, reward presentation, and free-play details remain
  to be decided.
- **Presentation proof standard (D9):** 3/4 top-down perspective, hybrid
  placeholder-to-custom assets, and audio/visual feedback are roadmap goals;
  their acceptance standard remains to be decided after the campaign loop is
  proven.

## Related design documents

- [Game Vision](vision.md) gives the player-facing premise and long-term
  direction.
- [Battle Screen](battle-screen.md) places the Retreat control and tactical
  controls.
- [Combat System](combat-system.md) defines round-level combat rules.
- [Intelligence System](intelligence.md) defines discovery, scouting, and
  optional quest intelligence.
- [Classes](class-system.md), [Monster Manual](monster-manual.md), and the
  [Equipment Handbook](equipment-handbook.md) define the tactical choices that
  authored encounters and recovery use.
