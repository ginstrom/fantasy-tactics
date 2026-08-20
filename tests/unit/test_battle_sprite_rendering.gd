extends GutTest

## docs/plans/2026-08-20-placeholder-sprites/02-battlefield-sprites.md: wires
## the Step 1 SpriteCatalog into Battlefield's tile and unit rendering.
## visual_key/the catalog are presentation-only -- nothing here touches
## action legality, saved state, simulation output, or RNG.

const UnitScript := preload("res://scripts/battle/unit.gd")
const BattleControllerScript := preload("res://scripts/battle/battle_controller.gd")
const BattlefieldScene := preload("res://scenes/battle/battlefield.tscn")


func before_each() -> void:
	GameSession.reset()
	AudioManager.reset()


func after_each() -> void:
	GameSession.reset_injectable_rolls()
	AudioManager.reset()


func _instantiate_bare_battlefield() -> Node2D:
	var battlefield: Node2D = BattlefieldScene.instantiate()
	add_child_autofree(battlefield)
	var controller: Node2D = battlefield.grid
	# Battlefield._ready() already populated unit_container/shadow_container
	# once with its own auto-spawned units; those children are queue_free()'d
	# (deferred, not synchronous), so they would still show up in
	# get_children() below alongside our own scenario's nodes unless removed
	# immediately here (see the same workaround in test_battle_controller.gd).
	for stale_child in controller.unit_container.get_children():
		stale_child.free()
	for stale_child in controller.shadow_container.get_children():
		stale_child.free()
	for stale_child in controller.tile_container.get_children():
		stale_child.free()
	return controller


func _sprite_children(container: Node) -> Array:
	var sprites: Array = []
	for child in container.get_children():
		if child is Sprite2D:
			sprites.append(child)
	return sprites


func test_draw_units_creates_one_catalog_backed_sprite_per_living_unit_at_the_required_scale() -> void:
	var controller := _instantiate_bare_battlefield()
	var player_unit := UnitScript.new(Vector2i(1, 1), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	player_unit.visual_key = "player_warrior"
	var enemy_unit := UnitScript.new(Vector2i(4, 4), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6)
	enemy_unit.visual_key = "enemy_kobold"
	controller.units = [player_unit, enemy_unit]

	controller._draw_units()

	var sprites: Array = _sprite_children(controller.unit_container)
	assert_eq(sprites.size(), 2, "One Sprite2D per living unit")
	for sprite in sprites:
		assert_not_null(sprite.texture, "Every unit sprite must carry a catalog texture")
		assert_eq(
			sprite.scale, Vector2(4, 4), "Unit sprites must use the required integral 4x nearest-neighbor scale"
		)
	var player_sprite: Sprite2D = sprites[0] if sprites[0].texture == SpriteCatalog.get_unit_texture("player_warrior") else sprites[1]
	var enemy_sprite: Sprite2D = sprites[1] if player_sprite == sprites[0] else sprites[0]
	assert_eq(player_sprite.texture, SpriteCatalog.get_unit_texture("player_warrior"))
	assert_eq(enemy_sprite.texture, SpriteCatalog.get_unit_texture("enemy_kobold"))


func test_draw_units_bottom_anchors_the_sprite_to_its_shadow_baseline() -> void:
	var controller := _instantiate_bare_battlefield()
	var unit := UnitScript.new(Vector2i(2, 2), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	unit.visual_key = "player_warrior"
	controller.units = [unit]

	controller._draw_units()

	var sprites: Array = _sprite_children(controller.unit_container)
	assert_eq(sprites.size(), 1)
	var sprite: Sprite2D = sprites[0]
	var shadow: ColorRect = controller.shadow_container.get_child(0)
	var shadow_baseline: float = shadow.position.y + shadow.size.y
	var sprite_bottom: float = sprite.position.y + (sprite.texture.get_height() * sprite.scale.y) / 2.0
	assert_almost_eq(
		sprite_bottom, shadow_baseline, 0.01, "The sprite's bottom edge must meet the existing shadow baseline"
	)
	assert_almost_eq(
		sprite.position.x, Vector2(unit.grid_position).x * BattleControllerScript.TILE_SIZE + BattleControllerScript.TILE_SIZE / 2.0,
		0.01, "The sprite must be horizontally centered on its tile"
	)


func test_draw_units_draws_the_lower_row_unit_sprite_over_the_upper_row_unit_sprite() -> void:
	var controller := _instantiate_bare_battlefield()
	var upper_unit := UnitScript.new(Vector2i(1, 0), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	upper_unit.visual_key = "player_warrior"
	var lower_unit := UnitScript.new(Vector2i(1, 3), Color.INDIAN_RED, BattleControllerScript.Side.ENEMY, 6)
	lower_unit.visual_key = "enemy_goblin"
	# Insertion order is deliberately reversed from row order, so a passing
	# assertion proves _draw_units() draws in row order rather than merely
	# preserving `units`' own array order.
	controller.units = [lower_unit, upper_unit]

	controller._draw_units()

	var upper_texture: Texture2D = SpriteCatalog.get_unit_texture("player_warrior")
	var lower_texture: Texture2D = SpriteCatalog.get_unit_texture("enemy_goblin")
	var upper_index := -1
	var lower_index := -1
	for sprite in _sprite_children(controller.unit_container):
		if sprite.texture == upper_texture:
			upper_index = sprite.get_index()
		elif sprite.texture == lower_texture:
			lower_index = sprite.get_index()
	assert_true(upper_index != -1 and lower_index != -1, "Both row sprites must be present")
	assert_true(
		lower_index > upper_index,
		"The lower-row (larger grid_position.y) unit's sprite must draw after -- i.e. on top of -- the upper row's"
	)


func test_draw_units_attaches_a_correctly_placed_high_contrast_facing_indicator_to_each_sprite() -> void:
	var controller := _instantiate_bare_battlefield()
	var unit := UnitScript.new(Vector2i(2, 3), Color.CORNFLOWER_BLUE, BattleControllerScript.Side.PLAYER, 6)
	unit.visual_key = "player_warrior"
	unit.set_facing(Vector2i.RIGHT)
	controller.units = [unit]

	controller._draw_units()

	var indicator: ColorRect = null
	for child in controller.unit_container.get_children():
		if str(child.name).begins_with("FacingIndicator"):
			indicator = child
	assert_not_null(indicator, "Every unit must have a FacingIndicator")
	assert_eq(
		indicator.color, BattleControllerScript.FACING_INDICATOR_COLOR, "The indicator must stay high-contrast"
	)
	var tile_center: Vector2 = (
		Vector2(unit.grid_position) * BattleControllerScript.TILE_SIZE
		+ Vector2(BattleControllerScript.TILE_SIZE, BattleControllerScript.TILE_SIZE) / 2.0
	)
	var indicator_center: Vector2 = indicator.position + indicator.size / 2.0
	assert_true(
		indicator_center.x > tile_center.x, "RIGHT facing must offset the indicator toward its own tile's right edge"
	)
	assert_almost_eq(
		indicator_center.y, tile_center.y, 0.01, "A purely horizontal facing must not offset the indicator vertically"
	)


func test_draw_tiles_uses_non_null_alternating_catalog_textures_for_all_thirty_six_tiles() -> void:
	var controller := _instantiate_bare_battlefield()

	controller._draw_tiles()

	var tiles: Array = controller.tile_container.get_children()
	assert_eq(tiles.size(), 36, "The 6x6 board must render exactly 36 ground tiles")
	var light_texture: Texture2D = SpriteCatalog.get_tile_texture(true)
	var dark_texture: Texture2D = SpriteCatalog.get_tile_texture(false)
	assert_ne(light_texture, dark_texture)
	for tile in tiles:
		assert_true(tile is Sprite2D, "Each tile must be a catalog-backed Sprite2D")
		assert_not_null(tile.texture, "Every tile texture must be non-null")
		var grid_pos := Vector2i(tile.position / BattleControllerScript.TILE_SIZE)
		var expected_texture: Texture2D = light_texture if (grid_pos.x + grid_pos.y) % 2 == 0 else dark_texture
		assert_eq(tile.texture, expected_texture, "Tiles must alternate light/dark catalog ground textures")
