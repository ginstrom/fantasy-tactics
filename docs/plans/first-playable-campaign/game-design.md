# First Playable Campaign Game Design

## Purpose

Define the first complete, repeatable campaign loop for the game. This is a
product-design roadmap: it describes the player experience, the order in which
systems should become playable, and the boundaries that keep the project
small enough to learn from. It is not an implementation plan.

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
     spending a shared per-unit movement-points budget
  -> defeat each enemy: resolve its kill XP immediately, split evenly across
     the deployed party (a modal Level-Up overlay appears if a member
     crosses a level threshold)
  -> win: clear the site for its clear XP and return to the World Map
     or lose: return the party to the Starting Settlement; site remains
     available
  -> return to Encampment to deposit pending gold; review XP, Attack, and any
     unspent skill points from Unit Details (skill points are spent from the
     in-battle Level-Up overlay, not from Unit Details); optionally spend
     gold at the Guild Hall to raise the party-size cap
```

Party creation and Warrior assignment, previously reachable from an
Encampment "Party Manager" screen, are superseded by the Milestone 4
encampment UI shell below. Party Details now offers Add Member for an
encamped party, restoring the ordinary in-game assignment path. Roster and
Recruitment (below) let a new campaign grow beyond its starting Warrior
without debug tooling.

`GameSession` owns the Warrior-only roster and each adventurer's progression
(XP, level, Attack, unspent skill points, perks), player-created parties and
their deployment state, world position, committed travel route, movement
spent, world turn, encounter completion, active encounter/recruitment
instances and their vacancy-refill clocks, and the Guild Hall's level and
resulting party-size cap. `GameManager` owns named scene transitions. A party
is visible and movable only while deployed. World-map travel is deliberately
simple: an in-bounds, empty-grid Manhattan route moves one tile per World Map
turn; no terrain costs, obstacles, waypoints, or multi-party scheduling are
implied yet — one party is deployed and battled at a time.

### Adventurer progression

Every kill and every cleared site awards XP immediately, split evenly across
the deployed party: 5/10 for a Goblin kill/clear, 10/20 for an Orc kill/clear.
Cumulative level thresholds are 0, 20, 50, 90, and so on — each level costing
10 more XP than the last. A level grants one maximum-health point (applied
immediately to both the persistent adventurer and the active battle unit) and ten
unspent skill points, spendable on Attack from a modal Level-Up overlay that
resolves immediately, before further input or a battle-result transition.
Attack starts at 60 and has no cap, though its derived hit chance caps at 95%.
Every third level requires a perk choice; the first available perk, Bonus
Move, grants one extra tile of movement range. The same XP, Attack, health,
and perk data is legible outside battle from Unit Details.

### Vacancy-timed encounter and recruitment population

The map and the recruitment offer list no longer show every possible site or
candidate at once. A campaign starts with two active encounters, the
one-star Goblin Camp (difficulty 1) and the two-star Orc Outpost (difficulty
2), and one active recruitment offer (a Warrior); each category still holds
at most two active encounters or four active offers at a time. Clearing a
site or hiring a recruit opens a vacancy; that vacancy's own 15- (encounter)
or 30- (recruitment) World Map turn clock refills it with a new instance only
if its category is still under its cap when the clock completes. A cleared
site never reopens — a later spawn is a distinct new instance, though it may
reuse a previously seen encounter template at a different map tile.

The World Map marks each active encounter with a difficulty-only star badge
(one star for Goblin Camp, two for Orc Outpost) rather than a numeric label,
so the player can compare expedition risk at a glance before committing a
route. The approved rationale for starting with two simultaneous expedition
choices and for star-only markers is recorded in
[Two Starting Encounters Design](../2026-08-06-two-starting-encounters-design.md).

Site entry retains selection-before-activation. The first click selects the
party, so it can still move away; a second click enters the settlement or an
active site. A cleared camp rejects entry.

### Full-party battles and the Guild Hall

Every deployed party member — not just the first — is fielded on the
battlefield, at a fixed start position, alongside the site's full enemy
count. A unit's movement is a spendable per-turn points budget (base 3
tiles, plus one per Bonus Move perk) rather than an all-or-nothing flag, so
WASD steps and multi-tile mouse clicks can be freely interleaved with a
unit's one attack. The player selects a unit by mouse, WASD, or number key
(1-5); a left portrait panel shows one square per fielded party member, with
the unit's colour, health, a selection ring, and a dimmed state once
defeated.

Each site's star rating now drives a randomly resolved enemy composition
instead of a fixed matchup: the one-star Goblin Camp always fields one
Goblin; the two-star Orc Outpost fields two Goblins or one Orc, chosen at
random each time the site is entered. A Warrior has 3 health, Attack 60 (a
60% hit chance), and deals 2 damage with its Sword; a Goblin has 3 health, a
30% hit chance, and deals 1 damage with its Short Sword; an Orc has 5
health, a 50% hit chance, and deals 2 damage. Enemies take a visible,
deterministic AI decision sequence after the player ends the round.

The Guild Hall is the game's first gold-funded building. A fresh campaign
caps party assignment at 4 members (Guild Hall level 1); spending 50 gold at
the Guild Hall raises the cap to 5 (level 2, the max for this slice).
`party_details.gd` and `unit_details.gd` both reject an assignment past the
current cap rather than silently failing it. The approved spec for this
slice — fielding, movement points, selection, the portrait panel, and the
Guild Hall cap — is recorded in
[Guild Hall and Full-Party Battles Design](../2026-08-07-guild-hall-and-full-party-battles-design.md).

The player-facing shell is also in place: New Game begins at the settlement;
Continue and Load are intentionally disabled until a save system exists; and
Escape opens a pause-menu overlay from the settlement, encampment, party
manager, world map, and battlefield. The overlay can return to the unchanged
scene, open the World Map, show the current "Not implemented yet" Save status,
or quit. Opening the World Map during an active battle preserves that battle:
its encounter can be re-entered, while End Turn remains locked until the battle
resolves.

For fast development checks, a debug-only F9 scenario menu can open a fresh
campaign at the settlement, encampment, party manager, a ready-to-depart
party, the world map, or the Goblin Camp battle. It uses the same public
campaign APIs and scene routes as ordinary play and is unavailable in release
builds.

The completed implementation plans are historical delivery records. The
enduring design reference for the settlement/party boundaries is
[Settlement and First Party Design](settlement-and-first-party-design.md).

## Next work

The prototype now fields a full party against a full, star-tier-randomized
enemy composition, and the Guild Hall gives players their first gold-funded
tactical decision (a larger party). Recruitment, XP, and gold all feed that
loop already. The next implementation work should focus on these unfinished
outcomes, in order:

1. Give players a second gold-funded, expedition-facing decision beyond
   party size. Buildings currently offers only the Guild Hall and Trade is
   still unimplemented, so an equipment or Trade improvement (e.g. a
   blacksmith upgrading the Warrior's Sword) is the natural next building.
2. Broaden the encounter catalogue beyond the Goblin Camp and Orc Outpost
   templates so expedition choice differs by more than star rating alone —
   Milestone 3's remaining gap.
3. Add save/load now that the expedition, reward, and upgrade loop is
   repeatable; then enable the existing Continue and Load UI.
4. Assemble Milestone 5's first campaign slice — onboarding and pacing —
   once at least one more building and encounter type have landed.
5. Add durable presentation assets only when their associated gameplay choices
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

**Status: completed for the Goblin Camp and Orc Outpost.** The implemented
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

**Status: reward, replacement, and full-party tactical loops shipped;
catalogue breadth is incomplete.** Every expedition now pays out two reward
types: gold (banked on return to Encampment) and individual adventurer XP
(awarded immediately per kill and per clear; see Adventurer progression
above). Cleared sites are persistent but not permanent — each vacancy
refills on its own 15-turn clock under a two-site cap, so the world map
keeps changing within a campaign rather than only accumulating grey markers.
Each site's star rating also now resolves to a randomized enemy composition
(see Full-party battles and the Guild Hall above), so the two templates
already produce more than one tactical setup. The encounter catalogue
itself is still just the Goblin Camp and Orc Outpost templates; a broader
roster of encounter types, and any travel-time or resource cost beyond
World Map turns, remain future work.

### Player outcome

An expedition has a purpose and a consequence. The player chooses a
destination, resolves its risk, receives a reward or setback, and returns to
camp with a reason to plan the next trip differently.

### Design scope

- Define a small encounter catalogue, beginning with clear roles such as
  bandits, wandering monsters, or a dungeon entrance.
- Add gold as the first reward and spending currency. Any first item reward
  should have one simple, observable effect.
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
adventurer progression, and the first gold-funded building are shipped;
equipment and Trade are not.** The prototype has an encampment UI shell
(Units, Buildings, Trade, Deploy Party) and Units -> Parties -> Party Details
-> Unit Details browsing with deliberate party deployment. An encamped party
can use Add Member to assign an existing available adventurer, or Roster can
assign one directly from Unit Details, up to the Guild Hall's current
party-size cap (see Full-party battles and the Guild Hall above). Recruitment
offers a small, vacancy-timed pool of gold-costed Warrior candidates (see
Vacancy-timed encounter and recruitment population above) rather than a fixed
catalogue. Adventurers gain XP, levels, Attack points, and perks from
expeditions (see Adventurer progression above), legible from Unit Details.
Buildings currently offers only the Guild Hall; it does not yet offer
equipment, Trade, or any other settlement investment.

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
  training option, skill point, or equipment improvement.
- Present town growth as card-like buildings and services. Start with one or
  two meaningful options, such as a blacksmith or a temple.
- Each town choice must state and deliver an expedition-facing benefit. A
  temple may attract a cleric or unlock training; a blacksmith may improve
  equipment.
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

The encampment UI shell shows these destinations early to establish the
campaign's shape, but this first UI slice implements only Units -> Parties ->
Party Details -> Unit Details and Deploy Party. The remaining destinations
remain visibly unavailable or labelled TBD; they must not simulate systems
that do not exist yet.

- **Buildings:** the Guild Hall is the first building card, with a real cost
  (50 gold), an upgrade level (1-2), and a service effect (a raised
  party-size cap). Further building cards, construction prerequisites, and
  associated art remain TBD; implement each after its expedition-facing
  benefit is proven.
- **Trade:** buy/sell inventory, prices, stock, and equipment ownership are
  TBD. Do not invent an item economy before the first improvement loop.
- **Roster and Recruitment growth:** this slice intentionally has no search,
  pagination, town-size rules, building prerequisites, or class-specific
  combat behavior. Refill timing and caps are deterministic, not random.
  Later town growth can expand or filter the vacancy-timed offer pool without
  changing ownership or screen routing.
- **Party management limits:** party capacity is now the Guild Hall's cap (4,
  or 5 after the upgrade); removal, reassignment between parties, injuries,
  and availability rules beyond the current available status remain TBD.
  The existing Add Member flow is the party-first assignment path; Roster's
  Unit Details action is the unit-first path.

The durable model direction is deliberately modest. Parties keep stable IDs,
display names, member IDs, location/deployment state, and placeholder fields
for party-level progression. Adventurers keep stable IDs, display name, class,
level, availability status, and placeholder combat/progression fields. A
deployability query—not a UI-specific special case—decides whether an
encamped party is shown for deployment. This supports future dead,
incapacitated, and otherwise unavailable members while keeping the current
prototype's single Warrior immediately usable.

## Milestone 5: First campaign slice

**Status: not started.** The reward and upgrade loop now exists (gold, XP,
the Guild Hall, and randomized site compositions), but this milestone still
waits on the catalogue and Trade/equipment gaps called out in Next work
above — one building and two encounter templates are not yet the "several
expeditions, several upgrades" this milestone asks for.

### Player outcome

The player can play a short campaign with several expeditions, make different
upgrades, and see their party and encampment become more capable before the
available local threats are cleared.

### Design scope

- Assemble the proven systems into a compact local area with varied encounter
  types and a modest upgrade path.
- Balance reward pacing, difficulty, and the information shown in the UI.
- Improve onboarding so the first game explains movement, rounds, world turns,
  rewards, and upgrades through play.
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
- Deep class, spell, skill-tree, and equipment systems
- Broad enemy, item, and encounter catalogues
- Procedural maps or generated content
- Full supplies, injuries, permadeath, trade-route, and diplomacy systems
- Self-sustaining settlement income and conflict with neighbouring cities
- Save/load, long-term balance, accessibility, and production-grade polish

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
