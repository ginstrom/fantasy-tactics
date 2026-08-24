extends GutTest

## Stage 6 Step 4 (docs/plans/2026-08-24-stage-6-content-and-domain-foundations/
## 04-branching-perk-definitions.md): DAG-shaped PerkCatalog behavior --
## prerequisite gating, mutual-exclusion, and catalog-data validation
## (circular prerequisites, invalid class ids, duplicate rank assignments,
## unrecognized effect descriptors), plus deterministic serialization of a
## chosen perk graph. PerkCatalog itself is pure/static (see perk_catalog.gd)
## so every test here constructs its own adventurer-shaped Dictionary rather
## than touching the live GameSession singleton.

const PerkCatalogScript := preload("res://scripts/progression/perk_catalog.gd")


func _adventurer(class_id: String, specialization_id: String, chosen_perks: Array) -> Dictionary:
	return {
		"class": class_id,
		"specialization": specialization_id,
		"progression": {"perks": chosen_perks.duplicate()},
	}


## --- Real shipped catalog: prerequisite gating -----------------------------

func test_knight_shield_bash_and_chain_blow_are_unavailable_before_discipline_is_chosen() -> void:
	var adventurer := _adventurer("warrior", "knight", [])
	assert_false(PerkCatalogScript.can_choose_perk(adventurer, "knight_shield_bash"))
	assert_false(PerkCatalogScript.can_choose_perk(adventurer, "knight_chain_blow"))
	assert_true(PerkCatalogScript.can_choose_perk(adventurer, "knight_discipline"))


func test_knight_shield_bash_becomes_available_once_discipline_is_chosen() -> void:
	var adventurer := _adventurer("warrior", "knight", ["knight_discipline"])
	assert_true(PerkCatalogScript.can_choose_perk(adventurer, "knight_shield_bash"))
	assert_true(PerkCatalogScript.can_choose_perk(adventurer, "knight_chain_blow"))


## --- Real shipped catalog: mutual exclusion --------------------------------

func test_choosing_shield_bash_permanently_excludes_chain_blow() -> void:
	var adventurer := _adventurer("warrior", "knight", ["knight_discipline", "knight_shield_bash"])
	assert_false(PerkCatalogScript.can_choose_perk(adventurer, "knight_chain_blow"))
	var available_ids: Array[String] = []
	for definition in PerkCatalogScript.get_available_perks(adventurer):
		available_ids.append(str(definition.id))
	assert_false(available_ids.has("knight_chain_blow"), "Excluded sibling must not appear in get_available_perks() either")


func test_choosing_chain_blow_permanently_excludes_shield_bash() -> void:
	var adventurer := _adventurer("warrior", "knight", ["knight_discipline", "knight_chain_blow"])
	assert_false(PerkCatalogScript.can_choose_perk(adventurer, "knight_shield_bash"))


## --- get_perk_status() (level_up.gd/unit_details.gd's locked/available/
## excluded/owned rendering, task 5) -----------------------------------------

func test_get_perk_status_reports_locked_before_discipline_and_available_after() -> void:
	var before_discipline := _adventurer("warrior", "knight", [])
	assert_eq(PerkCatalogScript.get_perk_status(before_discipline, "knight_shield_bash"), "locked")
	assert_eq(PerkCatalogScript.get_perk_status(before_discipline, "knight_discipline"), "available")

	var after_discipline := _adventurer("warrior", "knight", ["knight_discipline"])
	assert_eq(PerkCatalogScript.get_perk_status(after_discipline, "knight_shield_bash"), "available")


func test_get_perk_status_reports_excluded_for_the_unchosen_branch_and_owned_for_the_chosen_one() -> void:
	var adventurer := _adventurer("warrior", "knight", ["knight_discipline", "knight_shield_bash"])
	assert_eq(PerkCatalogScript.get_perk_status(adventurer, "knight_shield_bash"), "owned")
	assert_eq(PerkCatalogScript.get_perk_status(adventurer, "knight_chain_blow"), "excluded")


func test_get_perk_status_is_unknown_for_an_unrecognized_id() -> void:
	assert_eq(PerkCatalogScript.get_perk_status(_adventurer("warrior", "", []), "not_a_real_perk"), "unknown")


## --- apply_perk() -----------------------------------------------------------

func test_apply_perk_appends_the_perk_and_leaves_the_input_untouched() -> void:
	var adventurer := _adventurer("warrior", "knight", ["knight_discipline"])
	var updated := PerkCatalogScript.apply_perk(adventurer, "knight_shield_bash")
	assert_true((updated.progression.perks as Array).has("knight_shield_bash"))
	assert_false(
		(adventurer.progression.perks as Array).has("knight_shield_bash"), "apply_perk() must not mutate its input"
	)


func test_apply_perk_is_a_no_op_for_an_illegal_choice() -> void:
	var adventurer := _adventurer("warrior", "knight", [])
	var updated := PerkCatalogScript.apply_perk(adventurer, "knight_shield_bash")
	assert_eq(updated.progression.perks, [] as Array, "Discipline not yet chosen -- Shield Bash must not be applied")


## --- Non-Knight classes: empty prerequisite/exclusion sets are a no-op -----

func test_warrior_root_perks_have_no_prerequisite_or_exclusion_relationship() -> void:
	var adventurer := _adventurer("warrior", "", [])
	assert_true(PerkCatalogScript.can_choose_perk(adventurer, "warrior_juggernaut"))
	assert_true(PerkCatalogScript.can_choose_perk(adventurer, "warrior_bulwark"))
	var with_juggernaut := _adventurer("warrior", "", ["warrior_juggernaut"])
	assert_true(
		PerkCatalogScript.can_choose_perk(with_juggernaut, "warrior_bulwark"),
		"Warrior's two root perks must stay fully independent -- only Knight branches in Stage 6"
	)


## --- Catalog-data validation ------------------------------------------------

func test_validate_definitions_accepts_the_real_shipped_catalog() -> void:
	var errors := PerkCatalogScript.validate_definitions(PerkCatalogScript.get_definitions().values())
	assert_eq(errors, [] as Array[String], "The real shipped catalog must always be internally valid")


func test_validate_definitions_rejects_a_circular_prerequisite() -> void:
	var definitions: Array[Dictionary] = [
		{
			"id": "a", "class_id": "warrior", "tier": 1, "prerequisite_ids": ["b"] as Array[String],
			"mutually_exclusive_with": [] as Array[String], "rank_cap": 1, "name_key": "x", "description_key": "x",
			"effect_descriptor": {"type": "none"},
		},
		{
			"id": "b", "class_id": "warrior", "tier": 2, "prerequisite_ids": ["a"] as Array[String],
			"mutually_exclusive_with": [] as Array[String], "rank_cap": 1, "name_key": "x", "description_key": "x",
			"effect_descriptor": {"type": "none"},
		},
	]
	var errors := PerkCatalogScript.validate_definitions(definitions)
	assert_true(errors.any(func(e): return String(e).begins_with("circular_prerequisite")))


func test_validate_definitions_rejects_an_invalid_class_id() -> void:
	var definitions: Array[Dictionary] = [
		{
			"id": "a", "class_id": "not_a_real_class", "tier": 1, "prerequisite_ids": [] as Array[String],
			"mutually_exclusive_with": [] as Array[String], "rank_cap": 1, "name_key": "x", "description_key": "x",
			"effect_descriptor": {"type": "none"},
		},
	]
	var errors := PerkCatalogScript.validate_definitions(definitions)
	assert_true(errors.any(func(e): return String(e).begins_with("invalid_class_id")))


func test_validate_definitions_rejects_an_unrecognized_effect_descriptor() -> void:
	var definitions: Array[Dictionary] = [
		{
			"id": "a", "class_id": "warrior", "tier": 1, "prerequisite_ids": [] as Array[String],
			"mutually_exclusive_with": [] as Array[String], "rank_cap": 1, "name_key": "x", "description_key": "x",
			"effect_descriptor": {"type": "made_up_type"},
		},
	]
	var errors := PerkCatalogScript.validate_definitions(definitions)
	assert_true(errors.any(func(e): return String(e).begins_with("unrecognized_effect_descriptor")))


func test_validate_definitions_rejects_a_duplicate_rank_assignment() -> void:
	var definitions: Array[Dictionary] = [
		{
			"id": "a", "class_id": "warrior", "tier": 1, "prerequisite_ids": [] as Array[String],
			"mutually_exclusive_with": [] as Array[String], "rank_cap": 1, "name_key": "x", "description_key": "x",
			"effect_descriptor": {"type": "none"},
		},
		{
			"id": "a", "class_id": "warrior", "tier": 2, "prerequisite_ids": [] as Array[String],
			"mutually_exclusive_with": [] as Array[String], "rank_cap": 1, "name_key": "x", "description_key": "x",
			"effect_descriptor": {"type": "none"},
		},
	]
	var errors := PerkCatalogScript.validate_definitions(definitions)
	assert_true(
		errors.any(func(e): return String(e).begins_with("duplicate_rank")),
		"Two separate authored entries claiming the identical perk id is an authoring collision"
	)


func test_validate_definitions_allows_two_independent_perks_to_share_a_tier() -> void:
	var definitions: Array[Dictionary] = [
		{
			"id": "a", "class_id": "warrior", "tier": 1, "prerequisite_ids": [] as Array[String],
			"mutually_exclusive_with": [] as Array[String], "rank_cap": 1, "name_key": "x", "description_key": "x",
			"effect_descriptor": {"type": "none"},
		},
		{
			"id": "b", "class_id": "warrior", "tier": 1, "prerequisite_ids": [] as Array[String],
			"mutually_exclusive_with": [] as Array[String], "rank_cap": 1, "name_key": "x", "description_key": "x",
			"effect_descriptor": {"type": "none"},
		},
	]
	var errors := PerkCatalogScript.validate_definitions(definitions)
	assert_eq(
		errors, [] as Array[String],
		"Two independent, non-exclusive perks (e.g. Warrior's own Juggernaut/Bulwark) sharing a tier is not an error"
	)


## --- Deterministic serialization/deserialization ---------------------------

func test_serialize_chosen_perks_is_deterministic_regardless_of_choice_order() -> void:
	var forward := PerkCatalogScript.serialize_chosen_perks(["knight_discipline", "knight_shield_bash"])
	var backward := PerkCatalogScript.serialize_chosen_perks(["knight_shield_bash", "knight_discipline"])
	assert_eq(forward, backward)


func test_is_valid_perk_graph_accepts_a_legally_reachable_graph_in_any_array_order() -> void:
	assert_true(PerkCatalogScript.is_valid_perk_graph(["knight_discipline", "knight_shield_bash"]))
	assert_true(
		PerkCatalogScript.is_valid_perk_graph(["knight_shield_bash", "knight_discipline"]),
		"DAG validity must not depend on array order -- only on reachability"
	)


func test_is_valid_perk_graph_rejects_a_perk_missing_its_prerequisite() -> void:
	assert_false(PerkCatalogScript.is_valid_perk_graph(["knight_shield_bash"]))


func test_is_valid_perk_graph_rejects_a_mutually_exclusive_pair() -> void:
	assert_false(
		PerkCatalogScript.is_valid_perk_graph(["knight_discipline", "knight_shield_bash", "knight_chain_blow"]),
		"A hand-edited save claiming BOTH branches of a mutually exclusive pair must be rejected"
	)


func test_is_valid_perk_graph_accepts_the_empty_graph_and_independent_flat_perks() -> void:
	assert_true(PerkCatalogScript.is_valid_perk_graph([]))
	assert_true(PerkCatalogScript.is_valid_perk_graph(["warrior_juggernaut", "warrior_bulwark"]))
