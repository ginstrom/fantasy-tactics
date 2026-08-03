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

The first implementation slice is smaller: a starting settlement, one
unassigned Warrior, a player-created party, deployment to the existing world
map, and return to the settlement. It is specified in
[Settlement and First Party Design](settlement-and-first-party-design.md).

Developer verification is a supporting part of that slice, not a player
feature. Before building the settlement and party-management screens, add a
development-only scenario menu that can reset the campaign and open a valid
encampment, party-management, world-map, or battle setup. The menu must use
the same `GameSession` state APIs and `GameManager` transitions as normal play;
it accelerates checking a destination but does not replace manually testing
the complete player route. The staged implementation is in
[Developer Tools Implementation](developer-tools-implementation/index.md).

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

- The existing world-map TODOs are resolved in player-visible behavior.
- The player can always understand the current map state and return safely to
  the main menu.
- The campaign state clearly separates world turns, battle rounds, parties,
  and encounters.

### Presentation milestone

Establish the visual language before content expands: camera scale, grid/tile
size, palette, type treatment, selection states, and icon rules. Replace
abstract markers with a minimal reusable kit of terrain tiles, party/enemy
silhouettes, and movement/selection feedback. Record each asset's source and
licence, including temporary assets.

## Milestone 2: Tactical encounter loop

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

### Player outcome

Returning home presents useful choices: improve an existing party or make one
encampment investment that changes future expeditions.

### Design scope

- Provide a clear roster and party-formation view for the initial four
  characters.
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

## Milestone 5: First campaign slice

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
