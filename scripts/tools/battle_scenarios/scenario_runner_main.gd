extends SceneTree

const ReportAggregator := preload("res://scripts/tools/battle_scenarios/report_aggregator.gd")
const SCENARIO_EXPANDER_PATH := "res://scripts/tools/battle_scenarios/scenario_expander.gd"
const SCENARIO_RUNNER_PATH := "res://scripts/tools/battle_scenarios/scenario_runner.gd"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# This entry script runs with `godot -s`, before autoload globals are
	# registered at compile time. Load the GameSession-using battle scripts
	# only after one frame, mirroring battle_sim_main.gd.
	await process_frame
	var parsed := parse_args(OS.get_cmdline_user_args())
	if not parsed.ok:
		push_error("[scenario_runner] %s" % parsed.error)
		quit(1)
		return
	var options: Dictionary = parsed.options
	var text := FileAccess.get_file_as_string(options.scenario)
	var raw = JSON.parse_string(text)
	if not raw is Dictionary:
		push_error("[scenario_runner] scenario_parse_failed")
		quit(1)
		return
	raw.randomness = raw.get("randomness", {})
	raw.randomness.root_seed = options.seed
	raw.randomness.iterations = options.iterations
	var scenario_expander = load(SCENARIO_EXPANDER_PATH)
	var scenario_runner = load(SCENARIO_RUNNER_PATH)
	var records: Array = []
	for case in scenario_expander.expand(raw):
		records.append_array(scenario_runner.new().run_case(case))
	var output_dir: String = options.output_dir
	if output_dir.is_empty():
		output_dir = "user://battle-scenarios/%d-%d" % [Time.get_unix_time_from_system(), options.seed]
	DirAccess.make_dir_recursive_absolute(output_dir)
	var records_path := output_dir.path_join("records.jsonl")
	var written: Dictionary = scenario_runner.new().write_records(records_path, records)
	if not written.ok:
		push_error("[scenario_runner] %s" % written.error)
		quit(1)
		return
	var fingerprint := str(hash(FileAccess.get_file_as_string("res://config/game_config.json")))
	for record in records:
		record["config_fingerprint"] = fingerprint
	var report := ReportAggregator.aggregate(records, {"raw_records_path": records_path, "command": "scenario", "config_fingerprint": fingerprint})
	var report_file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report, "\t"))
	report_file.close()
	print("[scenario_runner] %d records in %s" % [records.size(), output_dir])
	quit()


static func parse_args(args: Array) -> Dictionary:
	var options := {"scenario": "", "seed": 0, "iterations": 1, "axis_overrides": {}, "output_dir": "", "format": "json"}
	for argument in args:
		var arg := String(argument)
		if arg.begins_with("--scenario="):
			options.scenario = arg.trim_prefix("--scenario=")
		elif arg.begins_with("--seed=") or arg.begins_with("--iterations="):
			var split := arg.split("=", false, 1)
			if not split[1].is_valid_int(): return {"ok": false, "error": {"code": "invalid_argument", "argument": arg}}
			options[split[0].trim_prefix("--")] = int(split[1])
		elif arg.begins_with("--axis="):
			var axis := arg.trim_prefix("--axis=").split("=", false, 1)
			if axis.size() != 2: return {"ok": false, "error": {"code": "invalid_argument", "argument": arg}}
			options.axis_overrides[axis[0]] = axis[1]
		elif arg.begins_with("--output-dir="):
			options.output_dir = arg.trim_prefix("--output-dir=")
		elif arg.begins_with("--format="):
			options.format = arg.trim_prefix("--format=")
			if not options.format in ["json", "table"]: return {"ok": false, "error": {"code": "invalid_argument", "argument": arg}}
		else:
			return {"ok": false, "error": {"code": "invalid_argument", "argument": arg}}
	if options.scenario.is_empty() or options.iterations <= 0:
		return {"ok": false, "error": {"code": "invalid_argument"}}
	return {"ok": true, "options": options}
