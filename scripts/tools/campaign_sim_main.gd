extends SceneTree
## Entry point for `make campaign-sim` / `make campaign-sim-sweep`, run via
## `godot -s`. In representative mode (the default -- no seed-related args,
## or an explicit `--seeds=`), runs CampaignSim.run_campaign() once per seed
## in an explicit, named list. In sweep mode (`--seed=`/`--runs=`), runs a
## contiguous numeric sweep seed, seed+1, ..., seed+N-1 -- an arbitrary
## sample, not evidence of universal completability; see resolve_options()
## and campaign_sim_metrics.gd's mode-aware labeling. Aggregates telemetry
## (CampaignSimMetrics.aggregate()) and writes a JSON report alongside a
## printed summary -- the same "one line per run, then a done/summary line"
## convention scripts/tools/battle_sim_main.gd already establishes for
## `make simulate`.

const CAMPAIGN_SIM_SCRIPT := "res://scripts/tools/campaign_sim.gd"
const CAMPAIGN_SIM_METRICS_SCRIPT := "res://scripts/tools/campaign_sim_metrics.gd"

# Compile-time preload (not the load()-by-path CAMPAIGN_SIM_METRICS_SCRIPT
# string _run() uses) is safe here specifically because campaign_sim_
# metrics.gd never references an autoload -- unlike campaign_sim.gd, whose
# own top-level preload _run()'s comment explains would fail to compile
# before autoloads (GameConfig, GameManager, GameSession) are registered.
# MODE_REPRESENTATIVE/MODE_SWEEP are owned by campaign_sim_metrics.gd (see
# its own header comment); referenced here rather than re-declared so the
# two files can never drift on what the mode strings are.
const CampaignSimMetricsScript := preload("res://scripts/tools/campaign_sim_metrics.gd")
const MODE_REPRESENTATIVE := CampaignSimMetricsScript.MODE_REPRESENTATIVE
const MODE_SWEEP := CampaignSimMetricsScript.MODE_SWEEP

const DEFAULT_SEED := 42
const DEFAULT_RUNS := 10
const DEFAULT_REPORT_PATH := "user://campaign_sim_report.json"
const SEED_ARG_PREFIX := "--seed="
const RUNS_ARG_PREFIX := "--runs="
const SEEDS_ARG_PREFIX := "--seeds="
const REPORT_ARG_PREFIX := "--report="


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	# load(), not preload(): preloading would compile campaign_sim.gd while
	# this bootstrap script itself is still being compiled, before autoloads
	# (GameConfig, GameManager, GameSession) are registered, so its
	# references to them would fail to resolve -- see battle_sim_main.gd's
	# own comment for the same reasoning. resolve_options() takes the
	# representative seed list as an explicit parameter for the same reason,
	# so it stays free of any top-level preload of campaign_sim.gd and
	# remains callable directly (with a caller-supplied list) from tests.
	var sim_script: GDScript = load(CAMPAIGN_SIM_SCRIPT)
	var metrics_script: GDScript = load(CAMPAIGN_SIM_METRICS_SCRIPT)

	var resolved := resolve_options(OS.get_cmdline_user_args(), sim_script.REPRESENTATIVE_VICTORY_SEEDS)
	if not resolved.ok:
		# resolved.error is a Dictionary ({code, message} for a rejected
		# mixed-mode call, {code, argument} for an invalid argument) -- print
		# its message/argument text, not the raw Dictionary (which would
		# stringify as `{ "code": ..., "message": ... }`, contradicting the
		# bare-message symptom docs/dev/running-the-game.md documents).
		var error: Dictionary = resolved.error
		push_error("[campaign_sim] %s" % str(error.get("message", error.get("argument", error))))
		quit(1)
		return

	var mode: String = resolved.mode
	var seeds: Array = resolved.seeds
	var report_path: String = resolved.report_path

	var records: Array = []
	for index in seeds.size():
		var seed: int = int(seeds[index])
		var sim = sim_script.new()
		var record: Dictionary = sim.run_campaign(seed)
		records.append(record)
		print(
			"[campaign_sim] %d/%d seed=%d -> %s (world_turns=%d, battles=%d/%d won, wipes=%d)"
			% [
				index + 1, seeds.size(), record.seed, record.reason,
				record.world_turns, record.battles_won, record.battles_fought, record.party_wipes,
			]
		)

	var report: Dictionary = metrics_script.aggregate(records, mode, seeds)
	print(metrics_script.format_summary(report))

	var report_file := FileAccess.open(report_path, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(metrics_script.to_json(report))
		report_file.close()
		print("[campaign_sim] done: %d campaigns logged, report written to %s" % [seeds.size(), report_path])
	else:
		push_error("[campaign_sim] could not open report file: %s" % report_path)
		print("[campaign_sim] done: %d campaigns logged (report write failed)" % seeds.size())

	quit()


## Parses `OS.get_cmdline_user_args()`-style args into
## `{ok, mode, seeds, report_path}` on success or `{ok: false, error}` on
## failure. `representative_seeds` is the caller-supplied
## CampaignSim.REPRESENTATIVE_VICTORY_SEEDS list -- see _run()'s comment for
## why this function takes it as a parameter instead of preloading
## campaign_sim.gd itself.
##
## Representative mode (default; no seed-related arg, or `--seeds=a,b,c`) is
## an explicit, named seed list. Sweep mode (`--seed=`/`--runs=`, either or
## both) is a contiguous numeric sample starting at `--seed=` (default 42)
## for `--runs=` runs (default 10). The two modes cannot be mixed: supplying
## `--seeds=` together with `--seed=` or `--runs=` is an error, not a
## silent pick of one over the other.
static func resolve_options(args: Array, representative_seeds: Array) -> Dictionary:
	var seeds_raw = null
	var seed_raw = null
	var runs_raw = null
	var report_path := DEFAULT_REPORT_PATH

	for argument in args:
		var arg := String(argument)
		if arg.begins_with(SEEDS_ARG_PREFIX):
			seeds_raw = arg.substr(SEEDS_ARG_PREFIX.length())
		elif arg.begins_with(SEED_ARG_PREFIX):
			seed_raw = arg.substr(SEED_ARG_PREFIX.length())
		elif arg.begins_with(RUNS_ARG_PREFIX):
			runs_raw = arg.substr(RUNS_ARG_PREFIX.length())
		elif arg.begins_with(REPORT_ARG_PREFIX):
			report_path = arg.substr(REPORT_ARG_PREFIX.length())
		else:
			return {"ok": false, "error": {"code": "invalid_argument", "argument": arg}}

	var sweep_requested: bool = seed_raw != null or runs_raw != null
	if seeds_raw != null and sweep_requested:
		return {
			"ok": false,
			"error": {
				"code": "mixed_modes",
				"message": "--seeds= cannot be combined with --seed=/--runs= -- pick representative or sweep mode, not both",
			},
		}

	if sweep_requested:
		if seed_raw != null and not String(seed_raw).is_valid_int():
			return {"ok": false, "error": {"code": "invalid_argument", "argument": SEED_ARG_PREFIX + String(seed_raw)}}
		if runs_raw != null and not String(runs_raw).is_valid_int():
			return {"ok": false, "error": {"code": "invalid_argument", "argument": RUNS_ARG_PREFIX + String(runs_raw)}}
		var seed: int = int(seed_raw) if seed_raw != null else DEFAULT_SEED
		var runs: int = int(runs_raw) if runs_raw != null else DEFAULT_RUNS
		if runs <= 0:
			return {"ok": false, "error": {"code": "invalid_argument", "argument": RUNS_ARG_PREFIX + String(runs_raw)}}
		var swept_seeds: Array = []
		for offset in runs:
			swept_seeds.append(seed + offset)
		return {"ok": true, "mode": MODE_SWEEP, "seeds": swept_seeds, "report_path": report_path}

	if seeds_raw != null:
		var parsed := _parse_seeds_list(String(seeds_raw))
		if not parsed.ok:
			return parsed
		return {"ok": true, "mode": MODE_REPRESENTATIVE, "seeds": parsed.seeds, "report_path": report_path}

	return {"ok": true, "mode": MODE_REPRESENTATIVE, "seeds": representative_seeds, "report_path": report_path}


## Parses a `--seeds=` value ("4,9,10,12,14") into an Array[int]. Rejects an
## empty list and any non-integer or non-positive entry.
static func _parse_seeds_list(raw: String) -> Dictionary:
	if raw.is_empty():
		return {"ok": false, "error": {"code": "invalid_argument", "argument": SEEDS_ARG_PREFIX + raw}}
	var seeds: Array = []
	for part in raw.split(",", false):
		if not part.is_valid_int():
			return {"ok": false, "error": {"code": "invalid_argument", "argument": SEEDS_ARG_PREFIX + raw}}
		var value := int(part)
		if value <= 0:
			return {"ok": false, "error": {"code": "invalid_argument", "argument": SEEDS_ARG_PREFIX + raw}}
		seeds.append(value)
	if seeds.is_empty():
		return {"ok": false, "error": {"code": "invalid_argument", "argument": SEEDS_ARG_PREFIX + raw}}
	return {"ok": true, "seeds": seeds}
