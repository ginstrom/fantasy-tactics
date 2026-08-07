# Config and Automation Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Move `GameSession`'s balance constants (combat, progression, guild
hall, population) into an external, hot-editable JSON config loaded by a new
`GameConfig` autoload, and add a headless battle simulator that plays full
battles with a scripted player-side bot and logs per-battle outcomes
(damage, kills, locations cleared, gold) as JSON lines — the two pieces of
prep work named in [`../config-and-automation.md`](../config-and-automation.md).

**Architecture:** `GameConfig` is a third autoload, registered *before*
`GameManager`/`GameSession` in `project.godot`, that loads
`config/game_config.json` once at construction and exposes typed
`get_int`/`get_float` accessors with a built-in `DEFAULTS` fallback so a
missing or malformed file never crashes the game. `GameSession`'s balance
constants become instance `var`s (still declared in `UPPER_SNAKE_CASE` to
keep every existing `GameSession.SOME_CONSTANT` call site working
unchanged) that are populated from `GameConfig` in a new `_ready()`. Neither
`GameManager` nor `GameSession` change ownership of anything — see
[`docs/dev/code-map.md`](../../dev/code-map.md) for why that split is load-
bearing. Automation reuses `GameSession`/`GameManager`'s existing public
API end to end (the same one the debug menu and UI already call) rather
than reaching around it: a new `BattleBot` (`scripts/tools/battle_bot.gd`,
shaped exactly like the existing `DebugScenarios` — `class_name`,
`RefCounted`, static funcs) picks player actions by mirroring
`BattleController._take_enemy_unit_actions()`'s own "move toward nearest
living opponent, attack if adjacent" policy; a `battle_sim.gd`/
`battle_sim_main.gd` pair (mirroring the existing
`screenshot_tour.gd`/`screenshot_tour_main.gd` split) drives real
`battlefield.tscn` instances headlessly, run via `make simulate`.

**Tech Stack:** Godot 4.7.1, GDScript, GUT 9.7.1, plain-text JSON (no new
dependency) for config, JSON Lines (one `JSON.stringify()`ed dict per line)
for the simulator's log file.

## Global constraints

- Godot **4.7.1** (stable) on `PATH`, run from the repo root — see
  [`docs/dev/README.md`](../../dev/README.md#repository-wide-prerequisites).
- Work on a plain branch off `main`; **do not** create a git worktree (see
  [`AGENTS.md`](../../../AGENTS.md)).
- Every behavior change is driven by a failing GUT test first (`godot
  --headless -s addons/gut/gut_cmdln.gd -gselect=<file> -gexit`), made to
  pass with the smallest change, per [`docs/dev/testing.md`](../../dev/testing.md).
- No new Godot addons/GDExtensions (rules out SQLite; JSON Lines log files
  only) and no new config file format beyond plain JSON.
- Every constant this plan migrates keeps its exact current default value —
  this is infrastructure prep, not a balance change. If a screenshot or
  manual-play value looks different after a task, that is a bug in the
  task, not an intentional change.

## Design decisions

These were not specified in the one-paragraph source spec and were settled
before writing tasks (see conversation that produced this plan):

1. **Config storage:** a single `config/game_config.json` file loaded at
   boot by `GameConfig`, not a Godot `Resource`/`.tres` and not scattered
   `user://` overrides. Plain JSON is the easiest to hand-edit and diff,
   and this plan doesn't yet need runtime-editable or per-save overrides —
   difficulty presets (e.g. swappable `config/hard.json`) are a natural
   follow-up once this lands, not part of this plan.
2. **Config scope (first slice):** only the sixteen numbers in
   `GameSession` that are genuinely tunable balance/difficulty values —
   combat formula inputs, level-up growth, Guild Hall caps/cost, and
   population caps/timers (see Task 2's full list). IDs (`GOBLIN_CAMP_ID`,
   `WARRIOR_ID`, `BONUS_MOVE_PERK_ID`, ...), the `EXPEDITIONS`/
   `STAR_ENEMY_COMPOSITIONS`/`RECRUITMENT_CANDIDATE_TEMPLATES` content
   tables, and grid dimensions stay as code constants — they're content
   and structure, not difficulty knobs, and moving them would multiply
   this plan's size for no stated benefit.
3. **Automation driver:** a scripted bot that plays real, full battles
   through `BattleController`'s public action API (not a full
   deploy/travel/recruit campaign loop, and not just replaying the
   existing debug scenarios). This is bounded to the battle itself — where
   essentially all of this game's balance-relevant randomness (hit rolls,
   enemy composition rolls) lives — while still being small enough to
   build and verify in this plan.
4. **Log destination:** JSON Lines (`user://battle_sim.jsonl` by default,
   one `JSON.stringify()`ed object per battle), not SQLite. Godot has no
   built-in SQLite support; a JSONL file needs no new dependency, is
   trivial to append to from GDScript, and is easy to `grep`/load into
   pandas or a real database later if this ever needs proper querying.

## Scope and sequencing

Deliver the tasks in order — Task 2 depends on Task 1's `GameConfig`; Task 4
depends on Task 3's `BattleBot`; Task 5 depends on everything before it:

1. [01-game-config-autoload.md](01-game-config-autoload.md) — the
   `GameConfig` autoload: JSON loading, `DEFAULTS` fallback, typed getters.
2. [02-migrate-balance-constants-to-config.md](02-migrate-balance-constants-to-config.md)
   — move `GameSession`'s sixteen balance constants onto `GameConfig`.
3. [03-battle-bot-decision-logic.md](03-battle-bot-decision-logic.md) — the
   headless-testable `BattleBot` player-turn policy.
4. [04-headless-battle-sim-and-logging.md](04-headless-battle-sim-and-logging.md)
   — `make simulate`: play N full battles headlessly, log JSONL outcomes.
5. [05-integration-and-docs.md](05-integration-and-docs.md) — regression
   sweep, `docs/dev/` updates, manual verification, merge to `main`.

## Shared delivery protocol

1. Work on a regular branch off current `main` (e.g. `config-and-automation`);
   do not create a worktree.
2. For every behavior change: add the named GUT test, run it and confirm the
   expected failure, implement the smallest code path, rerun it green.
   Tasks 2 and 4 include one step each that is a **refactor**, not new
   behavior — see those tasks' own notes on why their "red" step looks like
   a compile-time reference error instead of a failing assertion.
3. Commit at the end of each completed task (see each task's own `git add`
   list — never a bare `git add -A`).
4. Run `make check` after every task; do not start the next task on a red
   suite.
5. Do not merge until the user signs off on Task 5's manual verification.
   Then merge locally into `main`, delete the branch, and do not push unless
   asked.

## Definition of done

- `config/game_config.json` exists, `GameConfig` loads it, and every one of
  the sixteen constants listed in Task 2 reads its value from `GameConfig`
  instead of being a hardcoded literal — with identical default behavior to
  before this plan (same Attack/Health/Guild-Hall-cost/vacancy-timer values
  in a fresh campaign).
- A malformed or missing `config/game_config.json` does not crash the game;
  it falls back to `GameConfig.DEFAULTS` and logs a `push_error`.
- `make simulate` (alias for `godot --headless -s
  scripts/tools/battle_sim_main.gd`) plays `--runs=N` full battles against
  both the Goblin Camp and Orc Outpost encounters with no human input,
  correctly resolving battles that trigger a mid-battle level-up (Orc
  Outpost's kill+clear XP crosses the level-2 threshold), and appends one
  JSON line per battle — `encounter_id`, `outcome`, `cleared`, `rounds`,
  `damage_dealt`, `kills`, `gold_earned` — to a log file.
- `make check` passes, and `make play` shows unchanged Attack/Health/gold
  values in a fresh campaign (proving the config migration didn't shift any
  balance number).
