# Task 5: Regression sweep, docs, and merge

## Objective

Confirm the whole branch is coherent, document the new autoload and tool
for future readers, get manual sign-off, and merge to `main`.

## Files

- Modify: `docs/dev/code-map.md`
- Modify: `docs/dev/running-the-game.md`
- Modify: `docs/dev/README.md`

## Steps

1. In `docs/dev/code-map.md`, add a new section right after "The two
   autoloads own everything" (keep that section's own title and table as-is
   — `GameManager`/`GameSession` are still the only two that own durable
   state; `GameConfig` is a read-only settings source, not a third state
   owner):

   ```markdown
   ## Configuration: `GameConfig` is read-only and loads once

   A third autoload, `GameConfig` (`scripts/autoload/game_config.gd`),
   loads `config/game_config.json` once at startup and exposes typed
   `get_int(section, key, default)`/`get_float(section, key, default)`
   accessors. It owns no gameplay state and is never mutated at runtime.
   `GameSession` reads sixteen balance constants from it in its own
   `_ready()` (combat formula inputs, level-up growth, Guild Hall
   caps/cost, population caps/timers — see
   `docs/plans/2026-08-07-config-and-automation/02-migrate-balance-constants-to-config.md`
   for the exact list and why those sixteen and not others). Every other
   `GameSession` constant (ids, the `EXPEDITIONS`/`STAR_ENEMY_COMPOSITIONS`
   content tables, grid dimensions) is still a plain code constant — only
   genuinely tunable difficulty/balance numbers moved. `GameConfig` is
   declared first in `project.godot`'s `[autoload]` list, before
   `GameManager`/`GameSession`, specifically so it's fully constructed
   before `GameSession._ready()` reads from it.

   A missing or malformed `config/game_config.json` never crashes the
   game — `GameConfig` falls back to its own built-in `DEFAULTS` (which
   mirrors the shipped file exactly) and logs a `push_error`.
   ```

2. In `docs/dev/code-map.md`, add a short section near the bottom (after
   "Localization" is fine) documenting the simulator, since it's a
   non-obvious way to exercise real battles without a human:

   ```markdown
   ## Headless battle simulation

   `scripts/tools/battle_bot.gd` (`BattleBot`) and
   `scripts/tools/battle_sim.gd`/`battle_sim_main.gd` play full, real
   battles with no human input — `BattleBot` picks player actions with the
   same "move toward nearest living opponent, attack if adjacent" policy
   `BattleController._take_enemy_unit_actions()` already uses for the enemy
   side, and `battle_sim.gd` drives a real `battlefield.tscn` instance
   through to `GameManager.complete_battle()`/`fail_battle()`, including
   auto-resolving any level-up modal a battle's XP award queues (see
   `docs/plans/2026-08-07-config-and-automation/04-headless-battle-sim-and-logging.md`
   for why that's necessary — Orc Outpost's kill+clear XP always crosses
   the level-2 threshold). Run via `make simulate`; see
   [running-the-game.md](running-the-game.md#run-the-headless-battle-simulator).
   This exists for balance/AI-tuning data (damage/kills/gold per battle),
   not for testing — `tests/unit/test_battle_bot.gd` already covers
   `BattleBot`'s decision logic in isolation without needing a real battle.
   ```

3. In `docs/dev/running-the-game.md`, add a new top-level section (after
   "Capture a screenshot of every known scene/state", before "Open the
   project in the editor"), matching this doc's existing
   Steps/Verification/Troubleshooting structure:

   ```markdown
   ## Run the headless battle simulator

   Plays N full battles with no human input — `BattleBot` controls the
   player side, the game's existing enemy AI controls the enemy side — and
   logs one JSON line per battle outcome. Useful for balance/AI-tuning data
   (damage dealt, kills, gold earned, win rate per encounter), not for
   correctness testing (see [testing.md](testing.md) for that).

   ### Steps

   1. From the repository root, run:
      ```
      make simulate
      ```
      This plays 20 battles by default (10 Goblin Camp, 10 Orc Outpost,
      alternating) and appends results to `user://battle_sim.jsonl`.
   2. Override the run count with `RUNS=N make simulate`.

   ### Verification

   - The terminal prints one `[battle_sim] i/N <encounter_id> -> <outcome>`
     line per battle, ending with `[battle_sim] done: N battles logged to
     user://battle_sim.jsonl`.
   - `user://` resolves to Godot's per-project user data directory — on
     Linux, `find ~/.local/share/godot -name battle_sim.jsonl`. Each line
     parses as JSON with keys `encounter_id`, `outcome` (`"victory"` /
     `"defeat"` / `"stalemate"`), `cleared`, `rounds`, `damage_dealt`,
     `kills`, `gold_earned`.

   ### Troubleshooting

   | Symptom | Cause | Fix |
   |---|---|---|
   | A line's `outcome` is `"stalemate"` | The bot couldn't reach or defeat every enemy within the round cap | Rare for the two shipped encounters under normal balance values; if it happens consistently after a balance change (`config/game_config.json`), the change likely made a fight unwinnable by the greedy bot policy — not necessarily a bug, but worth a second look |
   ```

4. In `docs/dev/README.md`'s task table, add a row for the simulator:

   ```markdown
   | Play N headless battles and log balance/outcome data | [running-the-game.md](running-the-game.md#run-the-headless-battle-simulator) |
   ```

5. Run the full regression sweep:

   ```bash
   make check
   godot --headless --path . --editor --quit
   git diff --check
   ```

   The middle command opens and closes the editor headlessly, which forces
   Godot to parse/import every resource in the project (including the new
   `config/game_config.json` and the two new `scripts/tools/*.gd` files) —
   a broader compile check than `make check` alone. `git diff --check`
   catches stray whitespace. All three must be clean before manual
   verification.

6. Manual verification (do not merge until the user signs off on this
   step):

   - `make play` → New Campaign → confirm the Warrior's Attack/Health and
     the Guild Hall's upgrade cost match the pre-existing screenshots
     (`./screenshots/`), proving Task 2's migration changed no balance
     number.
   - `make simulate` → confirm the log file and terminal output described
     in Task 4, including at least one Orc Outpost `"victory"` line (proof
     the level-up auto-resolve works, not just that the code compiles).
   - `make screenshots` (optional but cheap) → confirm no scene crashed as
     a side effect of the new autoload.

7. Commit the docs:

   ```bash
   git add docs/dev/code-map.md docs/dev/running-the-game.md docs/dev/README.md
   git commit -m "docs: document GameConfig and the headless battle simulator"
   ```

8. Once the user signs off on step 6, merge locally and clean up (per
   `AGENTS.md` — do not push unless separately asked):

   ```bash
   git checkout main
   git pull
   git merge config-and-automation
   git branch -d config-and-automation
   ```

## Milestone

`main` has a working `GameConfig`-backed balance system and a headless
battle simulator, both documented in `docs/dev/`, with a full green
regression sweep and explicit manual sign-off behind the merge.
