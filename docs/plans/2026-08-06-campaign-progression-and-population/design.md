# Campaign Progression and Population Design

## Goal

Make expeditions advance individual adventurers, and let the world gradually
refill a bounded number of available expeditions and recruitment offers.

## Approved rules

- Start a campaign with one roster Warrior, one Goblin Camp, and one
  recruitable Warrior.
- A cleared encounter leaves a vacant encounter slot. Fifteen World Map turns
  after that vacancy begins, add one new encounter if fewer than two sites are
  active. A hired recruit similarly leaves a vacancy; refill it after thirty
  World Map turns if fewer than four recruit offers are active.
- A site that was cleared is never reopened. A later spawn is a new encounter
  instance, which may use a previously seen encounter template at a different
  valid map tile. Recruitment offers are likewise distinct candidate records.
- Award XP immediately: 5 for a Goblin kill and 10 for clearing its site; 10
  for an Orc kill and 20 for clearing its site. Divide each award evenly among
  the deployed party's members. Store fractional XP, but display integers.
- The cumulative level thresholds are 0, 20, 50, 90, and so on: level 2 costs
  20 XP, and each following level costs 10 XP more than the prior one.
- Each level gives one maximum-health point and ten unspent skill points.
  Attack starts at 60; every point spent raises the stored Attack value by one.
  Combat caps its effective hit chance at 95%, while retaining values above it
  for future defence and debuff calculations.
- Every third level requires a perk choice. The first perk is Bonus Move,
  which grants one extra tile of movement range.
- A level-up resolves immediately in a modal battle overlay, before further
  input or a battle-result scene transition. It applies the health increase to
  both the persistent adventurer and the active unit.

## Scope boundary

This slice does **not** add multi-unit battles. The deployed party may grow
and shares XP, but only the existing player combat unit is on the battlefield.
The follow-up slice will spawn up to four healthy party members and rebalance
encounters around that action economy.

## Ownership

`GameSession` owns adventurer progression, encounter instances, recruitment
offers, vacancy clocks, and deterministic scheduling. `BattleController`
reads derived stats and reports combat events; `Battlefield` owns asynchronous
pacing and the level-up overlay. `GameManager` remains the boundary for scene
routes. Screens render session state and emit intents only.
