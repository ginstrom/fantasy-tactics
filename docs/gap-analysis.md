# Vision Gap Analysis & Remaining Implementation Roadmap

## Scope and sources of truth

This document records the remaining work needed to reach the broad game vision
in [`designs/vision.md`](designs/vision.md).

For a feature's exact rules and delivery order, use the supporting design
documents: [`designs/class-system.md`](designs/class-system.md),
[`designs/equipment-handbook.md`](designs/equipment-handbook.md),
[`designs/monster-manual.md`](designs/monster-manual.md),
[`designs/movement-and-action-points.md`](designs/movement-and-action-points.md),
[`designs/weapon-armor-inventory.md`](designs/weapon-armor-inventory.md), and
[`designs/UI-Layout-Design-Guidelines.md`](designs/UI-Layout-Design-Guidelines.md).
Where a supporting design marks an idea as **Future** or requires a separate
approved rule, this document calls it a decision gate rather than an
implementation requirement.

---

## Executive summary: shipped state and remaining gaps

| Subsystem | Shipped in `main` | Remaining to meet the vision | Status |
|---|---|---|---|
| **Tactical combat** | 6x6 grid, generic 6 AP rounds, 1-AP movement, 3-AP attacks, melee/ranged range and line-of-sight checks, potions, item transfer, and deterministic enemy AI. | Battlefield fog of war, perception, stale information, richer abilities, player-side AI delegation, and pre-battle auto-resolve. | Major gap |
| **Classes** | Warrior and Scout are playable. Scouts recruit, equip bows/daggers, and make ranged attacks. | Cleric and Mage roots; useful Scout reconnaissance; then specializations and data-backed perk trees. | Major gap |
| **Skills and perks** | XP, level-up health, manual skill points spent on Attack, and the level-3 Bonus Move perk. | Replace manual point allocation with automatic class-owned skills; add further perk choices and only the derived mechanics whose owning systems have been approved. | Major gap |
| **Equipment, loot, and crafting** | Equipment, loot, Stores, buying/selling, passive shop income, blacksmith, alchemy, runic work, mana crystals, and unique improved-item ownership are implemented. | More content and balance only where it supports a class or campaign slice; do not duplicate the existing ownership/crafting foundations. | Foundation shipped |
| **Healing** | Healing potions are crafted and usable in battle. | Natural/rest healing, stronger encampment recovery, and Temple/Cleric healing/buffs described by the vision. | Major gap |
| **Party management** | One party only; Guild Hall expands its size from four to five. Warrior and Scout recruitment offers refill over time. | Multiple parties, formations, simultaneous deployment, building-gated specialists, and resolution of the vision's initial four-member-party expectation. | Major gap |
| **Town and economy** | Encampment building screens, shop income, item commerce, and timed crafting jobs exist. | Card-oriented town decisions, specialist-attracting buildings, training, trade-route safety, caravans, and an economy that outgrows adventuring income. | Major gap |
| **World map** | Visible 7x7 map, selected party route movement, active encounter instances, vacancy-timed refill, and power-weighted encounter selection. | Map fog, settlement/party vision, watchtowers, vague distant intelligence, and wandering threats. | Major gap |
| **Dungeon, story, and endgame** | World Map encounters enter fixed tactical arenas; first-campaign guidance covers the existing loop. | Local dungeon exploration, formations, narrative/clue progression, final encounter, and sandbox continuation. | Major gap |

## Current implementation notes that constrain the roadmap

- A fresh campaign begins with one Warrior and no party; the player creates the
  first party. This differs from the vision's stated starting party of four.
  Treat the difference as an explicit product decision before changing
  onboarding or balance.
- Encounters are live instances, not permanently static map nodes. Clearing an
  instance opens a vacancy clock; a later refill can choose a template and a
  different position. The current system is a useful population foundation,
  but it is not roaming enemy-party simulation.
- Goblin Archer data exists, but it is not part of the active
  `STAR_ENEMY_COMPOSITIONS` table. Do not describe it as a fully fielded
  campaign enemy until an encounter uses it.
- The live combat model still calls its stored accuracy value `attack` and its
  mitigation value `defense`. A schema migration to the shared tactical names
  is not required merely to add a new feature.

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

### 1.2 Classes, abilities, and resources

Warrior and Scout are already the first two playable roots. The remaining
class work is not a generic stat expansion:

1. Give Scout a useful reconnaissance loop before adding Ranger specialization
   perks.
2. Add a tested action/ability primitive with explicit AP cost, range, target
   shape, resolution order, failure behavior, UI feedback, and AI treatment.
3. Add Cleric healing/protection and its recruitment/building gate.
4. Add Mage MP, spells, area/control effects, and their counterplay.
5. Add specializations only after their root's combat loop is proven in an
   encounter and balance scenario.

The long-term class design currently names seven specializations—Knight,
Archer, Spellcaster, Battle Mage, Healer, Paladin, and Ranger—not eight.

### 1.3 Skills, attributes, perks, terrain, and reactions

The approved advancement direction is automatic, class-owned skill progression:
each level advances only the skills the adventurer's class uses. For example,
only Scouts develop Scouting; the player does not distribute a generic skill
point pool. Melee, missile, dodge, spellcasting, and scouting are candidate
domains, but each class slice must define the applicable skills, their starting
values, gains, effects, UI, save migration, and balance scenarios. The current
manual Attack point allocation is shipped compatibility that this replacement
will retire.

Perks remain player choices every three levels. They must stay distinct from
automatic skills: a perk changes or adds a capability, while the class-owned
skill track provides predictable level-based growth.

The vision's Fallout-inspired attributes and its statement that AP derives from
Agility are not yet a settled runtime contract. The class design intentionally
keeps Strength, Agility, Vitality, Intelligence, Piety, and Luck as future
vocabulary while dodge, critical hits, carrying capacity, MP, and luck rolls
lack owning systems.

Before implementing these concepts, approve a rule that specifies persisted
data, derived values, migration behavior, UI, and balance tests. In
particular, do not add an arbitrary dodge or critical-hit formula in this
roadmap.

Likewise, terrain costs, cover, reactions, and opportunity attacks require
their own approved rule and tests. The shipped AP baseline remains flat
1-AP-per-tile movement; it must remain legible as extensions are added.

### 1.4 Automation

[`battle_bot.gd`](../scripts/tools/battle_bot.gd) and the scenario tools prove
that the synchronous combat controller can be driven without player clicks,
but they are not runtime player controls.

Remaining work:

1. Add a player-facing in-battle auto-combat toggle that uses the same public
   combat actions as the player and can be stopped safely.
2. Design a pre-battle auto-resolve result contract before implementing a
   button. It must define outcome, casualties/injuries, rewards, XP, and
   deterministic test inputs rather than silently bypassing campaign rules.

### 1.5 Dungeon crawling and advanced monster behavior

Encounters currently transition directly from the World Map to tactical battle.
The vision still requires a local, turn-based exploration map, group selection,
formation-preserving movement, and a clean transition into and out of combat.

Future monster families and behavior—pack tactics, webs, resistances,
incorporeal movement, and area attacks—should arrive only with the combat
primitive they need, an encounter that exposes their role, rewards, and
automated balance evidence. The current live campaign enemies are Goblin, Orc,
Kobold, and Hobgoblin; generic AI and the Thorn Rune's paralyze interaction do
not satisfy the full monster-manual vision.

---

## 2. Campaign, party, and town

### 2.1 Party scale and formation

`GameSession` deliberately permits only one party, and the World Map renders
only the selected deployed party. Remaining work is to make multiple parties a
coherent campaign system rather than merely allowing extra records:

1. Resolve the initial-party-size decision and preserve a clear first-playable
   onboarding path.
2. Add party-slot and party-size unlocking rules.
3. Define selected-party and multi-party World Map ownership, movement, and
   encounter collision behavior.
4. Add party formation data and UI before local-dungeon group movement relies
   on it.

### 2.2 Town growth, recruitment, and trade

The current economy is no longer a placeholder: shop transactions and passive
income, loot banking, equipment ownership, and workshop jobs are live.
Remaining town work is the strategic layer around those foundations:

1. Add card-oriented building choices and specialist buildings such as a
   Temple, Mage Tower, and Archery/Scout facility.
2. Gate specialist recruitment, spells, and training behind those buildings.
3. Define trade-route records, safety, guarding, and turn-based caravan
   outcomes in `GameSession`; screens should render and request those state
   transitions rather than own them.
4. Balance passive income against adventuring rewards with deterministic
   campaign scenarios.

### 2.3 Healing and recovery

Healing is a separate vision requirement, not a consequence of adding Clerics.
The remaining design must specify recovery timing and durability state across
battles, World Map turns, and returns to Encampment. Implement, in order:

1. Baseline natural/rest recovery.
2. The stronger Encampment recovery rule.
3. Potion, Temple, and Cleric modifiers after their relevant systems exist.

---

## 3. World map, story, and endgame

### 3.1 World-map information and threats

The World Map is fully visible. Remaining work is a fog-and-intelligence system
with settlement vision, watchtower upgrades, party/unit vision, and intentionally
vague information beyond known tiles. Roaming monsters or enemy parties must
have explicit movement, encounter, and loss-resolution rules before they are
added to `end_world_turn()`.

### 3.2 Narrative arc and sandbox

The three expedition templates and campaign guide provide a mechanical opening,
not the Vision's story arc. The campaign still needs narrative events and clues
that lead from borderland incursions to the source of dungeon generation, a
final encounter, and a post-story sandbox state with wandering monsters and
naturally occurring dungeons.

---

## 4. Dependency-ordered roadmap

Every slice follows the repository workflow in [`AGENTS.md`](../AGENTS.md): a
plain branch from `main`, red/green TDD, `make check`, a relevant manual
`make play` signoff, a commit, and only then a local merge after user approval.

1. **Resolve foundations and recovery.** Decide the initial party/onboarding
   target, define automatic class-owned skill tracks and their migration from
   manual Attack points, and add the baseline healing lifecycle. Keep perks at
   the existing every-third-level cadence; do not silently convert deferred
   attributes into mechanics.
2. **Complete complementary class roots.** Build the ability primitive, make
   Scout reconnaissance useful, then add Cleric and Mage in independently
   balanced slices. Add their building gates and only the necessary equipment
   content.
3. **Improve tactical information and control.** Add battlefield fog and
   perception, then runtime auto-combat. Treat auto-resolve as a separately
   specified campaign outcome contract.
4. **Expand strategic play.** Add multiple-party/formation foundations,
   town-building choices, recruitment gates, map fog, and trade-route systems.
   Roaming threats follow only after World Map state and loss rules are clear.
5. **Deliver dungeon and narrative endgame.** Use the established formation,
   fog, class, and campaign systems for local dungeon exploration, story
   events, the final battle, and sandbox continuation.

This order deliberately keeps the generic AP and item-ownership foundations
stable while dependent rules are introduced one at a time.
