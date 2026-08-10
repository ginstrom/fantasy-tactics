class_name ReportCompare
extends RefCounted


static func compare(first: Dictionary, second: Dictionary) -> Dictionary:
	return {"equal": first == second, "first_summary": first.get("summary", {}), "second_summary": second.get("summary", {})}
