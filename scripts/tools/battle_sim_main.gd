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
