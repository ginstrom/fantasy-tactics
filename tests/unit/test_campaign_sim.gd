extends GutTest
## Covers scripts/tools/campaign_sim.gd (CampaignSim) and scripts/tools/
## campaign_sim_metrics.gd (CampaignSimMetrics) -- the headless, scene-free
## campaign-level simulator and its telemetry aggregator (docs/plans/
## 2026-08-18-core-loop-and-engagement/06-campaign-simulation-and-balance-
## harness.md).

const CampaignSimScript := preload("res://scripts/tools/campaign_sim.gd")
const CampaignSimMetricsScript := preload("res://scripts/tools/campaign_sim_metrics.gd")

## The representative seed set CampaignSim's own bot/gear/upgrade policy is
## verified (below) to carry all the way to Final Boss victory. Per the step
## doc's own task-list wording ("reach victory on an explicitly listed
## representative seed set ... report failures for every other seed; do not
## claim a universal completion percentage from ten arbitrary samples"), this
## is a deliberately small, hand-verified set -- not a claim that every seed
## outside it fails, only that these are the ones this suite locks a victory
## guarantee to.
##
## A wider sweep (seeds 1-40, run manually while building this suite; see
## this step's report for the full table) shows the campaign is completable
## but not on every seed: a bit under two-thirds of that range wins cleanly
## in exactly 51 world turns with zero party wipes, and the rest fall into a
## repeated-wipe spiral around objective 10-11 (a genuine balance finding
## for a later tuning pass, not a bug in the simulator itself -- see the
## step report's "Design decisions" section). Seeds 1, 2, 4, 5, and 7 are
## the first five of that winning majority, chosen in ascending order rather
## than cherry-picked for any other property.
const REPRESENTATIVE_VICTORY_SEEDS: Array[int] = [1, 2, 4, 5, 7]


func before_each() -> void:
	GameSession.reset()
	GameSession.reset_injectable_rolls()


## --- Task 1: execution engine ----------------------------------------------

func test_run_campaign_initializes_a_fresh_session_and_advances_through_objectives() -> void:
	var sim := CampaignSimScript.new()

	var record := sim.run_campaign(42)

	assert_gt(GameSession.world_turn, 1, "A campaign run must advance world turns from the fresh-session default of 1")
	assert_true(
		GameSession.completed_objectives.size() > 0 or GameSession.is_campaign_completed,
		"At least one campaign objective must be completed by the time run_campaign() returns"
	)
	assert_eq(record.seed, 42)


func test_run_campaign_handles_recruitment_movement_combat_and_returns_to_encampment() -> void:
	var sim := CampaignSimScript.new()

	sim.run_campaign(42)

	# Recruitment: the roster grew past the four starting Warriors (matches
	# is_campaign_guide_first_improvement_made's own "more than the starting
	# roster" convention -- see code-map.md).
	assert_gt(GameSession.adventurers.size(), GameSession.STARTING_ROSTER_SIZE, "The simulator must recruit beyond the starting roster")
	# Combat: at least one battle was actually fought and resolved.
	assert_gt(GameSession.completed_encounters.size(), 0, "At least one encounter must be cleared")
	# Returns to Encampment between attempts: the party is not left deployed
	# out on the World Map once run_campaign() returns control.
	assert_false(GameSession.has_deployed_party(), "The party must be back at the Encampment (undeployed) once the run loop yields control")


## Locks in the "Injectable seed parameter ... for 100% reproducible
## deterministic campaign runs" requirement: two independent runs of the
## same seed against a freshly reset session must reach byte-identical
## outcomes, not just the same win/loss verdict. Exercises every injectable
## roll _wire_deterministic_rolls() wires (loot, enemy composition/count,
## vacancy timers, recruitment class, minted instance ids) plus the
## per-battle seed derivation in _fight_objective().
func test_run_campaign_is_fully_deterministic_for_a_fixed_seed() -> void:
	var first := CampaignSimScript.new().run_campaign(7)
	GameSession.reset()
	var second := CampaignSimScript.new().run_campaign(7)

	assert_eq(first, second, "Identical seeds must produce byte-identical telemetry")


## Locks in the "reach victory on an explicitly listed representative seed
## set" requirement verbatim -- every seed here is expected to resolve
## (is_campaign_completed) via CampaignSim's own bot/gear/recruit/upgrade
## policy alone, deterministically. A regression that breaks the campaign's
## completability (a balance change, a policy bug) fails loudly here rather
## than only showing up as a lower make campaign-sim victory rate.
func test_run_campaign_reaches_victory_on_the_representative_seed_set() -> void:
	for seed in REPRESENTATIVE_VICTORY_SEEDS:
		GameSession.reset()
		var sim := CampaignSimScript.new()
		var record := sim.run_campaign(seed)
		assert_true(
			record.victory,
			"seed %d: expected campaign victory but got reason=%s (world_turns=%d, battles=%d/%d won, wipes=%d)"
			% [seed, record.reason, record.world_turns, record.battles_won, record.battles_fought, record.party_wipes]
		)
		assert_eq(record.reason, "victory")
		assert_true(GameSession.is_campaign_completed)


## --- Task 2: metrics collection and verification ---------------------------

func test_telemetry_records_accurate_battle_counts_gold_income_and_level_curves() -> void:
	var sim := CampaignSimScript.new()

	var record := sim.run_campaign(42)

	assert_eq(record.battles_fought, record.battles_won + record.party_wipes + record.stalemates)
	assert_true(record.battles_won >= GameSession.completed_encounters.size())
	assert_gt(record.gold_earned, 0, "A multi-battle campaign must have earned some gold")
	assert_false(record.party_level_curve.is_empty(), "At least one tier's average party level must be recorded")
	for key in record.party_level_curve:
		assert_gt(float(record.party_level_curve[key]), 0.0, "A recorded tier level must be a real average, not the empty-party sentinel 0.0")


func test_metrics_aggregate_reports_victory_rate_and_failed_seeds_across_runs() -> void:
	var sim := CampaignSimScript.new()
	var records: Array = []
	for seed in [1, 2]:
		GameSession.reset()
		records.append(sim.run_campaign(seed))

	var report := CampaignSimMetricsScript.aggregate(records)

	assert_eq(report.runs, 2)
	assert_eq(report.victories, 2)
	assert_almost_eq(report.victory_rate, 1.0, 0.001)
	assert_true(report.failed_seeds.is_empty())
	assert_gt(report.mean_world_turns, 0.0)
	assert_has(report, "mean_party_level_curve")
	assert_has(report, "gold")


func test_metric_output_generates_formatted_json_and_summary_report() -> void:
	var sim := CampaignSimScript.new()
	var report := CampaignSimMetricsScript.aggregate([sim.run_campaign(42)])

	var json_text := CampaignSimMetricsScript.to_json(report)
	var parsed = JSON.parse_string(json_text)
	assert_not_null(parsed, "to_json() output must be valid, parseable JSON")
	assert_true(parsed is Dictionary)
	assert_eq(int(parsed.runs), 1)

	var summary := CampaignSimMetricsScript.format_summary(report)
	assert_true(summary.begins_with("Campaign Simulation Summary"))
	assert_true(summary.contains("Victories:"))
	assert_true(summary.contains("Mean world turns"))
