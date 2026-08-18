# Core Loop Completion and Engagement Roadmap

> **Status:** Approved Product Roadmap — defines the scope and sequencing required
> to deliver a complete, closed campaign loop before executing the full
> presentation pass.

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
- Warrior and Scout data exist, with automatic class-owned stat growth and
  every-third-level perk choices.
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

### 1. Lock the campaign contract

Define the first campaign as a 60–90 minute Borderlands-cleared arc (~10–15
battles total). Specify the three encounter tiers, their authored objectives,
their unlock conditions, and the final boss encounter.

- **Party Scope:** Exactly 1 active party (`party_001`). Guild Hall upgrades
  increase party size capacity (from 3 up to 5 members), deferring multi-party
  coordination to post-campaign expansion.
- **Campaign vs Sandbox State:** Track campaign milestone progression in
  `GameSession` separately from repeatable encounter vacancies so respawns cannot
  reopen or invalidate completed objectives.
- **Onboarding Flow:** Starting a new game routes directly to party formation
  with clear guidance toward the first objective (e.g., clearing the Goblin Outpost).

**Milestone:** A campaign UI communicates the current objective, next unlock,
and final victory condition, persisting across saves.

### 2. Establish the streamlined building and tier model

Make every building level a visible strategic choice with a cost, a world-turn
or immediate completion rule, a prerequisite, and a concrete unlock. Keep the
Encampment a fast, card-like decision layer without screen sprawl.

Core Encampment Hubs:

| Building Hub | Core Role | Progression & Tier Unlocks |
|---|---|---|
| **Guild Hall** | Roster & Party Capacity | Increases max party size (3 → 4 → 5), expands roster cap, houses general recruitment (Warrior, Scout). |
| **Temple** | Sustain & Faith | Recruits Clerics, provides encampment healing/blessing services, accelerates wound recovery. |
| **Blacksmith & Workshops** | Physical & Magical Gear | Weapon/armor crafting, sharpening (Blacksmith), healing potions (Alchemy), rune upgrades (Runic). |
| **Trade Post & Stores** | Economy & Supplies | Selling encounter loot, purchasing basic weapons/armor/provisions, and generating passive encampment income (2 gold/turn base; increases to 5 gold/turn at shop tier 2). |

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
   and potential loot drops before entering an encounter).
3. **Cleric (Sustain & Protection):** Moderate durability, blunt melee, and
   in-combat healing/protection spells. Mitigates attrition without trivializing
   defeat risk.
4. **Deferred:** Mage, advanced specializations, and complex reaction trees
   remain deferred until the Warrior/Scout/Cleric triad is balanced.

**Milestone:** A Warrior/Scout/Cleric party has clear tactical synergies,
Scout reconnaissance provides real world-map value, and `make check` passes.

### 4. Build the encounter and reward ladder

Create authored tier-1, tier-2, tier-3, and final boss encounter templates.
Calibrate reward scaling (~25g average for tier 1, ~50g for tier 2, crafting
materials for tier 3) to support a 60–90 minute playthrough:

- **Tier 1 (Goblins / Kobolds):** Teaches formation, directional facing,
  flanking, and returning with loot.
- **Tier 2 (Orcs / Brutes):** High durability and heavy armor; rewards
  scouting, ranged kiting, armor-piercing gear, and potion use.
- **Tier 3 (Hobgoblin Command / Mixed Forces):** Mixed compositions with
  support and heavy frontline; requires deliberate target prioritization.
- **Final Encounter (Borderlands Chieftain / Boss):** Climactic multi-unit
  encounter testing party composition, positioning, and accumulated upgrades.

**Milestone:** Each tier has deterministic scenario coverage and a manual
play-through demonstrating intended counterplay and clean victory resolution.

### 5. Define defeat, recovery, and permadeath policy

Enforce high stakes through permanent loss while guarding against unrecoverable
campaign soft locks:

- **Unit Permadeath:** Units reduced to 0 HP that are slain in combat are
  permanently removed from the roster. High-level veterans and upgraded gear
  are precious and painful to lose.
- **Expedition Defeat / Wipe:** If all party members fall or retreat, the
  expedition fails. The party is routed back to the Encampment, unbanked battle
  and pending loot are lost, and world time advances (e.g., 2–3 turns).
- **Soft-Lock Prevention & Encampment Income:** The recruitment candidate pool
  always guarantees affordable level-1 recruits. To guarantee the economy cannot
  stall after a wipe or bankruptcy, the starting Encampment provides a baseline
  passive income of **2 gold/turn**, scaling to **5 gold/turn** when upgrading
  the shop to tier 2. This guarantees the player can always fund replacement
  recruits and basic gear by advancing world turns.

**Milestone:** Unit death, party retreat, recruitment replenishment, and
recovery paths are fully tested and prevent dead ends.

### 6. Prove campaign balance and usability

Use deterministic battle scenarios and the headless simulator (`battle_sim.gd`,
`scenario_runner_main.gd`) to verify that each tier is winnable with intended
preparation and that the economy does not stall.

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

1. **Campaign Scope:** 60–90 minute compact Borderlands campaign (~10–15 encounters).
2. **Defeat Policy & Economy Floor:** Permadeath for slain adventurers; party
   wipe causes retreat and loss of unbanked loot; recruitment floor and passive
   encampment income (2 gold/turn base, 5 gold/turn at shop tier 2) prevent
   campaign soft-locks.
3. **Party Count:** Exactly 1 deployed party for Campaign 1; Guild Hall scales
   party size (3 to 5 units).
4. **Third Root Class:** Cleric (combat sustain, holy protection, Temple synergy).
5. **Visual Perspective & Assets:** 3/4 top-down perspective; hybrid asset
   strategy beginning with simple, rapid placeholders and iterating.

## Sequencing Rule

Do not begin broad graphics or sound production until campaign progression,
permadeath/recovery loops, and the final objective are stable and verified.
Small feedback placeholders may be used during feature development, but the
major presentation pass follows a proven playable loop.
