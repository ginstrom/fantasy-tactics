extends GutTest

const ReportAggregator := preload("res://scripts/tools/battle_scenarios/report_aggregator.gd")


func test_aggregate_counts_outcomes_and_groups_records_by_case_and_policy() -> void:
	var report := ReportAggregator.aggregate([
		{"case_id": "a", "policies": {"player": "greedy_pursuit"}, "outcome": "victory", "rounds": 2, "damage": 7, "survivors": {"player": [{"health": 5}], "enemy": []}},
		{"case_id": "a", "policies": {"player": "greedy_pursuit"}, "outcome": "stalemate", "rounds": 4, "damage": 3, "survivors": {"player": [{"health": 2}], "enemy": [{"health": 1}]}},
		{"case_id": "b", "policies": {"player": "greedy_pursuit"}, "outcome": "error", "rounds": 0, "damage": 0, "survivors": {"player": [], "enemy": []}},
	], {"raw_records_path": "records.jsonl", "command": "test"})

	assert_eq(report.summary.runs, 3)
	assert_eq(report.summary.wins, 1)
	assert_eq(report.summary.stalemates, 1)
	assert_eq(report.summary.errors, 1)
	assert_eq(report.summary.win_rate, 0.5)
	assert_eq(report.metadata.raw_records_path, "records.jsonl")
	assert_eq(report.groups.size(), 2)
