extends GutTest

## docs/plans/2026-08-20-placeholder-sprites/03-world-map-sprites-and-
## acceptance.md: wires the Step 1 SpriteCatalog into World Map's terrain and
## party-marker rendering. visual_key/the catalog are presentation-only --
## nothing here touches action legality, saved state, simulation output, or
## RNG. Route, settlement, encounter, selection, and Scout-intel *behavior*
## are exercised separately (and left unchanged) in test_world_map.gd; this
## file only asserts on the rendered sprites themselves.

const WorldMapScript := preload("res://scripts/world/world_map.gd")
const WorldMapScene := preload("res://scenes/world/world_map.tscn")


func before_each() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.depart_selected_party()


func after_each() -> void:
	GameSession.reset_injectable_rolls()
	AudioManager.reset()


func _instantiate_world_map() -> Node2D:
	var world_map: Node2D = WorldMapScene.instantiate()
	add_child_autofree(world_map)
	return world_map


## _ready() already drew tiles/markers once with its own auto-resolved party
## state; those children are queue_free()'d (deferred, not synchronous) by
## the explicit _draw_tiles()/_draw_markers() calls below, so they would
## still show up in get_children() right alongside the fresh set unless
## removed immediately here (mirrors the same workaround in
## test_battle_sprite_rendering.gd's _instantiate_bare_battlefield()).
func _instantiate_bare_world_map() -> Node2D:
	var world_map := _instantiate_world_map()
	for stale_child in world_map.get_node("Board/Tiles").get_children():
		stale_child.free()
	for stale_child in world_map.get_node("Board/Markers").get_children():
		stale_child.free()
	return world_map


func _sprite_children(container: Node) -> Array:
	var sprites: Array = []
	for child in container.get_children():
		if child is Sprite2D:
			sprites.append(child)
	return sprites


func test_draw_tiles_renders_49_catalog_backed_sprites_at_the_existing_64px_coordinates() -> void:
	var world_map := _instantiate_bare_world_map()

	world_map._draw_tiles()

	var tiles: Array = world_map.get_node("Board/Tiles").get_children()
	assert_eq(tiles.size(), 49, "The 7x7 board must render exactly 49 ground tiles")
	var light_texture: Texture2D = SpriteCatalog.get_tile_texture(true)
	var dark_texture: Texture2D = SpriteCatalog.get_tile_texture(false)
	assert_ne(light_texture, dark_texture)
	for tile in tiles:
		assert_true(tile is Sprite2D, "Each tile must be a catalog-backed Sprite2D")
		assert_not_null(tile.texture, "Every tile texture must be non-null")
		assert_eq(
			tile.scale, Vector2(4, 4), "Tiles must use the required integral 4x nearest-neighbor scale"
		)
		assert_false(
			tile.centered, "Tiles stay top-left anchored so position keeps meaning a tile's own corner"
		)
		var grid_pos := Vector2i(tile.position / WorldMapScript.TILE_SIZE)
		var expected_texture: Texture2D = light_texture if (grid_pos.x + grid_pos.y) % 2 == 0 else dark_texture
		assert_eq(tile.texture, expected_texture, "Tiles must alternate light/dark catalog ground textures")
		# Existing 64px coordinates (unchanged by this plan): position stays
		# an exact multiple of TILE_SIZE, same as the ColorRect it replaces.
		assert_eq(tile.position, Vector2(grid_pos) * WorldMapScript.TILE_SIZE)


func test_draw_markers_renders_the_party_as_one_bottom_centered_sprite_in_its_cell() -> void:
	var world_map := _instantiate_bare_world_map()

	world_map._draw_markers()

	var sprites: Array = _sprite_children(world_map.get_node("Board/Markers"))
	assert_eq(sprites.size(), 1, "Exactly one world_party Sprite2D must be drawn for the deployed party")
	var party_sprite: Sprite2D = sprites[0]
	assert_eq(party_sprite.texture, SpriteCatalog.get_unit_texture("world_party"))
	assert_eq(
		party_sprite.scale, Vector2(4, 4), "Party sprite must use the required integral 4x nearest-neighbor scale"
	)
	assert_eq(
		party_sprite.position, party_sprite.position.round(),
		"Sprite position must be pixel-integral on both axes -- no fractional placement"
	)
	var tile_origin: Vector2 = Vector2(world_map.party_position) * WorldMapScript.TILE_SIZE
	assert_almost_eq(
		party_sprite.position.x, tile_origin.x + WorldMapScript.TILE_SIZE / 2.0, 0.01,
		"The sprite must be horizontally centered on its tile"
	)
	var expected_bottom: float = tile_origin.y + WorldMapScript.TILE_SIZE
	var sprite_bottom: float = (
		party_sprite.position.y + (party_sprite.texture.get_height() * party_sprite.scale.y) / 2.0
	)
	assert_almost_eq(
		sprite_bottom, expected_bottom, 0.5,
		"The sprite's bottom edge must land on the tile's own bottom edge (bottom-centered)"
	)


func test_no_party_sprite_is_drawn_when_no_party_is_deployed() -> void:
	GameSession.reset()
	var world_map := _instantiate_bare_world_map()

	world_map._draw_markers()

	assert_eq(
		_sprite_children(world_map.get_node("Board/Markers")).size(), 0,
		"No world_party sprite should be drawn without a deployed party"
	)


## A Sprite2D carries no Control mouse_filter at all -- it can never
## participate in the GUI input pipeline the way the ColorRect it replaces
## did, so it is inherently non-interactive. This proves a click landing on
## the party's own cell (where the sprite is drawn) still reaches world_map's
## own tile-click handling rather than being silently absorbed by the
## marker's display node.
func test_party_marker_display_is_non_interactive_and_does_not_intercept_clicks() -> void:
	var world_map := _instantiate_world_map()
	assert_false(world_map.party_selected)

	world_map._handle_tile_click(world_map.party_position)

	assert_true(world_map.party_selected, "A click on the party's own tile must still select it")


func test_party_sprite_redraws_at_the_new_cell_after_a_committed_one_tile_move() -> void:
	var world_map := _instantiate_world_map()
	var target: Vector2i = world_map.party_position + Vector2i(1, 0)
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(target)

	world_map._handle_tile_click(target)
	await get_tree().process_frame

	assert_eq(world_map.party_position, target, "A committed one-tile route step must still move the party")
	assert_eq(GameSession.get_deployed_party_route(), [] as Array[Vector2i], "The spent route step must be consumed")
	var sprites: Array = _sprite_children(world_map.get_node("Board/Markers"))
	assert_eq(sprites.size(), 1, "Exactly one party sprite must remain after the redraw")
	var expected_x: float = Vector2(target).x * WorldMapScript.TILE_SIZE + WorldMapScript.TILE_SIZE / 2.0
	assert_almost_eq(
		sprites[0].position.x, expected_x, 0.01, "The redrawn sprite must sit over the party's new cell"
	)


func test_party_sprite_stays_put_after_setting_a_route_then_right_click_canceling_the_hover_preview() -> void:
	var world_map := _instantiate_world_map()
	var start: Vector2i = world_map.party_position
	world_map._handle_tile_click(world_map.party_position)
	world_map._handle_tile_click(start + Vector2i(1, 0))
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true

	world_map._unhandled_input(right_click)
	await get_tree().process_frame

	# Right-click only cancels the transient hover preview and deselects --
	# it does not clear a route that has already been committed (see
	# test_right_click_cancels_the_hover_preview_and_preserves_the_route in
	# test_world_map.gd) -- so the party stays at its pre-move cell and the
	# sprite must still be drawn there, unmoved by the cancel.
	assert_eq(GameSession.get_deployed_party_route(), [start + Vector2i(1, 0)])
	assert_eq(world_map.party_position, start, "Committing a route must not move the party until a step is taken")
	assert_false(world_map.party_selected)
	var sprites: Array = _sprite_children(world_map.get_node("Board/Markers"))
	assert_eq(sprites.size(), 1, "The party sprite must still be drawn after the hover preview is canceled")
	var expected_x: float = Vector2(start).x * WorldMapScript.TILE_SIZE + WorldMapScript.TILE_SIZE / 2.0
	assert_almost_eq(sprites[0].position.x, expected_x, 0.01)
