# Monster Tiers and Weighted Encounters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Kobolds and Hobgoblins, a new three-star "Ruined Fortress" encounter
that fields 4-8 Kobolds, 3-6 Goblins, 2-4 Orcs, or 1-3 Hobgoblins, a
player-power-weighted chance of a refill producing a one/two/three-star site,
and a rebalance of every combatant's HP and damage around the Warrior's new
10 HP baseline (an Orc is tuned to be roughly an even 1-on-1 fight against a
level-1 Warrior).

**Architecture:** Everything lives in the existing `GameSession` autoload
(constants and pure functions — no new nodes or classes) plus a small
capacity increase in `BattleController` so a battle can field up to 8
enemies instead of 3. Kobold/Hobgoblin loot tables already exist in
`GameSession.ENEMY_LOOT_TABLES`; this plan adds their combat stats and wires
them into a fightable site.

**Tech Stack:** Godot 4.7.1, GDScript, GUT test framework (`make test` /
`make check`), the project's own headless battle simulator (`make simulate`)
and screenshot tour (`make screenshots`).

## Global Constraints

- Follow `AGENTS.md`: one branch per step off `main`, red/green TDD, `make
  check` must pass before merging, merge each step back to `main` locally
  and delete the branch before starting the next step. Only push to
  `origin` or open a PR if the user asks.
- Do not touch weapon/armor catalogs, hit-chance formulas, XP thresholds, or
  the Guild Hall/Trading Post systems — out of scope for this plan.
- Every new or changed balance constant that already has a GameConfig-backed
  twin (`BASE_MAX_HEALTH` today) must be updated in all three places it's
  duplicated: the `var` default in `game_session.gd`, `DEFAULTS` in
  `game_config.gd`, and `config/game_config.json`. New monster stats
  (Kobold/Hobgoblin, Goblin/Orc's damage) are plain `const` Dictionaries in
  `game_session.gd` only — they are not GameConfig-backed today and this
  plan does not make them so.
- Enemies stay unarmored (`defense = 0`, `resistance = 0`), matching every
  existing enemy — this plan does not migrate monsters onto the
  weapon/armor system.
- GDScript methods prefixed `_` are conventionally private but are already
  called directly from tests throughout this codebase (e.g.
  `session._start_encounter_vacancy()` in `test_game_session.gd:1795`) —
  follow that existing convention rather than adding public wrappers.

---

## Why these numbers: HP and damage rebalance

The user's brief: Warrior HP becomes 10, and a level-1 Warrior should be
"roughly equal" to an Orc. "Roughly equal" is made concrete here as: the
expected number of rounds for each side to kill the other in a solo 1-on-1
are approximately equal, using the combat math already in
`BattleController.try_attack_selected_unit`:

- `effective_hit_chance = attacker.hit_chance - defender.defense/100` (floored at 0.05)
- `damage = round(raw_damage * (1 - defender.resistance/100))`

A level-1 Warrior (Attack 60 -> 0.6 hit chance, starting Iron Longsword 1-8
damage, Leather Armor: 10 defense / 10 resistance) has an average
"damage rate" of `0.6 * 4.5 = 2.7` per round against any unarmored monster
(monsters keep 0 defense/0 resistance, per the constraint above, so this
rate is the same against every monster tier).

Working backward from "Orc rounds-to-kill-Warrior ≈ Warrior
rounds-to-kill-Orc" while keeping the Orc's existing 0.5 hit chance produces
Orc HP 22 and Orc damage 3 (see the table below). Kobold and Hobgoblin are
then placed below and above that anchor respectively, using the same
formula, so all four monster tiers form one consistent curve:

| Monster | HP | Hit chance | Damage | Warrior kills it in | It kills Warrior in |
|---|---|---|---|---|---|
| Kobold | 6 | 0.25 | 1 | 6/2.7 ≈ 2.2 rounds | 10/0.15 ≈ 66.7 rounds |
| Goblin | 13 | 0.30 | 2 | 13/2.7 ≈ 4.8 rounds | 10/0.4 = 25 rounds |
| Orc | 22 | 0.50 | 3 | 22/2.7 ≈ 8.1 rounds | 10/1.2 ≈ 8.3 rounds |
| Hobgoblin | 30 | 0.60 | 4 | 30/2.7 ≈ 11.1 rounds | 10/2.0 = 5 rounds |

Reading the table: a solo Warrior curb-stomps a Kobold or Goblin (the
one-star Goblin Camp stays an easy intro fight), is in a genuinely even
fight with a single Orc (8.1 vs 8.3 rounds), and would lose to a solo
Hobgoblin (5 vs 11.1 rounds) — appropriate, since Hobgoblins only ever
appear 1-3 at a time as the "elite, low-count" option of the new three-star
site, meant to be fought by a full party, not a lone adventurer. Kobolds are
individually harmless but appear 4-8 at a time, so their danger comes from
volume of attacks rather than any single Kobold's power.

Goblin and Orc damage change from their current flat 1/2 to 2/3 — at the old
values, a monster would need dozens of rounds to scratch a 10 HP Warrior,
which is not "roughly equal" for the Orc and makes every fight trivially
long. Every other stat (Warrior Attack 60, weapon/armor catalog, hit-chance
cap/divisor) is unchanged.

## Why this formula: player-power-weighted star tier

"Weighted by player power" is made concrete as: `power = adventurers.size()
+ guild_hall_level` (starts at `1 + 1 = 2`, since a fresh campaign has one
Warrior and Guild Hall level 1), and each star tier's selection weight is:

```
weight(tier, power) = max(1, STAR_WEIGHT_BASE[tier] + STAR_WEIGHT_PER_POWER[tier] * power)
STAR_WEIGHT_BASE     = {1: 6, 2: 2, 3: -2}
STAR_WEIGHT_PER_POWER = {1: -1, 2: 1, 3: 1}
```

The floor of 1 means no tier's odds ever hit exactly zero — a maxed-out
campaign can still rarely see a one-star site, and a brand-new one can still
rarely see a three-star site. Worked examples (probabilities are each
tier's weight over the sum of all *currently inactive* tiers' weights, since
a template that already has a live instance is never re-selected):

| Power | 1-star weight | 2-star weight | 3-star weight | 1★ / 2★ / 3★ odds |
|---|---|---|---|---|
| 2 (fresh campaign) | 4 | 4 | 1 | 44% / 44% / 11% |
| 3 | 3 | 5 | 1 | 33% / 56% / 11% |
| 5 | 1 | 7 | 3 | 9% / 64% / 27% |
| 6 | 1 | 8 | 4 | 8% / 62% / 31% |

**Behavior change from today:** `_choose_encounter_template()` currently
guarantees the player sees every known template at least once before any is
reused (see its docstring in `game_session.gd`). This plan replaces that
guarantee with pure power-weighted randomness on every refill, because the
two are incompatible in practice: at a brand-new campaign's very first
refill, the Ruined Fortress would be the *only* unseen template and the old
rule would force it in immediately regardless of power, defeating the point
of weighting it down for a weak party. The two starting encounters (Goblin
Camp, Orc Outpost) are seeded directly by `reset()` and are unaffected —
only later vacancy refills go through the weighted picker.

## Files touched

- `scripts/autoload/game_session.gd` — monster stats, composition schema,
  the new template, the weighted picker.
- `scripts/autoload/game_config.gd`, `config/game_config.json` — Warrior's
  base HP default.
- `scripts/battle/battle_controller.gd` — enemy start-position capacity.
- `scripts/debug/debug_scenarios.gd`, `scripts/autoload/game_manager.gd`,
  `scripts/debug/debug_menu.gd`, `scenes/debug/debug_menu.tscn` — a debug
  scenario to jump straight into a Ruined Fortress battle.
- `translations/en.tres` — new enemy/expedition name strings.
- `tests/unit/test_game_session.gd`, `tests/unit/test_battle_controller.gd`,
  `tests/unit/test_battlefield.gd`, `tests/unit/test_debug_menu.gd` — new
  and updated assertions.
- `docs/plans/first-playable-campaign/game-design.md`,
  `docs/dev/running-the-game.md` — design doc and dev doc sync.

## Steps

1. [01-rebalance-warrior-goblin-orc-hp.md](01-rebalance-warrior-goblin-orc-hp.md)
   — Retune Warrior/Goblin/Orc HP and damage to the table above.
2. [02-add-kobold-and-hobgoblin.md](02-add-kobold-and-hobgoblin.md) — Add
   their combat stat blocks and localization strings (not yet fightable).
3. [03-expand-battlefield-enemy-capacity.md](03-expand-battlefield-enemy-capacity.md)
   — Raise `BattleController`'s fieldable-enemy cap from 3 to 8.
4. [04-ranged-composition-counts-and-three-star-template.md](04-ranged-composition-counts-and-three-star-template.md)
   — Generalize enemy counts to a min/max range and add the Ruined Fortress
   three-star site with its four composition options.
5. [05-power-weighted-encounter-tier-selection.md](05-power-weighted-encounter-tier-selection.md)
   — Replace deterministic template cycling with the weighted picker above.
6. [06-debug-scenario-for-ruined-fortress.md](06-debug-scenario-for-ruined-fortress.md)
   — Add a one-click debug scenario to battle-test an 8-enemy fight.
7. [07-docs-sync.md](07-docs-sync.md) — Update the design doc and dev docs
   to match the shipped behavior.

Each step is independently branchable, testable, and mergeable — do them in
order, since later steps depend on constants/schemas earlier steps introduce.
