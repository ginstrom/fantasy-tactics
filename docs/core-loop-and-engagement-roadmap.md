# Core Loop Completion and Engagement Roadmap

> **Status:** Decision-recorded product roadmap — the blocking campaign
> decisions (D1–D5) from
> [`core-loop-and-engagement-required-decisions.md`](core-loop-and-engagement-required-decisions.md)
> are incorporated below. D6–D9 remain feature-slice decisions; assign their
> owners and decision dates before treating this as a complete implementation
> contract.

## Goal

Deliver a compact, completable Borderlands campaign in which tactical
victories improve an encampment, the improved encampment expands the party's
options, and those options unlock the next tactical challenge. Once that
loop is trustworthy and satisfying, iterate on engagement and appeal through
**graphics** (3/4 top-down perspective) and **sound**.

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
- Tactical mechanics (directional facing, flanking, critical hits, armor/guard,
  AP budgets) are implemented.
- Warrior and Scout have automatic class-owned stat growth and every-third-level
  perk choices. Cleric, healing/protection, and Scout reconnaissance are not
  yet live systems.
- Encounters and recruitment offers replenish over world turns.

The campaign is not yet completable: encounter replenishment currently makes
it a repeatable sandbox rather than a progression path with a final outcome.

## Completion boundary

The core loop is complete when a fresh campaign can, without debug tools:

1. **Streamline Onboarding:** Guide the player directly into recruiting and
   deploying their initial party with a clear starting objective.
2. **Authored Objectives & Rewards:** Present clear tier-1, tier-2, and tier-3
   objectives with meaningful resources (calibrated for a 10–15 battle arc).
3. **Dual Improvement Paths:** Offer encampment upgrades and party progression
   as mutually reinforcing choices.
4. **Meaningful Gating:** Gate tier-2, tier-3, and final challenges behind
   understandable preparation (tactical counterplay, gear, composition).
5. **Class & Tactical Relevance:** Make 3-class composition (Warrior / Scout / Cleric),
   directional positioning, and equipment decisions matter to outcomes.
6. **Permadeath, Stakes & Economy Floor:** Enforce permanent death for slain
   units and meaningful setback on party defeat, while ensuring recruitment
   replenishment and encampment passive income prevent unrecoverable soft locks.
7. **Victory & Free Play:** End in an authored final boss encounter, display
   a campaign victory screen, and permit optional free play afterwards.

## Roadmap

### 1. Lock the campaign contract and durable state

Define the first campaign as a 60–90 minute Borderlands-cleared arc of twelve
required battles: three tiers of three authored encounters, a two-battle
pre-boss sequence, and one final boss. Each next node unlocks only when its
campaign-objective prerequisite is complete; repeatable free-play vacancies
appear only after victory.

- **Party Scope:** Exactly 1 active party (`party_001`). Start with three
  deployable slots, then upgrade to four and five. The initial roster may have
  more than three adventurers, but only three deploy. Multi-party coordination
  remains post-campaign work.
- **Campaign vs Sandbox State:** Track campaign milestone progression in
  `GameSession` separately from repeatable encounter vacancies. Persist a
  versioned campaign state containing the current objective, completed
  objective ids, unlocked authored encounters, final-victory state, and
  post-victory free-play state. Respawns must never reopen or invalidate a
  completed objective. The final boss atomically records victory, shows a
  dedicated victory screen, and unlocks clearly labelled free play; free play
  never modifies completed objectives or replays that screen.
- **Authored Arc:** Every authored node declares an objective id, exact enemy
  composition, prerequisite, reward, intended counterplay, and loss
  consequence. Repeatable vacancies are free-play content, not a source of
  required campaign battles or progression gates.
- **Onboarding Flow:** Starting a new game routes directly to party formation
  with clear guidance toward the first objective (for example, clearing the
  Goblin Outpost).

**Milestone:** A campaign UI communicates the current objective, next unlock,
and final victory condition, persisting across saves.

### 2. Establish the streamlined building and tier model

Make every building level a visible strategic choice with a cost, a world-turn
or immediate completion rule, a prerequisite, and a concrete unlock. Keep the
Encampment a fast, card-like decision layer without screen sprawl.

Core Encampment Hubs:

| Building Hub | Core Role | Progression & Tier Unlocks |
|---|---|---|
| **Guild Hall** | Roster & Party Capacity | Raises deployment from 3 to 4 to 5 and houses general recruitment (Warrior, Scout). Tier 1 holds up to 10 roster members and 4 recruitable offers; tier 2 holds 15 and 6 respectively. When a new offer arrives to a full pool, remove the oldest offer. |
| **Temple** | Sustain & Faith | Recruits Clerics and provides one encampment blessing. The first Cleric slice adds one targeted in-battle heal and one temporary protection effect; it does not add a broad spell tree or Mage prerequisites. |
| **Blacksmith & Workshops** | Physical & Magical Gear | Weapon/armor crafting, sharpening (Blacksmith), healing potions (Alchemy), rune upgrades (Runic). |
| **Shop & Stores** | Economy & Supplies | Sells encounter loot and buys basic weapons, armor, and provisions. It supplies 2 gold/turn at tier 1 (iron arms), 5 gold/turn at tier 2 (steel arms), and 10 gold/turn at tier 3 (2–8 HP healing potions for 20 gold). |

**Milestone:** A fresh player can afford and understand the first upgrade,
then see it unlock a new recruit, tool, or capability before tier 2.

### 3. Finish the first class system slice

Treat a class as a role with unique tactical and strategic decisions. Retain
automatic class-owned skill growth and the every-third-level perk cadence;
remove legacy manual Attack-spending.

1. **Warrior (Front Line):** High Health, Might, and Guard. Holds space,
   protects allies, and punishes flanking enemies.
2. **Scout (Ranged Pressure & Reconnaissance):** High Accuracy and AP. On the
   tactical grid, delivers safe ranged attacks. On the World Map, provides
   **Strategic Reconnaissance** (reveals exact enemy types and counts, danger
   tier, and reward categories—gold band, crystal tier, and possible gear—before
   entering an encounter). It does not reveal random-roll outcomes, enemy
   positions, or every future ability.
3. **Cleric (Sustain & Protection):** Moderate durability, blunt melee, and
   in-combat healing/protection spells. Mitigates attrition without trivializing
   defeat risk.
4. **Deferred:** Mage, advanced specializations, and complex reaction trees
   remain deferred until the Warrior/Scout/Cleric triad is balanced.

**Milestone:** A Warrior/Scout/Cleric party has clear tactical synergies;
Scout reconnaissance provides real world-map value; and class-owned equipment,
abilities, save state, deterministic scenarios, and `make check` all agree.

### 4. Build the encounter and reward ladder

Create three authored encounters in each of tiers 1–3, a two-battle pre-boss
sequence, and a final boss. For every required battle, define its objective id,
exact composition, prerequisite, reward, intended counterplay, and failure
consequence. Monster threat rises over world turns; its timing must allow a
party of five to reach about level 6, make several Encampment upgrades, and
reach the final boss. Show the resulting threat level as 1–5 star icons in the
UI. Calibrate rewards against the resolved economy contract rather than fixed
averages alone:

- **Tier 1 (Goblins / Kobolds):** Teaches formation, directional facing,
  flanking, and returning with loot.
- **Tier 2 (Orcs / Brutes):** High durability and heavy armor; rewards
  scouting, ranged kiting, the selected answer to armor/resistance, and potion
  use.
- **Tier 3 (Hobgoblin Command / Mixed Forces):** Mixed compositions with
  support and heavy frontline; requires deliberate target prioritization.
- **Final Encounter (Borderlands Chieftain / Boss):** Climactic multi-unit
  encounter testing party composition, positioning, and accumulated upgrades.

**Milestone:** Each tier has deterministic scenario coverage and a manual
play-through demonstrating intended counterplay and clean victory resolution.

### 5. Define defeat, recovery, and the economy floor

Enforce high stakes through permanent loss while guarding against unrecoverable
campaign soft locks:

- **Unit Permadeath:** Define the battle state that constitutes a death and
  permanently remove a unit at battle resolution when it reaches 0 HP. Validate
  all state before mutation, then transfer its equipped, carried, and unique
  modified items atomically to the party loot pool, returning them to the
  Encampment bank after a successful retreat. A dead id may not remain in party
  members, item ownership, save data, or battle-aftermath input.
- **Retreat & Wipe:** Add a Retreat button at the lower left of the bottom
  panel, alongside Move, Action, and End Turn. On retreat, apply the
  nearest-enemy consequence below and leave the party over the encounter
  location; on a party wipe, return to the Encampment and lose all gold and
  loot. In either case, discard unbanked/pending rewards.

  | Nearest enemy distance | No remaining-HP loss | 10% loss | 50% loss | Death |
  |---|---:|---:|---:|---:|
  | 1–3 | 10% | 30% | 30% | 30% |
  | 4–6 | 20% | 50% | 10% | 10% |
  | 7+ | 50% | 30% | 10% | 10% |

- **Soft-Lock Prevention & Encampment Income:** Guarantee an affordable
  level-1 replacement and a player-accessible way to advance recovery time
  after a wipe or bankruptcy. Every turn advances healing, jobs, recruitment
  vacancies, and the Shop income above even when no party is deployable. Test
  zero-gold, no-party, repeated-retreat, and wipe states through to a legal
  replacement party.

**Milestone:** Unit death, party retreat, recruitment replenishment, and
recovery paths are fully tested and prevent dead ends.

### 6. Prove campaign balance and usability

Use deterministic battle scenarios and the headless simulator (`battle_sim.gd`,
`scenario_runner_main.gd`) to verify each battle's tactical counterplay. Add a
campaign-level deterministic harness that advances the durable campaign state,
economy, recovery, and authored encounter graph; battle-only simulations cannot
prove a campaign is completable.

- Run headless campaign passes measuring rounds, damage, survival rate,
  gold velocity, and upgrade progression.
- Execute manual playthroughs from a clean save to final victory, including a
  setback/rebuilding loop from a zero-gold wipe.

**Milestone:** A clean campaign consistently reaches victory without soft
locks or opaque mechanics, and `make check` passes.

### 7. Iterate for engagement and appeal: graphics and sound

Once the mechanical loop is proven, execute the presentation pass to maximize
clarity and game feel.

**Graphics (3/4 Top-Down Perspective)**

- **Perspective:** Standardize on a clear **3/4 top-down perspective** for both
  the tactical Battlefield and the World Map.
- **Asset Pipeline:** Use a hybrid approach starting with clean, simple
  placeholders (curated CC0/Kenney assets and minimal geometric sprites) for
  rapid iteration, upgrading to polished custom assets as systems settle.
- **Tactical Feedback:** High-contrast combat floating numbers (hits, misses,
  criticals, damage, healing), wound state indicators, and directional facing
  arrows.
- **Strategic Readability:** Clean Encampment building states and clear World Map
  fog-of-war and scouting overlays.

**Sound**

- **Audio Cues:** Crisp sound effects for UI actions, movement, weapon swings,
  hits/misses/crits, spell healing, loot acquisition, building upgrades,
  victory, and unit death.
- **Music & Ambience:** Restrained background music states for Encampment, World
  Map travel, combat, and victory.
- **Audio Controls:** Master, Music, and SFX volume buses with complete visual
  feedback parity when sound is muted.

**Milestone:** Screenshots, an audio checklist, and a manual clarity test cover
tactical selection, facing, hit results, wounds, objectives, gates, and mute
parity without obscuring tactical information.

## Decisions Locked

1. **Campaign Scope:** 60–90 minute compact Borderlands campaign with twelve
   required battles: three tiers of three, two pre-boss battles, and a final boss.
2. **Party Count & Recruitment:** Exactly one deployed party starts at three
   slots and upgrades to four then five; Guild Hall tier 1 caps the roster at
   10 and recruitable offers at 4, tier 2 at 15 and 6, with oldest-offer removal
   on overflow.
3. **Defeat & Recovery:** Slain units are removed atomically at battle
   resolution; retreat has distance-based HP-loss/death consequences, while a
   wipe loses all gold and loot. Shop tiers provide 2/5/10 gold per turn and
   all recovery systems advance without a deployable party.
4. **Threat Visibility:** World-turn monster threat rises on a campaign pace
   toward level 6 and several upgrades, and appears as 1–5 star icons.
5. **Third Root Class:** Cleric (combat sustain, holy protection, Temple synergy).
6. **Visual Perspective & Assets:** 3/4 top-down perspective; hybrid asset
   strategy beginning with simple, rapid placeholders and iterating.

## Required decisions

The companion [required decision register](core-loop-and-engagement-required-decisions.md)
records the implemented contract choices D1–D5. Assign an owner and decision
date for D6 (Scout reconnaissance), D7 (Cleric and Temple scope), D8 (final
encounter and free play), and D9 (presentation proof standard) before their
feature slices begin.

## Sequencing Rule

Do not begin broad graphics or sound production until campaign progression,
permadeath/recovery loops, the economy floor, and the final objective are
stable and verified.
Small feedback placeholders may be used during feature development, but the
major presentation pass follows a proven playable loop.
