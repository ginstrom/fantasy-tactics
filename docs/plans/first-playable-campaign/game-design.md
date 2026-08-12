# First Playable Campaign Game Design

## Purpose

Define the first complete, repeatable campaign loop for the game. This is a
product-design roadmap: it describes the player experience, the order in which
systems should become playable, and the boundaries that keep the project
small enough to learn from.

The intended game is a fantasy tactics campaign: tactical, D&D-inspired local
battles sit inside an XCOM-like cycle of party development, expeditions, and
settlement growth. Basic Fantasy RPG rules are the primary rules reference;
XCOM, Xenonauts, and Fallout 1/2 inform the development and management feel.

## First playable campaign

The first campaign is successful when a player can repeat this loop and make
meaningful choices at every transition:

```text
Encampment
  -> choose and prepare a party
  -> travel on the world map
  -> resolve a tactical encounter
  -> receive rewards or setbacks
  -> return to the encampment
  -> improve the party or encampment
  -> choose the next expedition
```

The minimal version of this loop — create a party, add a unit, deploy it,
move to an encounter, fight it, and bank the reward back at the encampment —
is playable manually today; see "Completed first playable foundation" below
for the full route, including everything the minimal loop leaves out (XP,
recruitment, Trade, the Guild Hall).

The full first campaign target has one party of four, a small local area,
several encounters, gold as its first economy currency, and a small number of
visible upgrades. Its purpose is to prove that tactical victories make the
strategic game more interesting and that strategic choices make the next battle
feel different.

## Completed first playable foundation

The current prototype delivers this manually playable route:

```text
Start Menu
  -> New Game
  -> Starting Settlement
  -> Encampment
  -> Units -> Parties -> assign up to four members (five after a Guild Hall
     upgrade) -> Deploy Party
  -> depart to the World Map
  -> select the deployed party and plan a route
  -> advance one world-map tile manually or with End Turn
  -> select the party at an active site and enter battle on a second click
  -> field every deployed party member and the site's full, star-tier enemy
     count; move and attack by mouse, WASD, or number-key (1-5) selection,
     spending a shared per-unit Action Point (AP) budget
  -> defeat each enemy: resolve its kill XP immediately, split evenly across
     the deployed party (a modal Level-Up overlay appears if a member
     crosses a level threshold); each kill also queues gold, a mana crystal,
     and a chance of the enemy's weapon (see Trade, equipment, and loot below)
  -> win: clear the site for its clear XP. Display a summary screen with XP and loot
     awarded, and return to the World Map
     or 
     -> lose: return the party to the Starting Settlement; site remains
     available
  -> return to Encampment to deposit pending gold, mana crystals, and gear;
     review XP, Attack, and any unspent skill points from Unit Details
     (skill points are spent from the in-battle Level-Up overlay, not from
     Unit Details); optionally spend gold at the Guild Hall to raise the
     party-size cap; buy and assign gear; or build and use the Blacksmith,
     Alchemy Workshop, and Runic Workshop
```

Party Details offers Add Member for an encamped party. Roster and
Recruitment (below) let a new campaign grow beyond its starting single Warrior.

`GameSession` owns the Warrior-only roster and each adventurer's progression
(XP, level, Attack, unspent skill points, perks), equipped and carried items,
player-created parties and their deployment state, world position, committed
travel route, movement spent, world turn, encounter completion, active
encounter/recruitment instances and their vacancy-refill clocks, banked
gold/mana crystals/gear, unique upgraded-item ownership, and the Guild Hall,
Trading Post, and workshop levels/jobs. `GameManager` owns named scene
transitions. A party is visible and movable only while deployed. World-map
travel is deliberately simple: an in-bounds, empty-grid Manhattan route moves
one tile per World Map turn; no terrain costs, obstacles, waypoints, or
multi-party scheduling are implied yet — one party is deployed and battled at
a time.

### Adventurer progression

Every kill and every cleared site awards XP immediately, split evenly across
the deployed party: 5/10 for a Goblin kill/clear, 10/20 for an Orc kill/clear.
Cumulative level thresholds are 0, 20, 50, 90, and so on — each level costing
10 more XP than the last. A level sets maximum HP to Vitality × level, applied
immediately to both the persistent adventurer and the active battle unit — the
Warrior's Vitality is 10, so a level-1 Warrior has 10 HP and a level-2 Warrior
has 20. A level also grants ten unspent skill points, spendable on Attack from
a modal Level-Up overlay that resolves immediately, before further input or a
battle-result transition.
Attack starts at 60 and has no cap, though its derived hit chance caps at 95%.
Every third level requires a perk choice; the first available perk, Bonus
Move, grants one flexible Action Point. The same XP, Attack, health,
equipment, and perk data is legible outside battle from Unit Details.

### Vacancy-timed encounter and recruitment population

The map and the recruitment offer list no longer show every possible site or
candidate at once. A campaign starts with two active encounters, the
one-star Goblin Camp (difficulty 1) and the two-star Orc Outpost (difficulty
2), and one active recruitment offer (a Warrior); each category still holds
at most two active encounters or four active offers at a time. Clearing a
site or hiring a recruit opens a vacancy; that vacancy's own 15 +/- 5 (encounter)
or 30 +/- 5 (recruitment) World Map turn clock refills it with a new instance only
if its category is still under its cap when the clock completes. A cleared
site never reopens — a later spawn is a distinct new instance, though it may
reuse a previously seen encounter template at a different map tile. Each new
encounter or recruitment instance gets its own unique identity, so a refill is
always distinguishable from the instance it replaced even when it reuses a
template. A refill's map position is chosen in-bounds and unoccupied, so it
never visually appears to reopen the exact site that was just cleared.

A three-star Ruined Fortress template now exists alongside the Goblin Camp
and Orc Outpost, but it is never one of the campaign's two starting sites.
Which template an encounter vacancy's refill produces is chosen at random,
weighted toward higher star tiers as the player's power (adventurer count
plus Guild Hall level) grows, rather than deterministically cycling through
every known template, among the templates with no currently-active instance
(in the common single-vacancy case, only two of the three tiers are ever
candidates, so the odds split between just those two). At a fresh
campaign's starting power, assuming all three templates are simultaneously
eligible, a refill is roughly 44% one-star, 44% two-star, and 11%
three-star; by the time a player has recruited several adventurers and
maxed the Guild Hall, those odds shift toward roughly 8% / 62% / 31%. No
tier's odds ever reach zero.

The World Map marks each active encounter with a difficulty-only star badge
(one star for Goblin Camp, two for Orc Outpost, three for the Ruined
Fortress) rather than a numeric label, so the player can compare expedition
risk at a glance before committing a route.

Site entry retains selection-before-activation. The first click selects the
party, so it can still move away; a second click enters the settlement or an
active site. A cleared camp rejects entry.

### Full-party battles and the Guild Hall

Every deployed party member is fielded on the
battlefield, at a fixed start position, alongside the site's full enemy
count. Every living unit begins its active Battle Round with 6 Action Points:
each tile moved costs 1 AP and each adjacent basic attack costs 3 AP. WASD
steps and multi-tile mouse clicks share that budget, and any affordable legal
sequence—including two stationary attacks—is allowed. Bonus Move grants +1 AP.
End Turn forfeits the remainder. The player selects a unit by mouse, clicking on the portrait
in the left panel, or number key (1-5); a left portrait panel shows one 
square per fielded party member, with the unit's colour, health, a selection ring, 
and a dimmed state once defeated.

Each site's star rating drives a randomly resolved enemy composition: the
one-star Goblin Camp always fields one Goblin; the two-star Orc Outpost
fields two Goblins or one Orc; the three-star Ruined Fortress fields 4-8
Kobolds, 3-6 Goblins, 2-4 Orcs, or 1-3 Hobgoblins. Both which option and,
for the Ruined Fortress, the exact count within its range are chosen at
random each time the site is entered. The battlefield can field up to 8
enemies at once (up from 3), so the Ruined Fortress's Kobold swarm is the
first fight to use the board's full width.

A Warrior has 10 base health and Attack 60 (a 60% base hit chance before
armor); its damage and defensive stats come from its equipped gear — see
Trade, equipment, and loot below for how weapon and armor choice change a
Warrior's damage range, effective hit chance, and damage taken. Monster HP
and damage are tuned around that 10 HP baseline so a level-1 Warrior is in
a roughly even solo fight against a single Orc (tuned against
expected-rounds-to-kill math for that baseline against each monster type; see
the monster stat tables in `GameSession`):

| Monster | Health | Hit chance | Damage | Weapon |
|---|---|---|---|---|
| Kobold | 6 | 25% | 1 | Rusty Dagger |
| Goblin | 13 | 30% | 2 | Short Sword |
| Orc | 22 | 50% | 3 | War Axe |
| Hobgoblin | 30 | 60% | 4 | Two-Handed Sword |

Enemies take a visible, deterministic AI decision sequence after the
player ends the round.

The Guild Hall is the game's first gold-funded building. A fresh campaign
caps party assignment at 4 members (Guild Hall level 1); spending 50 gold at
the Guild Hall raises the cap to 5 (level 2, the max for this slice).
`party_details.gd` and `unit_details.gd` both reject an assignment past the
current cap rather than silently failing it.

### Trade, equipment, and loot

Damage is a function of a unit's equipped weapon rather than a fixed
per-class number. Every adventurer carries an `equipment` record (`weapon`,
`armor`) alongside their stats; a fresh Warrior starts with an Iron
Longsword and Leather Armor. Two damage tiers exist for each of four weapon
shapes, Steel dealing one point more than Iron at both ends of its range:

| Weapon | Iron damage | Steel damage | Iron price | Steel price |
|---|---|---|---|---|
| Dagger | 1-4 | 2-5 | 10g | 30g |
| Shortsword | 1-6 | 2-7 | 20g | 60g |
| Longsword | 1-8 | 2-9 | 30g | 90g |
| Two-handed sword | 1-10 | 2-11 | 35g | 105g |

Armor grants two protections, each an integer percentage: **defense**
subtracts directly from an attacker's hit chance (floored at a 5% minimum
chance to hit), and **resistance** reduces incoming damage by that percent,
rounded to the nearest whole point. The maximum resistance is capped at 95% 
after all buffs and debuffs are applied.

Five armor tiers run from the Leather Armor every Warrior starts with up to Full Plate:

| Armor | Defense | Resistance | Price |
|---|---|---|---|
| Leather | 10 | 10 | 10g |
| Chainmail | 15 | 20 | 30g |
| Split | 15 | 25 | 50g |
| Platemail | 15 | 30 | 200g |
| Full plate | 15 | 35 | 500g |

Every kill now queues three reward types: 
* a random gold amount
* a mana crystal (tier depends on the enemy), and 
* a 25% chance of that enemy's own Iron-tier weapon as gear. 

A Goblin kill queues 1-6 gold, a tier-1 mana crystal, and a chance at an Iron Shortsword; 
an Orc kill queues double gold (1-5, x2) and a tier-2 crystal and a chance at an Iron Longsword.

A Kobold kill (fought at the Ruined Fortress) queues 0-5 gold and a tier-1
mana crystal, plus a chance at an Iron Dagger; a Hobgoblin kill there
queues triple gold (1-4, x3) and a tier-2 crystal, plus a chance at an Iron
Two-Handed Sword — the catalogue's top loot tier, matching its status as
the toughest monster in the game. All of it queues on victory and only banks
into the Encampment's stores once the party returns home, alongside gold —
mana crystals sell for a flat 5 (tier 1) or 15 (tier 2) gold each; gear
sells for half its catalog price.

Trade is a new, permanent Encampment nav destination (alongside Units,
Buildings, and Deploy Party) with two screens:

- **Stores** lists everything banked — gear and mana crystals — as a table
  with name, type, count, and sale price. Selecting a row offers **Sell**
  (gated on owning a Trading Post) and, for gear, **Assign**, which opens a
  roster list; activating an adventurer there equips the item immediately.
  Equipping is a swap, not a one-way consumption — whatever was in that slot
  returns to the bank rather than being lost.
- **Trading Post** is the game's second gold-funded building: a one-time
  50-gold purchase (bought from the Trade screen, not from Buildings) that
  grants 1 gold of passive income per World Map turn and unlocks buying and
  selling. Its Buy table lists every weapon and armor in the catalog above,
  gated on affordability.

Normal gear remains an immutable, stackable base item in Stores. A permanent
improvement materializes one normal weapon or armor into a unique owned item
instance with a `base_item_id` and modifier records. That instance must be in
exactly one location — Stores or the matching adventurer inventory — so it
cannot be copied through assignment, save/load, or a workshop job.

The Buildings screen now also contains three timed, World Map turn-driven
workshops:

- **Blacksmith** costs 50 gold to build and upgrades from level 1 to 3 for
  50 then 100 gold. Its level gates Iron and Steel weapon crafting; one
  five-turn craft job and one independent twenty-turn sharpening job may run
  in parallel. Crafting adds a normal base weapon to Stores; sharpening
  consumes one normal weapon and returns a unique sharpened instance.
- **Alchemy Workshop** costs 50 gold to build and 50 gold to reach level 2.
  It runs one seven-turn potion job at a time, consuming gold and an eligible
  mana crystal. The level-1 Healing Potion heals 1–6, while the level-2
  Greater Healing Potion heals 2–8.
- **Runic Workshop** costs 50 gold to build and 50 gold to reach level 2.
  Its current seven-turn job sockets the 20-gold, tier-1-crystal **Thorn**
  rune into an owned armor instance. After a successful melee hit against
  Thorn armor, the attacker can be paralyzed; this is the only shipped rune.

Potions are assigned from Stores into an adventurer's shared ten-item carried
capacity. During a player Battle Round, a selected, un-paralyzed adventurer
can consume a carried potion or transfer one to an ally for 2 AP; an invalid
action leaves both AP and inventory unchanged. The Trading Post has no
upgrade tiers. Further recipes, runes, modifiers, and crafting content remain
future scope (see the asset and scope-expansion principles below).

Escape opens a pause-menu overlay from the settlement, encampment, party
manager, world map, and battlefield. The overlay can return to the unchanged
scene, open the World Map, Save, Load, or quit. Opening the World Map during
an active battle preserves that battle: its encounter can be re-entered,
while End Turn remains locked until the battle resolves.

### Save, load, and first-campaign guidance

New Game begins at the settlement. Save writes one durable snapshot to
`user://campaign-save.json` atomically — a temp file is renamed over the
target, so a crash or power loss mid-write never corrupts the existing save —
and only from Encampment or World Map with no battle in progress; the same
guard also blocks saving while a just-won battle's loot is still unsettled
(not yet banked or merged into the party), and an active encounter makes no
write attempt at all rather than failing one. Load parses and validates the
file before importing anything — an absent save, a corrupt file, and one
written by an incompatible format each get a distinct diagnostic — and a
failed or rejected load leaves the current session completely untouched.
Because loading discards whatever is currently live, the pause menu's Load
asks for confirmation before it proceeds; the Start Menu's Continue and Load,
which run before any campaign is in progress, do not. There is intentionally
one save slot, not multiple — Continue, Load, and the pause menu's Load all
read and write the same file.

A short, dismissible first-campaign guide (instanced on Encampment and World
Map, never a modal and never blocking input) leads a new player through the
opening loop: form a party, deploy it, select and commit a route, enter a
site, return home to bank the reward, and choose the first affordable
improvement (recruit, equipment, or the Guild Hall). Each message shows once,
is dismissed explicitly by the player, and that dismissal survives save/load
like the rest of durable campaign state.

For fast development checks, a debug-only F9 scenario menu can open a fresh
campaign at the settlement, encampment, party manager, a ready-to-depart
party, the world map, or a battle at either site, as well as a party stocked
with a Trading Post and pre-banked stores for exercising the Trade loop
directly. It uses the same public campaign APIs and scene routes as ordinary
play and is unavailable in release builds; see
[docs/dev/running-the-game.md](../../dev/running-the-game.md) for the full
scenario list.

## Next work

The prototype now fields a full party against a full, star-tier-randomized
enemy composition, up to 8 enemies strong. Its upgrade loop includes the
Guild Hall, Trading Post, normal stackable gear, unique sharpened/rune-ready
instances, carried crafted potions, and three timed workshops; loot (gold,
mana crystals, gear) joins XP as expedition rewards. The encounter catalogue
spans three star tiers and four monster types (Goblin, Orc, Kobold,
Hobgoblin), with a refill's tier chosen at random, weighted by the player's
growing power. The next implementation work should focus on these unfinished
outcomes, in order:

1. Assemble Milestone 5's first campaign slice — onboarding and pacing — now
   that both the encounter catalogue and the upgrade path have several
   options each, save/load lets a campaign persist across sessions, and a
   short first-campaign guide covers the opening loop (see Save, load, and
   first-campaign guidance above). What remains is compact-area assembly and
   pacing/difficulty playtesting.
2. Broaden crafting only after the current weapon, potion, and Thorn-rune
   choices have been playtested: further recipes, runes, modifier families,
   and content must preserve the immutable-base/unique-instance ownership
   contract.
3. Add durable presentation assets only when their associated gameplay choices
   have been playtested, following the asset policy below.

Developer verification remains a supporting concern rather than a player
feature. The completed scenario menu and the headless battle simulator (see
`docs/dev/running-the-game.md`) accelerate checks, but neither replaces
exercising the complete settlement-to-expedition route by hand.

## Design principles

- **A connected loop before system depth.** A thin but complete expedition,
  battle, reward, and upgrade cycle is more valuable than a sophisticated
  isolated combat or town-management prototype.
- **Tactics must reward positioning.** Battle choices should be legible:
  movement, target choice, terrain or formation, and turn order should matter.
- **The settlement is a decision interface, not a city painter.** Town growth
  is presented through readable cards, services, and upgrades rather than
  freeform placement or construction simulation.
- **Parties are strategic assets.** Even though the first loop has one party,
  its state must be owned by that party so scouts, hunters, and dungeon
  expeditions can be added later without redefining campaign state.
- **Presentation supports play.** Sprite, sound, and interface work begins
  early enough to test clarity and feel, but expensive content follows proven
  mechanics.

## Milestone 1: Campaign foundation

**Status: completed.** The implemented foundation includes party formation and
deployment, selection-first settlement and camp entry, committed single-party
world-map routes, manual/automatic one-tile turn movement, persistent cleared
sites, separate World Map turns and Battle Rounds, and safe pause/quit access.

### Player outcome

The player can move a party through a small world map, understand whose turn
it is, enter an available encounter, and return to a world where completed
sites have changed.

### Design scope

- World-map turns are distinct from local-battle rounds.
- A party can select, enter, and leave an encounter tile according to its
  encounter rules.
- A completed encounter cannot be entered again unless a future encounter type
  explicitly supports repetition.
- Campaign state is party-owned: each party has a world position and can later
  have a named location. The currently selected party is explicit. Scene-only
  selections, such as the active encounter, are not treated as global party
  location.
- The game begins at the settlement with one available adventurer and no
  formed or deployed party. The model leaves room for more parties later.

### Completion criteria

- The first settlement, party formation, deployment, world-map movement, and
  settlement-return route is playable.
- The player can understand the current map state and pause or quit safely
  from each gameplay scene.
- The campaign state clearly separates world turns, battle rounds, parties,
  and encounters.

### Presentation milestone

Establish the visual language before content expands: camera scale, grid/tile
size, palette, type treatment, selection states, and icon rules. Replace
abstract markers with a minimal reusable kit of terrain tiles, party/enemy
silhouettes, and movement/selection feedback. Record each asset's source and
licence, including temporary assets.

## Milestone 2: Tactical encounter loop

**Status: completed, now exercised by all three sites (Goblin Camp, Orc
Outpost, Ruined Fortress).** The implemented
battle has the full-party setup described in Full-party battles and the
Guild Hall above, real win/loss detection, visible enemy pacing, and
campaign outcomes: victory clears the site and returns to the map; defeat
returns the party home without clearing the site.

### Player outcome

The player can win or lose a short tactical battle through movement, turns,
and basic attacks. The outcome is understandable and changes the campaign.

### Design scope

- Add a small, complete combat vocabulary: health, basic attacks, damage,
  defeat, victory, and battle-end results.
- Retain clear alternating rounds and enforce legal movement, occupancy, and
  turn ownership.
- Use a narrow starting roster and enemy set. The goal is a good positioning
  decision, not a broad reproduction of every Basic Fantasy RPG combat rule.
- Define what defeat means for the first campaign, such as a return to camp,
  lost time, or a limited resource cost. Avoid permanent death until the core
  loop is enjoyable.

### Completion criteria

- At least one encounter is winnable and losable through normal play.
- The player can identify an active unit, legal choices, the battle objective,
  and the resulting victory or defeat.
- Encounter completion updates the world-map state rather than relying on a
  temporary completion control.

### Presentation milestone

Introduce the first durable gameplay assets: readable unit sprites, a battle
backdrop or terrain set, and compact sound feedback for selection, movement,
attack, damage, victory, and defeat. Test these assets for tactical clarity,
not only appearance.

## Milestone 3: Expedition and reward loop

**Status: completed.** Every expedition now pays out three reward types:
gold and mana crystals (banked on return to Encampment), individual
adventurer XP (awarded immediately per kill and per clear; see Adventurer
progression above), and a chance of the killed enemy's own weapon as gear
(see Trade, equipment, and loot above). Cleared sites are persistent but
not permanent — each vacancy refills on its own variable 15 +/- 5 turn clock
under a two-site cap, so the world map keeps changing within a campaign rather
than only accumulating grey markers. The encounter catalogue now spans
three star tiers (Goblin Camp, Orc Outpost, Ruined Fortress) and four
monster types, with both the enemy composition and, for the Ruined
Fortress, the fielded count resolved at random each time a site is
entered (see Full-party battles and the Guild Hall above); any
travel-time or resource cost beyond World Map turns remains future work.

### Player outcome

An expedition has a purpose and a consequence. The player chooses a
destination, resolves its risk, receives a reward or setback, and returns to
camp with a reason to plan the next trip differently.

### Design scope

- Define a small encounter catalogue, beginning with clear roles such as
  bandits, wandering monsters, or a dungeon entrance.
- Add gold as the first reward and spending currency. Any first item reward
  should have one simple, observable effect. *(Done: gear from loot has an
  observable effect the moment it's equipped — see Trade, equipment, and
  loot above.)*
- Make world-map changes persistent within a campaign: cleared sites, newly
  available routes, or changed local threats.
- Keep travel time, supplies, injuries, and random events minimal until the
  reward loop is compelling.

### Completion criteria

- At least two expedition choices differ in risk, reward, or tactical setup.
- Completing an expedition changes the player's available resource or world
  state.
- The player can explain why they chose their next expedition.

### Presentation milestone

Extend the established asset kit with a small number of encounter variants,
world-map site states, and short ambient or outcome sounds. Reuse visual
language rather than creating bespoke art for every prototype variation.

## Milestone 4: Encampment and party management

**Status: encampment UI, party browsing/deployment, recruitment, individual
adventurer progression, and the Guild Hall, Trading Post, Blacksmith, Alchemy
Workshop, and Runic Workshop are shipped.** The prototype has an encampment UI shell
(Units, Buildings, Trade, Deploy Party) and Units -> Parties -> Party Details
-> Unit Details browsing with deliberate party deployment. An encamped party
can use Add Member to assign an existing available adventurer, or Roster can
assign one directly from Unit Details, up to the Guild Hall's current
party-size cap (see Full-party battles and the Guild Hall above). Recruitment
offers a small, vacancy-timed pool of gold-costed Warrior candidates (see
Vacancy-timed encounter and recruitment population above) rather than a fixed
catalogue. Adventurers gain XP, levels, Attack points, equipment, and perks
from expeditions (see Adventurer progression and Trade, equipment, and loot
above), legible from Unit Details. Buildings offers the Guild Hall,
Blacksmith, Alchemy Workshop, and Runic Workshop; Trade is its own top-level
destination (see Trade, equipment, and loot above) rather than a Buildings
entry.

### Player outcome

Returning home presents useful choices: improve an existing party or make one
encampment investment that changes future expeditions.

### Design scope

- Provide a clear roster and party-formation view. Roster lists each
  adventurer's name, class, level, availability, and current party (or
  Unassigned), and routes to Unit Details.
- From Unit Details opened through Roster, let an available unassigned unit be
  assigned to a chosen encamped party. On success return to Roster, whose
  Party column shows the new assignment. Keep the existing Party Details ->
  Add Member route as the complementary party-first path.
- Add Recruitment as a fixed first candidate catalogue: three individually
  identified Warrior candidates, each costing 10 gold. A successful purchase
  deducts gold once, removes that candidate, adds the adventurer to Roster,
  and returns there. Future town size and buildings may add or filter
  candidates, but are not implemented in this slice.
- Establish the encampment's strategic UI shell before adding those systems:
  Units, Buildings, Trade, and Deploy Party. The information panel always
  shows player name and banked gold; selecting a party or unit adds that
  entity's compact summary and an explicit View action.
- Make party deployment a deliberate selection: Deploy Party lists only
  encamped parties with at least one deployable member, then deploys the
  chosen party to the World Map. This intentionally excludes empty parties
  and future parties whose members are all dead or incapacitated.
- Add an intentionally small development choice, such as one recruit,
  training option, skill point, or equipment improvement. *(Done: the
  Trading Post's buy/sell/equip loop and the three workshops — see Trade,
  equipment, and loot above.)*
- Present town growth as card-like buildings and services. *(Done: the Guild
  Hall, Blacksmith, Alchemy Workshop, and Runic Workshop expose their costs,
  levels, active jobs, and expedition-facing effects.)*
- Each town choice must state and deliver an expedition-facing benefit.
  *(Done: the Trading Post changes immediately available gear; the Blacksmith
  crafts or sharpens weapons; Alchemy provides carried healing; and the Runic
  Workshop applies the Thorn counterattack.)*
- Do not build a freeform city-construction interface.

### Completion criteria

- The player can make at least one party or settlement decision with an
  observable tactical or expedition effect.
- The encampment is legible as a growing place, not only a menu.
- A player can understand how gold turns into greater capability.

### Presentation milestone

Add portrait, equipment, building-card, and NPC/service art only for choices
that have survived playtesting. Use the same UI language established in the
campaign foundation. This is the first point where a small number of
characterful, durable assets are justified.

### Deferred encampment surfaces and data

The encampment UI shell now implements Units -> Parties -> Party Details ->
Unit Details, Deploy Party, Trade -> Stores/Trading Post, and Buildings ->
Guild Hall/Blacksmith/Alchemy Workshop/Runic Workshop. The following broader
surfaces and data remain deferred rather than being simulated by placeholder
UI.

- **Buildings:** Guild Hall, Blacksmith, Alchemy Workshop, and Runic Workshop
  are real Building routes with the costs, levels, and timed jobs described
  in Trade, equipment, and loot above. The Trading Post is bought and used
  from Trade instead of Buildings. Further building cards, construction
  prerequisites, and associated art remain TBD; implement each after its
  expedition-facing benefit is proven.
- **Trade:** Stores and the Trading Post are shipped (see Trade, equipment,
  and loot above): buy/sell inventory, prices, stock, stackable base gear,
  unique item ownership, and potion assignment are all real. Trading Post
  upgrade tiers and further crafting recipes, runes, and modifier families
  remain TBD — do not add them before the current loops have been playtested.
- **Roster and Recruitment growth:** this slice intentionally has no search,
  pagination, town-size rules, building prerequisites, or class-specific
  combat behavior. Refill delay is randomized per vacancy (see Vacancy-timed
  encounter and recruitment population above); once that delay elapses,
  whether a refill actually spawns is deterministic, gated only by the
  category's cap. Later town growth can expand or filter the vacancy-timed offer pool without
  changing ownership or screen routing.
- **Party management limits:** party capacity is now the Guild Hall's cap (4,
  or 5 after the upgrade); removal, reassignment between parties, injuries,
  and availability rules beyond the current available status remain TBD.
  The existing Add Member flow is the party-first assignment path; Roster's
  Unit Details action is the unit-first path.

The durable model direction is deliberately modest. Parties keep stable IDs,
display names, member IDs, location/deployment state, and placeholder fields
for party-level progression. Adventurers keep stable IDs, display name, class,
level, availability status, equipment, and placeholder combat/progression
fields. A deployability query—not a UI-specific special case—decides whether
an encamped party is shown for deployment. This supports future dead,
incapacitated, and otherwise unavailable members while keeping the current
prototype's single Warrior immediately usable.

## Milestone 5: First campaign slice

**Status: not started, less blocked.** The reward and upgrade loop now
exists (gold, mana crystals, gear, XP, the Guild Hall, the Trading Post,
and randomized site compositions), and the encounter catalogue now spans
three star tiers and four monster types — both halves of this milestone's
"several expeditions, several upgrades" precondition (see Next work above)
are satisfied. Save/load and a first-campaign guide (see Save, load, and
first-campaign guidance above) also cover this milestone's onboarding design
scope. What remains is assembling a compact local area from the proven
systems and playtesting pacing/difficulty for the slice itself.

### Player outcome

The player can play a short campaign with several expeditions, make different
upgrades, and see their party and encampment become more capable before the
available local threats are cleared.

### Design scope

- Assemble the proven systems into a compact local area with varied encounter
  types and a modest upgrade path.
- Balance reward pacing, difficulty, and the information shown in the UI.
- Improve onboarding so the first game explains movement, rounds, world turns,
  rewards, and upgrades through play. *(Partly done: a dismissible
  first-campaign guide now covers party formation, deployment, route
  selection, battle entry, rewards, and the first improvement — see Save,
  load, and first-campaign guidance above. It does not yet separately teach
  battle-round mechanics or world-turn pacing.)*
- Define the data boundaries and content workflows needed to add more
  encounters, units, buildings, and assets after the slice is fun.

### Completion criteria

- A new player can complete a short multi-expedition campaign without
  developer-only controls.
- Different town or party choices produce noticeably different subsequent
  expeditions.
- The project has clear evidence for the next investment: deeper tactics,
  character development, or expanded strategic play.

### Presentation milestone

Polish the tested experience with cohesive terrain variants, town progression
states, music or ambience, and stronger outcome feedback. Expand content only
where it reinforces an already working player choice.

## Deferred beyond the first campaign

The following are important to the larger vision but are deliberately not
required to validate the first campaign:

- Multiple simultaneously active parties, specialised party roles, and their
  management UI
- Deep class, spell, and skill-tree systems; equipment depth beyond the
  current weapon/armor swap (crafting mana crystals into magical items,
  Trading Post upgrade tiers, unique or found-only items)
- Broad enemy, item, and encounter catalogues
- Procedural maps or generated content
- Full supplies, injuries, permadeath, trade-route/caravan, and diplomacy
  systems
- Self-sustaining settlement income and conflict with neighbouring cities
- Long-term balance, accessibility, and production-grade polish (save/load
  now ships in single-slot form — see Save, load, and first-campaign
  guidance above — but multiple save slots remain deferred)

These systems should be introduced only when the first campaign shows what
specific player decision they improve.

## Decision gates after the first campaign

Before expanding scope, use playtesting to answer:

1. Are tactical battles enjoyable enough to justify deeper character options?
2. Do reward and settlement choices make expeditions feel purposeful?
3. Would a second party create interesting simultaneous decisions, or merely
   duplicate the first party's work?
4. Is the next bottleneck encounter variety, tactical depth, or strategic
   management?

The answers choose the next phase: deepen combat and character development,
add strategic multi-party play, or expand settlement and regional systems.

## Asset policy

Use temporary but stylistically coherent assets while mechanics and interface
patterns are changing. Make, buy, or commission durable assets only after a
system has been playtested and its visual requirements are stable. Every asset
must have a known source, licence, and replacement plan where applicable.

This lets the game acquire a recognizable identity early while avoiding a
large art or audio investment in content that design iteration may discard.
