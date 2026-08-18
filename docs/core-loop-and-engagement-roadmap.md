# Core Loop Completion and Engagement Roadmap

> **Status:** Decision-gated product roadmap — the loop and sequencing are
> approved in principle, but the decisions in
> [`core-loop-and-engagement-required-decisions.md`](core-loop-and-engagement-required-decisions.md)
> must be resolved before this becomes an implementation contract.

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

Define the first campaign as a 60–90 minute Borderlands-cleared arc (~10–15
battles total). Specify the three encounter tiers, their authored objectives,
their unlock conditions, and the final boss encounter.

- **Party Scope:** Exactly 1 active party (`party_001`). Resolve the starting
  and upgraded party-size sequence before implementation; the current game
  supports four members at Guild Hall level 1 and five at level 2. Multi-party
  coordination remains post-campaign work.
- **Campaign vs Sandbox State:** Track campaign milestone progression in
  `GameSession` separately from repeatable encounter vacancies. Persist a
  versioned campaign state containing the current objective, completed
  objective ids, unlocked authored encounters, final-victory state, and
  post-victory free-play state. Respawns must never reopen or invalidate a
  completed objective.
- **Authored Arc:** Define a fixed objective graph that supplies the promised
  10–15 battles. Repeatable vacancies are free-play content, not a source of
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
| **Guild Hall** | Roster & Party Capacity | Raises the resolved party-size cap and houses general recruitment (Warrior, Scout). Do not promise a roster cap until one is specified and implemented. |
| **Temple** | Sustain & Faith | Recruits Clerics, provides encampment healing/blessing services, accelerates wound recovery. |
| **Blacksmith & Workshops** | Physical & Magical Gear | Weapon/armor crafting, sharpening (Blacksmith), healing potions (Alchemy), rune upgrades (Runic). |
| **Shop & Stores** | Economy & Supplies | Sells encounter loot and buys basic weapons, armor, and provisions. It also owns the campaign's passive-income rule; its exact base, upgrade amount, and time-advance path are decision-gated. |

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
   **Strategic Reconnaissance** (reveals exact enemy composition, danger rating,
   and potential loot drops before entering an encounter). Specify which of
   those facts are exact, which are ranges, and how the player reads them.
3. **Cleric (Sustain & Protection):** Moderate durability, blunt melee, and
   in-combat healing/protection spells. Mitigates attrition without trivializing
   defeat risk.
4. **Deferred:** Mage, advanced specializations, and complex reaction trees
   remain deferred until the Warrior/Scout/Cleric triad is balanced.

**Milestone:** A Warrior/Scout/Cleric party has clear tactical synergies;
Scout reconnaissance provides real world-map value; and class-owned equipment,
abilities, save state, deterministic scenarios, and `make check` all agree.

### 4. Build the encounter and reward ladder

Create authored tier-1, tier-2, tier-3, and final boss encounter templates.
For every required battle, define its objective id, exact composition,
prerequisite, reward, intended counterplay, and failure consequence. Calibrate
rewards against the resolved economy contract rather than fixed averages alone:

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
  permanently remove that unit from the roster and party. Resolve the fate of
  carried, equipped, and unique modified gear atomically; it cannot be left
  owned by a removed adventurer.
- **Expedition Defeat / Wipe:** If all party members fall or retreat, the
  expedition fails. The party is routed back to the Encampment, unbanked battle
  and pending loot are lost, and the resolved recovery-time rule applies. State
  whether retreat is an explicit player action or only the result of a wipe.
- **Soft-Lock Prevention & Encampment Income:** Guarantee an affordable
  level-1 replacement and a player-accessible way to advance recovery time
  after a wipe or bankruptcy. The passive-income amount, its Shop-tier scaling,
  and whether time can advance from the Encampment are explicit decisions, not
  assumptions.

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
- Execute manual playthroughs from clean save to final victory, including
  at least one party setback/rebuilding loop.

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

**Milestone:** Screenshots, audio tours, and manual play confirm that 3/4
top-down graphics and audio elevate clarity and game feel without obscuring
tactical information.

## Decisions Locked

1. **Campaign Scope:** 60–90 minute compact Borderlands campaign (~10–15 battles).
2. **Party Count:** Exactly 1 deployed party for Campaign 1; Guild Hall scales
   party size using the sequence selected in the decision register.
3. **Third Root Class:** Cleric (combat sustain, holy protection, Temple synergy).
4. **Visual Perspective & Assets:** 3/4 top-down perspective; hybrid asset
   strategy beginning with simple, rapid placeholders and iterating.

## Required decisions

The companion [required decision register](core-loop-and-engagement-required-decisions.md)
contains the remaining product decisions, recommended defaults, alternatives,
and the implementation consequences of each. Resolve its blocking decisions
before changing this roadmap back to an approved implementation contract.

## Sequencing Rule

Do not begin broad graphics or sound production until campaign progression,
permadeath/recovery loops, the economy floor, and the final objective are
stable and verified.
Small feedback placeholders may be used during feature development, but the
major presentation pass follows a proven playable loop.
