# Vision Gap Analysis & Remaining Implementation Roadmap

## Scope and sources of truth

This document records the remaining work needed to reach the broad game vision
in [`designs/vision.md`](designs/vision.md).

For a feature's exact rules, formulas, and delivery order, use the supporting design
documents:
- [`designs/class-system.md`](designs/class-system.md)
- [`designs/combat-system.md`](designs/combat-system.md)
- [`designs/equipment-handbook.md`](designs/equipment-handbook.md)
- [`designs/monster-manual.md`](designs/monster-manual.md)
- [`designs/movement-and-action-points.md`](designs/movement-and-action-points.md)
- [`designs/weapon-armor-inventory.md`](designs/weapon-armor-inventory.md)
- [`designs/UI-Layout-Design-Guidelines.md`](designs/UI-Layout-Design-Guidelines.md)
- [`design-resolutions.md`](design-resolutions.md)

Where a supporting design marks an idea as **Future** or requires a separate
approved rule, this document calls it a decision gate rather than an
implementation requirement. Approved design decisions for cross-document ambiguities
are cataloged in [`design-resolutions.md`](design-resolutions.md) and form the baseline for
this roadmap.

---

## Executive summary: shipped state and remaining gaps

| Subsystem | Shipped in `main` | Remaining to meet the vision | Status |
|---|---|---|---|
| **Tactical combat** | 6x6 grid, generic 6 AP rounds, 1-AP tile movement, 3-AP basic attacks, 2-AP potion consumption/tactical item/transfer, melee & missile range and line-of-sight checks, potions, item transfer, and deterministic enemy AI. | Battlefield fog of war (unexplored, visible, stale), perception, cover (+25%/+50% Guard), flanking (-20%/-50% Guard, +50% rear damage), dodge, parry, attacks of opportunity (-10% hit penalty), wound debuffs (50% HP -> -10%; 20% HP -> -25%), spell resolution pipeline & magic resistance rolls, richer abilities, in-battle AI delegation toggle, and pre-battle auto-resolve contract. | Major gap |
| **Classes & RPG Attributes** | Warrior and Scout roots playable. Primary attribute creation ranges (1–10: Warrior Str 6–8/Int 1–4; Scout Str 4–6/Int 3–5; Mage Str 1–3/Int 6–8; Priest Str 4–5/Int 4–6), base hit % scaling (`agility * 10 * class_multiplier %`), and class multipliers. | Cleric and Mage roots; automatic class-owned skill progression (random roll within low/med/hi tier ranges: low=1–2, med=3–4, hi=4–5 per level) replacing manual Attack point spending; Level Up Screen displaying skill gains and perk choice button; 7 class specializations (Knight, Archer, Spellcaster, Battle Mage, Healer, Paladin, Ranger). | Major gap |
| **Skills and perks** | XP accumulation, level-up health, manual Attack point spending (shipped compatibility), and level-3 Bonus Move perk (+1 AP). | Replace manual Attack spending with automatic class-owned skills (random roll in tier range); Level Up Screen with perk choice button; data-backed perk trees (Robust, Tank, Glass Cannon, etc.); high agility AP scaling (+1 AP per point above 6). | Major gap |
| **Equipment, loot, and crafting** | Uniform item representation, item instance schema (`enhancements: {smithing, enchantment, runes}`), Stores, buying/selling, passive shop income, Blacksmith (Sharpened +1 damage), Alchemy Workshop (potions, Accuracy Tonic, Guard Tonic, Basic Accuracy), Runic Workshop (Thorn Rune socketing, Blood Rune), mana crystals, multi-item unit inventory (`weapon_inventory`, `armor_inventory`) with active pointers & unequip/activate API, and returning replaced runes to Stores. | Item scrapping mechanic for base materials, advanced runes, and additional gear content supporting class or campaign slices. | Foundation shipped |
| **Healing** | Healing potions are crafted (Alchemy Workshop) and usable in battle (2 AP). | Natural/rest healing over time (faster stationary, faster in Encampment), Temple building recovery, and Cleric healing/protection abilities. | Major gap |
| **Party management** | Single active party (`party_001`, 4 members starter onboarding), Guild Hall roster size expansion, vacancy-timed recruitment refill, and multi-item unit equipment inventory carrying multiple weapons/armors per slot. | Multiple active parties on world map, party formations (pre-battle formation setup for dungeon transitions), simultaneous deployment, building-gated specialist recruitment (Temple -> Clerics/Paladins, Fighter's Guild -> Warriors, Mage Tower -> Mages, etc.). | Major gap |
| **Town and economy** | Encampment UI shell, Shop level & passive income, item commerce, and timed workshop jobs (Blacksmith, Alchemy, Runic). | Card-oriented town decisions (Rome: Total War style building choices), specialist-attracting buildings (Temple, Mage Tower, Fighter's Guild, Scout post), recruit training, trade routes, trade route safety/patrols, caravans, and an economy that outgrows adventuring income. | Major gap |
| **World map** | 5x5 board, turn-based route movement (1 step/turn), active encounter instances, vacancy refill timers, and power-weighted encounter selection. World map turn time freezes during tactical battle rounds. | World map fog of war, settlement vision radius & watchtower upgrades, party/unit vision (Scout utility), vague distant intelligence, and roaming monster threats/caravans. | Major gap |
| **Dungeon, story, and endgame** | World Map encounter tiles transition directly to tactical battle arenas; first-campaign guidance loop. | Local turn-based dungeon exploration (free party movement in formation until line-of-sight/trigger distance), narrative event/clue progression (magical dungeon generation source), final encounter, and post-game sandbox continuation. | Major gap |

---

## Current implementation notes that constrain the roadmap

- **Decided (2026-08-13):** start with a roster of 4 warriors plus 4
  recruitable units (3 warriors, 1 scout); maximum party size 4 and maximum
  party count 1, both enforced and displayed. The Guild Hall level 2
  party-size unlock (4 → 5) is shipped; the level 3 party-count unlock
  (1 → 2) is deferred to roadmap part 4 (§2.1) with multi-party play.
- Encounters are live instances, not permanently static map nodes. Clearing an
  instance opens a vacancy clock; a later refill can choose a template and a
  different position. The current system is a useful population foundation,
  but it is not roaming enemy-party simulation.
- Goblin Archer data exists in design documentation, but it is not part of the active
  `STAR_ENEMY_COMPOSITIONS` table. Do not describe it as a fully fielded
  campaign enemy until an encounter uses it.
- The live combat model still calls its stored accuracy value `attack` and its
  mitigation value `defense`. A schema migration to the shared tactical names
  is not required merely to add a new feature.
- Multi-item inventories (`weapon_inventory`, `armor_inventory`) operate alongside active item pointers (`weapon`, `armor`) in `GameSession`, allowing units to carry extra gear without in-battle switching.

---

## 1. Tactical combat

### 1.1 Fog of war and perception

The vision requires a player's view to be limited by units' 360-degree line of
sight, with perception affecting both range and detection. The current
`has_line_of_sight` implementation in [`grid.gd`](../scripts/battle/grid.gd)
only establishes attack legality; it does not control rendering, information
memory, or AI knowledge.

Remaining work:

1. Define a minimal, data-owned perception and detection contract, including
   whether Scout reconnaissance affects only the World Map, battlefield sight,
   or both.
2. Add battlefield tile knowledge states: unexplored, currently visible, and
   stale.
3. Render those states and hide enemy positions that are no longer visible.
4. Ensure AI target selection and player action validation use the same
   information rules.

### 1.2 Classes, primary attributes, and combat formulas

Warrior and Scout are already the first two playable roots. Character creation rolls primary attributes on a 1–10 scale based on class-specific ranges:
* **Warrior:** Strength 6–8, Intelligence 1–4
* **Scout:** Strength 4–6, Intelligence 3–5
* **Mage:** Strength 1–3, Intelligence 6–8
* **Priest:** Strength 4–5, Intelligence 4–6

Initial combat skills scale directly from primary attributes and class multipliers:
* **Base hit chance (`melee` and `missile`):** `(agility * 10 * class_multiplier)%`
  * Class multipliers: Warrior: 1.5, Paladin: 1.25, Scout: 1.0, Priest: 0.8, Mage: 0.5.
* **Max Health:** `vitality * level * perk_modifiers` (e.g., `Robust` and `Tank` perks grant percentage HP bonuses; `Glass Cannon` grants spell damage at the expense of a percentage HP penalty).

The standardized combat profile across adventurers and monsters uses 9 attributes: `max_health`, `might`, `melee`, `missile`, `guard`, `spellcasting`, `magic_resistance`, `resistance`, and `action_points`.

Combat formulas:
* **Physical hit chance:** `final hit chance = clamp(attacker melee_or_missile - defender guard, 5%, 95%)`
* **Guard Stacking:** Armor Guard adds directly as a percentage to unit Base Guard (`base_guard + armor_guard_bonus`, capped at 95%).
* **Damage Resistance:** `final damage = max(1, round(raw damage * (1 - defender damage resistance / 100)))` (capped at 95%).
* **Spell Resolution:** Guard applies exclusively to physical attacks. Spells land automatically initially (future high-level spells will check `spellcasting` vs unit level), but the defender rolls `magic_resistance` (`(magic_resistance - spellcasting) / 100`) to negate or reduce effects (e.g., Fire Bolt damage halved). Future immunities (e.g., Fire Immunity) cannot be overcome by spellcasting level.
* **Action Points (AP):** Fixed base budget of 6 AP for all units per Round. Action costs: Movement = 1 AP/tile, Basic Attack = 3 AP, Consume Potion = 2 AP, Use Tactical Item = 2 AP, Transfer Item to Adjacent Unit = 2 AP. High Agility grants AP bonuses (+1 AP per point above 6), as do Haste spells and speed items. AP debuffs apply for wounds, slow, or entanglement.

The remaining class work is not a generic stat expansion:
1. Give Scout a useful reconnaissance loop before adding Ranger specialization perks.
2. Add tested action/ability primitives with explicit AP costs, range, target shape, resolution order, failure behavior, UI feedback, and AI treatment.
3. Add Cleric healing/protection and its recruitment/building gate.
4. Add Mage MP, spells, area/control effects, and their counterplay.
5. Add specializations (Knight, Archer, Spellcaster, Battle Mage, Healer, Paladin, Ranger) only after their root's combat loop is proven.

### 1.3 Skills, perks, terrain, and tactical combat subsystems

The approved advancement direction is automatic, class-owned skill progression: each level advances only the skills the adventurer's class uses (random roll within tier ranges: `low` = 1–2, `med` = 3–4, `hi` = 4–5). On level up, a dedicated **Level Up Screen** displays the increased skills and presents a perk choice button if earned (or defer selection to Unit Details). The current manual Attack point allocation is shipped compatibility that this replacement will retire.

Perks remain player choices every three levels. They stay distinct from automatic skills: a perk changes or adds a capability, while the class-owned skill track provides predictable level-based growth.

Approved rules for tactical combat subsystems (from [`design-resolutions.md`](design-resolutions.md)):
1. **Dodge:** Small chance to evade an attack; on success, the attacker becomes off-balanced (-10% Guard next round).
2. **Parry:** Small chance to evade a melee attack; on success, the attacker is off-balanced (-10% Guard), and defender gains a counter-bonus (+10% `melee` to-hit against that attacker on next turn).
3. **Cover:** Provides direct `guard` bonus against missile attacks: Low Cover = +25% Guard; High Cover = +50% Guard.
4. **Flanking:** Attack angle modifiers: Side/Oblique Flank = -20% defender Guard; Rear Flank = -50% defender Guard and +50% raw damage multiplier for attacker.
5. **Attacks of Opportunity (AoO):** If a unit moves out of a tile adjacent to an enemy, that enemy gets a free melee attack at a -10% `melee` hit penalty.
6. **Wounds:** HP <= 50% Max HP -> -10% to all combat stats, available AP, and world map movement speed; HP < 20% Max HP -> -25% to all combat stats, available AP, and world map speed.

### 1.4 Automation

[`battle_bot.gd`](../scripts/tools/battle_bot.gd) and scenario tools prove that the synchronous combat controller can be driven without player clicks.

Remaining work:
1. Add a player-facing in-battle auto-combat toggle (AI delegation) that uses standard public combat actions and can be stopped safely.
2. Design a pre-battle auto-resolve result contract before implementing a button. It must define outcome, casualties/injuries, rewards, XP, and deterministic test inputs rather than bypassing campaign rules.

### 1.5 Dungeon crawling and monster roster

Encounters currently transition directly from the World Map to tactical battle.
The vision requires a local, turn-based exploration map: party movement out of combat is free (units move in unison maintaining formation as a single sprite, Baldur's Gate style) until combat is triggered (line of sight or trigger distance), at which point tactical turn-based combat begins.

Monsters adopt the shared tactical unit attributes (might, melee, missile, guard, spellcasting, magic_resistance, resistance, mobility), with non-applicable attributes set to 0. Shipped initial roster: Kobold, Goblin, Orc, Hobgoblin. Future skirmisher/archer equipped variants (slings/bows) and monster families (Bandits, Skeletons, Wolves, Giant Spiders, Ogres, Wraiths) enter only alongside encounter templates, AI behavior, rewards, and balance coverage.

---

## 2. Campaign, party, and town

### 2.1 Party scale and formation

`GameSession` currently permits one active party (`party_001`), rendered on the World Map. Remaining work:

1. ~~Resolve initial-party onboarding (1 Warrior vs 4-hero vision starting party) as a product decision while preserving a clean first-playable onboarding path.~~ Decided and implemented 2026-08-13 (foundations-and-recovery step 1): 4-warrior starting roster plus 4 recruitment offers, party size 4 / party count 1 caps enforced and displayed.
2. Add party-slot and party-size unlocking rules. (Partially shipped: the party-size cap and its Guild Hall level 2 unlock (4 → 5) are enforced and regression-tested; the party-count cap is explicit (`get_max_party_count()` = 1), with its Guild Hall level 3 unlock (1 → 2) deferred to roadmap part 4.)
3. Define selected-party and multi-party World Map ownership, movement, and encounter collision behavior.
4. Add party formation data and UI for pre-battle deployment and local-dungeon group movement.

### 2.2 Town growth, recruitment, and trade

The economy includes shop transactions, passive income, loot banking, uniform item representations (`enhancements: {smithing, enchantment, runes}`), multi-item equipment inventory, and workshop jobs (Blacksmith, Alchemy, Runic). Remaining town work:

1. Add card-oriented building choices (Rome: Total War style) and specialist buildings (Temple, Mage Tower, Fighter's Guild, Scout Post).
2. Gate specialist recruitment, spells, and recruit training behind those buildings.
3. Add item scrapping mechanic in workshops to break down unneeded gear into base materials.
4. Define trade-route records, safety, guarding, patrols, and turn-based caravan outcomes in `GameSession`.
5. Balance passive income against adventuring rewards with deterministic campaign scenarios so settlement income eventually outgrows adventuring income.

### 2.3 Healing and recovery

Healing potions cost 2 AP and restore health in combat. Out-of-combat recovery timing across World Map turns and Encampment returns must be implemented in order:

1. Baseline natural/rest recovery over time (faster when stationary).
2. Stronger Encampment recovery rules.
3. Potion, Temple, and Cleric modifiers after their relevant systems exist.

---

## 3. World map, story, and endgame

### 3.1 World-map information and threats

Time on the World Map advances in **Turns** (governing repopulation, recruit availability, crafting, etc.), while combat advances in **Rounds**. World map turn time freezes during tactical combat.

Remaining work:
1. World map fog of war: fixed settlement vision radius, watchtower upgrades, party/unit vision (Scout utility), and vague distant intelligence beyond known tiles.
2. Roaming monster parties and bandit threats with explicit movement, encounter, and loss-resolution rules in `end_world_turn()`.

### 3.2 Narrative arc and sandbox

The campaign needs story progression:
1. Land grant grant background quelling borderland incursions.
2. Narrative events and clues revealing that dungeons are being generated by an unknown magical source.
3. Source investigation leading to a final climactic battle.
4. Post-story sandbox state with wandering monsters and naturally occurring dungeons.

---

## 4. Dependency-ordered roadmap

Every slice follows the repository workflow in [`AGENTS.md`](../AGENTS.md): a
plain branch off `main`, red/green TDD, `make check`, relevant manual
`make play` signoff, commit, and local merge.

1. **Core RPG Attributes & Automatic Skill Progression.** Implement creation attribute rolling (1–10), initial hit % scaling (`agility * 10 * class_multiplier %`), `max_health` calculation (`vitality * level * modifiers`), and automatic class-owned skill gains (random rolls in low/med/hi tier ranges) on level up. Add Level Up Screen with perk choice button and perk selection.
2. **Combat Systems & Tactical Mechanics.** Enforce 2-AP item/potion/transfer costs. Implement tactical combat subsystems: dodge, parry, cover (+25%/+50% Guard), flanking (-20%/-50% Guard, +50% rear damage), attacks of opportunity (-10% hit penalty), wound debuffs (50% / 20% HP thresholds), and basic spell/magic resistance pipeline (`(magic_resistance - spellcasting) / 100`).
3. **Complementary Class Roots & Abilities.** Add tested action/ability primitive framework. Give Scout useful reconnaissance loops, then add Cleric (healing/protection) and Mage (MP, spells, control) roots with their respective building gates and equipment.
4. **Tactical Fog, Perception & Exploration.** Implement battlefield fog of war (unexplored, visible, stale tiles) and 360° line-of-sight perception. Add local turn-based dungeon exploration with free formation movement out of combat and line-of-sight combat initiation.
5. **Strategic Expansion & Town Buildings.** Implement card-oriented town building decisions, specialist recruitment gates (Temple, Mage Tower, Fighter's Guild, Scout Post), item scrapping mechanic, multiple active parties, party formations, trade routes, trade route safety/patrols, caravans, and world map fog/watchtowers.
6. **Narrative Arc, Specializations & Endgame.** Deliver root specializations (Knight, Archer, Spellcaster, Battle Mage, Healer, Paladin, Ranger), story events/clues, final climactic encounter, and sandbox continuation.

This order keeps the generic AP, uniform item representation, and workshop job foundations stable while introducing dependent systems cleanly one at a time.
