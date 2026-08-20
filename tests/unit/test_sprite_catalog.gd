extends GutTest


func test_world_party_texture_is_non_null() -> void:
	assert_not_null(SpriteCatalog.get_unit_texture("world_party"), "world_party must resolve to a texture")


func test_player_class_textures_are_non_null() -> void:
	for visual_key in ["player_warrior", "player_scout", "player_cleric"]:
		assert_not_null(SpriteCatalog.get_unit_texture(visual_key), "%s must resolve to a texture" % visual_key)


func test_enemy_family_textures_are_non_null() -> void:
	for visual_key in ["enemy_goblin", "enemy_kobold", "enemy_orc", "enemy_hobgoblin", "enemy_ogre"]:
		assert_not_null(SpriteCatalog.get_unit_texture(visual_key), "%s must resolve to a texture" % visual_key)


func test_unknown_unit_key_falls_back_to_a_non_null_texture() -> void:
	var fallback: Texture2D = SpriteCatalog.get_unit_texture("not_a_real_key")

	assert_not_null(fallback, "Unknown keys must still resolve to a texture")
	assert_eq(fallback, SpriteCatalog.get_unit_texture("enemy_goblin"), "Unknown keys fall back to enemy_goblin")


func test_tile_textures_are_non_null_and_distinct() -> void:
	var light: Texture2D = SpriteCatalog.get_tile_texture(true)
	var dark: Texture2D = SpriteCatalog.get_tile_texture(false)

	assert_not_null(light, "Light tile texture must be non-null")
	assert_not_null(dark, "Dark tile texture must be non-null")
	assert_ne(light, dark, "Light and dark tile textures must be distinct")
