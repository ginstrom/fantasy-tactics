# Initial Campaign Readiness and Play Automation Design

## Purpose

Turn the implemented expedition systems into a short, newcomer-ready campaign
slice, and establish a reproducible automated-battle foundation for balancing
and future AI work. This is a product and architecture design, not an
implementation plan.

It extends the first-playable campaign design rather than broadening its
scope. The target remains a compact loop in which expeditions improve a party,
and encampment choices change the next expedition:

```text
prepare party -> choose site -> travel -> tactical battle -> rewards
     ^                                                       |
     |------------- return, bank, recruit, equip, upgrade ---|
```

The relevant long-term direction is [Game Vision](../../designs/vision.md).
The first campaign is evidence for that vision, not an attempt to implement
all of it at once.

## Current foundation

The following are already usable in a manual campaign:

- Formation and deployment of one party; recruitment of additional Warriors.
- Route-based World Map travel and separate World Map turns.
- Three active encounter tiers, full-party tactical battles, XP, level-ups,
  equipment, and defeat returning the party home without clearing the site.
- Loot carried from battle, banked at the Encampment, and spent through the
  Guild Hall and Trading Post.
- Vacancy-timed encounter and recruitment replenishment.
- A debug-only scenario menu and a headless `make simulate` command. The
  current simulator runs a fixed greedy player bot against the normal enemy AI
  and appends one outcome per battle to JSONL.

The missing work is therefore integration, confidence, and player legibility,
not another isolated combat or economy subsystem.

## First campaign slice

### Player promise

A first-time player can start a new campaign, understand the immediate goal,
play several expeditions without developer tools, make at least two different
improvements, and see those improvements change a subsequent battle. They can
save at a safe point, leave, and resume the same campaign without duplicated
rewards, reset vacancy clocks, or lost equipment.

The slice should make the vision's core exchange visible:

| Player decision | Immediate consequence | Later consequence |
| --- | --- | --- |
| Choose a lower- or higher-star site | Risk, enemy composition, and likely reward differ | Determines how quickly the party can afford capability |
| Recruit or improve a party | More bodies versus delayed equipment/building spend | Changes tactical options and encounter viability |
| Buy, sell, or equip gear | Changes attack damage, hit chance, or protection | Changes odds and pace of the next battle |
| Upgrade the Guild Hall | Raises party-size capacity | Enables a larger tactical team |

### Campaign shape and pacing

The opening must guide, rather than interrupt. A new campaign should make its
next useful action obvious: form a party, deploy it, choose a route, and enter
the first site. Contextual hints may point to a control or explain a result,
but must be short, dismissible, and never prevent normal input after the
player has demonstrated the action.

The compact local area starts with the active Goblin Camp and Orc Outpost. The
Ruined Fortress is a later, visible objective produced through the normal
encounter-population rules, not a compulsory scripted finale. The campaign is
successful when the player has experienced multiple expedition decisions and
at least one reward-to-upgrade-to-battle feedback loop; it does not need a
finite story ending or permanent world completion.

Balance should favour legible choices over precise symmetry. A lower-star
site should be a credible recovery or learning choice. A higher-star site
should offer a materially different risk/reward proposition, not merely more
health. A player who loses may retry after returning home; injuries,
permadeath, supplies, and travel costs remain outside this slice.

### Save and resume

Save/load is the remaining required durability feature, not a new strategic
system. A save represents the complete durable `GameSession` state needed to
continue a campaign: roster and parties, equipment and stores, gold, buildings,
world position and route, turn/vacancy state, encounter instances/completions,
and any unresolved carried or battle rewards.

The player can save only at stable campaign boundaries: the settlement,
encampment, or World Map when no battle is active. Saving during an active
battle is explicitly deferred so a save never has to reconstruct transient UI,
animation, policy, or modal state. Continue resumes the most recent valid save;
Load chooses from the available saved campaigns once multiple slots are
introduced. A failed or incompatible save must leave the player at the start
menu with a clear explanation and must not alter an in-memory campaign.

Return-to-Encampment settlement remains exactly once: loading before banking
does not bank rewards, and loading after banking does not bank them again.

### Readiness gates

The slice is ready for broader investment only when all of these are true:

- A new player can complete several expeditions and an upgrade loop with no F9
  scenario or developer explanation.
- The player can describe why their next site and improvement choice differs
  from the previous one.
- Save, quit, and resume preserve campaign state at the supported boundaries.
- Repeated playtests and automated results show no dominant trivial route or
  unexplained encounter that is routinely unwinnable by the baseline policy.
- Feedback identifies the next bottleneck as tactical depth, character depth,
  or strategic management.

Only after these gates should durable terrain, portraits, sounds, ambience,
and town-state assets be selected or commissioned. Every such asset needs a
known source and licence.

## Automated battle scenario runner

### Role

The runner is a developer-only, headless evaluation tool. It answers questions
such as:

- How does a two-Warrior party fare against one Orc versus two Goblins?
- Does +10 Attack improve win rate by a meaningful amount at each encounter
  tier?
- Does Defense or Resistance produce an unexpectedly large survival gain?
- Which policy wins when two AI candidates receive the same scenario matrix?

It does not determine whether a battle is fun, replace manual playtests, or
silently tune balance values. Its purpose is reproducible evidence that guides
those decisions.

### Architectural boundary

Introduce a battle-level contract beneath the existing scene-driven simulator:

```text
scenario definition + seed + side policies
                    |
                    v
             scenario runner
                    |
                    v
     public battle rules / BattleController
                    |
                    v
  per-iteration records -> aggregate report -> balance decision
```

The runner creates battle state directly from a declared scenario and drives
the same public battle actions available to gameplay. It must not depend on
F9, screen navigation, frame pacing, or persistent campaign reward settlement.
The current `battle_sim` remains a useful smoke-test client: it can translate
its existing Goblin Camp and Orc Outpost cases into runner scenarios while
continuing to exercise the player-facing battle scene where that is valuable.

This separation lets battle balance run quickly and deterministically, while a
later campaign automation layer composes travel, recruitment, economy, and
multiple battles around the same scenario runner.

### Scenario contract

A scenario is declarative, versioned data with a stable `scenario_id`. It
contains only the information needed to construct and evaluate one battle:

- **Board:** dimensions, blocked tiles when supported, and starting positions.
- **Player side:** each unit's template/class, equipment, level-derived state,
  health, movement, and optional Attack, Defense, Resistance, or damage-range
  modifiers.
- **Enemy side:** monster templates, count or explicit units, positions, and
  optional stat modifiers.
- **Rules:** round limit, victory condition, and any explicitly supported
  battlefield rules variant.
- **Policies:** named player and enemy policies plus policy configuration.
- **Randomness:** a root seed and the number of iterations. Iteration seeds are
  derived from the root seed and recorded, never pulled implicitly from global
  randomness.
- **Labels:** readable tags such as `party_size_2`, `orc`, or
  `resistance_10` for filtering reports.

Scenario data may describe a single exact matchup or a matrix. A matrix is a
named set of parameter axes—party size, monster count, and modifiers, for
example—that expands into individually identified concrete scenarios before
execution. The expanded cases, not just the input matrix, are recorded in the
output so a result can always be reproduced.

Modifiers are explicit test inputs, never hidden mutations of global balance
configuration. The normal game configuration remains the default baseline.

### Policy contract

A policy is a named decision provider for one side. Given an immutable view of
the legal battle state, it chooses legal actions for its current units; the
runner applies those actions through the battle engine and records the result.
Policies may be deterministic or stochastic, but any stochastic policy must
use the scenario's supplied random stream.

The first supplied policies are:

- **Greedy pursuit:** the current `BattleBot` behaviour for the player side.
- **Current enemy policy adapter:** an adapter around the game's shipped enemy
  decision rules, so existing behaviour is measurable rather than duplicated.

Future policies may include a defensive player bot, a tactical heuristic, a
scripted encounter boss, or an experimental learned agent. They are evaluated
under identical scenarios and seeds. A policy must not inspect private engine
state or modify battle state directly; this keeps results comparable and
prevents an AI shortcut from hiding a game-rules defect.

### Execution and result contract

Each concrete scenario runs for its requested number of iterations. Every
iteration ends as `player_victory`, `enemy_victory`, `stalemate`, or `error`.
A round cap produces `stalemate`; illegal policy actions and setup failures
produce `error` with a machine-readable reason. Neither may be folded into a
loss rate or silently discarded.

Each JSONL iteration record includes:

- runner and scenario-contract versions, scenario ID, expanded parameters,
  root/iteration seed, and balance-config fingerprint;
- policy identifiers and versions;
- outcome, rounds, actions attempted/rejected, damage dealt/taken, kills,
  surviving units, and remaining health; and
- elapsed wall-clock time and an error/stalemate reason where applicable.

An aggregate report groups results by concrete scenario and policy pairing. At
minimum it reports runs, wins/losses/stalemates/errors, win rate with sample
count, mean and percentile rounds, mean damage, and survival/remaining-health
distributions. Reports must retain raw-record paths and command/configuration
metadata; an aggregate without reproducible inputs is not balance evidence.

The command-line interface accepts a scenario file or ID, optional matrix-axis
filters, iteration override, root seed, output directory, and output format.
Default output paths are unique per run rather than append-only, so unrelated
experiments are never mixed. A deliberately named comparison command may read
several completed reports and produce a table, but never reruns cases
implicitly.

### Determinism and validity

Given the same scenario version, balance-config fingerprint, policies, root
seed, and engine version, the runner must produce the same per-iteration
outcomes and aggregate values. Changing any of those inputs marks results as a
new experiment rather than a continuation.

The runner validates before execution: unit counts fit the board, positions do
not overlap, templates and modifiers exist, policies support the requested
side/rules, and iteration/round limits are positive. Invalid definitions fail
the whole requested scenario with an actionable diagnostic; they do not yield
plausible-looking partial numbers.

Automated scenario tests protect the runner itself: fixed-seed replay,
parameter-matrix expansion, modifier application, policy legality, outcome
classification, and aggregate math. Gameplay tests remain the authority for
normal combat rules. A balance experiment is additionally checked by manually
playing representative baseline, favourable, and adverse cases.

### Initial experiment set

The first useful comparison suite is deliberately small:

| Question | Scenario axes | Decision supported |
| --- | --- | --- |
| Starting-party viability | 1-4 Warriors × Goblin Camp / Orc Outpost | Party and encounter baseline |
| Encounter count pressure | 1-4 Warriors × 1-8 monsters by template | Board/enemy-count limits |
| Offensive scaling | Attack and weapon damage variants | Value of XP, skills, and gear |
| Defensive scaling | Defense and Resistance variants | Armor value and survivability |
| Policy comparison | Same matchup × baseline/experimental policy | AI quality without changing balance |

The suite reports uncertainty honestly. Small iteration counts are useful for
smoke checks; balance conclusions require a declared, adequate sample size and
comparison against a fixed baseline run.

## Automation growth boundary

The automated battle runner is the seed of a wider play-automation system, but
only battle-level automation belongs to this design's first delivery. Later
layers can add:

- campaign scenarios that create a `GameSession` from declarative state and
  choose encampment, route, recruitment, trade, and battle actions;
- policy evaluation over multi-battle resources and risk, including save/resume
  regression cases; and
- regression suites that pin important policy/balance outcomes while allowing
  intentional, reviewed changes.

Those layers must consume the battle scenario and policy contracts rather than
forking them. They are deferred because campaign-level success depends on
player goals and economy decisions that first need manual playtest evidence.

Fog of war, dungeon crawling, generic action points, healing, class systems,
crafting, multiple simultaneous parties, trade routes, and the story campaign
remain outside the initial slice. Their future automation needs should inform
extension points, but must not inflate the current runner.

## Design decisions and open questions

Decisions made here:

- Policies are first-class from the beginning; the runner is not permanently
  tied to one player bot or the current enemy AI.
- Scenario inputs and outputs are reproducible and versioned.
- The battle runner is headless and independent of UI/campaign settlement.
- Campaign readiness is measured by manual multi-expedition play as well as
  automation; neither substitutes for the other.

Questions to answer through the initial playtest and first experiments:

1. Which outcome ranges feel desirable for each star tier and party size?
2. Which player-policy baselines are representative enough to support balance
   conclusions, rather than merely exposing one bot's blind spots?
3. Does the existing board and full-party UI remain readable at the intended
   1-5 player and 1-8 enemy bounds?
4. Which save-slot and campaign-selection experience is sufficient before a
   second campaign is introduced?

The answers guide the first implementation plan after this design is approved;
they do not require a larger strategic-game commitment now.
