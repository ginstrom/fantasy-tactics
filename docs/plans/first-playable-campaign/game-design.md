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
  -> Units -> Parties -> Deploy Party
  -> depart to the World Map
  -> select the deployed party and plan a route
  -> advance one world-map tile manually or with End Turn
  -> select the party at Goblin Camp and enter battle on a second click
  -> win: clear the camp and return to the World Map
     or lose: return the party to the Starting Settlement; camp remains available
```

Party creation and Warrior assignment, previously reachable from an
Encampment "Party Manager" screen, are superseded by the Milestone 4
encampment UI shell below. Party Details now offers Add Member for an
encamped party, restoring the ordinary in-game assignment path. The next
encampment work adds the complementary roster-first path and recruitment so a
new campaign can grow beyond its starting Warrior without debug tooling.

`GameSession` owns the one-Warrior roster, the single player-created party,
its deployment state, world position, committed travel route, movement spent,
world turn, and encounter completion. `GameManager` owns named scene
transitions. The party is visible and movable only while deployed. World-map
travel is deliberately simple: an in-bounds, empty-grid Manhattan route moves
one tile per World Map turn; no terrain costs, obstacles, waypoints, or
multi-party scheduling are implied yet.

Site entry retains selection-before-activation. The first click selects the
party, so it can still move away; a second click enters the settlement or
Goblin Camp. A cleared camp rejects entry. In the battle, the Warrior and one
Goblin each have 3 health and can move once and make one adjacent attack in
either order. The Warrior's Sword deals 2 damage on a 60% hit chance; the
Goblin's Short Sword deals 1 damage on a 30% hit chance. The Goblin takes a
visible, deterministic AI decision sequence after the player ends the round.

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

The foundation establishes the campaign's entry, travel, tactical result, and
return paths, but it is not yet a repeatable campaign. The next implementation
work should focus on the unfinished outcomes below, in milestone order:

1. Make tactical results matter in campaign state: add a small reward or
   setback and a second expedition whose risk, reward, or tactical setup
   differs from the Goblin Camp.
2. Turn the return to camp into a meaningful choice: add gold and one
   deliberately small, player-visible party or settlement improvement funded
   by it.
3. Expand the roster from one Warrior toward the planned initial party of four
   only after the first improvement makes a later expedition meaningfully
   different.
4. Add save/load only after the repeatable expedition, reward, and upgrade
   loop works; then enable the existing Continue and Load UI.
5. Add durable presentation assets only when their associated gameplay choices
   have been playtested, following the asset policy below.

Developer verification remains a supporting concern rather than a player
feature. The completed scenario menu accelerates checks, but it does not
replace exercising the complete settlement-to-expedition route.

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

**Status: completed for the Goblin Camp.** The implemented battle has the
narrow Warrior-versus-Goblin setup described above, real win/loss detection,
visible enemy pacing, and campaign outcomes: victory clears the camp and
returns to the map; defeat returns the party home without clearing the camp.

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

**Status: next.** The first tactical expedition exists, but it has no reward,
resource cost, or alternative destination yet.

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

**Status: encampment UI shell, party browsing/deployment, and party-first Add
Member completed; roster and recruitment next.** The prototype already has an
encampment UI shell (Units, Buildings, Trade, Deploy Party) and Units ->
Parties -> Party Details -> Unit Details browsing with deliberate party
deployment. An encamped party can use Add Member to assign an existing
available adventurer. The next slice activates Roster and Recruitment: it
adds a roster-first assignment path and a small gold-costed, finite candidate
list. It does not yet offer a four-member starting party, development,
equipment, buildings, trade, or a settlement investment.

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

- **Buildings:** building cards, construction prerequisites and costs,
  service effects, upgrade levels, and associated art are TBD. Implement after
  one gold-funded improvement has a proven expedition-facing benefit.
- **Trade:** buy/sell inventory, prices, stock, and equipment ownership are
  TBD. Do not invent an item economy before the first improvement loop.
- **Roster and Recruitment growth:** this slice intentionally has no search,
  pagination, random offers, town-size rules, building prerequisites, or
  class-specific combat behavior. Later town growth can expand or filter the
  fixed recruitment catalogue without changing ownership or screen routing.
- **Party management limits:** party capacity, removal, reassignment between
  parties, injuries, and availability rules beyond the current available
  status remain TBD. The existing Add Member flow is the party-first
  assignment path; Roster's Unit Details action is the unit-first path.

The durable model direction is deliberately modest. Parties keep stable IDs,
display names, member IDs, location/deployment state, and placeholder fields
for party-level progression. Adventurers keep stable IDs, display name, class,
level, availability status, and placeholder combat/progression fields. A
deployability query—not a UI-specific special case—decides whether an
encamped party is shown for deployment. This supports future dead,
incapacitated, and otherwise unavailable members while keeping the current
prototype's single Warrior immediately usable.

## Milestone 5: First campaign slice

**Status: not started.** This milestone begins only after the reward and
upgrade loop gives players a reason to choose among multiple expeditions.

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
