extends GutTest

const ScenarioRunnerMain := preload("res://scripts/tools/battle_scenarios/scenario_runner_main.gd")


func test_parse_args_accepts_the_documented_runner_options() -> void:
	var result := ScenarioRunnerMain.parse_args([
		"--scenario=scenarios/battle/baseline-party-viability.json", "--seed=7", "--iterations=3",
		"--axis=monster=orc", "--output-dir=/tmp/out", "--format=table",
	])

	assert_true(result.ok)
	assert_eq(result.options.seed, 7)
	assert_eq(result.options.iterations, 3)
	assert_eq(result.options.axis_overrides, {"monster": "orc"})
	assert_eq(result.options.format, "table")


func test_parse_args_rejects_malformed_values_before_creating_output() -> void:
	var result := ScenarioRunnerMain.parse_args(["--seed=nope"])

	assert_false(result.ok)
	assert_eq(result.error.code, "invalid_argument")
