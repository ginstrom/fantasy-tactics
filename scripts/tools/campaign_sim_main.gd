extends SceneTree
## Entry point for `make campaign-sim`, run via `godot -s`. Runs N full,
## deterministic headless campaigns (CampaignSim.run_campaign()) seeded
## seed, seed+1, ..., seed+N-1, aggregates their telemetry
## (CampaignSimMetrics.aggregate()), and writes a JSON report alongside a
## printed summary -- the same "one line per run, then a done/summary line"
## convention scripts/tools/battle_sim_main.gd already establishes for
## `make simulate`.

const CAMPAIGN_SIM_SCRIPT := "res://scripts/tools/campaign_sim.gd"
const CAMPAIGN_SIM_METRICS_SCRIPT := "res://scripts/tools/campaign_sim_metrics.gd"

const DEFAULT_SEED := 42
const DEFAULT_RUNS := 10
const DEFAULT_REPORT_PATH := "user://campaign_sim_report.json"
const SEED_ARG_PREFIX := "--seed="
const RUNS_ARG_PREFIX := "--runs="
const REPORT_ARG_PREFIX := "--report="


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	# load(), not preload(): preloading would compile campaign_sim.gd while
	# this bootstrap script itself is still being compiled, before autoloads
	# (GameConfig, GameManager, GameSession) are registered, so its
	# references to them would fail to resolve -- see battle_sim_main.gd's
	# own comment for the same reasoning.
	var sim_script: GDScript = load(CAMPAIGN_SIM_SCRIPT)
	var metrics_script: GDScript = load(CAMPAIGN_SIM_METRICS_SCRIPT)

	var seed := _resolve_int_arg(SEED_ARG_PREFIX, DEFAULT_SEED)
	var runs := _resolve_int_arg(RUNS_ARG_PREFIX, DEFAULT_RUNS)
	var report_path := _resolve_report_path()

	var records: Array = []
	for run_index in runs:
		var sim = sim_script.new()
		var record: Dictionary = sim.run_campaign(seed + run_index)
		records.append(record)
		print(
			"[campaign_sim] %d/%d seed=%d -> %s (world_turns=%d, battles=%d/%d won, wipes=%d)"
			% [
				run_index + 1, runs, record.seed, record.reason,
				record.world_turns, record.battles_won, record.battles_fought, record.party_wipes,
			]
		)

	var report: Dictionary = metrics_script.aggregate(records)
	print(metrics_script.format_summary(report))

	var report_file := FileAccess.open(report_path, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(metrics_script.to_json(report))
		report_file.close()
		print("[campaign_sim] done: %d campaigns logged, report written to %s" % [runs, report_path])
	else:
		push_error("[campaign_sim] could not open report file: %s" % report_path)
		print("[campaign_sim] done: %d campaigns logged (report write failed)" % runs)

	quit()


func _resolve_int_arg(prefix: String, default_value: int) -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return int(arg.substr(prefix.length()))
	return default_value


func _resolve_report_path() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(REPORT_ARG_PREFIX):
			return arg.substr(REPORT_ARG_PREFIX.length())
	return DEFAULT_REPORT_PATH
