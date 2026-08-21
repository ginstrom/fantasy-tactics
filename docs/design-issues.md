# Game Design Review: Tactical & Strategic Systems

This review evaluates the complete design document set in [`docs/designs/`](docs/designs/) following the addition of the **Intelligence System** ([`intelligence.md`](docs/designs/intelligence.md)), the **World Map & Encounters** model ([`world-map-and-encounters.md`](docs/designs/world-map-and-encounters.md)), and related integration edits across [`campaign-loop.md`](docs/designs/campaign-loop.md), [`combat-system.md`](docs/designs/combat-system.md), [`battle-screen.md`](docs/designs/battle-screen.md), and [`vision.md`](docs/designs/vision.md).

---

## 1. Executive Summary & Core Strengths

The overall game design presents a coherent, compelling hybrid of **XCOM-style strategic management** and **D&D/tactical RPG combat**. 

### Key Design Highlights
* **Action Economy Clarity:** The generic 6-AP system in [`movement-and-action-points.md`](docs/designs/movement-and-action-points.md) cleanly standardizes movement (1 AP/tile), attacks (3 AP), and consumable usage (2 AP).
* **Defeat & Recovery Floor:** The anti-soft-lock economy floor in [`campaign-loop.md`](docs/designs/campaign-loop.md) (passive shop income, affordable level-1 replacements, permanent objective retention) guarantees campaigns cannot enter unrecoverable bankruptcy.
* **Separation of Concerns:** Tactical combat (Rounds) and strategic progression (World Map Turns) are cleanly decoupled, with clear ownership boundaries across files.

However, several **critical mathematical edge cases**, **cross-document discrepancies**, and **severe risk-vs-reward friction points** require refinement.

---

## 2. Consistency & Cross-Document Alignment

| Category | Issue / Inconsistency | Primary File | Conflicting Files |
| :--- | :--- | :--- | :--- |
| **Mobility vs AP** | [`monster-manual.md`](docs/designs/monster-manual.md) still defines `mobility: 3` and `accuracy: 60` in the shared monster schema. | [`monster-manual.md`](docs/designs/monster-manual.md) | [`class-system.md`](docs/designs/class-system.md) & [`movement-and-action-points.md`](docs/designs/movement-and-action-points.md) use unified `action_points` (6 AP base). |
| **Class Nomenclature** | The divine caster root class is called `Priest` in attribute formulas and skill progression tables, but `Cleric` elsewhere. | [`class-system.md`](docs/designs/class-system.md) | [`vision.md`](docs/designs/vision.md), [`campaign-loop.md`](docs/designs/campaign-loop.md), [`class-system.md`](docs/designs/class-system.md). |
| **Scout Specialization** | [`vision.md`](docs/designs/vision.md) describes Scouts specializing into *Ranger* or *Rogue* (luck/crit focus), while [`class-system.md`](docs/designs/class-system.md) only lists *Ranger*. | [`vision.md`](docs/designs/vision.md) | [`class-system.md`](docs/designs/class-system.md). |
| **Fog-of-War Model** | [`vision.md`](docs/designs/vision.md) describes a geometric visual radius around the city. The actual system is node/probability based. | [`vision.md`](docs/designs/vision.md) | [`intelligence.md`](docs/designs/intelligence.md) & [`world-map-and-encounters.md`](docs/designs/world-map-and-encounters.md). |
| **Multi-Party UI Scope** | [`world-map-and-encounters.md`](docs/designs/world-map-and-encounters.md) describes party dispatch modals and multi-party routing, but the campaign loop enforces exactly 1 active party. | [`world-map-and-encounters.md`](docs/designs/world-map-and-encounters.md) | [`campaign-loop.md`](docs/designs/campaign-loop.md). |

---

## 3. Critical Gaps & Mathematical Edge Cases

### 3.1. Encounter Discovery Soft-Lock
In [`intelligence.md`](docs/designs/intelligence.md):
$$\text{detection\_chance} = \text{clamp}(\text{encampment\_detection} + \text{best\_scout\_scouting} - (\text{turn\_distance} \times 10), 0, 100)$$

* **The Problem:** 
  * Without a Watchtower, base `encampment_detection` is `25`.
  * An encounter spawned at `turn_distance = 4` incurs a `40%` distance penalty ($4 \times 10$).
  * A starter Scout with Scouting $\le 15$ produces a detection chance of:
    $$25 + 15 - 40 = 0\%$$
  * If the initial 50% Guild Hall quest generation roll fails, the encounter will **never be discovered from town**, and deployed party detection without town bonus ($15 - 40 \le 0$) is also $0\%$.
* **Risk:** The player cannot discover or travel to required campaign objectives, creating an inadvertent progress soft-lock.
* **Fix:** Ensure authored campaign objectives have either guaranteed discovery upon unlocking, a non-zero floor for discovery, or automatic fallback escalation.

---

### 3.2. Distance Penalty on High-Tier Intelligence Gathering
In [`intelligence.md`](docs/designs/intelligence.md):
$$\text{intel\_chance} = \text{clamp}((\text{Scouting} \times \text{modifier}) - (\text{turn\_distance} \times 10), 0, 100)$$

| Information Tier | Modifier | Required Scouting at Distance 2 | Required Scouting at Distance 3 |
| :--- | :---: | :---: | :---: |
| **1. Tier Level** | $\times 2.0$ | $> 10$ | $> 15$ |
| **2. Main Monster** | $\times 1.0$ | $> 20$ | $> 30$ |
| **3. All Monsters** | $\times 0.75$ | $> 27$ | $> 40$ |
| **4. Monster Counts** | $\times 0.5$ | $> 40$ | $> 60$ |

* **The Problem:** The steep linear penalty ($-10\%$ per turn distance) makes accumulating higher intelligence tiers mathematically impossible for anything beyond 1–2 tiles from the Encampment unless Scout attributes reach endgame values.
* **Fix:** Use a softer distance falloff (e.g., $5 \times \text{turn\_distance}$) or apply the modifier to $(\text{Scouting} - \text{penalty})$ rather than scaling down Scouting before subtracting the penalty.

---

### 3.3. Pre-Battle "Withdraw" Permadeath Trap
In [`world-map-and-encounters.md`](docs/designs/world-map-and-encounters.md), arriving at an encounter location and choosing **Withdraw** triggers:
* 80% No HP loss
* 10% Lose 10% max HP
* 5% Lose 50% max HP
* **5% Permanent Death**

* **The Problem:** In a standard 5-unit party, declining to fight after arriving carries an immediate permadeath chance for at least one unit:
  $$1 - (0.95)^5 \approx 22.6\%$$
* **Impact:** A player doing cautious reconnaissance has a ~1-in-4 chance of losing a beloved hero just for declining to enter combat. This severely discourages exploratory play and scouting.
* **Fix:** Pre-battle Withdraw should have **0% death risk**, causing at most minor HP chip (e.g., 90% no loss, 10% lose 10% HP) or travel fatigue. High death risk should be reserved exclusively for in-combat **Battle Retreat** ([`campaign-loop.md`](docs/designs/campaign-loop.md)).

---

### 3.4. Underspecified Healing Rate & Turn-Pass Loophole
* In [`vision.md`](docs/designs/vision.md) and [`campaign-loop.md`](docs/designs/campaign-loop.md), units heal naturally over World Map Turns.
* In [`campaign-loop.md`](docs/designs/campaign-loop.md), the Shop generates 2g / 5g / 10g per World Map Turn.
* **Gaps:**
  1. No specific formula or numerical rate is defined for resting HP recovery per World Map Turn (in town vs. in field).
  2. If the player can manually pass turns at the Encampment without resource consumption (food/upkeep) or escalating threat, they can infinitely farm passive gold and full HP recovery without leaving town.

---

### 3.5. Wound Penalties on Fractional AP
In [`combat-system.md`](docs/designs/combat-system.md):
* 50% HP or less: $-10\%$ AP
* 20% HP or less: $-25\%$ AP

* **The Problem:** Base AP is an integer (6 AP). 
  * $6 \times 0.9 = 5.4\text{ AP} \rightarrow 5\text{ AP}$ (rounded down).
  * $6 \times 0.75 = 4.5\text{ AP} \rightarrow 4\text{ AP}$ (rounded down).
* With 4 AP, a unit can move 1 tile + attack (4 AP), but cannot move 2 tiles + attack (costs 5 AP), nor attack twice (costs 6 AP).
* **Recommendation:** Explicitly document the rounding mode (e.g. `floor()`) in [`movement-and-action-points.md`](docs/designs/movement-and-action-points.md) and [`combat-system.md`](docs/designs/combat-system.md).

---

## 4. Gameplay, Appeal & Engagement Analysis

```text
+-----------------------------------------------------------------------------+
|                            Strategic Agency Loop                            |
|                                                                             |
|   [ Encampment ]  ──( Scout / Watchtower )──>  [ Live Intel Gathering ]     |
|         │                                                  │                |
|    (Equip/Craft)                                    (Informed Prep)         |
|         ▼                                                  ▼                |
|   [ Deploy Party ] ──( World Map Travel )───>  [ Encounter: Enter/Withdraw]|
|                                                            │                |
|                                                     (Tactical Combat)       |
|                                                            ▼                |
|   [ Encampment Bank ] <───( Victory / Loot )──────  [ Tactical Victory ]    |
+-----------------------------------------------------------------------------+
```

### 4.1. Strategic Agency & Depth
* **The Information Advantage:** Knowing whether an encounter contains high-armor Orcs vs. swarm Kobolds allows meaningful pre-battle equipment choices (e.g., bludgeoning/penetration gear, Thorn runes, or bows).
* **Guild Hall Quests:** Adding optional quests with 50% bonus gold/loot gives players an engaging risk/reward decision: rush to complete a timed bounty for extra resources, or methodically develop the party.

### 4.2. Friction & Pain Points
1. **Passive Waiting vs. Active Scouting:** Currently, accumulating intelligence requires waiting turn-by-turn for passive probability checks. Introducing active scout actions (e.g., sending an encamped scout on a dedicated recon mission, purchasing rumors at the Shop) will increase player agency.
2. **Punitive Retreats vs. Tactical Recovery:** The high death rates on Withdraw make players feel punished for respecting the scouting information they just unlocked. If intelligence reveals a deadly Hobgoblin boss and the player wisely decides to withdraw, rolling a 5% permadeath feels unfair.

---

## 5. Summary of Recommended Edits

```diff
docs/designs/
├── monster-manual.md
│   └── Replace legacy 'mobility' and 'accuracy' with 'action_points', 'melee', and 'missile'.
├── class-system.md
│   └── Standardize class name 'Priest' -> 'Cleric' throughout tables and formulas.
├── world-map-and-encounters.md
│   └── Remove 5% permadeath from pre-battle 'Withdraw' (replace with 0% death / low HP fatigue).
├── intelligence.md
│   ├── Add guaranteed discovery rule or minimum floor for authored campaign objectives.
│   └── Rebalance distance penalty formula for higher intelligence tiers.
├── campaign-loop.md & vision.md
│   ├── Clarify natural healing HP rate per World Map Turn.
│   └── Define turn-advancement controls and pacing boundaries against passive gold exploitation.
└── combat-system.md
    └── Clarify integer floor rounding for wounded AP reductions.
```
