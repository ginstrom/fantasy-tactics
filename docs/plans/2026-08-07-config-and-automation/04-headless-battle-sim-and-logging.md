# Task 4: Headless battle simulator and JSONL logging

## Objective

Add `make simulate`: a headless runner that plays `--runs=N` full battles
(alternating Goblin Camp / Orc Outpost), with `BattleBot` controlling the
player side and the game's own existing enemy AI (`run_enemy_turn()`)
controlling the enemy side, and appends one JSON line per battle —
`encounter_id`, `outcome`, `cleared`, `rounds`, `damage_dealt`, `kills`,
`gold_earned` — to a log file.

## Why this needs to drive the real `battlefield.tscn`, and the level-up wrinkle

The whole point is real signal-wired battles — the same XP/gold/level-up
code paths a human playthrough exercises — not a shortcut that skips them.
That surfaces one real wrinkle worth understanding before you write this:
`Battlefield._apply_battle_outcome()` (`scripts/battle/battlefield.gd:137`)
does **not** call `GameManager.complete_battle()` immediately on victory if
the clear-XP award queued a level-up (`_pending_victory_completion = true`,
then it returns and waits for the `LevelUp` control's `resolved` signal —
see `scripts/battle/battlefield.gd:145-232`). In the real game that signal
only fires when a human clicks Continue on the level-up modal
(`scripts/ui/level_up.gd:103`), which also requires choosing a perk first
if one is pending (`GameSession.is_perk_choice_pending`).

This isn't a rare edge case for this simulator: a fresh Warrior starts at 0
XP, and the level-2 threshold is 20 XP (`GameSession.get_level_xp_threshold`
— see `docs/dev/code-map.md`'s progression formulas). Goblin Camp's total
kill+clear XP is 15 (under the threshold — no level-up), but **Orc
Outpost's is 30 (10 kill + 20 clear) — over it**, so a level-up modal *will*
appear mid-battle on essentially every simulated Orc Outpost victory. If
this task didn't handle it, every Orc Outpost run would hang waiting for
a click that never comes, until this task's own round cap silently turned
every one of them into a false "stalemate". Step 5 below auto-resolves any
level-up modal by calling the exact same GDScript methods the buttons call
(`GameSession.choose_perk(...)`, `level_up._on_continue_pressed()`) —
nothing new is invented, it's just driven programmatically instead of by a
click.

## Files

- Create: `scripts/tools/battle_sim.gd`
- Create: `scripts/tools/battle_sim_main.gd`
- Modify: `Makefile`

No new GUT test file — like the existing `screenshot_tour.gd` (which also
has none), this tool drives a real scene end to end and is verified by
running it and inspecting its output, not by a unit test. `BattleBot`'s own
decision logic is already covered in isolation by Task 3's tests; this task
is verified manually in step 4 below.

## Steps

1. Create `scripts/tools/battle_sim.gd`:

   ```gdscript
   extends Node
   ## Plays N full battles headlessly with BattleBot controlling the player
   ## side, appending one JSON line per battle outcome to a log file. See
   ## docs/plans/2026-08-07-config-and-automation/04-headless-battle-sim-and-logging.md
   ## for why this has to auto-resolve level-up modals.

   const BattlefieldScene := preload("res://scenes/battle/battlefield.tscn")
   const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")

   const ENCOUNTER_IDS := [GameSession.GOBLIN_CAMP_ID, GameSession.ORC_OUTPOST_ID]
   # Generous headroom over the handful of rounds a normal battle takes,
   # so a genuinely stuck bot (e.g. boxed in with no path to the enemy)
   # degrades to a "stalemate" result instead of hanging the whole run.
   const MAX_ROUNDS := 30
   const MAX_SETTLE_FRAMES := 60


   func run(runs: int, log_path: String) -> void:
   	var log_file := FileAccess.open(log_path, FileAccess.WRITE)
   	for run_index in runs:
   		var encounter_id: String = ENCOUNTER_IDS[run_index % ENCOUNTER_IDS.size()]
   		var result: Dictionary = await _play_one_battle(encounter_id)
   		log_file.store_line(JSON.stringify(result))
   		if result.outcome == "stalemate":
   			print("[battle_sim] %d/%d %s -> stalemate (did not resolve within %d rounds)" % [run_index + 1, runs, encounter_id, MAX_ROUNDS])
   		else:
   			print("[battle_sim] %d/%d %s -> %s" % [run_index + 1, runs, encounter_id, result.outcome])
   	log_file.close()
   	print("[battle_sim] done: %d battles logged to %s" % [runs, log_path])
   	get_tree().quit()


   func _play_one_battle(encounter_id: String) -> Dictionary:
   	DebugScenarios.apply(encounter_id)
   	GameSession.enter_encounter(encounter_id)

   	var battlefield: Node2D = BattlefieldScene.instantiate()
   	battlefield.enemy_turn_beat_seconds = 0.0
   	add_child(battlefield)
   	await process_frame

   	var damage_dealt := 0
   	var kills := 0
   	var rounds := 0

   	while GameSession.selected_encounter != "" and rounds < MAX_ROUNDS:
   		rounds += 1
   		for step in BattleBot.take_player_turn(battlefield.grid):
   			if step.get("type") == "attack":
   				damage_dealt += step.damage
   				if step.defeated:
   					kills += 1
   		await _resolve_round(battlefield)

   	var outcome := "stalemate"
   	if GameSession.selected_encounter == "":
   		outcome = "victory" if battlefield.grid.is_battle_won() else "defeat"

   	var result := {
   		"encounter_id": encounter_id,
   		"outcome": outcome,
   		"cleared": outcome == "victory",
   		"rounds": rounds,
   		"damage_dealt": damage_dealt,
   		"kills": kills,
   		"gold_earned": GameSession.pending_reward,
   	}

   	battlefield.queue_free()
   	await process_frame
   	return result


   ## Resolves any level-up modal the bot's turn just queued, ends the turn,
   ## then waits for Battlefield's own async resolution chain (end_turn ->
   ## _play_enemy_turn -> _resolve_battle -> _apply_battle_outcome, which can
   ## itself queue and show more level-ups on a victorious clear) to settle —
   ## the same fire-and-forget-coroutine pattern documented in
   ## docs/dev/testing.md, generalized to run every round instead of once.
   func _resolve_round(battlefield: Node) -> void:
   	_resolve_level_up(battlefield.level_up)
   	battlefield._on_end_turn_pressed()

   	var frames := 0
   	while frames < MAX_SETTLE_FRAMES:
   		_resolve_level_up(battlefield.level_up)
   		if battlefield.grid.active_side == BattleControllerScript.Side.PLAYER or GameSession.selected_encounter == "":
   			return
   		await process_frame
   		frames += 1


   ## Drives the level-up modal exactly the way a human would click through
   ## it: choose the only available perk if one is pending (the same
   ## ChooseBonusMoveButton handler in scripts/ui/level_up.gd calls), then
   ## Continue. Repeats for every queued level-up.
   func _resolve_level_up(level_up: Control) -> void:
   	while level_up.visible:
   		if GameSession.is_perk_choice_pending(level_up.adventurer_id):
   			GameSession.choose_perk(level_up.adventurer_id, GameSession.BONUS_MOVE_PERK_ID)
   		level_up._on_continue_pressed()
   ```

2. Create `scripts/tools/battle_sim_main.gd` — mirrors
   `scripts/tools/screenshot_tour_main.gd`'s bootstrap exactly (a
   `SceneTree` main-loop override run via `godot -s`, so the game's
   autoloads register but the configured `main_scene` never loads):

   ```gdscript
   extends SceneTree
   ## Entry point for `make simulate`, run via `godot -s`.

   const BATTLE_SIM_SCRIPT := "res://scripts/tools/battle_sim.gd"

   const DEFAULT_RUNS := 10
   const DEFAULT_LOG_PATH := "user://battle_sim.jsonl"
   const RUNS_ARG_PREFIX := "--runs="
   const LOG_ARG_PREFIX := "--log="


   func _initialize() -> void:
   	call_deferred("_run")


   func _run() -> void:
   	await process_frame

   	# load(), not preload(): preloading would compile battle_sim.gd while
   	# this bootstrap script itself is still being compiled, before autoloads
   	# (GameConfig, GameManager, GameSession) are registered, so its
   	# references to them would fail to resolve. See screenshot_tour_main.gd.
   	var sim: Node = load(BATTLE_SIM_SCRIPT).new()
   	root.add_child(sim)
   	await sim.run(_resolve_runs(), _resolve_log_path())


   func _resolve_runs() -> int:
   	for arg in OS.get_cmdline_user_args():
   		if arg.begins_with(RUNS_ARG_PREFIX):
   			return int(arg.substr(RUNS_ARG_PREFIX.length()))
   	return DEFAULT_RUNS


   func _resolve_log_path() -> String:
   	for arg in OS.get_cmdline_user_args():
   		if arg.begins_with(LOG_ARG_PREFIX):
   			return arg.substr(LOG_ARG_PREFIX.length())
   	return DEFAULT_LOG_PATH
   ```

3. Add a `simulate` target to `Makefile`, alongside the existing targets,
   and list it in `help`:

   ```makefile
   .PHONY: help editor play test check screenshots simulate

   help:
   	@echo "make editor       Open the Godot editor"
   	@echo "make play         Run the project"
   	@echo "make test         Run automated tests"
   	@echo "make check        Run the current validation suite"
   	@echo "make screenshots  Capture a screenshot of every scene/state into ./screenshots"
   	@echo "make simulate     Play N headless battles and log outcomes (RUNS=20 make simulate)"
   ```

   ```makefile
   RUNS ?= 20

   simulate:
   	godot --headless -s scripts/tools/battle_sim_main.gd -- --runs=$(RUNS)
   ```

   (`RUNS ?= 20` only sets a default — `RUNS=100 make simulate` overrides
   it. Add this `?=` line near the top of the Makefile, above the
   `.PHONY` line, not inside the `simulate` target itself.)

4. Manually verify — this task's real test, since there's no GUT coverage
   for the scene-driving parts:

   ```bash
   make simulate
   ```

   - Confirm the terminal prints one `[battle_sim] i/20 <encounter> ->
     <outcome>` line per run, ending with `[battle_sim] done: 20 battles
     logged to user://battle_sim.jsonl`.
   - Find the actual log file: `user://` resolves to Godot's per-project
     user data directory — on Linux, `find ~/.local/share/godot -name
     battle_sim.jsonl` (project name is "Fantasy Tactics", per
     `project.godot`'s `config/name`).
   - Open the log file and confirm every line parses as JSON with the
     seven expected keys, **all 10 Orc Outpost lines show `"outcome":
     "victory"` or `"outcome": "defeat"` — never `"stalemate"`** (this is
     the concrete proof the level-up auto-resolve in step 1 actually
     works, since Orc Outpost is the encounter that triggers it), and
     `damage_dealt`/`kills`/`gold_earned` are all non-negative and
     internally consistent (a `"defeat"` line has `gold_earned == 0`; a
     `"victory"` Orc Outpost line has `gold_earned == 25`, matching
     `EXPEDITIONS.orc_outpost.reward`).
   - Run it again with an override to confirm the CLI arg works:
     `RUNS=5 make simulate`, and confirm exactly 5 lines are appended.

5. Run the full suite once more — this task didn't touch anything under
   `tests/`, so it should be unaffected:

   ```bash
   make check
   ```

6. Commit:

   ```bash
   git add scripts/tools/battle_sim.gd scripts/tools/battle_sim_main.gd Makefile
   git commit -m "feat: add headless battle simulator with JSONL outcome logging"
   ```

## Milestone

`make simulate` (or `RUNS=N make simulate`) plays N full, real battles with
no human input, correctly resolving both encounters — including the
mid-battle level-up Orc Outpost always triggers — and produces a
`user://battle_sim.jsonl` log with one structured outcome line per battle.
