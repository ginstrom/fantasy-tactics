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
| Temple | Future Cleric recruitment and one blessing. Exact Cleric/Temple feature scope is deferred. |
| Blacksmith and Workshops | Physical gear, potions, and rune upgrades; see the Equipment Handbook. |
| Shop and Stores | Sells loot and buys basic gear/provisions. It grants 2 gold per World Map Turn at tier 1, 5 at tier 2, and 10 at tier 3; the tier-3 contract includes 2–8 HP healing potions costing 20 gold. |

World Map Turns advance healing, jobs, recruitment vacancies, and Shop income
even with no deployable party. The campaign must always permit an affordable
level-1 replacement and an accessible way to advance recovery after bankruptcy
or a wipe. Zero-gold, no-party, repeated-retreat, and wipe states must lead to
a legal replacement party rather than a soft lock.

## Defeat, death, and retreat

A unit at 0 HP is dead. At battle resolution, validate all aftermath state
before changing it, then remove the dead unit permanently. Its equipped,
carried, and unique modified items transfer atomically to the party loot pool;
after a successful retreat, that loot returns to the Encampment bank. A dead
id must not remain in party membership, item ownership, save data, or
battle-aftermath input.

Retreat is an explicit player action. It ends the battle, discards all
unbanked/pending rewards, applies the nearest-enemy consequence below to each
surviving party member, and leaves the party at the encounter location.

| Nearest enemy distance | No remaining-HP loss | 10% loss | 50% loss | Death |
|---|---:|---:|---:|---:|
| 1–3 | 10% | 30% | 30% | 30% |
| 4–6 | 20% | 50% | 10% | 10% |
| 7+ | 50% | 30% | 10% | 10% |

The distance is measured when retreat resolves. Each row is a complete,
mutually exclusive outcome distribution and totals 100%.

A party wipe returns the party to the Encampment, permanently resolves deaths,
and loses all gold and loot. It also discards unbanked/pending rewards. It must
not erase completed campaign objectives or upgrades.

## Deferred roadmap decisions

The following are intentionally not implementation contracts yet:

- **Scout reconnaissance (D6):** the roadmap target is pre-battle information
  about enemy types/counts, danger tier, and reward categories, but its exact
  reveal and UI rules remain to be decided.
- **Cleric and Temple scope (D7):** a targeted in-battle heal and temporary
  protection are the proposed first slice, without a broad spell tree; final
  costs, targeting, and Temple integration remain to be decided.
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
- [Classes](class-system.md), [Monster Manual](monster-manual.md), and the
  [Equipment Handbook](equipment-handbook.md) define the tactical choices that
  authored encounters and recovery use.
