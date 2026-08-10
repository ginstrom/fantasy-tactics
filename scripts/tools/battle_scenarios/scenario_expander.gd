class_name ScenarioExpander
extends RefCounted
## Expands a raw scenario's optional top-level `matrix` (a named set of
## parameter axes, e.g. party size or monster count -- see the governing
## design's "Scenario contract" section) into individually identified,
## normalized, and validated concrete cases. A scenario with no `matrix`
## expands to exactly one case, whose id is its own scenario_id.
##
## Each returned case is a Dictionary:
##   {
##     "case_id": String,               -- stable, reproducible
##     "scenario": Dictionary,          -- ScenarioContract.normalize()d
##     "axis_values": Dictionary,       -- axis name -> value applied here
##     "errors": Array[String],         -- ScenarioContract.validate() output
##     "iteration_seeds": Array[int],   -- empty when `errors` is non-empty
##   }
##
## An invalid case is still returned (never silently dropped) with its
## `errors` populated and no iteration seeds -- see the design's "Invalid
## definitions fail the whole requested scenario with an actionable
## diagnostic; they do not yield plausible-looking partial numbers."
##
## Purely a data-shaping step: this file never constructs battle state (see
## battle_state_factory.gd) and never touches GameSession/GameConfig.

const ScenarioContractScript := preload("res://scripts/tools/battle_scenarios/scenario_contract.gd")


## Each matrix axis level is `{"value": <scalar>, "overrides": Dictionary}`.
## `value` is the human/CLI-facing label (e.g. an int party size, or a
## string monster name) recorded verbatim in the case id and in
## `axis_values`; `overrides` is deep-merged onto the base scenario for that
## axis. Axes are enumerated in sorted (alphabetical) name order, and levels
## within an axis in their declared order, so the resulting case list and
## ids are fully deterministic given the same raw input.
static func expand(raw: Dictionary) -> Array[Dictionary]:
	var scenario_id := String(raw.get("scenario_id", ""))
	var matrix: Dictionary = raw.get("matrix", {})
	var base: Dictionary = raw.duplicate(true)
	base.erase("matrix")

	var axis_names: Array = matrix.keys()
	axis_names.sort()

	var cases: Array[Dictionary] = []
	if axis_names.is_empty():
		cases.append(_build_case(scenario_id, base, {}))
	else:
		for combo in _cartesian(matrix, axis_names):
			var case_id := _case_id_for(scenario_id, axis_names, combo)
			var overridden := _apply_axis_overrides(base, axis_names, combo)
			cases.append(_build_case(case_id, overridden, _axis_values(axis_names, combo)))

	_flag_case_id_collisions(cases)
	return cases


static func _build_case(case_id: String, raw_case: Dictionary, axis_values: Dictionary) -> Dictionary:
	var single_case: Dictionary = raw_case.duplicate(true)
	single_case["scenario_id"] = case_id

	var scenario := ScenarioContractScript.normalize(single_case)
	var errors := ScenarioContractScript.validate(scenario)

	var iteration_seeds: Array[int] = []
	if errors.is_empty():
		var root_seed: int = scenario.randomness.root_seed
		var iterations: int = scenario.randomness.iterations
		for iteration_index in iterations:
			iteration_seeds.append(ScenarioContractScript.derive_iteration_seed(root_seed, case_id, iteration_index))

	return {
		"case_id": case_id,
		"scenario": scenario,
		"axis_values": axis_values,
		"errors": errors,
		"iteration_seeds": iteration_seeds,
	}


## Cross product of every axis's levels, one combo Dictionary
## (axis_name -> level) per resulting case. Built axis-by-axis in
## `axis_names`' (already-sorted) order so enumeration order is
## deterministic.
static func _cartesian(matrix: Dictionary, axis_names: Array) -> Array[Dictionary]:
	var combos: Array[Dictionary] = [{}]
	for axis_name in axis_names:
		var levels: Array = matrix[axis_name]
		var next_combos: Array[Dictionary] = []
		for combo in combos:
			for level in levels:
				var extended: Dictionary = combo.duplicate()
				extended[axis_name] = level
				next_combos.append(extended)
		combos = next_combos
	return combos


static func _case_id_for(scenario_id: String, axis_names: Array, combo: Dictionary) -> String:
	var parts: Array[String] = []
	for axis_name in axis_names:
		var level: Dictionary = combo[axis_name]
		parts.append("%s=%s" % [axis_name, str(level.get("value", ""))])
	return "%s__%s" % [scenario_id, ",".join(parts)]


static func _axis_values(axis_names: Array, combo: Dictionary) -> Dictionary:
	var values := {}
	for axis_name in axis_names:
		values[axis_name] = combo[axis_name].get("value")
	return values


static func _apply_axis_overrides(base: Dictionary, axis_names: Array, combo: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	for axis_name in axis_names:
		var level: Dictionary = combo[axis_name]
		var overrides: Dictionary = level.get("overrides", {})
		result = _deep_merge(result, overrides)
	return result


## Recursively merges `overrides` onto `base`: a Dictionary value merges key
## by key into the matching Dictionary field; any other value (including an
## Array, e.g. a full unit list) replaces the base field wholesale, which
## keeps override semantics predictable -- an axis that overrides
## `player.units` always states the complete unit list for that level
## rather than trying to splice individual unit entries.
static func _deep_merge(base: Dictionary, overrides: Dictionary) -> Dictionary:
	var merged: Dictionary = base.duplicate(true)
	for key in overrides:
		var value = overrides[key]
		if value is Dictionary and merged.get(key) is Dictionary:
			merged[key] = _deep_merge(merged[key], value)
		elif value is Dictionary or value is Array:
			merged[key] = value.duplicate(true)
		else:
			merged[key] = value
	return merged


## A case_id collision (two axis combinations producing the identical id --
## e.g. an authoring mistake giving two levels of the same axis the same
## `value`) is a duplicate-id problem, exactly like two units sharing an id
## within one scenario. Every colliding case is flagged, not just the
## second one, so no case silently looks more trustworthy than its twin.
static func _flag_case_id_collisions(cases: Array[Dictionary]) -> void:
	var seen_by_id := {}
	for single_case in cases:
		var case_id: String = single_case.case_id
		if seen_by_id.has(case_id):
			var message := "duplicate_id: case_id \"%s\" is produced by more than one axis combination" % case_id
			single_case.errors.append(message)
			single_case.iteration_seeds = []
			var earlier: Dictionary = seen_by_id[case_id]
			if not earlier.errors.has(message):
				earlier.errors.append(message)
				earlier.iteration_seeds = []
		else:
			seen_by_id[case_id] = single_case
