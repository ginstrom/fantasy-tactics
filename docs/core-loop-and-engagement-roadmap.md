# Core Loop Completion and Engagement Roadmap

> **Status:** Draft for discussion — this is a product roadmap, not an
> implementation plan or a claim that the listed work has shipped.

## Goal

Deliver a compact, completable Borderlands campaign in which tactical
victories improve an encampment, the improved encampment expands the party's
options, and those options unlock the next tactical challenge. Once that
loop is trustworthy and satisfying, iterate on engagement and appeal through
**graphics** and sound.

The intended first-complete loop is:

```text
Start -> recruit and form a party -> clear a tier -> return with loot
      -> recover, equip, and improve the encampment -> unlock the next tier
      -> defeat the final encounter -> optional free play
```

## Current foundation

The following are already useful foundations, not roadmap promises:

- A player can form and deploy one party, travel on the World Map, fight,
  return to the Encampment, and bank loot.
- Recruitment, equipment transfer, shops/stores, item instances, workshops,
  saving, and world-turn jobs are in place.
- Warrior and Scout data exist, with automatic class-owned stat growth and
  every-third-level perk choices.
- Encounters and recruitment offers replenish over world turns.

The campaign is not yet completable: encounter replenishment currently makes
it a repeatable sandbox rather than a progression path with a final outcome.

## Completion boundary

The core loop is complete when a fresh campaign can, without debug tools:

1. Teach the player to create and deploy a viable party.
2. Present a clear tier-1 objective and reward it with meaningful resources.
3. Offer at least two mutually useful improvement paths: encampment and party.
4. Gate tier-2 and tier-3 challenges behind understandable preparation,
   rather than arbitrary level checks.
5. Make class composition and equipment decisions matter to outcomes.
6. Resolve defeat with a clear, durable recovery consequence.
7. End in a final encounter, show campaign victory, and permit intentional
   free play afterwards.

## Roadmap

### 1. Lock the campaign contract

Define the first campaign as a 60–90 minute Borderlands-cleared arc. Specify
the three encounter tiers, their objectives, their unlock conditions, and the
final encounter. Track campaign state separately from repeatable encounter
vacancies so that free-play respawns cannot reopen or invalidate completed
objectives.

**Milestone:** a campaign screen communicates the current objective, next
unlock, and final victory condition.

### 2. Establish the building and tier model

Make every building level a visible strategic choice with a cost, a world-turn
or immediate completion rule, a prerequisite, and a concrete unlock.

Initial building tree:

| Building | First role | Example tier unlocks |
|---|---|---|
| Guild Hall | Party capacity and organisation | party size, then a second party only if multi-party play is in scope |
| Fighters' Guild | Martial recruits and training | Warrior recruitment, martial equipment or training |
| Scout Lodge | Reconnaissance | Scout recruitment, encounter previews, improved map information |
| Temple | Sustain | Cleric recruitment, recovery or protection services |
| Blacksmith | Physical gear | weapon/armor crafting and improvements |
| Alchemy Workshop | Consumables | healing-potion tiers |
| Runic Workshop | Magical gear | rune access and upgrades |
| Trade Post / Watchtower | Economy and world access | income/trade stock; safer or more-visible routes |

Do not build a city-builder simulation. The Encampment should remain a fast,
card-like decision layer where each completed building changes a future
adventuring choice.

**Milestone:** a fresh player can afford and understand the first upgrade,
then see it unlock a new recruit, tool, or route before tier 2.

### 3. Finish the first class system slice

Treat a class as a role with a unique decision, not a stat package. Retain
automatic class-owned skill growth and the every-third-level perk cadence;
remove the temporary manual Attack-spending path rather than supporting both.

1. Complete Warrior and Scout end-to-end: starting values, owned skills,
   level-up presentation, save migration, perks, and balance coverage.
2. Give Scout a world role before expanding its perk tree: reveal encounter
   danger, composition, routes, or objectives in a way that changes expedition
   choice.
3. Add one sustain/control root class, recommended: Cleric. Its healing or
   protection must create attrition-management decisions without removing
   defeat risk.
4. Defer Mage, specialisations, and complex reactions until the three-role
   party has proven its value against distinct encounters.

**Milestone:** a Warrior/Scout/Cleric party has understandable trade-offs,
and each role has at least one encounter where it is clearly valuable but not
mandatory.

### 4. Build the encounter and reward ladder

Create authored tier-1, tier-2, tier-3, and final encounter templates. Each
needs a tactical pattern, a preparation expectation, a reward, and a reason
to return to the Encampment.

- Tier 1 teaches formation, movement, attacks, and returning with loot.
- Tier 2 rewards scouting, ranged pressure, consumables, or first equipment
  upgrades.
- Tier 3 requires deliberate party composition and stronger gear.
- The final encounter tests the campaign's accumulated decisions rather than
  simply having larger numbers.

Use repeatable encounters for optional income and practice only after the
authored campaign objective has been recorded as completed.

**Milestone:** each tier has deterministic scenario coverage and a manual
play-through demonstrating the intended preparation and counterplay.

### 5. Define defeat, recovery, and pacing

Choose and implement one coherent defeat policy before balancing the full
campaign. Recommended initial policy: a defeated expedition retreats to the
Encampment, advances world time, applies injuries/recovery time, and forfeits
unbanked battle rewards; no permanent adventurer death in the first complete
arc.

This keeps setbacks meaningful while avoiding a campaign-ending punishment
before recovery tools and replacement recruitment are sufficiently rich.

**Milestone:** defeat, retreat, recovery, save/load, and return-to-objective
paths are all explicit and tested.

### 6. Prove campaign balance and usability

Use deterministic battle scenarios and the existing headless simulator to
check that each required tier is winnable with intended preparation and that
the economy does not stall. Run manual play-throughs from a clean save,
including one loss and recovery.

Measure campaign evidence such as completion rate, encounter outcome, rounds,
damage, rewards, upgrade order, and recovery time. This is balance evidence,
not a presentation feature.

**Milestone:** a clean campaign can reach victory reproducibly, with no soft
locks or opaque requirements, and `make check` passes.

### 7. Iterate for engagement and appeal: graphics and sound

Only after the above loop works, improve its clarity and emotional payoff.

**Graphics**

- Establish a coherent visual direction for terrain, buildings, units,
  portraits, items, status effects, and encounter tiers.
- Add readable combat feedback: hit, miss, critical hit, damage, healing,
  loot, completion, and defeat.
- Improve World Map and Encampment state readability so new unlocks and
  current objectives are visible at a glance.

**Sound**

- Add a small, consistent sound set for UI confirmation, movement, attacks,
  hit/miss/critical outcomes, healing, loot, building completion, victory,
  and defeat.
- Add restrained music states for Encampment, travel, battle, and victory.
- Provide master/music/effects volume controls and preserve clear visual
  feedback when sound is disabled.

**Milestone:** screenshots and manual play verify that graphics and sound make
every major action and campaign-state change easier to read and more rewarding
without slowing input or obscuring tactical information.

## Decisions still required

1. Confirm the 60–90 minute first-campaign target, or choose a longer
   settlement-builder arc.
2. Confirm the recommended no-permadeath defeat policy for this first arc.
3. Confirm whether Guild Hall tiering should include multi-party play now, or
   leave it as a post-campaign expansion.
4. Confirm Cleric as the third root class, or choose Mage instead.
5. Choose the art direction and audio production approach before asset work:
   placeholder/procedural, commissioned, licensed, or a defined hybrid.

## Sequencing rule

Do not begin broad graphics or sound production until campaign progression,
defeat recovery, and the final objective are stable. Small feedback assets may
be added alongside a feature when they are necessary to understand it, but the
large presentation pass follows a proven playable loop.
