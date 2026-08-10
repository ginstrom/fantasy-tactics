class_name ReportAggregator
extends RefCounted


static func aggregate(records: Array, metadata: Dictionary = {}) -> Dictionary:
	var summary := {"runs": records.size(), "wins": 0, "losses": 0, "stalemates": 0, "errors": 0, "rounds_total": 0, "damage_total": 0}
	var groups_by_key := {}
	for record in records:
		match String(record.get("outcome", "error")):
			"victory": summary.wins += 1
			"defeat": summary.losses += 1
			"stalemate": summary.stalemates += 1
			_: summary.errors += 1
		summary.rounds_total += int(record.get("rounds", 0))
		summary.damage_total += int(record.get("damage", 0))
		var policy := String(record.get("policies", {}).get("player", ""))
		var group_key := "%s|%s" % [record.get("case_id", ""), policy]
		if not groups_by_key.has(group_key):
			groups_by_key[group_key] = {"case_id": record.get("case_id", ""), "player_policy": policy, "runs": 0, "wins": 0, "rounds_total": 0, "damage_total": 0}
		var group: Dictionary = groups_by_key[group_key]
		group.runs += 1
		group.wins += 1 if String(record.get("outcome", "")) == "victory" else 0
		group.rounds_total += int(record.get("rounds", 0))
		group.damage_total += int(record.get("damage", 0))
	summary["win_rate"] = float(summary.wins) / float(maxi(1, summary.wins + summary.losses + summary.stalemates))
	summary["mean_rounds"] = float(summary.rounds_total) / float(maxi(1, records.size()))
	summary["mean_damage"] = float(summary.damage_total) / float(maxi(1, records.size()))
	var groups: Array = groups_by_key.values()
	groups.sort_custom(func(a, b): return String(a.case_id) < String(b.case_id))
	return {"metadata": metadata.duplicate(true), "summary": summary, "groups": groups}
