extends GutTest
## Covers scripts/tools/campaign_sim_main.gd's argument-resolution logic --
## the `make campaign-sim` / `make campaign-sim-sweep` CLI entry point (see
## docs/plans/2026-08-19-core-loop-verification-remediation/
## 02-representative-seed-command.md). Exercises resolve_options() directly,
## the same "call the static parsing function without running the SceneTree
## entry point" pattern test_scenario_runner_main.gd already establishes for
## scenario_runner_main.gd's parse_args().
##
## resolve_options() takes the representative seed list as an explicit
## parameter rather than preloading campaign_sim.gd itself, matching this
## script's own existing load()-not-preload() discipline in _run() (see that
## function's comment: preloading an autoload-touching script at this
## bootstrap script's own top level would fail to compile under `godot -s`,
## before autoloads are registered). Tests below pass CampaignSim.
## REPRESENTATIVE_VICTORY_SEEDS explicitly for the same reason -- so this
## suite consumes the single production-owned constant rather than a copy.

const CampaignSimMainScript := preload("res://scripts/tools/campaign_sim_main.gd")
const CampaignSimScript := preload("res://scripts/tools/campaign_sim.gd")


func before_each() -> void:
	GameSession.reset()
	GameSession.reset_injectable_rolls()


## --- Task 1: representative seed list is the default, single source of truth ---

func test_resolve_options_with_no_seed_args_defaults_to_the_representative_list() -> void:
	var result := CampaignSimMainScript.resolve_options([], CampaignSimScript.REPRESENTATIVE_VICTORY_SEEDS)

	assert_true(result.ok)
	assert_eq(result.mode, "representative")
	assert_eq(result.seeds, CampaignSimScript.REPRESENTATIVE_VICTORY_SEEDS)


func test_resolve_options_accepts_an_explicit_seeds_list() -> void:
	var result := CampaignSimMainScript.resolve_options(["--seeds=4,9,10,12,14"], CampaignSimScript.REPRESENTATIVE_VICTORY_SEEDS)

	assert_true(result.ok)
	assert_eq(result.mode, "representative")
	assert_eq(result.seeds, [4, 9, 10, 12, 14])


func test_resolve_options_rejects_an_empty_seeds_list() -> void:
	var result := CampaignSimMainScript.resolve_options(["--seeds="], CampaignSimScript.REPRESENTATIVE_VICTORY_SEEDS)

	assert_false(result.ok)
	assert_eq(result.error.code, "invalid_argument")


func test_resolve_options_rejects_a_non_positive_seed_in_the_seeds_list() -> void:
	var result := CampaignSimMainScript.resolve_options(["--seeds=4,0,10"], CampaignSimScript.REPRESENTATIVE_VICTORY_SEEDS)

	assert_false(result.ok)
	assert_eq(result.error.code, "invalid_argument")


func test_resolve_options_rejects_a_non_integer_seed_in_the_seeds_list() -> void:
	var result := CampaignSimMainScript.resolve_options(["--seeds=4,nope,10"], CampaignSimScript.REPRESENTATIVE_VICTORY_SEEDS)

	assert_false(result.ok)
	assert_eq(result.error.code, "invalid_argument")


func test_resolve_options_with_seed_and_runs_produces_an_explicit_sweep() -> void:
	var result := CampaignSimMainScript.resolve_options(["--seed=1", "--runs=10"], CampaignSimScript.REPRESENTATIVE_VICTORY_SEEDS)

	assert_true(result.ok)
	assert_eq(result.mode, "sweep")
	assert_eq(result.seeds, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])


func test_resolve_options_sweep_mode_alone_uses_documented_defaults() -> void:
	var result := CampaignSimMainScript.resolve_options([], CampaignSimScript.REPRESENTATIVE_VICTORY_SEEDS)

	# Sanity: absent any args at all, mode is representative, not a
	# --seed=42 --runs=10 sweep -- see the "no args at all" test above. This
	# test instead checks the sweep-only-when-requested branch keeps its own
	# documented defaults (seed 42, 10 runs) when only one of --seed=/--runs=
	# is supplied explicitly.
	assert_eq(result.mode, "representative")

	var seed_only := CampaignSimMainScript.resolve_options(["--seed=5"], CampaignSimScript.REPRESENTATIVE_VICTORY_SEEDS)
	assert_true(seed_only.ok)
	assert_eq(seed_only.mode, "sweep")
	assert_eq(seed_only.seeds.size(), 10)
	assert_eq(seed_only.seeds[0], 5)

	var runs_only := CampaignSimMainScript.resolve_options(["--runs=3"], CampaignSimScript.REPRESENTATIVE_VICTORY_SEEDS)
	assert_true(runs_only.ok)
	assert_eq(runs_only.mode, "sweep")
	assert_eq(runs_only.seeds, [42, 43, 44])


func test_resolve_options_rejects_mixing_seeds_with_seed() -> void:
	var result := CampaignSimMainScript.resolve_options(["--seeds=4,9", "--seed=1"], CampaignSimScript.REPRESENTATIVE_VICTORY_SEEDS)

	assert_false(result.ok)
	assert_eq(result.error.code, "mixed_modes")


func test_resolve_options_rejects_mixing_seeds_with_runs() -> void:
	var result := CampaignSimMainScript.resolve_options(["--seeds=4,9", "--runs=3"], CampaignSimScript.REPRESENTATIVE_VICTORY_SEEDS)

	assert_false(result.ok)
	assert_eq(result.error.code, "mixed_modes")


func test_resolve_options_rejects_an_unknown_argument() -> void:
	var result := CampaignSimMainScript.resolve_options(["--bogus=1"], CampaignSimScript.REPRESENTATIVE_VICTORY_SEEDS)

	assert_false(result.ok)
	assert_eq(result.error.code, "invalid_argument")


func test_resolve_options_still_honors_report_path() -> void:
	var result := CampaignSimMainScript.resolve_options(["--report=user://custom.json"], CampaignSimScript.REPRESENTATIVE_VICTORY_SEEDS)

	assert_true(result.ok)
	assert_eq(result.report_path, "user://custom.json")
