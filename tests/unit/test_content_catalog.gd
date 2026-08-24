extends GutTest
## Stage 6 Step 3 (docs/plans/2026-08-24-stage-6-content-and-domain-
## foundations/03-authored-content-catalog.md). ContentCatalog is a pure,
## stateless loader: every test here builds its own throwaway manifest +
## encounter file(s) under user:// (a writable directory in headless test
## runs) rather than mutating the shipped config/content/ fixtures, except
## the "real catalog" linting tests at the bottom, which deliberately
## exercise the shipped res://config/content/catalog.json.

const ContentCatalogScript := preload("res://scripts/content/content_catalog.gd")
const WorldMapScript := preload("res://scripts/world/world_map.gd")

const FIXTURE_DIR := "user://test_content_catalog"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(FIXTURE_DIR)


func after_each() -> void:
	var dir := DirAccess.open(FIXTURE_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		dir.remove(file_name)
	DirAccess.remove_absolute(FIXTURE_DIR)


func _write(path: String, content) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if content is String:
		file.store_string(content)
	else:
		file.store_string(JSON.stringify(content))
	file.close()


func _write_manifest(encounter_paths: Array) -> String:
	var path := "%s/catalog.json" % FIXTURE_DIR
	_write(path, {"version": 1, "encounters": encounter_paths})
	return path


func _valid_encounter(overrides: Dictionary = {}) -> Dictionary:
	var encounter := {
		"id": "test_encounter",
		"name_key": "expedition.obj_tier1_1_goblin_outpost.name",
		"tier": 1,
		"category": "authored_objective",
		"world_position": {"x": 1, "y": 1},
		"grid_size": {"width": 7, "height": 7},
		"player_spawns": [{"x": 0, "y": 3}, {"x": 0, "y": 2}],
		"enemy_spawns": [{"x": 6, "y": 3}, {"x": 6, "y": 2}],
		"cover_tiles": [{"x": 3, "y": 3, "tier": "low"}],
		"enemy_composition": [{"template_id": "goblin", "count": 1}],
		"clear_xp": 15,
		"reward_bonus_multiplier": 1,
		"prerequisite_objective_id": "",
	}
	for key in overrides:
		encounter[key] = overrides[key]
	return encounter


func _write_encounter(file_name: String, overrides: Dictionary = {}) -> String:
	var path := "%s/%s.json" % [FIXTURE_DIR, file_name]
	_write(path, _valid_encounter(overrides))
	return path


## --- Happy path ---------------------------------------------------------

func test_loads_a_valid_catalog_manifest_and_encounter_file() -> void:
	var encounter_path := _write_encounter("goblin_outpost")
	var manifest_path := _write_manifest([encounter_path])

	var catalog := ContentCatalogScript.load_catalog(manifest_path)

	assert_true(catalog.valid, "Errors: %s" % [catalog.errors])
	assert_eq(catalog.errors, [] as Array[String])
	assert_eq(catalog.version, 1)
	assert_true(catalog.encounters.has("test_encounter"))
	var definition: Dictionary = catalog.encounters.test_encounter
	assert_eq(definition.id, "test_encounter")
	assert_eq(definition.world_position, Vector2i(1, 1))
	assert_eq(definition.grid_size, {"width": 7, "height": 7})
	assert_eq(definition.player_spawns, [Vector2i(0, 3), Vector2i(0, 2)] as Array[Vector2i])
	assert_eq(definition.enemy_spawns, [Vector2i(6, 3), Vector2i(6, 2)] as Array[Vector2i])
	assert_eq(definition.cover_tiles, {Vector2i(3, 3): "low"})
	assert_eq(definition.enemy_composition, [{"template_id": "goblin", "count": 1}] as Array[Dictionary])
	assert_eq(definition.clear_xp, 15)
	assert_eq(definition.reward_bonus_multiplier, 1.0)
	assert_eq(definition.prerequisite_objective_id, "")


func test_get_encounter_definition_returns_the_single_matching_definition() -> void:
	var encounter_path := _write_encounter("goblin_outpost")
	var manifest_path := _write_manifest([encounter_path])

	var definition := ContentCatalogScript.get_encounter_definition("test_encounter", manifest_path)

	assert_eq(definition.id, "test_encounter")


func test_get_encounter_definition_returns_empty_for_an_unknown_id() -> void:
	var encounter_path := _write_encounter("goblin_outpost")
	var manifest_path := _write_manifest([encounter_path])

	assert_eq(ContentCatalogScript.get_encounter_definition("no_such_id", manifest_path), {})


func test_a_missing_manifest_yields_a_clear_error_and_no_encounters() -> void:
	var catalog := ContentCatalogScript.load_catalog("%s/does_not_exist.json" % FIXTURE_DIR)

	assert_false(catalog.valid)
	assert_eq(catalog.encounters, {})
	assert_true(catalog.errors[0].begins_with("catalog_manifest:"))


## --- Rejection: duplicate ids --------------------------------------------

func test_rejects_two_encounter_files_declaring_the_same_id() -> void:
	var first := _write_encounter("first")
	var second := _write_encounter("second")
	var manifest_path := _write_manifest([first, second])

	var catalog := ContentCatalogScript.load_catalog(manifest_path)

	assert_false(catalog.valid)
	assert_true(_has_error(catalog.errors, "duplicate_id"))
	# First-seen wins; the later duplicate is rejected (reported as an error)
	# rather than silently overwriting it or being dropped entirely.
	assert_true(catalog.encounters.has("test_encounter"))


## --- Rejection: missing file paths ----------------------------------------

func test_rejects_a_manifest_entry_whose_file_does_not_exist() -> void:
	var manifest_path := _write_manifest(["%s/nonexistent.json" % FIXTURE_DIR])

	var catalog := ContentCatalogScript.load_catalog(manifest_path)

	assert_false(catalog.valid)
	assert_true(_has_error(catalog.errors, "missing_file"))
	assert_eq(catalog.encounters, {})


## --- Rejection: non-integer / out-of-bounds coordinates --------------------

func test_rejects_a_non_integer_coordinate() -> void:
	var path := _write_encounter("bad_coord", {"world_position": {"x": 1.5, "y": 1}})
	var manifest_path := _write_manifest([path])

	var catalog := ContentCatalogScript.load_catalog(manifest_path)

	assert_false(catalog.valid)
	assert_true(_has_error(catalog.errors, "invalid_coordinate"))


func test_rejects_a_coordinate_outside_the_encounters_own_grid() -> void:
	# grid_size is 7x7 (0..6); x=7 is one past the edge.
	var path := _write_encounter("out_of_bounds", {"player_spawns": [{"x": 7, "y": 0}]})
	var manifest_path := _write_manifest([path])

	var catalog := ContentCatalogScript.load_catalog(manifest_path)

	assert_false(catalog.valid)
	assert_true(_has_error(catalog.errors, "out_of_bounds"))


func test_rejects_a_negative_coordinate() -> void:
	var path := _write_encounter("negative_coord", {"enemy_spawns": [{"x": -1, "y": 0}]})
	var manifest_path := _write_manifest([path])

	var catalog := ContentCatalogScript.load_catalog(manifest_path)

	assert_false(catalog.valid)
	assert_true(_has_error(catalog.errors, "out_of_bounds"))


## --- Rejection: duplicate spawn points --------------------------------------

func test_rejects_a_duplicate_position_within_player_spawns() -> void:
	var path := _write_encounter("dup_player", {"player_spawns": [{"x": 0, "y": 0}, {"x": 0, "y": 0}]})
	var manifest_path := _write_manifest([path])

	var catalog := ContentCatalogScript.load_catalog(manifest_path)

	assert_false(catalog.valid)
	assert_true(_has_error(catalog.errors, "duplicate_spawn_point"))


func test_rejects_a_player_spawn_and_an_enemy_spawn_sharing_a_tile() -> void:
	var path := _write_encounter("shared_spawn", {
		"player_spawns": [{"x": 2, "y": 2}],
		"enemy_spawns": [{"x": 2, "y": 2}],
	})
	var manifest_path := _write_manifest([path])

	var catalog := ContentCatalogScript.load_catalog(manifest_path)

	assert_false(catalog.valid)
	assert_true(_has_error(catalog.errors, "duplicate_spawn_point"))


## --- Rejection: overlapping cover and spawn tiles ---------------------------

func test_rejects_a_cover_tile_that_coincides_with_a_spawn_tile() -> void:
	var path := _write_encounter("cover_overlap", {
		"player_spawns": [{"x": 0, "y": 3}],
		"cover_tiles": [{"x": 0, "y": 3, "tier": "low"}],
	})
	var manifest_path := _write_manifest([path])

	var catalog := ContentCatalogScript.load_catalog(manifest_path)

	assert_false(catalog.valid)
	assert_true(_has_error(catalog.errors, "overlapping_cover_and_spawn"))


## --- Rejection: unknown enemy template ids ----------------------------------

func test_rejects_an_unknown_enemy_template_id() -> void:
	var path := _write_encounter("unknown_template", {
		"enemy_composition": [{"template_id": "dragon", "count": 1}],
	})
	var manifest_path := _write_manifest([path])

	var catalog := ContentCatalogScript.load_catalog(manifest_path)

	assert_false(catalog.valid)
	assert_true(_has_error(catalog.errors, "unknown_enemy_template"))


## --- Rejection: circular objective prerequisites ----------------------------

func test_rejects_a_circular_prerequisite_chain() -> void:
	var a_path := "%s/a.json" % FIXTURE_DIR
	var b_path := "%s/b.json" % FIXTURE_DIR
	_write(a_path, _valid_encounter({"id": "node_a", "prerequisite_objective_id": "node_b"}))
	_write(b_path, _valid_encounter({"id": "node_b", "prerequisite_objective_id": "node_a"}))
	var manifest_path := _write_manifest([a_path, b_path])

	var catalog := ContentCatalogScript.load_catalog(manifest_path)

	assert_false(catalog.valid)
	assert_true(_has_error(catalog.errors, "circular_prerequisite"))


func test_rejects_an_encounter_that_names_itself_as_its_own_prerequisite() -> void:
	var path := _write_encounter("self_prereq", {"id": "node_self", "prerequisite_objective_id": "node_self"})
	var manifest_path := _write_manifest([path])

	var catalog := ContentCatalogScript.load_catalog(manifest_path)

	assert_false(catalog.valid)
	assert_true(_has_error(catalog.errors, "circular_prerequisite"))


## --- Enemy template resolution ---------------------------------------------

func test_resolve_enemy_template_returns_the_matching_gamesession_stats() -> void:
	assert_eq(ContentCatalogScript.resolve_enemy_template("goblin"), GameSession.GOBLIN_ENEMY_STATS)
	assert_eq(ContentCatalogScript.resolve_enemy_template("kobold"), GameSession.KOBOLD_ENEMY_STATS)
	assert_eq(ContentCatalogScript.resolve_enemy_template("no_such_template"), {})


## --- Content linting (Step 3 task 6) -----------------------------------

## Every catalog reference in the SHIPPED res://config/content/catalog.json
## must resolve cleanly -- proves the real shipped content, not just a
## throwaway fixture, is well-formed.
func test_the_shipped_catalog_resolves_with_no_errors() -> void:
	var catalog := ContentCatalogScript.load_catalog()

	assert_true(catalog.valid, "Errors: %s" % [catalog.errors])
	assert_true(catalog.encounters.has("obj_tier1_1_goblin_outpost"))


## Every shipped encounter's name_key must resolve to real, non-placeholder
## copy in translations/en.tres -- an authored id with a typo'd or missing
## key would otherwise silently render its own raw key string in the UI.
func test_every_shipped_encounters_name_key_resolves_in_translations() -> void:
	var catalog := ContentCatalogScript.load_catalog()

	for id in catalog.encounters:
		var definition: Dictionary = catalog.encounters[id]
		assert_ne(
			TranslationServer.translate(definition.name_key), definition.name_key,
			"%s's name_key \"%s\" must resolve to a real translation" % [id, definition.name_key]
		)


## Every shipped encounter's own coordinates must fit inside its declared
## board/world bounds -- load_catalog() already enforces this at load time
## (an out-of-bounds coordinate would show up as an error, not silently
## clamp), so a green catalog is sufficient proof.
func test_every_shipped_encounters_coordinates_fit_within_bounds() -> void:
	var catalog := ContentCatalogScript.load_catalog()

	for id in catalog.encounters:
		var definition: Dictionary = catalog.encounters[id]
		var grid_size: Dictionary = definition.grid_size
		for spawn in (definition.player_spawns as Array[Vector2i]) + (definition.enemy_spawns as Array[Vector2i]):
			assert_true(spawn.x >= 0 and spawn.x < grid_size.width, "%s spawn %s must fit grid width" % [id, spawn])
			assert_true(spawn.y >= 0 and spawn.y < grid_size.height, "%s spawn %s must fit grid height" % [id, spawn])
		assert_true(definition.world_position.x >= 0 and definition.world_position.x < WorldMapScript.GRID_WIDTH)
		assert_true(definition.world_position.y >= 0 and definition.world_position.y < WorldMapScript.GRID_HEIGHT)


## Guard-rail (mirrors scenario_contract.gd's own DEFAULT_BOARD_WIDTH/HEIGHT
## guard-rail test against BattleController): keeps ContentCatalog's world
## map bounds honest against WorldMap's real board constants rather than a
## hand-copied literal that could silently drift.
func test_world_map_bounds_mirror_world_maps_own_grid_constants() -> void:
	assert_eq(ContentCatalogScript.WORLD_MAP_WIDTH, WorldMapScript.GRID_WIDTH)
	assert_eq(ContentCatalogScript.WORLD_MAP_HEIGHT, WorldMapScript.GRID_HEIGHT)


func _has_error(errors: Array, category: String) -> bool:
	for error in errors:
		if String(error).begins_with(category + ":"):
			return true
	return false
